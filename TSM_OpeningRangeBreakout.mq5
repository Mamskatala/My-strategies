//+------------------------------------------------------------------+
//|                                    TSM_OpeningRangeBreakout.mq5 |
//|      M15 Reference + M5 Breakout/ReturnToLevel/Confirm - SELL  |
//|                    Strict State Machine v5.0                    |
//+------------------------------------------------------------------+
#property copyright "TSM Opening Range Breakout"
#property link      ""
#property version   "5.00"
#property description "M15 Ref + M5 Breakout/ReturnToLevel/BearConfirm - SELL Only"

#include <Trade\Trade.mqh>

//--- Inputs
input int    LookbackSwing         = 10;     // N M5 bars for swing high SL
input int    BufferSLPoints        = 50;     // SL buffer above recent high (points)
input int    MinSLPoints           = 100;    // Minimum SL distance (points)
input int    RetestTolerancePoints = 30;     // Touch zone tolerance (points)
input int    FixedTP_Pips          = 50;     // Take Profit (pips)
input double Lots                  = 0.10;   // Lot size
input int    MagicNumber           = 54321;  // Magic number
input int    MaxSlippagePoints     = 30;     // Max slippage (points)
input int    RefHour               = 0;      // Reference M15 candle hour (server)
input int    RefMinute             = 0;      // Reference M15 candle minute (server)
input bool   DrawRefLines          = true;   // Draw RefHigh / RefLow lines
input int    MaxBarsToReturn       = 6;      // Max M5 bars after breakout to return to level
input bool   CancelSetupIfExpired  = true;   // Cancel setup if return window expires

//--- State Machine (RETURN_TO_LEVEL — no "retest" term)
enum ENUM_ORB_STATE
{
   WAIT_REF_M15_CLOSE,     // State 0: Waiting for M15 reference candle close
   WAIT_BREAKOUT,          // State 1: Waiting for M5 breakout below RefLow
   WAIT_RETURN_TO_LEVEL,   // State 2: Waiting for price to return to RefLow touch zone
   WAIT_BEAR_CONFIRM,      // State 3: Waiting for bearish confirmation candle
   TRADE_DONE              // State 4: Trade executed, no more trading today
};

ENUM_ORB_STATE CurrentState = WAIT_REF_M15_CLOSE;

//--- Reference levels
double RefHigh = 0.0;
double RefLow  = 0.0;

//--- Tracking
datetime LastM5BarTime  = 0;
datetime CurrentDayDate = 0;

//--- Breakout timing (for return-to-level window)
datetime BreakoutTime       = 0;   // open time of the M5 bar that confirmed breakout
int      BarsSinceBreakout  = 0;

//--- Trade object
CTrade trade;

//+------------------------------------------------------------------+
//| Pip multiplier: 1 pip = 10 points for 5/3-digit brokers          |
//+------------------------------------------------------------------+
int PipMultiplier()
{
   return (_Digits == 5 || _Digits == 3) ? 10 : 1;
}

//+------------------------------------------------------------------+
//| Expert initialization                                            |
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(MaxSlippagePoints);

   Print("=== TSM ORB v5.00 initialized (SELL ONLY - RETURN_TO_LEVEL State Machine) ===");
   Print("Symbol: ", _Symbol, " | Digits: ", _Digits, " | PipMult: ", PipMultiplier());
   Print("RefHour: ", RefHour, ":", (RefMinute < 10 ? "0" : ""), RefMinute);
   Print("FixedTP_Pips: ", FixedTP_Pips, " | LookbackSwing: ", LookbackSwing);
   Print("TolerancePoints: ", RetestTolerancePoints);
   Print("MaxBarsToReturn: ", MaxBarsToReturn, " | CancelIfExpired: ", CancelSetupIfExpired);
   Print("Lots: ", DoubleToString(Lots, 2), " | Magic: ", MagicNumber);

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectDelete(0, "ORB_RefHigh");
   ObjectDelete(0, "ORB_RefLow");
   Print("=== TSM ORB v5.00 deinitialized ===");
}

//+------------------------------------------------------------------+
//| OnTester - custom optimization criterion                         |
//+------------------------------------------------------------------+
double OnTester()
{
   double netProfit    = TesterStatistics(STAT_PROFIT);
   double grossProfit  = TesterStatistics(STAT_GROSS_PROFIT);
   double grossLoss    = TesterStatistics(STAT_GROSS_LOSS);
   double maxDrawdown  = TesterStatistics(STAT_EQUITY_DD);
   int    totalTrades  = (int)TesterStatistics(STAT_TRADES);

   if(totalTrades < 5)
      return 0.0;

   double profitFactor = 0.0;
   if(MathAbs(grossLoss) > 0.0)
      profitFactor = grossProfit / MathAbs(grossLoss);

   double recoveryFactor = 0.0;
   if(maxDrawdown > 0.0)
      recoveryFactor = netProfit / maxDrawdown;

   double criterion = profitFactor * MathSqrt((double)totalTrades) * MathMax(recoveryFactor, 0.0);

   Print("=== OnTester === Trades: ", totalTrades,
         " PF: ", DoubleToString(profitFactor, 2),
         " Recovery: ", DoubleToString(recoveryFactor, 2),
         " Criterion: ", DoubleToString(criterion, 4));

   return criterion;
}

//+------------------------------------------------------------------+
//| OnTesterInit - log optimization guidance at start                 |
//+------------------------------------------------------------------+
void OnTesterInit()
{
   Print("=== OPTIMIZATION STARTED ===");
   Print("To optimize: go to Strategy Tester -> Inputs tab");
   Print("Check the box next to each parameter you want to optimize");
   Print("Set Start / Step / Stop values for each checked parameter");
   Print("Recommended parameters to optimize:");
   Print("  LookbackSwing:         Start=5   Step=5   Stop=30");
   Print("  BufferSLPoints:        Start=10  Step=10  Stop=100");
   Print("  RetestTolerancePoints: Start=10  Step=10  Stop=60");
   Print("  FixedTP_Pips:          Start=20  Step=10  Stop=100");
   Print("  MaxBarsToReturn:       Start=3   Step=1   Stop=12");
}

//+------------------------------------------------------------------+
//| OnTesterDeinit - log optimization completion                      |
//+------------------------------------------------------------------+
void OnTesterDeinit()
{
   Print("=== OPTIMIZATION COMPLETED ===");
}

//+------------------------------------------------------------------+
//| ResetDailyState - reset state machine for new day                |
//+------------------------------------------------------------------+
void ResetDailyState()
{
   CurrentState       = WAIT_REF_M15_CLOSE;
   RefHigh            = 0.0;
   RefLow             = 0.0;
   BreakoutTime       = 0;
   BarsSinceBreakout  = 0;
   LastM5BarTime      = 0;  // reset so first bar of new day is detected

   ObjectDelete(0, "ORB_RefHigh");
   ObjectDelete(0, "ORB_RefLow");

   Print("--- DAILY RESET --- State -> WAIT_REF_M15_CLOSE");
}

//+------------------------------------------------------------------+
//| DetectAndSetReferenceM15 - find reference M15 candle (closed)    |
//+------------------------------------------------------------------+
void DetectAndSetReferenceM15()
{
   if(CurrentState != WAIT_REF_M15_CLOSE)
      return;

   datetime serverTime = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(serverTime, dt);

   dt.hour = RefHour;
   dt.min  = RefMinute;
   dt.sec  = 0;
   datetime refBarTime = StructToTime(dt);

   datetime refCloseTime = refBarTime + 15 * 60;

   if(serverTime < refCloseTime)
      return;

   int shift = iBarShift(_Symbol, PERIOD_M15, refBarTime, true);
   if(shift < 0)
   {
      Print("DetectAndSetReferenceM15: Cannot find M15 bar at ", TimeToString(refBarTime));
      return;
   }

   datetime barOpenTime = iTime(_Symbol, PERIOD_M15, shift);
   if(barOpenTime != refBarTime)
   {
      Print("DetectAndSetReferenceM15: M15 bar time mismatch. Expected: ",
            TimeToString(refBarTime), " Got: ", TimeToString(barOpenTime));
      return;
   }

   if(serverTime < barOpenTime + 15 * 60)
   {
      Print("DetectAndSetReferenceM15: Reference M15 bar not yet closed.");
      return;
   }

   RefHigh = iHigh(_Symbol, PERIOD_M15, shift);
   RefLow  = iLow(_Symbol, PERIOD_M15, shift);

   // Transition: WAIT_REF_M15_CLOSE -> WAIT_BREAKOUT
   CurrentState = WAIT_BREAKOUT;

   Print("=== M15 REFERENCE SET === State -> WAIT_BREAKOUT");
   Print("  Time: ", TimeToString(barOpenTime));
   Print("  RefHigh: ", DoubleToString(RefHigh, _Digits));
   Print("  RefLow:  ", DoubleToString(RefLow, _Digits));

   if(DrawRefLines)
   {
      ObjectDelete(0, "ORB_RefHigh");
      ObjectDelete(0, "ORB_RefLow");

      ObjectCreate(0, "ORB_RefHigh", OBJ_HLINE, 0, 0, RefHigh);
      ObjectSetInteger(0, "ORB_RefHigh", OBJPROP_COLOR, clrLimeGreen);
      ObjectSetInteger(0, "ORB_RefHigh", OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, "ORB_RefHigh", OBJPROP_WIDTH, 1);

      ObjectCreate(0, "ORB_RefLow", OBJ_HLINE, 0, 0, RefLow);
      ObjectSetInteger(0, "ORB_RefLow", OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, "ORB_RefLow", OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, "ORB_RefLow", OBJPROP_WIDTH, 1);
   }
}

//+------------------------------------------------------------------+
//| IsNewClosedM5Bar - check if a new M5 bar just closed             |
//+------------------------------------------------------------------+
bool IsNewClosedM5Bar()
{
   datetime barTime = iTime(_Symbol, PERIOD_M5, 0);
   if(barTime == 0)
      return false;

   if(barTime != LastM5BarTime)
   {
      LastM5BarTime = barTime;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| CheckBreakoutM5 - bar[1] close < RefLow (closed bar only)        |
//|                                                                  |
//| BreakoutValid = (Close[1] < RefLow)                              |
//| GUARD: SELL is FORBIDDEN in this state                           |
//+------------------------------------------------------------------+
void CheckBreakoutM5()
{
   if(CurrentState != WAIT_BREAKOUT)
      return;

   double closeBar1 = iClose(_Symbol, PERIOD_M5, 1);
   if(closeBar1 < RefLow)
   {
      // Store breakout bar time for return-to-level window
      BreakoutTime = iTime(_Symbol, PERIOD_M5, 1);
      BarsSinceBreakout = 0;

      // Transition: WAIT_BREAKOUT -> WAIT_RETURN_TO_LEVEL
      CurrentState = WAIT_RETURN_TO_LEVEL;
      Print("BREAKOUT OK at ", TimeToString(BreakoutTime), " -> WAIT_RETURN_TO_LEVEL");
      Print("  M5 bar[1] Close: ", DoubleToString(closeBar1, _Digits),
            " < RefLow: ", DoubleToString(RefLow, _Digits));
   }
}

//+------------------------------------------------------------------+
//| CheckReturnToLevel - price returns up to RefLow touch zone       |
//|                                                                  |
//| ReturnToLevelValid =                                             |
//|   High[1]  >= RefLow - Tol   (price came back up to the level)   |
//|   Close[1] <= RefLow + Tol   (close held in/below zone)          |
//|                                                                  |
//| TEMPORAL WINDOW: must occur within MaxBarsToReturn M5 bars       |
//| GUARD: SELL is FORBIDDEN in this state                           |
//| GUARD: must happen AFTER BreakoutValid (enforced by state)       |
//+------------------------------------------------------------------+
void CheckReturnToLevel()
{
   if(CurrentState != WAIT_RETURN_TO_LEVEL)
      return;

   // --- Count bars since breakout (closed bars only) ---
   if(BreakoutTime > 0)
   {
      int breakoutShift = iBarShift(_Symbol, PERIOD_M5, BreakoutTime, false);
      if(breakoutShift > 0)
         BarsSinceBreakout = breakoutShift - 1;  // exclude the breakout bar itself
   }

   // --- Check temporal window expiration ---
   if(CancelSetupIfExpired && BarsSinceBreakout >= MaxBarsToReturn)
   {
      CurrentState = TRADE_DONE;
      Print("SETUP CANCELLED: no return within ", MaxBarsToReturn, " M5 bars");
      Print("  BarsSinceBreakout: ", BarsSinceBreakout,
            " | BreakoutTime: ", TimeToString(BreakoutTime));
      return;
   }

   double highBar1  = iHigh(_Symbol, PERIOD_M5, 1);
   double closeBar1 = iClose(_Symbol, PERIOD_M5, 1);
   double tolerance = RetestTolerancePoints * _Point;

   // Check if price returned UP to the RefLow touch zone
   // High must reach within tolerance below RefLow (price came back up)
   // Close must stay at or below RefLow plus tolerance (didn't break back above)
   if(highBar1 >= RefLow - tolerance && closeBar1 <= RefLow + tolerance)
   {
      // Transition: WAIT_RETURN_TO_LEVEL -> WAIT_BEAR_CONFIRM
      CurrentState = WAIT_BEAR_CONFIRM;
      Print("RETURN TO LEVEL OK -> WAIT_BEAR_CONFIRM");
      Print("  M5 bar[1] High: ", DoubleToString(highBar1, _Digits),
            " >= RefLow-Tol: ", DoubleToString(RefLow - tolerance, _Digits));
      Print("  M5 bar[1] Close: ", DoubleToString(closeBar1, _Digits),
            " <= RefLow+Tol: ", DoubleToString(RefLow + tolerance, _Digits));
   }
   else
   {
      int barsRemaining = MaxBarsToReturn - BarsSinceBreakout;
      Print("  Return-to-level check: High=", DoubleToString(highBar1, _Digits),
            " Close=", DoubleToString(closeBar1, _Digits),
            " | TouchZone=[", DoubleToString(RefLow - tolerance, _Digits),
            ",", DoubleToString(RefLow + tolerance, _Digits),
            "] -> NOT yet (", BarsSinceBreakout, "/", MaxBarsToReturn,
            " bars, ", barsRemaining, " remaining)");
   }
}

//+------------------------------------------------------------------+
//| CheckBearishConfirmationM5 - bar[1] bearish + close < RefLow     |
//|                                                                  |
//| BearConfirmValid = (Close[1] < Open[1]) AND (Close[1] < RefLow)  |
//| GUARD: can only fire in WAIT_BEAR_CONFIRM state                  |
//+------------------------------------------------------------------+
bool CheckBearishConfirmationM5()
{
   if(CurrentState != WAIT_BEAR_CONFIRM)
      return false;

   double openBar1  = iOpen(_Symbol, PERIOD_M5, 1);
   double closeBar1 = iClose(_Symbol, PERIOD_M5, 1);

   if(closeBar1 < openBar1 && closeBar1 < RefLow)
   {
      Print("BEAR CONFIRM OK -> OPEN SELL");
      Print("  M5 bar[1] Open: ", DoubleToString(openBar1, _Digits),
            " Close: ", DoubleToString(closeBar1, _Digits),
            " < RefLow: ", DoubleToString(RefLow, _Digits));
      return true;
   }

   Print("  Bear confirm check: Open=", DoubleToString(openBar1, _Digits),
         " Close=", DoubleToString(closeBar1, _Digits),
         " RefLow=", DoubleToString(RefLow, _Digits), " -> NOT yet");
   return false;
}

//+------------------------------------------------------------------+
//| CalculateRecentHighSL - highest high of N closed M5 bars + buffer|
//+------------------------------------------------------------------+
double CalculateRecentHighSL()
{
   double highestHigh = 0.0;
   for(int i = 1; i <= LookbackSwing; i++)
   {
      double high_i = iHigh(_Symbol, PERIOD_M5, i);
      if(high_i > highestHigh)
         highestHigh = high_i;
   }

   double sl = highestHigh + BufferSLPoints * _Point;
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickSize > 0)
      sl = NormalizeDouble(MathCeil(sl / tickSize) * tickSize, _Digits);
   else
      sl = NormalizeDouble(sl, _Digits);

   Print("  CalculateRecentHighSL: HighestHigh=", DoubleToString(highestHigh, _Digits),
         " Buffer=", BufferSLPoints, "pts => SL=", DoubleToString(sl, _Digits));
   return sl;
}

//+------------------------------------------------------------------+
//| CalculateTPFromPips - entry - fixed pips (SELL direction)         |
//+------------------------------------------------------------------+
double CalculateTPFromPips(double entryPrice)
{
   double tp = entryPrice - FixedTP_Pips * PipMultiplier() * _Point;
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickSize > 0)
      tp = NormalizeDouble(MathRound(tp / tickSize) * tickSize, _Digits);
   else
      tp = NormalizeDouble(tp, _Digits);

   Print("  CalculateTPFromPips: Entry=", DoubleToString(entryPrice, _Digits),
         " - ", FixedTP_Pips, " pips => TP=", DoubleToString(tp, _Digits));
   return tp;
}

//+------------------------------------------------------------------+
//| HasTradedToday - check if magic already has a trade today        |
//+------------------------------------------------------------------+
bool HasTradedToday()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol)
      {
         if((int)PositionGetInteger(POSITION_MAGIC) == MagicNumber)
            return true;
      }
   }

   MqlDateTime dtDay;
   TimeToStruct(TimeCurrent(), dtDay);
   dtDay.hour = 0;
   dtDay.min  = 0;
   dtDay.sec  = 0;
   datetime startOfDay = StructToTime(dtDay);

   HistorySelect(startOfDay, TimeCurrent());
   int totalDeals = HistoryDealsTotal();
   for(int i = totalDeals - 1; i >= 0; i--)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;
      if(HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol) continue;
      if((int)HistoryDealGetInteger(ticket, DEAL_MAGIC) != MagicNumber) continue;
      int dealEntry = (int)HistoryDealGetInteger(ticket, DEAL_ENTRY);
      if(dealEntry == DEAL_ENTRY_IN)
         return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| ExecuteSellOrder - place SELL market order with SL/TP             |
//|                                                                  |
//| ABSOLUTE GUARD BLOCK before OrderSend:                           |
//|   1. SELL only (no BUY logic)                                    |
//|   2. RangeDefined: RefHigh > RefLow                              |
//|   3. BreakoutConfirmed (state >= WAIT_RETURN_TO_LEVEL)           |
//|   4. ReturnToLevelConfirmed (state >= WAIT_BEAR_CONFIRM)         |
//|   5. BearConfirmValid (just validated)                            |
//|   6. Temporal window not expired                                  |
//|   7. TradeDoneToday == false                                      |
//|   CurrentState must be WAIT_BEAR_CONFIRM                         |
//+------------------------------------------------------------------+
void ExecuteSellOrder()
{
   // --- MANDATORY AUDIT LOGS ---
   Print("--- PRE-ORDER AUDIT ---");
   Print("  STATE=", EnumToString(CurrentState));
   Print("  BreakoutConfirmed=", (CurrentState >= WAIT_RETURN_TO_LEVEL));
   Print("  ReturnToLevelConfirmed=", (CurrentState >= WAIT_BEAR_CONFIRM));
   Print("  BearConfirmValid=true (just validated)");
   Print("  TradeDoneToday=", HasTradedToday());

   // --- GUARD BLOCK: all 7 conditions must pass ---
   bool rangeDefined = (RefHigh > RefLow);
   bool breakoutDone = (CurrentState >= WAIT_RETURN_TO_LEVEL);
   bool returnDone   = (CurrentState >= WAIT_BEAR_CONFIRM);
   bool tradeDone    = HasTradedToday();

   if(!(rangeDefined
        && breakoutDone
        && returnDone
        && CurrentState == WAIT_BEAR_CONFIRM
        && !tradeDone))
   {
      Print("ExecuteSellOrder: BLOCKED by guard block.");
      Print("  RangeDefined=", rangeDefined,
            " BreakoutDone=", breakoutDone,
            " ReturnDone=", returnDone,
            " State=", EnumToString(CurrentState),
            " TradeDoneToday=", tradeDone);
      return;
   }

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(bid <= 0)
   {
      Print("ExecuteSellOrder: Invalid BID price.");
      return;
   }

   double sl = CalculateRecentHighSL();
   double tp = CalculateTPFromPips(bid);

   // Validate SL > entry (SELL: SL must be above entry)
   if(sl <= bid)
   {
      Print("ExecuteSellOrder: REJECTED - SL (", DoubleToString(sl, _Digits),
            ") <= Bid (", DoubleToString(bid, _Digits), ")");
      return;
   }

   // Validate minimum SL distance
   double slDistPoints = (sl - bid) / _Point;
   if(slDistPoints < MinSLPoints)
   {
      Print("ExecuteSellOrder: REJECTED - SL distance (", DoubleToString(slDistPoints, 0),
            " pts) < MinSLPoints (", MinSLPoints, ")");
      return;
   }

   // Check broker stops level
   int stopsLevel = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   if(stopsLevel > 0)
   {
      double minDist = stopsLevel * _Point;
      if((sl - bid) < minDist)
      {
         Print("ExecuteSellOrder: REJECTED - SL too close. Min stops level: ",
               stopsLevel, " pts");
         return;
      }
      if((bid - tp) < minDist)
      {
         Print("ExecuteSellOrder: REJECTED - TP too close. Min stops level: ",
               stopsLevel, " pts");
         return;
      }
   }

   Print("=== SENDING SELL ORDER ===");
   Print("  State: ", EnumToString(CurrentState));
   Print("  Bid: ", DoubleToString(bid, _Digits));
   Print("  SL:  ", DoubleToString(sl, _Digits), " (", DoubleToString(slDistPoints, 0), " pts above entry)");
   Print("  TP:  ", DoubleToString(tp, _Digits));
   Print("  Lots: ", DoubleToString(Lots, 2));

   if(trade.Sell(Lots, _Symbol, bid, sl, tp, "ORB_SELL"))
   {
      // Transition: WAIT_BEAR_CONFIRM -> TRADE_DONE
      CurrentState = TRADE_DONE;
      uint retcode = trade.ResultRetcode();
      Print("=== SELL ORDER EXECUTED === State -> TRADE_DONE");
      Print("  Ticket: ", trade.ResultOrder(), " Retcode: ", retcode,
            " Comment: ", trade.ResultComment());
   }
   else
   {
      Print("ExecuteSellOrder: FAILED - Retcode: ", trade.ResultRetcode(),
            " Comment: ", trade.ResultComment());
   }
}

//+------------------------------------------------------------------+
//| Expert tick function - STRICT STATE MACHINE (SELL ONLY)          |
//|                                                                  |
//| WAIT_REF_M15_CLOSE    -> detect M15 ref, calc RefHigh/RefLow    |
//| WAIT_BREAKOUT         -> Close[1] < RefLow                       |
//| WAIT_RETURN_TO_LEVEL  -> High[1]>=RefLow-Tol, Close[1]<=RL+Tol  |
//|                       -> CANCELLED if window expires             |
//| WAIT_BEAR_CONFIRM     -> Close[1]<Open[1], Close[1]<RefLow->SELL|
//| TRADE_DONE            -> no more trading today                   |
//|                                                                  |
//| GUARDS / INTERDICTIONS:                                          |
//| - SELL forbidden in WAIT_BREAKOUT                                |
//| - SELL forbidden in WAIT_RETURN_TO_LEVEL                         |
//| - SELL forbidden if ReturnToLevel was never validated after break|
//| - Shift=0 (bar in formation) is NEVER used                       |
//| - Max 1 trade per day                                             |
//| - Each transition returns (separate bars enforced)                |
//| - NO BUY logic anywhere                                          |
//+------------------------------------------------------------------+
void OnTick()
{
   // --- Day change detection ---
   MqlDateTime dtNow;
   TimeToStruct(TimeCurrent(), dtNow);
   dtNow.hour = 0;
   dtNow.min  = 0;
   dtNow.sec  = 0;
   datetime todayDate = StructToTime(dtNow);

   if(todayDate != CurrentDayDate)
   {
      CurrentDayDate = todayDate;
      ResetDailyState();
      Print("New server day: ", TimeToString(TimeCurrent(), TIME_DATE));
   }

   // --- State 0: Wait for M15 reference candle close ---
   if(CurrentState == WAIT_REF_M15_CLOSE)
   {
      DetectAndSetReferenceM15();
      return;
   }

   // --- State 4: Already traded today ---
   if(CurrentState == TRADE_DONE)
      return;

   // --- Process only on new closed M5 bar (anti-duplication) ---
   if(!IsNewClosedM5Bar())
      return;

   // --- State 1: Check breakout (SELL FORBIDDEN HERE) ---
   if(CurrentState == WAIT_BREAKOUT)
   {
      CheckBreakoutM5();
      return;  // MUST wait for next bar
   }

   // --- State 2: Check return to level (SELL FORBIDDEN HERE) ---
   if(CurrentState == WAIT_RETURN_TO_LEVEL)
   {
      CheckReturnToLevel();
      return;  // MUST wait for next bar
   }

   // --- State 3: Check bear confirmation and execute ---
   if(CurrentState == WAIT_BEAR_CONFIRM)
   {
      if(CheckBearishConfirmationM5())
      {
         // Final safety: verify no trade today
         if(!HasTradedToday())
         {
            ExecuteSellOrder();
         }
         else
         {
            CurrentState = TRADE_DONE;
            Print("Trade already exists today - State -> TRADE_DONE");
         }
      }
   }
}
//+------------------------------------------------------------------+

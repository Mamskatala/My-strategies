//+------------------------------------------------------------------+
//|                                    TSM_OpeningRangeBreakout.mq5 |
//|      M15 Reference + M5 Breakout/Retest/Confirm - BUY ONLY     |
//|                    Strict State Machine v6.0                    |
//+------------------------------------------------------------------+
#property copyright "TSM Opening Range Breakout"
#property link      ""
#property version   "6.00"
#property description "M15 Ref + M5 Breakout/Retest/BullConfirm - BUY Only"

#include <Trade\Trade.mqh>

//--- Inputs
input int    LookbackSwing         = 10;     // N M5 bars for swing low SL
input int    BufferSLPoints        = 50;     // SL buffer below recent low (points)
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

//--- Trend Regime Filter
input bool              UseTrendFilter     = true;       // Enable bullish trend filter
input int               TrendMA_Period     = 200;        // Trend MA period
input ENUM_TIMEFRAMES   TrendMA_Timeframe  = PERIOD_H1;  // Trend MA timeframe
input ENUM_MA_METHOD    TrendMA_Method     = MODE_EMA;   // Trend MA method (EMA/SMA)

//--- State Machine
enum ENUM_ORB_STATE
{
   WAIT_REF_M15_CLOSE,     // State 0: Waiting for M15 reference candle close
   WAIT_BREAKOUT,          // State 1: Waiting for M5 breakout above RefHigh
   WAIT_RETEST,            // State 2: Waiting for price to pull back to RefHigh zone
   WAIT_CONFIRMATION,      // State 3: Waiting for bullish confirmation candle
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

//--- Trend MA handle
int TrendMA_Handle = INVALID_HANDLE;

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

   Print("=== TSM ORB v6.00 initialized (BUY ONLY - Strict Retest State Machine) ===");
   Print("Symbol: ", _Symbol, " | Digits: ", _Digits, " | PipMult: ", PipMultiplier());
   Print("RefHour: ", RefHour, ":", (RefMinute < 10 ? "0" : ""), RefMinute);
   Print("FixedTP_Pips: ", FixedTP_Pips, " | LookbackSwing: ", LookbackSwing);
   Print("TolerancePoints: ", RetestTolerancePoints);
   Print("MaxBarsToReturn: ", MaxBarsToReturn, " | CancelIfExpired: ", CancelSetupIfExpired);
   Print("Lots: ", DoubleToString(Lots, 2), " | Magic: ", MagicNumber);

   if(UseTrendFilter)
   {
      TrendMA_Handle = iMA(_Symbol, TrendMA_Timeframe, TrendMA_Period, 0, TrendMA_Method, PRICE_CLOSE);
      if(TrendMA_Handle == INVALID_HANDLE)
      {
         Print("ERROR: Failed to create trend MA indicator (period=", TrendMA_Period, ")");
         return INIT_FAILED;
      }
      Print("TrendFilter: ON | MA(", TrendMA_Period, ") on ", EnumToString(TrendMA_Timeframe),
            " Method: ", EnumToString(TrendMA_Method));
   }
   else
      Print("TrendFilter: OFF");

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectDelete(0, "ORB_RefHigh");
   ObjectDelete(0, "ORB_RefLow");
   if(TrendMA_Handle != INVALID_HANDLE)
      IndicatorRelease(TrendMA_Handle);
   Print("=== TSM ORB v6.00 deinitialized ===");
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
   Print("  TrendMA_Period:        Start=50  Step=50  Stop=300");
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
//| IsBullishTrend - check if price is above trend MA                |
//|                                                                  |
//| Returns true if:                                                  |
//|   - UseTrendFilter is false (filter disabled), OR                |
//|   - Current close is above the trend MA value                     |
//+------------------------------------------------------------------+
bool IsBullishTrend()
{
   if(!UseTrendFilter)
      return true;

   if(TrendMA_Handle == INVALID_HANDLE)
      return true;  // failsafe: don't block if indicator failed

   double maValue[1];
   if(CopyBuffer(TrendMA_Handle, 0, 1, 1, maValue) != 1)
   {
      Print("IsBullishTrend: CopyBuffer failed, allowing trade.");
      return true;  // failsafe: don't block on data error
   }

   double trendClose = iClose(_Symbol, TrendMA_Timeframe, 1);
   bool bullish = (trendClose > maValue[0]);

   if(!bullish)
      Print("  Trend filter: BEARISH (Close ", DoubleToString(trendClose, _Digits),
            " <= MA(", TrendMA_Period, ")=", DoubleToString(maValue[0], _Digits),
            ") -> Breakout blocked");

   return bullish;
}

//+------------------------------------------------------------------+
//| CheckBreakoutM5 - bar[1] close > RefHigh (closed bar only)       |
//|                                                                  |
//| BreakoutValid = (Close[1] > RefHigh)                              |
//| GUARD: BUY is FORBIDDEN in this state                            |
//+------------------------------------------------------------------+
void CheckBreakoutM5()
{
   if(CurrentState != WAIT_BREAKOUT)
      return;

   // --- Trend regime filter: only look for breakouts in bullish trend ---
   if(!IsBullishTrend())
      return;

   double closeBar1 = iClose(_Symbol, PERIOD_M5, 1);
   if(closeBar1 > RefHigh)
   {
      // Store breakout bar time for retest window
      BreakoutTime = iTime(_Symbol, PERIOD_M5, 1);
      BarsSinceBreakout = 0;

      // Transition: WAIT_BREAKOUT -> WAIT_RETEST
      CurrentState = WAIT_RETEST;
      Print("BREAKOUT OK at ", TimeToString(BreakoutTime), " -> WAIT_RETEST");
      Print("  M5 bar[1] Close: ", DoubleToString(closeBar1, _Digits),
            " > RefHigh: ", DoubleToString(RefHigh, _Digits));
   }
}

//+------------------------------------------------------------------+
//| CheckRetestM5 - price pulls back down to RefHigh zone            |
//|                                                                  |
//| RetestValid =                                                     |
//|   Low[1]   <= RefHigh + Tol  (price came back down to level)      |
//|   Close[1] >= RefHigh - Tol  (close held in/above zone)           |
//|                                                                  |
//| IMPORTANT: reject if Low[1] > RefHigh (price never came back)    |
//|                                                                  |
//| TEMPORAL WINDOW: must occur within MaxBarsToReturn M5 bars       |
//| GUARD: BUY is FORBIDDEN in this state                            |
//| GUARD: must happen AFTER BreakoutValid (enforced by state)       |
//+------------------------------------------------------------------+
void CheckRetestM5()
{
   if(CurrentState != WAIT_RETEST)
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
      Print("SETUP CANCELLED: no retest within ", MaxBarsToReturn, " M5 bars");
      Print("  BarsSinceBreakout: ", BarsSinceBreakout,
            " | BreakoutTime: ", TimeToString(BreakoutTime));
      return;
   }

   double lowBar1   = iLow(_Symbol, PERIOD_M5, 1);
   double closeBar1 = iClose(_Symbol, PERIOD_M5, 1);
   double tolerance = RetestTolerancePoints * _Point;

   // STRICT GUARD: reject if Low > RefHigh (price never came back to level)
   if(lowBar1 > RefHigh)
   {
      int barsRemaining = MaxBarsToReturn - BarsSinceBreakout;
      Print("  Retest check: Low=", DoubleToString(lowBar1, _Digits),
            " > RefHigh=", DoubleToString(RefHigh, _Digits),
            " -> REJECTED (price never came back) (",
            BarsSinceBreakout, "/", MaxBarsToReturn,
            " bars, ", barsRemaining, " remaining)");
      return;
   }

   // Check if price pulled back to the RefHigh zone
   // Low must reach at or below RefHigh + tolerance (came back down)
   // Close must stay at or above RefHigh - tolerance (held the zone)
   if(lowBar1 <= RefHigh + tolerance && closeBar1 >= RefHigh - tolerance)
   {
      // Transition: WAIT_RETEST -> WAIT_CONFIRMATION
      CurrentState = WAIT_CONFIRMATION;
      Print("RETEST OK -> WAIT_CONFIRMATION");
      Print("  M5 bar[1] Low: ", DoubleToString(lowBar1, _Digits),
            " <= RefHigh+Tol: ", DoubleToString(RefHigh + tolerance, _Digits));
      Print("  M5 bar[1] Close: ", DoubleToString(closeBar1, _Digits),
            " >= RefHigh-Tol: ", DoubleToString(RefHigh - tolerance, _Digits));
   }
   else
   {
      int barsRemaining = MaxBarsToReturn - BarsSinceBreakout;
      Print("  Retest check: Low=", DoubleToString(lowBar1, _Digits),
            " Close=", DoubleToString(closeBar1, _Digits),
            " | Zone=[", DoubleToString(RefHigh - tolerance, _Digits),
            ",", DoubleToString(RefHigh + tolerance, _Digits),
            "] -> NOT yet (", BarsSinceBreakout, "/", MaxBarsToReturn,
            " bars, ", barsRemaining, " remaining)");
   }
}

//+------------------------------------------------------------------+
//| CheckBullishConfirmationM5 - bar[1] bullish + close > RefHigh    |
//|                                                                  |
//| ConfirmationValid = (Close[1] > Open[1]) AND (Close[1] > RefHigh)|
//| GUARD: can only fire in WAIT_CONFIRMATION state                  |
//+------------------------------------------------------------------+
bool CheckBullishConfirmationM5()
{
   if(CurrentState != WAIT_CONFIRMATION)
      return false;

   double openBar1  = iOpen(_Symbol, PERIOD_M5, 1);
   double closeBar1 = iClose(_Symbol, PERIOD_M5, 1);

   if(closeBar1 > openBar1 && closeBar1 > RefHigh)
   {
      Print("BULL CONFIRM OK -> OPEN BUY");
      Print("  M5 bar[1] Open: ", DoubleToString(openBar1, _Digits),
            " Close: ", DoubleToString(closeBar1, _Digits),
            " > RefHigh: ", DoubleToString(RefHigh, _Digits));
      return true;
   }

   Print("  Bull confirm check: Open=", DoubleToString(openBar1, _Digits),
         " Close=", DoubleToString(closeBar1, _Digits),
         " RefHigh=", DoubleToString(RefHigh, _Digits), " -> NOT yet");
   return false;
}

//+------------------------------------------------------------------+
//| CalculateRecentLowSL - lowest low of N closed M5 bars - buffer   |
//+------------------------------------------------------------------+
double CalculateRecentLowSL()
{
   double lowestLow = DBL_MAX;
   for(int i = 1; i <= LookbackSwing; i++)
   {
      double low_i = iLow(_Symbol, PERIOD_M5, i);
      if(low_i < lowestLow)
         lowestLow = low_i;
   }

   double sl = lowestLow - BufferSLPoints * _Point;
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickSize > 0)
      sl = NormalizeDouble(MathFloor(sl / tickSize) * tickSize, _Digits);
   else
      sl = NormalizeDouble(sl, _Digits);

   Print("  CalculateRecentLowSL: LowestLow=", DoubleToString(lowestLow, _Digits),
         " Buffer=", BufferSLPoints, "pts => SL=", DoubleToString(sl, _Digits));
   return sl;
}

//+------------------------------------------------------------------+
//| CalculateTPFromPips - entry + fixed pips (BUY direction)          |
//+------------------------------------------------------------------+
double CalculateTPFromPips(double entryPrice)
{
   double tp = entryPrice + FixedTP_Pips * PipMultiplier() * _Point;
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickSize > 0)
      tp = NormalizeDouble(MathRound(tp / tickSize) * tickSize, _Digits);
   else
      tp = NormalizeDouble(tp, _Digits);

   Print("  CalculateTPFromPips: Entry=", DoubleToString(entryPrice, _Digits),
         " + ", FixedTP_Pips, " pips => TP=", DoubleToString(tp, _Digits));
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
//| ExecuteBuyOrder - place BUY market order with SL/TP              |
//|                                                                  |
//| VALIDATION BEFORE OrderSend:                                     |
//|   IF BreakoutConfirmed == true                                   |
//|   AND RetestConfirmed == true                                    |
//|   AND ConfirmationValid == true                                  |
//|   AND TradeDoneToday == false                                    |
//|   THEN Open BUY                                                  |
//|   ELSE Do nothing.                                               |
//|                                                                  |
//|   CurrentState must be WAIT_CONFIRMATION                         |
//|   SL < EntryPrice, distance >= MinSLPoints                       |
//|   TP = EntryPrice + FixedTP_Pips                                 |
//+------------------------------------------------------------------+
void ExecuteBuyOrder()
{
   // --- MANDATORY AUDIT LOGS ---
   Print("--- PRE-ORDER AUDIT ---");
   Print("  STATE=", EnumToString(CurrentState));
   Print("  BreakoutConfirmed=", (CurrentState >= WAIT_RETEST));
   Print("  RetestConfirmed=", (CurrentState >= WAIT_CONFIRMATION));
   Print("  ConfirmationValid=true (just validated)");
   Print("  TradeDoneToday=", HasTradedToday());

   // --- GUARD BLOCK: all conditions must pass ---
   bool rangeDefined   = (RefHigh > RefLow);
   bool breakoutDone   = (CurrentState >= WAIT_RETEST);
   bool retestDone     = (CurrentState >= WAIT_CONFIRMATION);
   bool tradeDone      = HasTradedToday();

   if(!(rangeDefined
        && breakoutDone
        && retestDone
        && CurrentState == WAIT_CONFIRMATION
        && !tradeDone))
   {
      Print("ExecuteBuyOrder: BLOCKED by guard block.");
      Print("  RangeDefined=", rangeDefined,
            " BreakoutDone=", breakoutDone,
            " RetestDone=", retestDone,
            " State=", EnumToString(CurrentState),
            " TradeDoneToday=", tradeDone);
      return;
   }

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(ask <= 0)
   {
      Print("ExecuteBuyOrder: Invalid ASK price.");
      return;
   }

   double sl = CalculateRecentLowSL();
   double tp = CalculateTPFromPips(ask);

   // Validate SL < entry (BUY: SL must be below entry)
   if(sl >= ask)
   {
      Print("ExecuteBuyOrder: REJECTED - SL (", DoubleToString(sl, _Digits),
            ") >= Ask (", DoubleToString(ask, _Digits), ")");
      return;
   }

   // Validate minimum SL distance
   double slDistPoints = (ask - sl) / _Point;
   if(slDistPoints < MinSLPoints)
   {
      Print("ExecuteBuyOrder: REJECTED - SL distance (", DoubleToString(slDistPoints, 0),
            " pts) < MinSLPoints (", MinSLPoints, ")");
      return;
   }

   // Check broker stops level
   int stopsLevel = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   if(stopsLevel > 0)
   {
      double minDist = stopsLevel * _Point;
      if((ask - sl) < minDist)
      {
         Print("ExecuteBuyOrder: REJECTED - SL too close. Min stops level: ",
               stopsLevel, " pts");
         return;
      }
      if((tp - ask) < minDist)
      {
         Print("ExecuteBuyOrder: REJECTED - TP too close. Min stops level: ",
               stopsLevel, " pts");
         return;
      }
   }

   Print("=== SENDING BUY ORDER ===");
   Print("  State: ", EnumToString(CurrentState));
   Print("  Ask: ", DoubleToString(ask, _Digits));
   Print("  SL:  ", DoubleToString(sl, _Digits), " (", DoubleToString(slDistPoints, 0), " pts below entry)");
   Print("  TP:  ", DoubleToString(tp, _Digits));
   Print("  Lots: ", DoubleToString(Lots, 2));

   if(trade.Buy(Lots, _Symbol, ask, sl, tp, "ORB_BUY"))
   {
      // Transition: WAIT_CONFIRMATION -> TRADE_DONE
      CurrentState = TRADE_DONE;
      uint retcode = trade.ResultRetcode();
      Print("=== BUY ORDER EXECUTED === State -> TRADE_DONE");
      Print("  Ticket: ", trade.ResultOrder(), " Retcode: ", retcode,
            " Comment: ", trade.ResultComment());
   }
   else
   {
      Print("ExecuteBuyOrder: FAILED - Retcode: ", trade.ResultRetcode(),
            " Comment: ", trade.ResultComment());
   }
}

//+------------------------------------------------------------------+
//| Expert tick function - STRICT STATE MACHINE (BUY ONLY)          |
//|                                                                  |
//| WAIT_REF_M15_CLOSE    -> detect M15 ref, calc RefHigh/RefLow    |
//| WAIT_BREAKOUT         -> Close[1] > RefHigh                      |
//| WAIT_RETEST           -> Low[1]<=RH+Tol, Close[1]>=RH-Tol       |
//|                       -> CANCELLED if window expires             |
//| WAIT_CONFIRMATION     -> Close[1]>Open[1], Close[1]>RefHigh->BUY|
//| TRADE_DONE            -> no more trading today                   |
//|                                                                  |
//| INTERDICTIONS ABSOLUES:                                          |
//| - BUY forbidden in WAIT_BREAKOUT                                 |
//| - BUY forbidden in WAIT_RETEST                                   |
//| - BUY forbidden if RetestConfirmed == false                      |
//| - Shift=0 (bar in formation) is NEVER used                       |
//| - Max 1 trade per day                                             |
//| - Each transition returns (separate bars enforced)                |
//| - NO SELL logic anywhere                                         |
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

   // --- State 1: Check breakout (BUY FORBIDDEN HERE) ---
   if(CurrentState == WAIT_BREAKOUT)
   {
      CheckBreakoutM5();
      return;  // MUST wait for next bar
   }

   // --- State 2: Check retest/pullback (BUY FORBIDDEN HERE) ---
   if(CurrentState == WAIT_RETEST)
   {
      CheckRetestM5();
      return;  // MUST wait for next bar
   }

   // --- State 3: Check bullish confirmation and execute ---
   if(CurrentState == WAIT_CONFIRMATION)
   {
      if(CheckBullishConfirmationM5())
      {
         // Final safety: verify no trade today
         if(!HasTradedToday())
         {
            ExecuteBuyOrder();
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

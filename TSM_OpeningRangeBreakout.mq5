//+------------------------------------------------------------------+
//|                                    TSM_OpeningRangeBreakout.mq5 |
//|         M15 Reference + M5 Breakout/Retest/Confirm - BUY Only  |
//+------------------------------------------------------------------+
#property copyright "TSM Opening Range Breakout"
#property link      ""
#property version   "2.00"
#property description "M15 Ref (00:00) + M5 Breakout/Retest/Confirm - BUY Only"

#include <Trade\Trade.mqh>

//--- Inputs
input int    LookbackSwing         = 10;     // N M5 bars for swing low SL
input int    BufferSLPoints        = 50;     // SL buffer below recent low (points)
input int    MinSLPoints           = 100;    // Minimum SL distance (points)
input int    RetestTolerancePoints = 30;     // Retest zone tolerance (points)
input int    FixedTP_Pips          = 50;     // Take Profit (pips)
input double Lots                  = 0.10;   // Lot size
input int    MagicNumber           = 54321;  // Magic number
input int    MaxSlippagePoints     = 30;     // Max slippage (points)
input int    RefHour               = 0;      // Reference M15 candle hour (server)
input int    RefMinute             = 0;      // Reference M15 candle minute (server)
input bool   DrawRefLines          = true;   // Draw RefHigh / RefLow lines

//--- Daily state
bool   RangeDefined       = false;
bool   BreakoutConfirmed  = false;
bool   RetestConfirmed    = false;
bool   TradeDoneToday     = false;

double RefHigh = 0.0;
double RefLow  = 0.0;

datetime LastM5BarTime  = 0;
datetime CurrentDayDate = 0;

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

   Print("=== TSM ORB v2.0 initialized ===");
   Print("Symbol: ", _Symbol, " | Digits: ", _Digits, " | PipMult: ", PipMultiplier());
   Print("RefHour: ", RefHour, ":", (RefMinute < 10 ? "0" : ""), RefMinute);
   Print("FixedTP_Pips: ", FixedTP_Pips, " | LookbackSwing: ", LookbackSwing);
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
   Print("=== TSM ORB v2.0 deinitialized ===");
}

//+------------------------------------------------------------------+
//| ResetDailyState - reset all flags for new day                    |
//+------------------------------------------------------------------+
void ResetDailyState()
{
   RangeDefined      = false;
   BreakoutConfirmed = false;
   RetestConfirmed   = false;
   TradeDoneToday    = false;
   RefHigh           = 0.0;
   RefLow            = 0.0;

   ObjectDelete(0, "ORB_RefHigh");
   ObjectDelete(0, "ORB_RefLow");

   Print("--- DAILY RESET --- All states cleared.");
}

//+------------------------------------------------------------------+
//| DetectAndSetReferenceM15 - find 00:00 M15 candle (closed)        |
//+------------------------------------------------------------------+
void DetectAndSetReferenceM15()
{
   if(RangeDefined)
      return;

   // Look for the M15 bar whose open time matches RefHour:RefMinute today
   datetime serverTime = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(serverTime, dt);

   // Build target time for today's reference candle
   dt.hour = RefHour;
   dt.min  = RefMinute;
   dt.sec  = 0;
   datetime refBarTime = StructToTime(dt);

   // The M15 candle closes 15 min later
   datetime refCloseTime = refBarTime + 15 * 60;

   // Only proceed if current server time is past the close of the reference candle
   if(serverTime < refCloseTime)
      return;

   // Find the bar index on M15 whose open time matches refBarTime
   int shift = iBarShift(_Symbol, PERIOD_M15, refBarTime, true);
   if(shift < 0)
   {
      Print("DetectAndSetReferenceM15: Cannot find M15 bar at ", TimeToString(refBarTime));
      return;
   }

   // Must be a completed bar (shift >= 1 means it's not the current forming bar)
   // But if shift == 0, the bar might still be forming
   datetime barOpenTime = iTime(_Symbol, PERIOD_M15, shift);
   if(barOpenTime != refBarTime)
   {
      Print("DetectAndSetReferenceM15: M15 bar time mismatch. Expected: ",
            TimeToString(refBarTime), " Got: ", TimeToString(barOpenTime));
      return;
   }

   // Ensure this bar is closed (current time must be >= barOpenTime + 15 min)
   if(serverTime < barOpenTime + 15 * 60)
   {
      Print("DetectAndSetReferenceM15: Reference M15 bar not yet closed.");
      return;
   }

   RefHigh = iHigh(_Symbol, PERIOD_M15, shift);
   RefLow  = iLow(_Symbol, PERIOD_M15, shift);
   RangeDefined = true;

   Print("=== M15 REFERENCE SET ===");
   Print("  Time: ", TimeToString(barOpenTime));
   Print("  RefHigh: ", DoubleToString(RefHigh, _Digits));
   Print("  RefLow:  ", DoubleToString(RefLow, _Digits));

   // Draw optional lines
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
//| CheckBreakoutM5 - bar[1] close > RefHigh                         |
//+------------------------------------------------------------------+
void CheckBreakoutM5()
{
   if(BreakoutConfirmed)
      return;

   double closeBar1 = iClose(_Symbol, PERIOD_M5, 1);
   if(closeBar1 > RefHigh)
   {
      BreakoutConfirmed = true;
      Print("=== BREAKOUT CONFIRMED ===");
      Print("  M5 bar[1] Close: ", DoubleToString(closeBar1, _Digits),
            " > RefHigh: ", DoubleToString(RefHigh, _Digits));
   }
}

//+------------------------------------------------------------------+
//| CheckRetestM5 - bar[1] low pulls back to RefHigh zone           |
//+------------------------------------------------------------------+
void CheckRetestM5()
{
   if(RetestConfirmed)
      return;

   double lowBar1  = iLow(_Symbol, PERIOD_M5, 1);
   double tolerance = RetestTolerancePoints * _Point;

   // Retest = price pulled back DOWN to RefHigh zone (true pullback)
   // Low must be AT or BELOW RefHigh (proving price actually came back down)
   // with tolerance on the downside only: [RefHigh - tolerance, RefHigh]
   if(lowBar1 <= RefHigh && lowBar1 >= RefHigh - tolerance)
   {
      RetestConfirmed = true;
      Print("=== RETEST (PULLBACK) CONFIRMED ===");
      Print("  M5 bar[1] Low: ", DoubleToString(lowBar1, _Digits),
            " pulled back to RefHigh zone [", DoubleToString(RefHigh - tolerance, _Digits),
            " , ", DoubleToString(RefHigh, _Digits), "]");
   }
   else
   {
      Print("  Retest check: bar[1] Low=", DoubleToString(lowBar1, _Digits),
            " | RefHigh=", DoubleToString(RefHigh, _Digits),
            " | Zone=[", DoubleToString(RefHigh - tolerance, _Digits),
            ",", DoubleToString(RefHigh, _Digits), "] -> NOT yet");
   }
}

//+------------------------------------------------------------------+
//| CheckBullishConfirmationM5 - bar[1] is bullish + close > RefHigh |
//+------------------------------------------------------------------+
bool CheckBullishConfirmationM5()
{
   double openBar1  = iOpen(_Symbol, PERIOD_M5, 1);
   double closeBar1 = iClose(_Symbol, PERIOD_M5, 1);

   if(closeBar1 > openBar1 && closeBar1 > RefHigh)
   {
      Print("=== BULLISH CONFIRMATION ===");
      Print("  M5 bar[1] Open: ", DoubleToString(openBar1, _Digits),
            " Close: ", DoubleToString(closeBar1, _Digits),
            " > RefHigh: ", DoubleToString(RefHigh, _Digits));
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| CalculateRecentLowSL - lowest low of N closed M5 bars - buffer   |
//+------------------------------------------------------------------+
double CalculateRecentLowSL()
{
   double lowestLow = DBL_MAX;
   // Start from bar[1] (last closed) to bar[LookbackSwing]
   for(int i = 1; i <= LookbackSwing; i++)
   {
      double low_i = iLow(_Symbol, PERIOD_M5, i);
      if(low_i < lowestLow)
         lowestLow = low_i;
   }

   double sl = lowestLow - BufferSLPoints * _Point;
   // Normalize to tick size
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
//| CalculateTPFromPips - entry + fixed pips                         |
//+------------------------------------------------------------------+
double CalculateTPFromPips(double entryPrice)
{
   double tp = entryPrice + FixedTP_Pips * PipMultiplier() * _Point;
   // Normalize to tick size
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
   // Check open positions
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol)
      {
         if((int)PositionGetInteger(POSITION_MAGIC) == MagicNumber)
            return true;
      }
   }

   // Check closed deals today using date struct
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
//+------------------------------------------------------------------+
void ExecuteBuyOrder()
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(ask <= 0)
   {
      Print("ExecuteBuyOrder: Invalid ASK price.");
      return;
   }

   double sl = CalculateRecentLowSL();
   double tp = CalculateTPFromPips(ask);

   // Validate SL < entry
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
         Print("ExecuteBuyOrder: REJECTED - SL too close to price. Min stops level: ",
               stopsLevel, " pts");
         return;
      }
      if((tp - ask) < minDist)
      {
         Print("ExecuteBuyOrder: REJECTED - TP too close to price. Min stops level: ",
               stopsLevel, " pts");
         return;
      }
   }

   Print("=== SENDING BUY ORDER ===");
   Print("  Ask: ", DoubleToString(ask, _Digits));
   Print("  SL:  ", DoubleToString(sl, _Digits), " (", DoubleToString(slDistPoints, 0), " pts)");
   Print("  TP:  ", DoubleToString(tp, _Digits));
   Print("  Lots: ", DoubleToString(Lots, 2));

   if(trade.Buy(Lots, _Symbol, ask, sl, tp, "ORB_BUY"))
   {
      TradeDoneToday = true;
      uint retcode = trade.ResultRetcode();
      Print("=== BUY ORDER EXECUTED === Ticket: ", trade.ResultOrder(),
            " Retcode: ", retcode, " Comment: ", trade.ResultComment());
   }
   else
   {
      Print("ExecuteBuyOrder: FAILED - Retcode: ", trade.ResultRetcode(),
            " Comment: ", trade.ResultComment());
   }
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // --- Day change detection (uses full date to handle year boundary) ---
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

   // --- Step 1: Detect M15 reference (once per day) ---
   if(!RangeDefined)
   {
      DetectAndSetReferenceM15();
      if(!RangeDefined)
         return;  // Wait until reference candle closes
   }

   // --- Already traded today? ---
   if(TradeDoneToday)
      return;

   // --- Step 2: Process only on new closed M5 bar ---
   if(!IsNewClosedM5Bar())
      return;

   // --- Step 3: Check breakout ---
   if(!BreakoutConfirmed)
   {
      CheckBreakoutM5();
      return;  // Wait for next bar after breakout
   }

   // --- Step 4: Check retest ---
   if(!RetestConfirmed)
   {
      CheckRetestM5();
      return;  // Wait for next bar after retest
   }

   // --- Step 5: Check bullish confirmation and execute ---
   if(CheckBullishConfirmationM5())
   {
      // Double-check no trade today (history + positions)
      if(!HasTradedToday())
      {
         ExecuteBuyOrder();
      }
      else
      {
         TradeDoneToday = true;
         Print("Trade already exists today - skipping.");
      }
   }
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                              EA_VolumeDeltaBreakout_Advanced.mq5 |
//|                     Breakout Strategy with Volume Delta Filter   |
//|                      Uses custom VolumeDelta.mq5 indicator       |
//+------------------------------------------------------------------+
#property copyright "Breakout Strategy Advanced"
#property link      ""
#property version   "2.00"
#property description "Advanced Breakout strategy with Volume Delta indicator"

//--- Include necessary libraries
#include <Trade\Trade.mqh>

//--- Input parameters
input group "=== Breakout Settings ==="
input int    BOoption = 1;                    // Breakout option: 1=Fixed point, 2=Volatility
input double FixedPoint = 1.6;                // Fixed point breakout level
input int    VolPer = 20;                     // ATR period for volatility calculation
input double BreakoutFactor = 1.0;            // Volatility multiplier
input bool   HoldOvernight = false;           // Hold positions overnight
input bool   PrecedeByInsideDay = false;      // Require inside day before trade

input group "=== Volume Delta Settings ==="
input bool   UseCustomIndicator = true;       // Use custom VolumeDelta.mq5 indicator
input int    VDPeriod = 14;                   // Volume Delta calculation period
input double VDThreshold = 0.0;               // Volume Delta threshold for confirmation
input bool   UseAbsoluteThreshold = false;    // Use absolute value for threshold

input group "=== Risk Management ==="
input double LotSize = 0.1;                   // Position size in lots
input double StopLossPips = 0;                // Stop Loss in pips (0 = disabled)
input double TakeProfitPips = 0;              // Take Profit in pips (0 = disabled)
input double MaxSpreadPips = 5.0;             // Maximum allowed spread in pips

input group "=== Trading Settings ==="
input int    MagicNumber = 123457;            // Magic number for this EA
input string TradeComment = "VDBrkAdv";       // Trade comment
input bool   EnableLogging = true;            // Enable detailed logging

input group "=== Session Settings ==="
input int    SessionEndHour = 23;             // Session end hour
input int    SessionEndMinute = 0;            // Session end minute

//--- Global variables
CTrade trade;
int volumeDeltaHandle = INVALID_HANDLE;       // Handle for custom indicator
datetime lastBarTime = 0;
datetime currentDate = 0;
double tOpen = 0;                             // Today's open
double tHigh = 0;                             // Today's high
double tLow = 0;                              // Today's low
double pHigh = 0;                             // Previous day high
double pLow = 0;                              // Previous day low
double ppHigh = 0;                            // Day before previous high
double ppLow = 0;                             // Day before previous low
double breakoutLevel = 0;                     // Current breakout level
bool insideDay = false;                       // Inside day flag
bool buyOrderPlaced = false;                  // Buy stop order flag
bool sellOrderPlaced = false;                 // Sell stop order flag

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Set trade parameters
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(10);
   trade.SetTypeFilling(ORDER_FILLING_FOK);
   
   //--- Initialize custom indicator if enabled
   if(UseCustomIndicator)
   {
      volumeDeltaHandle = iCustom(_Symbol, PERIOD_CURRENT, "VolumeDelta", VDPeriod);
      if(volumeDeltaHandle == INVALID_HANDLE)
      {
         Print("ERROR: Failed to load VolumeDelta indicator. Using built-in calculation.");
         UseCustomIndicator = false;
      }
      else
      {
         Print("Volume Delta indicator loaded successfully");
      }
   }
   
   //--- Initialize variables
   lastBarTime = 0;
   currentDate = 0;
   
   if(EnableLogging)
   {
      Print("=== EA_VolumeDeltaBreakout_Advanced initialized ===");
      Print("Breakout Option: ", BOoption == 1 ? "Fixed Point" : "Volatility");
      Print("Fixed Point: ", FixedPoint);
      Print("Volatility Period: ", VolPer);
      Print("Volume Delta Period: ", VDPeriod);
      Print("Volume Delta Threshold: ", VDThreshold);
      Print("Use Custom Indicator: ", UseCustomIndicator ? "Yes" : "No");
      Print("Lot Size: ", LotSize);
      Print("Stop Loss: ", StopLossPips, " pips");
      Print("Take Profit: ", TakeProfitPips, " pips");
   }
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- Release indicator handle
   if(volumeDeltaHandle != INVALID_HANDLE)
      IndicatorRelease(volumeDeltaHandle);
   
   if(EnableLogging)
      Print("EA_VolumeDeltaBreakout_Advanced stopped. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Check spread
   double spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point / _Point;
   if(spread > MaxSpreadPips)
   {
      if(EnableLogging)
         Print("Spread too high: ", spread, " pips > ", MaxSpreadPips, " pips");
      return;
   }
   
   //--- Check for new bar
   datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   bool newBar = (currentBarTime != lastBarTime);
   
   if(newBar)
   {
      lastBarTime = currentBarTime;
      OnNewBar();
   }
   
   //--- Check for end of day exit
   CheckEndOfDayExit();
   
   //--- Update today's high and low
   UpdateTodayHighLow();
}

//+------------------------------------------------------------------+
//| New bar event handler                                            |
//+------------------------------------------------------------------+
void OnNewBar()
{
   MqlDateTime time;
   TimeToStruct(TimeCurrent(), time);
   datetime today = StringToTime(IntegerToString(time.year) + "." + 
                                 IntegerToString(time.mon) + "." + 
                                 IntegerToString(time.day));
   
   //--- Check for new day
   if(today != currentDate)
   {
      OnNewDay();
      currentDate = today;
   }
   
   //--- Place breakout orders
   PlaceBreakoutOrders();
}

//+------------------------------------------------------------------+
//| New day event handler                                            |
//+------------------------------------------------------------------+
void OnNewDay()
{
   if(EnableLogging)
      Print("=== NEW DAY ===");
   
   //--- Update previous day values
   ppHigh = pHigh;
   ppLow = pLow;
   pHigh = tHigh;
   pLow = tLow;
   
   //--- Check for inside day
   if(pHigh < ppHigh && pLow > ppLow && ppHigh > 0 && ppLow > 0)
   {
      insideDay = true;
      if(EnableLogging)
         Print("Inside day detected - Previous High: ", pHigh, " < ", ppHigh, ", Previous Low: ", pLow, " > ", ppLow);
   }
   else
   {
      insideDay = false;
   }
   
   //--- Reset today's values
   tOpen = iOpen(_Symbol, PERIOD_CURRENT, 0);
   tHigh = iHigh(_Symbol, PERIOD_CURRENT, 0);
   tLow = iLow(_Symbol, PERIOD_CURRENT, 0);
   
   //--- Calculate breakout level
   if(BOoption == 1)
   {
      // Fixed point breakout
      breakoutLevel = FixedPoint * _Point;
      if(EnableLogging)
         Print("Breakout Level (Fixed): ", breakoutLevel);
   }
   else
   {
      // Volatility-based breakout
      int atrHandle = iATR(_Symbol, PERIOD_CURRENT, VolPer);
      double atrValue[];
      ArraySetAsSeries(atrValue, true);
      if(CopyBuffer(atrHandle, 0, 0, 1, atrValue) > 0)
      {
         breakoutLevel = atrValue[0] * BreakoutFactor;
         if(EnableLogging)
            Print("Breakout Level (Volatility): ", breakoutLevel, " (ATR: ", atrValue[0], ")");
      }
      IndicatorRelease(atrHandle);
   }
   
   //--- Close positions at open if not holding overnight
   if(!HoldOvernight && PositionSelect(_Symbol))
   {
      if(trade.PositionClose(_Symbol))
      {
         if(EnableLogging)
            Print("Closed position at market open (not holding overnight)");
      }
   }
   
   //--- Reset order flags
   buyOrderPlaced = false;
   sellOrderPlaced = false;
   
   if(EnableLogging)
   {
      Print("Today's Open: ", tOpen);
      Print("Buy Entry Level: ", tOpen + breakoutLevel);
      Print("Sell Entry Level: ", tOpen - breakoutLevel);
   }
}

//+------------------------------------------------------------------+
//| Update today's high and low                                      |
//+------------------------------------------------------------------+
void UpdateTodayHighLow()
{
   double currentHigh = iHigh(_Symbol, PERIOD_CURRENT, 0);
   double currentLow = iLow(_Symbol, PERIOD_CURRENT, 0);
   
   if(currentHigh > tHigh)
      tHigh = currentHigh;
   
   if(currentLow < tLow)
      tLow = currentLow;
}

//+------------------------------------------------------------------+
//| Place breakout orders                                            |
//+------------------------------------------------------------------+
void PlaceBreakoutOrders()
{
   //--- Check inside day condition
   if(PrecedeByInsideDay && !insideDay)
   {
      return;  // Only trade after inside day if required
   }
   
   //--- Get current position
   bool hasPosition = PositionSelect(_Symbol);
   ENUM_POSITION_TYPE posType = POSITION_TYPE_BUY;
   if(hasPosition)
      posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   
   //--- Calculate Volume Delta
   double volumeDelta = CalculateVolumeDelta();
   double volumeDeltaCumulative = CalculateCumulativeVolumeDelta();
   
   if(EnableLogging)
      Print("Volume Delta: ", volumeDelta, ", Cumulative: ", volumeDeltaCumulative);
   
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   //--- Calculate SL and TP
   double sl = 0, tp = 0;
   
   //--- Check for long entry (breakout up)
   if(!hasPosition || posType == POSITION_TYPE_SELL)
   {
      double buyLevel = tOpen + breakoutLevel;
      
      // Check if price has broken above buy level
      if(currentPrice >= buyLevel && !buyOrderPlaced)
      {
         // Volume Delta confirmation for buy
         bool vdConfirm = UseAbsoluteThreshold ? 
                         (MathAbs(volumeDeltaCumulative) >= VDThreshold && volumeDeltaCumulative > 0) :
                         (volumeDeltaCumulative >= VDThreshold);
         
         if(vdConfirm)
         {
            // Close short position if exists
            if(hasPosition && posType == POSITION_TYPE_SELL)
            {
               trade.PositionClose(_Symbol);
               if(EnableLogging)
                  Print("Closed short position for reversal");
            }
            
            // Calculate SL and TP for buy
            if(StopLossPips > 0)
               sl = ask - StopLossPips * _Point * 10;
            if(TakeProfitPips > 0)
               tp = ask + TakeProfitPips * _Point * 10;
            
            // Open long position
            if(trade.Buy(LotSize, _Symbol, ask, sl, tp, TradeComment + "_BOup"))
            {
               if(EnableLogging)
                  Print("BUY executed at ", ask, " (VD: ", volumeDeltaCumulative, ")");
               buyOrderPlaced = true;
            }
         }
         else
         {
            if(EnableLogging)
               Print("Buy signal rejected - Volume Delta: ", volumeDeltaCumulative, " < ", VDThreshold);
         }
      }
   }
   
   //--- Check for short entry (breakout down)
   if(!hasPosition || posType == POSITION_TYPE_BUY)
   {
      double sellLevel = tOpen - breakoutLevel;
      
      // Check if price has broken below sell level
      if(currentPrice <= sellLevel && !sellOrderPlaced)
      {
         // Volume Delta confirmation for sell
         bool vdConfirm = UseAbsoluteThreshold ? 
                         (MathAbs(volumeDeltaCumulative) >= VDThreshold && volumeDeltaCumulative < 0) :
                         (volumeDeltaCumulative <= -VDThreshold);
         
         if(vdConfirm)
         {
            // Close long position if exists
            if(hasPosition && posType == POSITION_TYPE_BUY)
            {
               trade.PositionClose(_Symbol);
               if(EnableLogging)
                  Print("Closed long position for reversal");
            }
            
            // Calculate SL and TP for sell
            if(StopLossPips > 0)
               sl = bid + StopLossPips * _Point * 10;
            if(TakeProfitPips > 0)
               tp = bid - TakeProfitPips * _Point * 10;
            
            // Open short position
            if(trade.Sell(LotSize, _Symbol, bid, sl, tp, TradeComment + "_BOdown"))
            {
               if(EnableLogging)
                  Print("SELL executed at ", bid, " (VD: ", volumeDeltaCumulative, ")");
               sellOrderPlaced = true;
            }
         }
         else
         {
            if(EnableLogging)
               Print("Sell signal rejected - Volume Delta: ", volumeDeltaCumulative, " > ", -VDThreshold);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Calculate Volume Delta (built-in method)                         |
//+------------------------------------------------------------------+
double CalculateVolumeDelta()
{
   double volumeDelta = 0;
   
   double open = iOpen(_Symbol, PERIOD_CURRENT, 0);
   double close = iClose(_Symbol, PERIOD_CURRENT, 0);
   long volume = iVolume(_Symbol, PERIOD_CURRENT, 0);
   
   // Get real volume if available
   long real_volume[];
   if(CopyRealVolume(_Symbol, PERIOD_CURRENT, 0, 1, real_volume) > 0 && real_volume[0] > 0)
      volume = real_volume[0];
   
   // Calculate volume delta
   if(close > open)
      volumeDelta = volume;  // Buying volume
   else if(close < open)
      volumeDelta = -volume;  // Selling volume
   
   return volumeDelta;
}

//+------------------------------------------------------------------+
//| Calculate Cumulative Volume Delta                                |
//+------------------------------------------------------------------+
double CalculateCumulativeVolumeDelta()
{
   //--- Use custom indicator if available
   if(UseCustomIndicator && volumeDeltaHandle != INVALID_HANDLE)
   {
      double buffer[];
      ArraySetAsSeries(buffer, true);
      
      // Get cumulative volume delta from indicator (buffer 2)
      if(CopyBuffer(volumeDeltaHandle, 2, 0, 1, buffer) > 0)
      {
         return buffer[0];
      }
   }
   
   //--- Fallback to built-in calculation
   double cumulativeVD = 0;
   
   for(int i = 0; i < VDPeriod; i++)
   {
      double open = iOpen(_Symbol, PERIOD_CURRENT, i);
      double close = iClose(_Symbol, PERIOD_CURRENT, i);
      long volume = iVolume(_Symbol, PERIOD_CURRENT, i);
      
      // Try to get real volume
      long real_volume[];
      if(CopyRealVolume(_Symbol, PERIOD_CURRENT, i, 1, real_volume) > 0 && real_volume[0] > 0)
         volume = real_volume[0];
      
      // Calculate volume delta
      if(close > open)
         cumulativeVD += volume;
      else if(close < open)
         cumulativeVD -= volume;
   }
   
   return cumulativeVD;
}

//+------------------------------------------------------------------+
//| Check for end of day exit                                        |
//+------------------------------------------------------------------+
void CheckEndOfDayExit()
{
   if(HoldOvernight)
      return;  // Don't exit if holding overnight
   
   MqlDateTime time;
   TimeToStruct(TimeCurrent(), time);
   
   //--- Check if it's time to exit
   int currentMinutes = time.hour * 60 + time.min;
   int sessionEndMinutes = SessionEndHour * 60 + SessionEndMinute;
   
   if(currentMinutes >= sessionEndMinutes)
   {
      if(PositionSelect(_Symbol))
      {
         ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         
         if(trade.PositionClose(_Symbol))
         {
            if(EnableLogging)
            {
               if(posType == POSITION_TYPE_BUY)
                  Print("Closed long position at end of day");
               else
                  Print("Closed short position at end of day");
            }
         }
      }
   }
}

//+------------------------------------------------------------------+

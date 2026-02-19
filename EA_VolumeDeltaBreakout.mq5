//+------------------------------------------------------------------+
//|                                   EA_VolumeDeltaBreakout.mq5     |
//|                     Breakout Strategy with Volume Delta Filter   |
//|                                                                   |
//+------------------------------------------------------------------+
#property copyright "Breakout Strategy"
#property link      ""
#property version   "1.00"
#property description "Breakout strategy with Volume Delta confirmation"

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
input int    VDPeriod = 14;                   // Volume Delta calculation period
input double VDThreshold = 0.0;               // Volume Delta threshold for confirmation
                                              // Positive for buy, negative for sell

input group "=== Trading Settings ==="
input double LotSize = 0.1;                   // Position size in lots
input int    MagicNumber = 123456;            // Magic number for this EA
input string TradeComment = "VDBrkout";       // Trade comment

input group "=== Session Settings ==="
input int    SessionEndHour = 23;             // Session end hour
input int    SessionEndMinute = 0;            // Session end minute

//--- Global variables
CTrade trade;
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
   
   //--- Initialize variables
   lastBarTime = 0;
   currentDate = 0;
   
   Print("EA_VolumeDeltaBreakout initialized successfully");
   Print("Breakout Option: ", BOoption == 1 ? "Fixed Point" : "Volatility");
   Print("Fixed Point: ", FixedPoint);
   Print("Volatility Period: ", VolPer);
   Print("Volume Delta Period: ", VDPeriod);
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("EA_VolumeDeltaBreakout stopped. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
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
   Print("=== NEW DAY ===");
   
   //--- Update previous day values
   ppHigh = pHigh;
   ppLow = pLow;
   pHigh = tHigh;
   pLow = tLow;
   
   //--- Check for inside day
   if(pHigh < ppHigh && pLow > ppLow)
   {
      insideDay = true;
      Print("Inside day detected");
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
      Print("Breakout Level (Fixed): ", breakoutLevel);
   }
   else
   {
      // Volatility-based breakout
      double atr = iATR(_Symbol, PERIOD_CURRENT, VolPer);
      double atrValue[];
      ArraySetAsSeries(atrValue, true);
      if(CopyBuffer(atr, 0, 0, 1, atrValue) > 0)
      {
         breakoutLevel = atrValue[0] * BreakoutFactor;
         Print("Breakout Level (Volatility): ", breakoutLevel, " (ATR: ", atrValue[0], ")");
      }
   }
   
   //--- Close positions at open if not holding overnight
   if(!HoldOvernight && PositionSelect(_Symbol))
   {
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
      {
         trade.PositionClose(_Symbol);
         Print("Closed long position at market open");
      }
      else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
      {
         trade.PositionClose(_Symbol);
         Print("Closed short position at market open");
      }
   }
   
   //--- Reset order flags
   buyOrderPlaced = false;
   sellOrderPlaced = false;
   
   Print("Today's Open: ", tOpen);
   Print("Buy Entry: ", tOpen + breakoutLevel);
   Print("Sell Entry: ", tOpen - breakoutLevel);
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
   
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   //--- Check for long entry (breakout up)
   if(!hasPosition || posType == POSITION_TYPE_SELL)
   {
      double buyLevel = tOpen + breakoutLevel;
      
      // Check if price has broken above buy level
      if(currentPrice >= buyLevel && !buyOrderPlaced)
      {
         // Volume Delta confirmation for buy
         if(volumeDelta >= VDThreshold)
         {
            // Close short position if exists
            if(hasPosition && posType == POSITION_TYPE_SELL)
            {
               trade.PositionClose(_Symbol);
               Print("Closed short position for reversal");
            }
            
            // Open long position
            if(trade.Buy(LotSize, _Symbol, ask, 0, 0, TradeComment + "_BOup"))
            {
               Print("BUY executed at ", ask, " (Volume Delta: ", volumeDelta, ")");
               buyOrderPlaced = true;
            }
         }
         else
         {
            Print("Buy signal rejected - Volume Delta insufficient: ", volumeDelta, " < ", VDThreshold);
         }
      }
   }
   
   //--- Check for short entry (breakout down)
   if(!hasPosition || posType == POSITION_TYPE_BUY)
   {
      double sellLevel = tOpen - breakoutLevel;
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      
      // Check if price has broken below sell level
      if(currentPrice <= sellLevel && !sellOrderPlaced)
      {
         // Volume Delta confirmation for sell
         if(volumeDelta <= -VDThreshold)
         {
            // Close long position if exists
            if(hasPosition && posType == POSITION_TYPE_BUY)
            {
               trade.PositionClose(_Symbol);
               Print("Closed long position for reversal");
            }
            
            // Open short position
            if(trade.Sell(LotSize, _Symbol, bid, 0, 0, TradeComment + "_BOdown"))
            {
               Print("SELL executed at ", bid, " (Volume Delta: ", volumeDelta, ")");
               sellOrderPlaced = true;
            }
         }
         else
         {
            Print("Sell signal rejected - Volume Delta insufficient: ", volumeDelta, " > ", -VDThreshold);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Calculate Volume Delta                                           |
//+------------------------------------------------------------------+
double CalculateVolumeDelta()
{
   double volumeDelta = 0;
   
   //--- Calculate cumulative volume delta over the period
   for(int i = 0; i < VDPeriod; i++)
   {
      double open = iOpen(_Symbol, PERIOD_CURRENT, i);
      double close = iClose(_Symbol, PERIOD_CURRENT, i);
      long volume = iVolume(_Symbol, PERIOD_CURRENT, i);
      
      // Simplified volume delta calculation
      // Positive if close > open (buying pressure)
      // Negative if close < open (selling pressure)
      if(close > open)
      {
         volumeDelta += volume;  // Buying volume
      }
      else if(close < open)
      {
         volumeDelta -= volume;  // Selling volume
      }
      // If close == open, volume is neutral (not added)
   }
   
   // Normalize the volume delta
   volumeDelta = volumeDelta / VDPeriod;
   
   return volumeDelta;
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
            if(posType == POSITION_TYPE_BUY)
               Print("Closed long position at end of day");
            else
               Print("Closed short position at end of day");
         }
      }
   }
}

//+------------------------------------------------------------------+

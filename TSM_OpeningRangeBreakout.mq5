//+------------------------------------------------------------------+
//|                                    TSM_OpeningRangeBreakout.mq5 |
//|                        TSM Opening Range Breakout - P.J. Kaufman |
//|                                     Production-Grade Multi-Symbol |
//+------------------------------------------------------------------+
#property copyright "TSM Opening Range Breakout - P.J. Kaufman"
#property link      ""
#property version   "1.00"
#property strict

//--- Include necessary files
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\AccountInfo.mqh>

//--- Input parameters
input group "=== Opening Range Settings ==="
input int      InpRangePeriodMinutes = 30;        // Opening range period (minutes)
input int      InpRangeStartHour = 9;             // Range start hour
input int      InpRangeStartMinute = 30;          // Range start minute

input group "=== Entry Settings ==="
input double   InpBreakoutPips = 2.0;             // Breakout buffer (pips)
input bool     InpTradeOnlyFirstBreak = true;     // Trade only first breakout

input group "=== Risk Management ==="
input double   InpLotSize = 0.1;                  // Lot size
input double   InpStopLossPips = 50.0;            // Stop loss (pips)
input double   InpTakeProfitPips = 100.0;         // Take profit (pips)
input bool     InpUseRangeStops = true;           // Use range as stop loss
input double   InpRiskPercent = 1.0;              // Risk per trade (%)
input bool     InpUseDynamicLots = false;         // Use dynamic lot sizing

input group "=== Trading Hours ==="
input int      InpTradingStartHour = 9;           // Trading start hour
input int      InpTradingEndHour = 16;            // Trading end hour

input group "=== General Settings ==="
input int      InpMagicNumber = 123456;           // Magic number
input string   InpTradeComment = "TSM_ORB";       // Trade comment
input bool     InpCloseAtEndOfDay = true;         // Close positions at end of day

//--- Global variables
CTrade         trade;
CPositionInfo  position;
CSymbolInfo    symbolInfo;
CAccountInfo   accountInfo;

struct SOpeningRange
{
   double   high;
   double   low;
   datetime startTime;
   datetime endTime;
   bool     calculated;
   bool     longTriggered;
   bool     shortTriggered;
};

SOpeningRange g_openingRange;
datetime      g_lastBarTime = 0;
datetime      g_currentDay = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Set magic number for trades
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(10);
   trade.SetTypeFilling(ORDER_FILLING_FOK);
   trade.SetAsyncMode(false);
   
   //--- Initialize symbol info
   if(!symbolInfo.Name(_Symbol))
   {
      Print("Error initializing symbol info for ", _Symbol);
      return INIT_FAILED;
   }
   symbolInfo.Refresh();
   
   //--- Validate inputs
   if(InpRangePeriodMinutes <= 0)
   {
      Print("Error: Opening range period must be greater than 0");
      return INIT_PARAMETERS_INCORRECT;
   }
   
   if(InpRangeStartHour < 0 || InpRangeStartHour > 23)
   {
      Print("Error: Range start hour must be between 0 and 23");
      return INIT_PARAMETERS_INCORRECT;
   }
   
   if(InpStopLossPips <= 0 && !InpUseRangeStops)
   {
      Print("Error: Stop loss must be greater than 0 or use range stops");
      return INIT_PARAMETERS_INCORRECT;
   }
   
   //--- Initialize opening range structure
   ResetOpeningRange();
   
   Print("TSM Opening Range Breakout EA initialized successfully");
   Print("Symbol: ", _Symbol);
   Print("Range Period: ", InpRangePeriodMinutes, " minutes");
   Print("Range Start: ", IntegerToString(InpRangeStartHour, 2, '0'), ":", IntegerToString(InpRangeStartMinute, 2, '0'));
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("TSM Opening Range Breakout EA deinitialized. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Check if new bar
   datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(currentBarTime == g_lastBarTime)
      return;
   g_lastBarTime = currentBarTime;
   
   //--- Check for new day
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   datetime currentDayStart = StringToTime(IntegerToString(dt.year) + "." + 
                                           IntegerToString(dt.mon, 2, '0') + "." + 
                                           IntegerToString(dt.day, 2, '0') + " 00:00");
   
   if(currentDayStart != g_currentDay)
   {
      g_currentDay = currentDayStart;
      ResetOpeningRange();
      if(InpCloseAtEndOfDay)
         CloseAllPositions();
   }
   
   //--- Update symbol info
   if(!symbolInfo.RefreshRates())
   {
      Print("Error refreshing rates for ", _Symbol);
      return;
   }
   
   //--- Calculate opening range if not done yet
   if(!g_openingRange.calculated)
   {
      CalculateOpeningRange();
   }
   
   //--- Check if within trading hours
   if(!IsWithinTradingHours())
   {
      if(InpCloseAtEndOfDay)
         CloseAllPositions();
      return;
   }
   
   //--- Check for breakout signals
   if(g_openingRange.calculated)
   {
      CheckBreakoutSignals();
   }
   
   //--- Manage open positions
   ManagePositions();
}

//+------------------------------------------------------------------+
//| Reset opening range structure                                    |
//+------------------------------------------------------------------+
void ResetOpeningRange()
{
   g_openingRange.high = 0.0;
   g_openingRange.low = DBL_MAX;
   g_openingRange.startTime = 0;
   g_openingRange.endTime = 0;
   g_openingRange.calculated = false;
   g_openingRange.longTriggered = false;
   g_openingRange.shortTriggered = false;
}

//+------------------------------------------------------------------+
//| Calculate opening range                                          |
//+------------------------------------------------------------------+
void CalculateOpeningRange()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   
   //--- Set range start time
   datetime rangeStart = StringToTime(IntegerToString(dt.year) + "." + 
                                      IntegerToString(dt.mon, 2, '0') + "." + 
                                      IntegerToString(dt.day, 2, '0') + " " +
                                      IntegerToString(InpRangeStartHour, 2, '0') + ":" + 
                                      IntegerToString(InpRangeStartMinute, 2, '0'));
   
   datetime rangeEnd = rangeStart + InpRangePeriodMinutes * 60;
   datetime currentTime = TimeCurrent();
   
   //--- Check if we are past the range end time
   if(currentTime < rangeEnd)
      return;
   
   //--- Calculate high and low within the opening range
   int totalBars = Bars(_Symbol, PERIOD_M1);
   if(totalBars < 1)
      return;
   
   g_openingRange.high = 0.0;
   g_openingRange.low = DBL_MAX;
   
   for(int i = 0; i < totalBars; i++)
   {
      datetime barTime = iTime(_Symbol, PERIOD_M1, i);
      
      if(barTime >= rangeStart && barTime < rangeEnd)
      {
         double high = iHigh(_Symbol, PERIOD_M1, i);
         double low = iLow(_Symbol, PERIOD_M1, i);
         
         if(high > g_openingRange.high)
            g_openingRange.high = high;
         if(low < g_openingRange.low)
            g_openingRange.low = low;
      }
      
      if(barTime < rangeStart)
         break;
   }
   
   //--- Validate range
   if(g_openingRange.high > 0.0 && g_openingRange.low < DBL_MAX && g_openingRange.high > g_openingRange.low)
   {
      g_openingRange.startTime = rangeStart;
      g_openingRange.endTime = rangeEnd;
      g_openingRange.calculated = true;
      
      Print("Opening Range calculated: High=", DoubleToString(g_openingRange.high, _Digits), 
            " Low=", DoubleToString(g_openingRange.low, _Digits),
            " Range=", DoubleToString((g_openingRange.high - g_openingRange.low) / symbolInfo.Point(), 1), " pips");
   }
}

//+------------------------------------------------------------------+
//| Check for breakout signals                                       |
//+------------------------------------------------------------------+
void CheckBreakoutSignals()
{
   //--- Get current price
   double bid = symbolInfo.Bid();
   double ask = symbolInfo.Ask();
   double point = symbolInfo.Point();
   int digits = (int)symbolInfo.Digits();
   
   //--- Calculate pip value once
   double pipValue = point * 10;
   
   //--- Calculate breakout levels
   double longEntry = g_openingRange.high + InpBreakoutPips * pipValue;
   double shortEntry = g_openingRange.low - InpBreakoutPips * pipValue;
   
   //--- Check for long breakout
   if(!g_openingRange.longTriggered && ask > longEntry)
   {
      if(!InpTradeOnlyFirstBreak || !g_openingRange.shortTriggered)
      {
         if(!HasPosition(POSITION_TYPE_BUY))
         {
            OpenPosition(ORDER_TYPE_BUY);
         }
      }
      g_openingRange.longTriggered = true;
   }
   
   //--- Check for short breakout
   if(!g_openingRange.shortTriggered && bid < shortEntry)
   {
      if(!InpTradeOnlyFirstBreak || !g_openingRange.longTriggered)
      {
         if(!HasPosition(POSITION_TYPE_SELL))
         {
            OpenPosition(ORDER_TYPE_SELL);
         }
      }
      g_openingRange.shortTriggered = true;
   }
}

//+------------------------------------------------------------------+
//| Open position                                                     |
//+------------------------------------------------------------------+
void OpenPosition(ENUM_ORDER_TYPE orderType)
{
   double price = 0.0;
   double sl = 0.0;
   double tp = 0.0;
   double lots = InpLotSize;
   
   //--- Get current prices
   double bid = symbolInfo.Bid();
   double ask = symbolInfo.Ask();
   double point = symbolInfo.Point();
   double pipValue = point * 10;
   
   //--- Calculate dynamic lot size if enabled
   if(InpUseDynamicLots)
   {
      lots = CalculateLotSize(orderType);
   }
   
   //--- Normalize lot size
   double minLot = symbolInfo.LotsMin();
   double maxLot = symbolInfo.LotsMax();
   double lotStep = symbolInfo.LotsStep();
   lots = MathMax(minLot, MathMin(maxLot, MathRound(lots / lotStep) * lotStep));
   
   //--- Calculate stops based on order type
   if(orderType == ORDER_TYPE_BUY)
   {
      price = ask;
      
      if(InpUseRangeStops)
      {
         sl = g_openingRange.low;
      }
      else
      {
         sl = price - InpStopLossPips * pipValue;
      }
      
      if(InpTakeProfitPips > 0)
      {
         tp = price + InpTakeProfitPips * pipValue;
      }
   }
   else // ORDER_TYPE_SELL
   {
      price = bid;
      
      if(InpUseRangeStops)
      {
         sl = g_openingRange.high;
      }
      else
      {
         sl = price + InpStopLossPips * pipValue;
      }
      
      if(InpTakeProfitPips > 0)
      {
         tp = price - InpTakeProfitPips * pipValue;
      }
   }
   
   //--- Normalize prices
   sl = NormalizeDouble(sl, (int)symbolInfo.Digits());
   tp = NormalizeDouble(tp, (int)symbolInfo.Digits());
   
   //--- Validate stop levels
   int stopsLevel = (int)symbolInfo.StopsLevel();
   double minDistance = stopsLevel * point;
   
   if(orderType == ORDER_TYPE_BUY)
   {
      if(sl > 0 && ask - sl < minDistance)
         sl = ask - minDistance;
      if(tp > 0 && tp - ask < minDistance)
         tp = ask + minDistance;
   }
   else
   {
      if(sl > 0 && sl - bid < minDistance)
         sl = bid + minDistance;
      if(tp > 0 && bid - tp < minDistance)
         tp = bid - minDistance;
   }
   
   //--- Open position
   bool result = false;
   if(orderType == ORDER_TYPE_BUY)
   {
      result = trade.Buy(lots, _Symbol, price, sl, tp, InpTradeComment);
   }
   else
   {
      result = trade.Sell(lots, _Symbol, price, sl, tp, InpTradeComment);
   }
   
   if(result)
   {
      Print("Position opened: ", EnumToString(orderType), " Lots=", DoubleToString(lots, 2), 
            " Price=", DoubleToString(price, (int)symbolInfo.Digits()),
            " SL=", DoubleToString(sl, (int)symbolInfo.Digits()),
            " TP=", DoubleToString(tp, (int)symbolInfo.Digits()));
   }
   else
   {
      Print("Error opening position: ", trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
//| Calculate dynamic lot size based on risk                         |
//+------------------------------------------------------------------+
double CalculateLotSize(ENUM_ORDER_TYPE orderType)
{
   double lots = InpLotSize;
   
   if(InpRiskPercent <= 0)
      return lots;
   
   double balance = accountInfo.Balance();
   double riskAmount = balance * InpRiskPercent / 100.0;
   
   double slDistance = 0.0;
   double point = symbolInfo.Point();
   double pipValue = point * 10;
   
   if(InpUseRangeStops)
   {
      slDistance = MathAbs(g_openingRange.high - g_openingRange.low);
   }
   else
   {
      slDistance = InpStopLossPips * pipValue;
   }
   
   if(slDistance > 0)
   {
      double tickValue = symbolInfo.TickValue();
      double tickSize = symbolInfo.TickSize();
      
      if(tickSize > 0)
      {
         double pointsRisk = slDistance / point;
         double moneyPerLot = pointsRisk * tickValue * point / tickSize;
         
         if(moneyPerLot > 0)
         {
            lots = riskAmount / moneyPerLot;
         }
      }
   }
   
   return lots;
}

//+------------------------------------------------------------------+
//| Check if position exists                                         |
//+------------------------------------------------------------------+
bool HasPosition(ENUM_POSITION_TYPE posType)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(position.SelectByIndex(i))
      {
         if(position.Symbol() == _Symbol && position.Magic() == InpMagicNumber)
         {
            if(position.PositionType() == posType)
               return true;
         }
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Manage open positions                                            |
//+------------------------------------------------------------------+
void ManagePositions()
{
   //--- Can add trailing stop, breakeven, or other management here
   //--- Currently positions are managed by their SL/TP levels
}

//+------------------------------------------------------------------+
//| Close all positions for this symbol and magic number             |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(position.SelectByIndex(i))
      {
         if(position.Symbol() == _Symbol && position.Magic() == InpMagicNumber)
         {
            trade.PositionClose(position.Ticket());
            Print("Position closed at end of day: Ticket=", position.Ticket());
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check if within trading hours                                    |
//+------------------------------------------------------------------+
bool IsWithinTradingHours()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   
   if(dt.hour < InpTradingStartHour || dt.hour >= InpTradingEndHour)
      return false;
   
   return true;
}
//+------------------------------------------------------------------+

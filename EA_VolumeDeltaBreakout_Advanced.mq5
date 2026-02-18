//+------------------------------------------------------------------+
//|                                EA_VolumeDeltaBreakout_Advanced.mq5 |
//|                        Copyright 2026, MetaQuotes Software Corp.  |
//|                                             https://www.mql5.com  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

// Include necessary libraries
#include <Trade\Trade.mqh>
#include <Object.mqh>
#include <StdLibErr.mqh>
#include <Trade\OrderInfo.mqh>
#include <Trade\HistoryOrderInfo.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\DealInfo.mqh>

// Input parameters
input double LotSize = 0.1;               // Lot size
input int StopLoss = 100;                 // Stop loss in points
input int TakeProfit = 200;               // Take profit in points
input int VolumePeriod = 20;              // Volume period
input double DeltaThreshold = 1.5;        // Delta threshold
input int BreakoutBars = 3;               // Breakout confirmation bars
input bool UseTrailing = true;            // Use trailing stop
input int TrailingStop = 50;              // Trailing stop in points
input int TrailingStep = 10;              // Trailing step in points
input int MagicNumber = 12345;            // Magic number
input string TradeComment = "VolumeDelta"; // Trade comment

// Global variables
CTrade trade;
CPositionInfo positionInfo;
COrderInfo orderInfo;
CDealInfo dealInfo;

datetime lastBarTime = 0;
double volumeBuffer[];
double priceBuffer[];
int barsTotal = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Set trade parameters
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(10);
   trade.SetTypeFilling(ORDER_FILLING_FOK);
   
   // Initialize arrays
   ArraySetAsSeries(volumeBuffer, true);
   ArraySetAsSeries(priceBuffer, true);
   
   // Print initialization message
   Print("EA_VolumeDeltaBreakout_Advanced initialized successfully");
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("EA_VolumeDeltaBreakout_Advanced stopped. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Check for new bar
   if(!IsNewBar())
      return;
   
   // Error on line 78 - trying to modify a constant
   const bool UseCustomIndicator = true;
   UseCustomIndicator = false;  // ERROR: constant cannot be modified
   
   // Calculate volume delta
   double volumeDelta = CalculateVolumeDelta();
   
   // Check for breakout signal
   if(volumeDelta > DeltaThreshold)
   {
      // Check if we can open a buy position
      if(!PositionExists())
      {
         OpenBuyPosition();
      }
   }
   else if(volumeDelta < -DeltaThreshold)
   {
      // Check if we can open a sell position
      if(!PositionExists())
      {
         OpenSellPosition();
      }
   }
   
   // Manage open positions
   if(UseTrailing)
   {
      ManageTrailingStop();
   }
}

//+------------------------------------------------------------------+
//| Check if it's a new bar                                          |
//+------------------------------------------------------------------+
bool IsNewBar()
{
   datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   
   if(currentBarTime != lastBarTime)
   {
      lastBarTime = currentBarTime;
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Calculate volume delta                                           |
//+------------------------------------------------------------------+
double CalculateVolumeDelta()
{
   // Get volume data
   long tickVolume[];
   ArraySetAsSeries(tickVolume, true);
   
   int copied = CopyTickVolume(_Symbol, PERIOD_CURRENT, 0, VolumePeriod, tickVolume);
   
   if(copied < VolumePeriod)
      return 0.0;
   
   // Calculate average volume
   long totalVolume = 0;
   for(int i = 0; i < VolumePeriod; i++)
   {
      totalVolume += tickVolume[i];
   }
   
   double avgVolume = (double)totalVolume / VolumePeriod;
   long currentVolume = tickVolume[0];
   
   // Calculate delta
   double delta = (currentVolume - avgVolume) / avgVolume;
   
   return delta;
}

//+------------------------------------------------------------------+
//| Check if position exists                                         |
//+------------------------------------------------------------------+
bool PositionExists()
{
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(positionInfo.SelectByIndex(i))
      {
         if(positionInfo.Symbol() == _Symbol && positionInfo.Magic() == MagicNumber)
         {
            return true;
         }
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Open buy position                                                |
//+------------------------------------------------------------------+
void OpenBuyPosition()
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   double sl = 0;
   double tp = 0;
   
   if(StopLoss > 0)
      sl = ask - StopLoss * _Point;
   
   if(TakeProfit > 0)
      tp = ask + TakeProfit * _Point;
   
   if(trade.Buy(LotSize, _Symbol, ask, sl, tp, TradeComment))
   {
      Print("Buy position opened at ", ask);
   }
   else
   {
      Print("Failed to open buy position. Error: ", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| Open sell position                                               |
//+------------------------------------------------------------------+
void OpenSellPosition()
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   double sl = 0;
   double tp = 0;
   
   if(StopLoss > 0)
      sl = bid + StopLoss * _Point;
   
   if(TakeProfit > 0)
      tp = bid - TakeProfit * _Point;
   
   if(trade.Sell(LotSize, _Symbol, bid, sl, tp, TradeComment))
   {
      Print("Sell position opened at ", bid);
   }
   else
   {
      Print("Failed to open sell position. Error: ", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| Manage trailing stop                                             |
//+------------------------------------------------------------------+
void ManageTrailingStop()
{
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(positionInfo.SelectByIndex(i))
      {
         if(positionInfo.Symbol() == _Symbol && positionInfo.Magic() == MagicNumber)
         {
            double currentPrice;
            double sl = positionInfo.StopLoss();
            double tp = positionInfo.TakeProfit();
            double openPrice = positionInfo.PriceOpen();
            
            if(positionInfo.Type() == POSITION_TYPE_BUY)
            {
               currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
               double newSL = currentPrice - TrailingStop * _Point;
               
               if(newSL > sl + TrailingStep * _Point)
               {
                  trade.PositionModify(positionInfo.Ticket(), newSL, tp);
               }
            }
            else if(positionInfo.Type() == POSITION_TYPE_SELL)
            {
               currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
               double newSL = currentPrice + TrailingStop * _Point;
               
               if(newSL < sl - TrailingStep * _Point || sl == 0)
               {
                  trade.PositionModify(positionInfo.Ticket(), newSL, tp);
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Calculate position size based on risk                            |
//+------------------------------------------------------------------+
double CalculatePositionSize(double riskPercent, int stopLossPoints)
{
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = accountBalance * riskPercent / 100.0;
   
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   double stopLossValue = stopLossPoints * point / tickSize * tickValue;
   
   double lotSize = riskAmount / stopLossValue;
   
   // Normalize lot size
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   lotSize = MathFloor(lotSize / lotStep) * lotStep;
   lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
   
   return lotSize;
}

//+------------------------------------------------------------------+
//| Get volume analysis                                              |
//+------------------------------------------------------------------+
void AnalyzeVolume()
{
   long tickVolume[];
   long realVolume[];
   
   ArraySetAsSeries(tickVolume, true);
   ArraySetAsSeries(realVolume, true);
   
   int tickCopied = CopyTickVolume(_Symbol, PERIOD_CURRENT, 0, 100, tickVolume);
   int realCopied = CopyRealVolume(_Symbol, PERIOD_CURRENT, 0, 100, realVolume);
   
   if(tickCopied > 0 && realCopied > 0)
   {
      long totalTickVolume = 0;
      long totalRealVolume = 0;
      
      for(int i = 0; i < 100; i++)
      {
         totalTickVolume += tickVolume[i];
         totalRealVolume += realVolume[i];
      }
      
      // WARNING: Type conversion from 'long' to 'double' on line 404
      double avgTickVolume = totalTickVolume / 100.0;
      // WARNING: Type conversion from 'long' to 'double' on line 406
      double avgRealVolume = totalRealVolume / 100.0;
      
      Print("Average Tick Volume: ", avgTickVolume);
      Print("Average Real Volume: ", avgRealVolume);
   }
}

//+------------------------------------------------------------------+
//| Calculate volume weighted average price                          |
//+------------------------------------------------------------------+
double CalculateVWAP()
{
   long volume[];
   double close[];
   
   ArraySetAsSeries(volume, true);
   ArraySetAsSeries(close, true);
   
   int volumeCopied = CopyTickVolume(_Symbol, PERIOD_CURRENT, 0, VolumePeriod, volume);
   int priceCopied = CopyClose(_Symbol, PERIOD_CURRENT, 0, VolumePeriod, close);
   
   if(volumeCopied < VolumePeriod || priceCopied < VolumePeriod)
      return 0.0;
   
   long totalVolume = 0;
   double totalPriceVolume = 0.0;
   
   for(int i = 0; i < VolumePeriod; i++)
   {
      totalPriceVolume += close[i] * volume[i];
      totalVolume += volume[i];
   }
   
   if(totalVolume == 0)
      return 0.0;
   
   // WARNING: Type conversion from 'long' to 'double' on line 445
   double vwap = totalPriceVolume / totalVolume;
   
   // WARNING: Type conversion from 'long' to 'double' on line 447
   double volumeRatio = totalVolume / VolumePeriod;
   
   return vwap;
}
//+------------------------------------------------------------------+

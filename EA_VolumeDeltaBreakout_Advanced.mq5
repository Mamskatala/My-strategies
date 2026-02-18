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
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>
#include <Trade\HistoryOrderInfo.mqh>
#include <Trade\DealInfo.mqh>

//--- Input parameters
input group "=== Indicator Settings ==="
input int    VolumePeriod = 14;              // Volume analysis period
input double VolumeThreshold = 1.5;          // Volume threshold multiplier

//--- Global configuration (not input parameter to allow modification)
bool UseCustomIndicator = true;              // Use custom Volume Delta indicator

input group "=== Breakout Settings ==="
input int    BreakoutPeriod = 20;            // Breakout detection period  
input double BreakoutBuffer = 10.0;          // Breakout buffer in points
input int    MinBarsForBreakout = 5;         // Minimum bars for valid breakout

input group "=== Risk Management ==="
input double RiskPercent = 1.0;              // Risk per trade in %
input double StopLossPips = 50.0;            // Stop loss in pips
input double TakeProfitPips = 100.0;         // Take profit in pips
input int    MaxPositions = 3;               // Maximum open positions

input group "=== Trading Hours ==="
input int    StartHour = 8;                  // Trading start hour
input int    EndHour = 20;                   // Trading end hour
input bool   TradeMondayOnly = false;        // Trade only on Monday

//--- Global variables
CTrade         trade;
CPositionInfo  positionInfo;
COrderInfo     orderInfo;
CDealInfo      dealInfo;

int            volumeHandle;
double         volumeBuffer[];
int            indicatorPeriod;
datetime       lastBarTime;
int            totalBarsProcessed;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Initialize trading parameters
   trade.SetExpertMagicNumber(123456);
   trade.SetDeviationInPoints(10);
   trade.SetTypeFilling(ORDER_FILLING_FOK);
   
   //--- Modify indicator usage in test mode if needed
   if(MQLInfoInteger(MQL_TESTER))
   {
      UseCustomIndicator = false;  // Disable custom indicator in tester
   }
   
   //--- Initialize indicator
   if(UseCustomIndicator)
   {
      volumeHandle = iCustom(_Symbol, _Period, "VolumeDelta", VolumePeriod);
      if(volumeHandle == INVALID_HANDLE)
      {
         Print("Failed to create custom indicator handle");
         return(INIT_FAILED);
      }
   }
   else
   {
      volumeHandle = iVolumes(_Symbol, _Period, VOLUME_TICK);
      if(volumeHandle == INVALID_HANDLE)
      {
         Print("Failed to create volume indicator handle");
         return(INIT_FAILED);
      }
   }
   
   ArraySetAsSeries(volumeBuffer, true);
   
   lastBarTime = 0;
   totalBarsProcessed = 0;
   indicatorPeriod = VolumePeriod;
   
   Print("EA initialized successfully");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- Release indicator handle
   if(volumeHandle != INVALID_HANDLE)
      IndicatorRelease(volumeHandle);
   
   Print("EA deinitialized, reason: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Check for new bar
   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   if(currentBarTime == lastBarTime)
      return;
   
   lastBarTime = currentBarTime;
   totalBarsProcessed++;
   
   //--- Check trading hours
   if(!IsTradingTime())
      return;
   
   //--- Update indicator data
   if(CopyBuffer(volumeHandle, 0, 0, VolumePeriod + 1, volumeBuffer) <= 0)
   {
      Print("Failed to copy indicator buffer");
      return;
   }
   
   //--- Check for trading signals
   int signal = AnalyzeMarket();
   
   if(signal != 0)
   {
      //--- Count current positions
      int currentPositions = CountPositions();
      
      if(currentPositions < MaxPositions)
      {
         if(signal > 0)
            OpenBuyPosition();
         else if(signal < 0)
            OpenSellPosition();
      }
   }
   
   //--- Manage existing positions
   ManagePositions();
}

//+------------------------------------------------------------------+
//| Check if current time is within trading hours                    |
//+------------------------------------------------------------------+
bool IsTradingTime()
{
   MqlDateTime dt;
   TimeCurrent(dt);
   
   //--- Check day of week if Monday only is enabled
   if(TradeMondayOnly && dt.day_of_week != 1)
      return false;
   
   //--- Check trading hours
   if(dt.hour < StartHour || dt.hour >= EndHour)
      return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| Analyze market conditions and return signal                      |
//+------------------------------------------------------------------+
int AnalyzeMarket()
{
   //--- Get price data
   double close[], high[], low[], open[];
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(open, true);
   
   if(CopyClose(_Symbol, _Period, 0, BreakoutPeriod + 5, close) <= 0)
      return 0;
   if(CopyHigh(_Symbol, _Period, 0, BreakoutPeriod + 5, high) <= 0)
      return 0;
   if(CopyLow(_Symbol, _Period, 0, BreakoutPeriod + 5, low) <= 0)
      return 0;
   if(CopyOpen(_Symbol, _Period, 0, BreakoutPeriod + 5, open) <= 0)
      return 0;
   
   //--- Find highest high and lowest low
   int highestBar = ArrayMaximum(high, 1, BreakoutPeriod);
   int lowestBar = ArrayMinimum(low, 1, BreakoutPeriod);
   
   if(highestBar < 0 || lowestBar < 0)
      return 0;
   
   double highestHigh = high[highestBar];
   double lowestLow = low[lowestBar];
   
   //--- Calculate breakout levels
   double buyLevel = highestHigh + BreakoutBuffer * _Point;
   double sellLevel = lowestLow - BreakoutBuffer * _Point;
   
   //--- Check for volume confirmation
   double avgVolume = CalculateAverageVolume();
   if(volumeBuffer[0] < avgVolume * VolumeThreshold)
      return 0;
   
   //--- Check for bullish breakout
   if(close[0] > buyLevel && close[1] <= buyLevel)
   {
      //--- Verify minimum bars requirement
      if(IsBullishBreakoutValid(high, close, highestBar))
         return 1;  // Buy signal
   }
   
   //--- Check for bearish breakout
   if(close[0] < sellLevel && close[1] >= sellLevel)
   {
      //--- Verify minimum bars requirement
      if(IsBearishBreakoutValid(low, close, lowestBar))
         return -1;  // Sell signal
   }
   
   return 0;  // No signal
}

//+------------------------------------------------------------------+
//| Calculate average volume                                         |
//+------------------------------------------------------------------+
double CalculateAverageVolume()
{
   double sum = 0.0;
   int count = 0;
   
   for(int i = 1; i < ArraySize(volumeBuffer); i++)
   {
      sum += volumeBuffer[i];
      count++;
   }
   
   return (count > 0) ? sum / count : 0.0;
}

//+------------------------------------------------------------------+
//| Validate bullish breakout                                        |
//+------------------------------------------------------------------+
bool IsBullishBreakoutValid(const double &high[], const double &close[], int highestBar)
{
   //--- Check if enough bars have passed since highest high
   if(highestBar < MinBarsForBreakout)
      return false;
   
   //--- Additional validation logic here
   return true;
}

//+------------------------------------------------------------------+
//| Validate bearish breakout                                        |
//+------------------------------------------------------------------+
bool IsBearishBreakoutValid(const double &low[], const double &close[], int lowestBar)
{
   //--- Check if enough bars have passed since lowest low
   if(lowestBar < MinBarsForBreakout)
      return false;
   
   //--- Additional validation logic here
   return true;
}

//+------------------------------------------------------------------+
//| Count current open positions                                     |
//+------------------------------------------------------------------+
int CountPositions()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(positionInfo.SelectByIndex(i))
      {
         if(positionInfo.Symbol() == _Symbol && 
            positionInfo.Magic() == trade.RequestMagic())
         {
            count++;
         }
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Open buy position                                                |
//+------------------------------------------------------------------+
void OpenBuyPosition()
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double sl = ask - StopLossPips * _Point * 10;
   double tp = ask + TakeProfitPips * _Point * 10;
   
   //--- Calculate position size based on risk
   double lotSize = CalculateLotSize(ask - sl);
   
   if(trade.Buy(lotSize, _Symbol, ask, sl, tp, "VDB Buy"))
   {
      Print("Buy position opened at ", ask);
   }
   else
   {
      Print("Failed to open buy position, error: ", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| Open sell position                                               |
//+------------------------------------------------------------------+
void OpenSellPosition()
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl = bid + StopLossPips * _Point * 10;
   double tp = bid - TakeProfitPips * _Point * 10;
   
   //--- Calculate position size based on risk
   double lotSize = CalculateLotSize(sl - bid);
   
   if(trade.Sell(lotSize, _Symbol, bid, sl, tp, "VDB Sell"))
   {
      Print("Sell position opened at ", bid);
   }
   else
   {
      Print("Failed to open sell position, error: ", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| Calculate lot size based on risk                                 |
//+------------------------------------------------------------------+
double CalculateLotSize(double stopLossDistance)
{
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = accountBalance * RiskPercent / 100.0;
   
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   
   double lotSize = 0.0;
   if(stopLossDistance > 0 && tickSize > 0)
   {
      lotSize = riskAmount / (stopLossDistance / tickSize * tickValue);
   }
   
   //--- Normalize lot size
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   lotSize = MathFloor(lotSize / lotStep) * lotStep;
   lotSize = MathMax(lotSize, minLot);
   lotSize = MathMin(lotSize, maxLot);
   
   return lotSize;
}

//+------------------------------------------------------------------+
//| Manage existing positions                                        |
//+------------------------------------------------------------------+
void ManagePositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(positionInfo.SelectByIndex(i))
      {
         if(positionInfo.Symbol() == _Symbol && 
            positionInfo.Magic() == trade.RequestMagic())
         {
            //--- Check for trailing stop or other management logic
            ManageTrailingStop(positionInfo);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Manage trailing stop for a position                              |
//+------------------------------------------------------------------+
void ManageTrailingStop(CPositionInfo &pos)
{
   double currentPrice;
   double currentSL = pos.StopLoss();
   double currentTP = pos.TakeProfit();
   
   if(pos.PositionType() == POSITION_TYPE_BUY)
   {
      currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double newSL = currentPrice - StopLossPips * _Point * 10;
      
      if(newSL > currentSL && currentPrice > pos.PriceOpen() + StopLossPips * _Point * 5)
      {
         trade.PositionModify(pos.Ticket(), newSL, currentTP);
      }
   }
   else if(pos.PositionType() == POSITION_TYPE_SELL)
   {
      currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double newSL = currentPrice + StopLossPips * _Point * 10;
      
      if(newSL < currentSL && currentPrice < pos.PriceOpen() - StopLossPips * _Point * 5)
      {
         trade.PositionModify(pos.Ticket(), newSL, currentTP);
      }
   }
}

//+------------------------------------------------------------------+
//| OnTrade event handler                                            |
//+------------------------------------------------------------------+
void OnTrade()
{
   //--- Handle trade events
   Print("Trade event occurred");
}

//+------------------------------------------------------------------+
//| OnTradeTransaction event handler                                 |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
{
   //--- Handle trade transactions
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
   {
      if(dealInfo.Select(trans.deal))
      {
         Print("Deal executed: ", dealInfo.Symbol(), " Volume: ", dealInfo.Volume());
      }
   }
}
//+------------------------------------------------------------------+

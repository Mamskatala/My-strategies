//+------------------------------------------------------------------+
//|                               EA_VolumeDeltaBreakout_Advanced.mq5 |
//|                                              Advanced Volume EA   |
//+------------------------------------------------------------------+
#property copyright "Trading Strategy"
#property version   "1.00"
#property description "Volume Delta Breakout Strategy"

// Input parameters
input double LotSize = 0.01;
input int MagicNumber = 123456;
input int Slippage = 3;

// Global variables
int ticket = 0;
datetime lastTradeTime = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("EA_VolumeDeltaBreakout_Advanced initialized");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("EA_VolumeDeltaBreakout_Advanced stopped");
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   // Check for new bar
   static datetime lastBarTime = 0;
   datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   
   if(currentBarTime == lastBarTime)
      return;
      
   lastBarTime = currentBarTime;
   
   // Get volume data
   long tickVolume = iVolume(_Symbol, PERIOD_CURRENT, 1);
   
   // Check for breakout conditions
   CheckBreakout(tickVolume);
}

//+------------------------------------------------------------------+
//| Check breakout conditions                                         |
//+------------------------------------------------------------------+
void CheckBreakout(long volume)
{
   // Calculate average volume
   long avgVolume = 0;
   for(int i = 2; i < 22; i++)
   {
      avgVolume += iVolume(_Symbol, PERIOD_CURRENT, i);
   }
   avgVolume = avgVolume / 20;
   
   // Volume spike detection
   if(volume > avgVolume * 1.5)
   {
      // Potential breakout detected
      double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double previousHigh = iHigh(_Symbol, PERIOD_CURRENT, 1);
      double previousLow = iLow(_Symbol, PERIOD_CURRENT, 1);
      
      // Check for bullish breakout
      if(currentPrice > previousHigh)
      {
         OpenPosition(ORDER_TYPE_BUY);
      }
      // Check for bearish breakout
      else if(currentPrice < previousLow)
      {
         OpenPosition(ORDER_TYPE_SELL);
      }
   }
}

//+------------------------------------------------------------------+
//| Open position                                                      |
//+------------------------------------------------------------------+
void OpenPosition(ENUM_ORDER_TYPE orderType)
{
   MqlTradeRequest request;
   MqlTradeResult result;
   
   ZeroMemory(request);
   ZeroMemory(result);
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = LotSize;
   request.type = orderType;
   request.price = (orderType == ORDER_TYPE_BUY) ? 
                   SymbolInfoDouble(_Symbol, SYMBOL_ASK) : 
                   SymbolInfoDouble(_Symbol, SYMBOL_BID);
   request.deviation = Slippage;
   request.magic = MagicNumber;
   
   if(!OrderSend(request, result))
   {
      Print("OrderSend error: ", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| Get volume delta                                                  |
//+------------------------------------------------------------------+
double GetVolumeDelta(int shift)
{
   long buyVolume = 0;
   long sellVolume = 0;
   
   datetime barTime = iTime(_Symbol, PERIOD_CURRENT, shift);
   datetime nextBarTime = (shift == 0) ? TimeCurrent() : iTime(_Symbol, PERIOD_CURRENT, shift - 1);
   
   // Historical deal selection
   HistorySelect(barTime, nextBarTime);
   
   int totalDeals = HistoryDealsTotal();
   
   for(int i = 0; i < totalDeals; i++)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      
      if(dealTicket > 0)
      {
         string dealSymbol = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
         
         if(dealSymbol == _Symbol)
         {
            ENUM_DEAL_TYPE dealType = (ENUM_DEAL_TYPE)HistoryDealGetInteger(dealTicket, DEAL_TYPE);
            long dealVolume = HistoryDealGetInteger(dealTicket, DEAL_VOLUME);
            
            if(dealType == DEAL_TYPE_BUY)
            {
               buyVolume += dealVolume;
            }
            else if(dealType == DEAL_TYPE_SELL)
            {
               sellVolume += dealVolume;
            }
         }
      }
   }
   
   return (double)(buyVolume - sellVolume);
}

//+------------------------------------------------------------------+
//| Calculate position size based on risk                             |
//+------------------------------------------------------------------+
double CalculatePositionSize(double riskPercent, double stopLossPips)
{
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = accountBalance * (riskPercent / 100.0);
   
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double pointValue = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double pipValue = tickValue * 10;
   
   double positionSize = riskAmount / (stopLossPips * pipValue);
   
   return NormalizeDouble(positionSize, 2);
}

//+------------------------------------------------------------------+
//| Check if trading is allowed                                       |
//+------------------------------------------------------------------+
bool IsTradingAllowed()
{
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
   {
      Print("Trading is not allowed in the terminal");
      return false;
   }
   
   if(!MQLInfoInteger(MQL_TRADE_ALLOWED))
   {
      Print("Trading is not allowed for the EA");
      return false;
   }
   
   if(!SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE))
   {
      Print("Trading is not allowed for ", _Symbol);
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Get average true range                                            |
//+------------------------------------------------------------------+
double GetATR(int period, int shift)
{
   double atrSum = 0;
   
   for(int i = shift; i < shift + period; i++)
   {
      double high = iHigh(_Symbol, PERIOD_CURRENT, i);
      double low = iLow(_Symbol, PERIOD_CURRENT, i);
      double prevClose = iClose(_Symbol, PERIOD_CURRENT, i + 1);
      
      double tr = MathMax(high - low, MathMax(MathAbs(high - prevClose), MathAbs(low - prevClose)));
      atrSum += tr;
   }
   
   return atrSum / period;
}

//+------------------------------------------------------------------+
//| Manage open positions                                             |
//+------------------------------------------------------------------+
void ManagePositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong positionTicket = PositionGetTicket(i);
      
      if(positionTicket > 0)
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
            PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         {
            double positionProfit = PositionGetDouble(POSITION_PROFIT);
            double positionOpenPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double currentPrice = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ?
                                 SymbolInfoDouble(_Symbol, SYMBOL_BID) :
                                 SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            
            // Trailing stop logic
            double atr = GetATR(14, 1);
            double trailingDistance = atr * 2.0;
            
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
            {
               double newStopLoss = currentPrice - trailingDistance;
               double currentStopLoss = PositionGetDouble(POSITION_SL);
               
               if(newStopLoss > currentStopLoss && newStopLoss < currentPrice)
               {
                  ModifyPosition(positionTicket, newStopLoss, PositionGetDouble(POSITION_TP));
               }
            }
            else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
            {
               double newStopLoss = currentPrice + trailingDistance;
               double currentStopLoss = PositionGetDouble(POSITION_SL);
               
               if((currentStopLoss == 0 || newStopLoss < currentStopLoss) && newStopLoss > currentPrice)
               {
                  ModifyPosition(positionTicket, newStopLoss, PositionGetDouble(POSITION_TP));
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Modify position                                                    |
//+------------------------------------------------------------------+
void ModifyPosition(ulong ticket, double stopLoss, double takeProfit)
{
   MqlTradeRequest request;
   MqlTradeResult result;
   
   ZeroMemory(request);
   ZeroMemory(result);
   
   request.action = TRADE_ACTION_SLTP;
   request.position = ticket;
   request.sl = NormalizeDouble(stopLoss, _Digits);
   request.tp = NormalizeDouble(takeProfit, _Digits);
   
   if(!OrderSend(request, result))
   {
      Print("Position modify error: ", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| Close all positions                                               |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong positionTicket = PositionGetTicket(i);
      
      if(positionTicket > 0)
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
            PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         {
            MqlTradeRequest request;
            MqlTradeResult result;
            
            ZeroMemory(request);
            ZeroMemory(result);
            
            request.action = TRADE_ACTION_DEAL;
            request.position = positionTicket;
            request.symbol = _Symbol;
            request.volume = PositionGetDouble(POSITION_VOLUME);
            request.type = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 
                          ORDER_TYPE_SELL : ORDER_TYPE_BUY;
            request.price = (request.type == ORDER_TYPE_BUY) ?
                           SymbolInfoDouble(_Symbol, SYMBOL_ASK) :
                           SymbolInfoDouble(_Symbol, SYMBOL_BID);
            request.deviation = Slippage;
            request.magic = MagicNumber;
            
            if(!OrderSend(request, result))
            {
               Print("Position close error: ", GetLastError());
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check for volume spike breakout                                   |
//+------------------------------------------------------------------+
bool CheckVolumeSpike()
{
   long currentVolume = iVolume(_Symbol, PERIOD_CURRENT, 1);
   long avgVolume = 0;
   
   for(int i = 2; i < 22; i++)
   {
      avgVolume += iVolume(_Symbol, PERIOD_CURRENT, i);
   }
   avgVolume = avgVolume / 20;
   
   return (currentVolume > avgVolume * 2.0);
}

//+------------------------------------------------------------------+
//| Calculate volume-weighted average price                           |
//+------------------------------------------------------------------+
double CalculateVWAP(int bars)
{
   double totalPriceVolume = 0;
   long totalVolume = 0;
   
   for(int i = 0; i < bars; i++)
   {
      double typicalPrice = (iHigh(_Symbol, PERIOD_CURRENT, i) + 
                            iLow(_Symbol, PERIOD_CURRENT, i) + 
                            iClose(_Symbol, PERIOD_CURRENT, i)) / 3.0;
      long volume = iVolume(_Symbol, PERIOD_CURRENT, i);
      
      totalPriceVolume += typicalPrice * volume;
      totalVolume += volume;
   }
   
   if(totalVolume > 0)
      return totalPriceVolume / totalVolume;
   else
      return 0;
}

//+------------------------------------------------------------------+
//| Advanced volume analysis                                          |
//+------------------------------------------------------------------+
void AnalyzeVolumePattern()
{
   // Get recent volume data
   long volumes[10];
   for(int i = 0; i < 10; i++)
   {
      volumes[i] = iVolume(_Symbol, PERIOD_CURRENT, i + 1);
   }
   
   // Calculate volume trend
   double volumeTrend = 0;
   for(int i = 0; i < 9; i++)
   {
      volumeTrend += (volumes[i] - volumes[i + 1]);
   }
   volumeTrend = volumeTrend / 9.0;
   
   // Analyze volume delta for each bar
   for(int i = 1; i < 5; i++)
   {
      double volumeDelta = GetVolumeDelta(i);
      
      // Use volume delta for trading decisions
      if(volumeDelta > 0)
      {
         // Bullish volume delta
         Print("Bullish volume delta at bar ", i, ": ", volumeDelta);
      }
      else if(volumeDelta < 0)
      {
         // Bearish volume delta
         Print("Bearish volume delta at bar ", i, ": ", volumeDelta);
      }
   }
   
   // Additional analysis functions
   //
   //
   //
   //
   //
   //
   //
   //
   //
   //
   //
   //
   //
   //
   //
   //
   //
   //
   //
   //
   //
   //
   // Check for valid deal
   ulong deal = 0;  // Declare deal variable
   if(deal > 0)  // Fixed: removed undeclared identifier, added proper syntax
   {
      Print("Processing deal");
   }
}
//+------------------------------------------------------------------+

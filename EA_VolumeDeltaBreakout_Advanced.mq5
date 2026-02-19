//+------------------------------------------------------------------+
//|                               EA_VolumeDeltaBreakout_Advanced.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

// Include required libraries
#include "Include/NotificationManager.mqh"
#include "Include/TradeExecution.mqh"
#include "Include/AdaptiveRiskController.mqh"

//--- input parameters
input double   InpLotSize = 0.1;              // Lot size
input int      InpMagicNumber = 123456;       // Magic number
input int      InpVolumePeriod = 20;          // Volume period
input double   InpDeltaThreshold = 0.5;       // Delta threshold
input int      InpBreakoutBars = 3;           // Breakout bars
input double   InpStopLoss = 100;             // Stop loss (points)
input double   InpTakeProfit = 200;           // Take profit (points)
input bool     InpEnableNotifications = true; // Enable notifications
input bool     InpEnableAdaptiveRisk = true;  // Enable adaptive risk
input double   InpMaxRiskPercent = 2.0;       // Max risk percent
input int      InpSlippage = 3;               // Slippage (points)

//--- global variables
double g_volumeDelta[];
double g_priceHigh[];
double g_priceLow[];
double g_priceClose[];
long g_volume[];
int g_barCount = 0;
bool g_initialized = false;
datetime g_lastBarTime = 0;

//--- strategy state
enum ENUM_SIGNAL_TYPE
{
   SIGNAL_NONE = 0,
   SIGNAL_BUY = 1,
   SIGNAL_SELL = -1
};

struct StrategyState
{
   ENUM_SIGNAL_TYPE lastSignal;
   datetime lastTradeTime;
   int consecutiveWins;
   int consecutiveLosses;
   double currentEquity;
   double startingEquity;
   bool inPosition;
   int positionTicket;
};

StrategyState g_state;

//--- tracking variables
struct PerformanceMetrics
{
   int totalTrades;
   int winningTrades;
   int losingTrades;
   double totalProfit;
   double totalLoss;
   double largestWin;
   double largestLoss;
   double currentDrawdown;
   double maxDrawdown;
};

PerformanceMetrics g_metrics;

//--- volume analysis
struct VolumeAnalysis
{
   double buyVolume;
   double sellVolume;
   double volumeDelta;
   double volumeRatio;
   bool bullishDivergence;
   bool bearishDivergence;
   double avgVolume;
   double volumeStdDev;
};

VolumeAnalysis g_volAnalysis;

//--- breakout detection
struct BreakoutSignal
{
   bool isValid;
   ENUM_SIGNAL_TYPE direction;
   double entryPrice;
   double stopLoss;
   double takeProfit;
   double volume;
   datetime signalTime;
   int strength;
};

BreakoutSignal g_breakout;

//--- global class instances
CNotificationManager g_notifier;
CTradeExecutor g_executor;
CAdaptiveRiskController g_riskCtrl;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- validate input parameters
   if(InpVolumePeriod <= 0 || InpVolumePeriod > 10000)
   {
      Print("Invalid InpVolumePeriod parameter: ", InpVolumePeriod, ". Must be between 1 and 10000.");
      return(INIT_PARAMETERS_INCORRECT);
   }
   
   if(InpBreakoutBars <= 0 || InpBreakoutBars > 1000)
   {
      Print("Invalid InpBreakoutBars parameter: ", InpBreakoutBars, ". Must be between 1 and 1000.");
      return(INIT_PARAMETERS_INCORRECT);
   }
   
   if(InpLotSize <= 0)
   {
      Print("Invalid InpLotSize parameter: ", InpLotSize, ". Must be greater than 0.");
      return(INIT_PARAMETERS_INCORRECT);
   }
   
   if(InpMaxRiskPercent <= 0 || InpMaxRiskPercent > 50)
   {
      Print("Invalid InpMaxRiskPercent parameter: ", InpMaxRiskPercent, ". Must be between 0 and 50.");
      return(INIT_PARAMETERS_INCORRECT);
   }
   
   if(InpStopLoss < 0 || InpTakeProfit < 0)
   {
      Print("Invalid stop loss or take profit parameters. Must be non-negative.");
      return(INIT_PARAMETERS_INCORRECT);
   }
   
   if(InpSlippage < 0)
   {
      Print("Invalid InpSlippage parameter: ", InpSlippage, ". Must be non-negative.");
      return(INIT_PARAMETERS_INCORRECT);
   }
   
   //--- initialize arrays
   ArrayResize(g_volumeDelta, InpVolumePeriod);
   ArrayResize(g_priceHigh, InpBreakoutBars);
   ArrayResize(g_priceLow, InpBreakoutBars);
   ArrayResize(g_priceClose, InpBreakoutBars);
   ArrayResize(g_volume, InpVolumePeriod);
   
   ArrayInitialize(g_volumeDelta, 0);
   ArrayInitialize(g_priceHigh, 0);
   ArrayInitialize(g_priceLow, 0);
   ArrayInitialize(g_priceClose, 0);
   for(int i = 0; i < InpVolumePeriod; i++)
      g_volume[i] = 0;
   
   //--- initialize state
   g_state.lastSignal = SIGNAL_NONE;
   g_state.lastTradeTime = 0;
   g_state.consecutiveWins = 0;
   g_state.consecutiveLosses = 0;
   g_state.currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_state.startingEquity = g_state.currentEquity;
   g_state.inPosition = false;
   g_state.positionTicket = 0;
   
   //--- initialize metrics
   g_metrics.totalTrades = 0;
   g_metrics.winningTrades = 0;
   g_metrics.losingTrades = 0;
   g_metrics.totalProfit = 0;
   g_metrics.totalLoss = 0;
   g_metrics.largestWin = 0;
   g_metrics.largestLoss = 0;
   g_metrics.currentDrawdown = 0;
   g_metrics.maxDrawdown = 0;
   
   //--- initialize volume analysis
   g_volAnalysis.buyVolume = 0;
   g_volAnalysis.sellVolume = 0;
   g_volAnalysis.volumeDelta = 0;
   g_volAnalysis.volumeRatio = 0;
   g_volAnalysis.bullishDivergence = false;
   g_volAnalysis.bearishDivergence = false;
   g_volAnalysis.avgVolume = 0;
   g_volAnalysis.volumeStdDev = 0;
   
   //--- initialize breakout signal
   g_breakout.isValid = false;
   g_breakout.direction = SIGNAL_NONE;
   g_breakout.entryPrice = 0;
   g_breakout.stopLoss = 0;
   g_breakout.takeProfit = 0;
   g_breakout.volume = 0;
   g_breakout.signalTime = 0;
   g_breakout.strength = 0;
   
   //--- initialize components
   if(!g_notifier.Init(_Symbol, InpMagicNumber, InpEnableNotifications))
   {
      Print("Failed to initialize notification manager");
      return(INIT_FAILED);
   }
   
   if(!g_executor.Init(_Symbol, InpMagicNumber, InpSlippage))
   {
      Print("Failed to initialize trade executor");
      return(INIT_FAILED);
   }
   
   if(!g_riskCtrl.Init(InpMaxRiskPercent, InpEnableAdaptiveRisk))
   {
      Print("Failed to initialize risk controller");
      return(INIT_FAILED);
   }
   
   g_initialized = true;
   g_lastBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   
   Print("EA_VolumeDeltaBreakout_Advanced initialized successfully");
   g_notifier.SendNotification("EA started on " + _Symbol);
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- cleanup
   ArrayFree(g_volumeDelta);
   ArrayFree(g_priceHigh);
   ArrayFree(g_priceLow);
   ArrayFree(g_priceClose);
   ArrayFree(g_volume);
   
   //--- send final notification
   string message = StringFormat("EA stopped. Reason: %d, Total trades: %d, Win rate: %.1f%%",
                                 reason,
                                 g_metrics.totalTrades,
                                 g_metrics.totalTrades > 0 ? (g_metrics.winningTrades * 100.0 / g_metrics.totalTrades) : 0);
   
   g_notifier.SendNotification(message);
   Print(message);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!g_initialized)
      return;
   
   //--- check for new bar
   datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   bool isNewBar = (currentBarTime != g_lastBarTime);
   
   if(isNewBar)
   {
      g_lastBarTime = currentBarTime;
      
      //--- update volume delta analysis
      UpdateVolumeDelta();
      
      //--- detect breakout signals
      DetectBreakout();
      
      //--- check for trading signals
      CheckTradingSignals();
   }
   
   //--- manage open positions
   ManagePositions();
   
   //--- update metrics
   UpdateMetrics();
}

//+------------------------------------------------------------------+
//| Update volume delta calculation                                  |
//+------------------------------------------------------------------+
void UpdateVolumeDelta()
{
   //--- get current bar data
   double high = iHigh(_Symbol, PERIOD_CURRENT, 1);
   double low = iLow(_Symbol, PERIOD_CURRENT, 1);
   double close = iClose(_Symbol, PERIOD_CURRENT, 1);
   double open = iOpen(_Symbol, PERIOD_CURRENT, 1);
   long volume = iVolume(_Symbol, PERIOD_CURRENT, 1);
   
   //--- estimate buy/sell volume based on price action
   double range = high - low;
   if(range > 0)
   {
      double buyPressure = (close - low) / range;
      double sellPressure = (high - close) / range;
      
      g_volAnalysis.buyVolume = volume * buyPressure;
      g_volAnalysis.sellVolume = volume * sellPressure;
      g_volAnalysis.volumeDelta = g_volAnalysis.buyVolume - g_volAnalysis.sellVolume;
      
      if(g_volAnalysis.sellVolume > 0)
         g_volAnalysis.volumeRatio = g_volAnalysis.buyVolume / g_volAnalysis.sellVolume;
      else
         g_volAnalysis.volumeRatio = 0;
   }
   
   //--- shift array and add new delta
   for(int i = InpVolumePeriod - 1; i > 0; i--)
   {
      g_volumeDelta[i] = g_volumeDelta[i-1];
      g_volume[i] = g_volume[i-1];
   }
   g_volumeDelta[0] = g_volAnalysis.volumeDelta;
   g_volume[0] = volume;
   
   //--- calculate average volume
   double sumVolume = 0;
   for(int i = 0; i < InpVolumePeriod; i++)
      sumVolume += (double)g_volume[i];
   
   // Protect against division by zero
   if(InpVolumePeriod > 0)
      g_volAnalysis.avgVolume = sumVolume / InpVolumePeriod;
   else
      g_volAnalysis.avgVolume = 0;
   
   //--- calculate volume standard deviation
   double sumSquares = 0;
   for(int i = 0; i < InpVolumePeriod; i++)
   {
      double diff = (double)g_volume[i] - g_volAnalysis.avgVolume;
      sumSquares += diff * diff;
   }
   
   // Protect against division by zero
   if(InpVolumePeriod > 0)
      g_volAnalysis.volumeStdDev = MathSqrt(sumSquares / InpVolumePeriod);
   else
      g_volAnalysis.volumeStdDev = 0;
   
   //--- detect volume divergence
   DetectVolumeDivergence();
}

//+------------------------------------------------------------------+
//| Detect volume divergence                                         |
//+------------------------------------------------------------------+
void DetectVolumeDivergence()
{
   if(g_barCount < InpVolumePeriod)
   {
      g_barCount++;
      return;
   }
   
   //--- ensure we have enough data
   if(InpVolumePeriod <= 0 || ArraySize(g_volumeDelta) < InpVolumePeriod)
   {
      g_volAnalysis.bullishDivergence = false;
      g_volAnalysis.bearishDivergence = false;
      return;
   }
   
   //--- simple divergence detection
   double priceTrend = iClose(_Symbol, PERIOD_CURRENT, 1) - iClose(_Symbol, PERIOD_CURRENT, InpVolumePeriod);
   double volumeTrend = g_volumeDelta[0] - g_volumeDelta[InpVolumePeriod-1];
   
   //--- bullish divergence: price falling but volume delta increasing
   g_volAnalysis.bullishDivergence = (priceTrend < 0 && volumeTrend > 0);
   
   //--- bearish divergence: price rising but volume delta decreasing
   g_volAnalysis.bearishDivergence = (priceTrend > 0 && volumeTrend < 0);
}

//+------------------------------------------------------------------+
//| Detect breakout signals                                          |
//+------------------------------------------------------------------+
void DetectBreakout()
{
   //--- reset breakout signal
   g_breakout.isValid = false;
   
   //--- get recent price data
   for(int i = 0; i < InpBreakoutBars; i++)
   {
      g_priceHigh[i] = iHigh(_Symbol, PERIOD_CURRENT, i + 1);
      g_priceLow[i] = iLow(_Symbol, PERIOD_CURRENT, i + 1);
      g_priceClose[i] = iClose(_Symbol, PERIOD_CURRENT, i + 1);
   }
   
   //--- find highest high and lowest low
   double highestHigh = g_priceHigh[ArrayMaximum(g_priceHigh)];
   double lowestLow = g_priceLow[ArrayMinimum(g_priceLow)];
   
   //--- current price
   double currentPrice = iClose(_Symbol, PERIOD_CURRENT, 0);
   double previousClose = iClose(_Symbol, PERIOD_CURRENT, 1);
   
   //--- check for bullish breakout
   if(previousClose > highestHigh && 
      g_volAnalysis.volumeDelta > InpDeltaThreshold * g_volAnalysis.avgVolume)
   {
      g_breakout.isValid = true;
      g_breakout.direction = SIGNAL_BUY;
      g_breakout.entryPrice = currentPrice;
      g_breakout.stopLoss = currentPrice - InpStopLoss * _Point;
      g_breakout.takeProfit = currentPrice + InpTakeProfit * _Point;
      g_breakout.volume = (double)g_volume[0];
      g_breakout.signalTime = TimeCurrent();
      
      // Protect against division by zero
      if(g_volAnalysis.avgVolume > 0)
         g_breakout.strength = (int)((g_volAnalysis.volumeDelta / g_volAnalysis.avgVolume) * 100);
      else
         g_breakout.strength = 0;
   }
   //--- check for bearish breakout
   else if(previousClose < lowestLow && 
           g_volAnalysis.volumeDelta < -InpDeltaThreshold * g_volAnalysis.avgVolume)
   {
      g_breakout.isValid = true;
      g_breakout.direction = SIGNAL_SELL;
      g_breakout.entryPrice = currentPrice;
      g_breakout.stopLoss = currentPrice + InpStopLoss * _Point;
      g_breakout.takeProfit = currentPrice - InpTakeProfit * _Point;
      g_breakout.volume = (double)g_volume[0];
      g_breakout.signalTime = TimeCurrent();
      
      // Protect against division by zero
      if(g_volAnalysis.avgVolume > 0)
         g_breakout.strength = (int)((-g_volAnalysis.volumeDelta / g_volAnalysis.avgVolume) * 100);
      else
         g_breakout.strength = 0;
   }
}

//+------------------------------------------------------------------+
//| Check for trading signals and execute trades                     |
//+------------------------------------------------------------------+
void CheckTradingSignals()
{
   //--- don't trade if already in position
   if(g_state.inPosition)
      return;
   
   //--- check if we have a valid breakout
   if(!g_breakout.isValid)
      return;
   
   //--- calculate position size using risk controller
   double lotSize = InpLotSize;
   if(InpEnableAdaptiveRisk)
   {
      double riskAmount = AccountInfoDouble(ACCOUNT_BALANCE) * InpMaxRiskPercent / 100.0;
      double stopLossPoints = MathAbs(g_breakout.entryPrice - g_breakout.stopLoss) / _Point;
      lotSize = g_riskCtrl.CalculateLotSize(riskAmount, stopLossPoints);
   }
   
   //--- normalize lot size
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   lotSize = MathMax(minLot, MathMin(maxLot, MathFloor(lotSize / lotStep) * lotStep));
   
   //--- ensure lot size is not zero
   if(lotSize < minLot)
      lotSize = minLot;
   
   //--- execute trade based on signal direction
   int ticket = -1;
   
   if(g_breakout.direction == SIGNAL_BUY)
   {
      ticket = g_executor.ExecuteBuy(lotSize, g_breakout.stopLoss, g_breakout.takeProfit);
      
      if(ticket > 0)
      {
         g_state.inPosition = true;
         g_state.positionTicket = ticket;
         g_state.lastSignal = SIGNAL_BUY;
         g_state.lastTradeTime = TimeCurrent();
         
         string msg = StringFormat("BUY order opened: Ticket=%d, Lots=%.2f, Entry=%.5f, SL=%.5f, TP=%.5f, Strength=%d%%",
                                   ticket, lotSize, g_breakout.entryPrice, g_breakout.stopLoss, 
                                   g_breakout.takeProfit, g_breakout.strength);
         Print(msg);
         g_notifier.SendNotification(msg);
      }
   }
   else if(g_breakout.direction == SIGNAL_SELL)
   {
      ticket = g_executor.ExecuteSell(lotSize, g_breakout.stopLoss, g_breakout.takeProfit);
      
      if(ticket > 0)
      {
         g_state.inPosition = true;
         g_state.positionTicket = ticket;
         g_state.lastSignal = SIGNAL_SELL;
         g_state.lastTradeTime = TimeCurrent();
         
         string msg = StringFormat("SELL order opened: Ticket=%d, Lots=%.2f, Entry=%.5f, SL=%.5f, TP=%.5f, Strength=%d%%",
                                   ticket, lotSize, g_breakout.entryPrice, g_breakout.stopLoss, 
                                   g_breakout.takeProfit, g_breakout.strength);
         Print(msg);
         g_notifier.SendNotification(msg);
      }
   }
}

//+------------------------------------------------------------------+
//| Manage open positions                                            |
//+------------------------------------------------------------------+
void ManagePositions()
{
   if(!g_state.inPosition)
      return;
   
   //--- check if position is still open
   if(!PositionSelectByTicket(g_state.positionTicket))
   {
      //--- position was closed
      OnPositionClosed();
      g_state.inPosition = false;
      g_state.positionTicket = 0;
   }
}

//+------------------------------------------------------------------+
//| Handle position closed event                                     |
//+------------------------------------------------------------------+
void OnPositionClosed()
{
   //--- get closed position info
   double profit = 0;
   
   if(HistorySelectByPosition(g_state.positionTicket))
   {
      int deals = HistoryDealsTotal();
      if(deals >= 2)  // entry and exit deals
      {
         ulong exitDealTicket = HistoryDealGetTicket(deals - 1);
         if(exitDealTicket > 0)
            profit = HistoryDealGetDouble(exitDealTicket, DEAL_PROFIT);
      }
   }
   
   //--- update metrics
   g_metrics.totalTrades++;
   
   if(profit > 0)
   {
      g_metrics.winningTrades++;
      g_metrics.totalProfit += profit;
      g_state.consecutiveWins++;
      g_state.consecutiveLosses = 0;
      
      if(profit > g_metrics.largestWin)
         g_metrics.largestWin = profit;
   }
   else
   {
      g_metrics.losingTrades++;
      g_metrics.totalLoss += MathAbs(profit);
      g_state.consecutiveLosses++;
      g_state.consecutiveWins = 0;
      
      if(MathAbs(profit) > g_metrics.largestLoss)
         g_metrics.largestLoss = MathAbs(profit);
   }
   
   //--- notify about closed position
   string msg = StringFormat("Position closed: Ticket=%d, Profit=%.2f, Total trades=%d, Win rate=%.1f%%",
                             g_state.positionTicket,
                             profit,
                             g_metrics.totalTrades,
                             g_metrics.totalTrades > 0 ? (g_metrics.winningTrades * 100.0 / g_metrics.totalTrades) : 0);
   Print(msg);
   g_notifier.SendNotification(msg);
}

//+------------------------------------------------------------------+
//| Update performance metrics                                       |
//+------------------------------------------------------------------+
void UpdateMetrics()
{
   //--- update current equity
   g_state.currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   
   //--- calculate current drawdown
   if(g_state.currentEquity < g_state.startingEquity)
   {
      g_metrics.currentDrawdown = g_state.startingEquity - g_state.currentEquity;
      
      if(g_metrics.currentDrawdown > g_metrics.maxDrawdown)
         g_metrics.maxDrawdown = g_metrics.currentDrawdown;
   }
   else
   {
      g_metrics.currentDrawdown = 0;
      g_state.startingEquity = g_state.currentEquity;  // reset high water mark
   }
}
//+------------------------------------------------------------------+

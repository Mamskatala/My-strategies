//+------------------------------------------------------------------+
//|                                    TSM_OpeningRangeBreakout.mq5 |
//|                        TSM Opening Range Breakout - P.J. Kaufman |
//|                                     Production-Grade Multi-Symbol |
//+------------------------------------------------------------------+
#property copyright "TSM Opening Range Breakout - P.J. Kaufman"
#property link      ""
#property version   "2.00"
#property strict

//--- Include necessary files
#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                  |
//+------------------------------------------------------------------+

// Opening Range Parameters
input group "=== Opening Range Settings ==="
input int      InpORPeriodMinutes = 60;           // Opening Range Period (minutes)
input int      InpORStartHour = 9;                // Opening Range Start Hour
input int      InpORStartMinute = 0;              // Opening Range Start Minute

// Signal Engine Parameters
input group "=== Signal Engine ==="
input double   InpMinBreakoutPoints = 10;         // Minimum Breakout Distance (points)
input bool     InpUseFalseBreakoutFilter = true;  // Use False Breakout Filter
input double   InpRangeCompressionFilter = 0.5;   // Min Range/ATR Ratio (0=off)

// Regime Engine Parameters
input group "=== Regime Engine ==="
input int      InpATRPeriod = 14;                 // ATR Period
input int      InpATRAvgPeriod = 20;              // ATR Average Period
input double   InpMinVolatilityRatio = 0.3;       // Min ATR/ATR_Avg Ratio
input double   InpMaxVolatilityRatio = 2.5;       // Max ATR/ATR_Avg Ratio
input bool     InpUseHTFFilter = true;            // Use Higher Timeframe Filter
input ENUM_TIMEFRAMES InpHTF = PERIOD_H1;         // Higher Timeframe
input int      InpHTFMAPeriod = 50;               // HTF MA Period

// Risk Engine Parameters
input group "=== Risk Engine ==="
input double   InpRiskPercent = 1.0;              // Risk per Trade (%)
input double   InpMaxRiskPercent = 2.0;           // Maximum Risk per Trade (%)
input double   InpStopLossPoints = 0;             // Stop Loss Points (0=OR range)
input double   InpTakeProfitRatio = 2.0;          // Take Profit / Stop Loss Ratio
input int      InpMaxConsecutiveLosses = 3;       // Max Consecutive Losses
input double   InpDailyLossPercent = 3.0;         // Daily Loss Limit (%)
input double   InpWeeklyLossPercent = 5.0;        // Weekly Loss Limit (%)
input double   InpDrawdownReducePercent = 10.0;   // Drawdown to Reduce Risk (%)
input double   InpRiskReductionFactor = 0.5;      // Risk Reduction Factor

// Execution Engine Parameters
input group "=== Execution Engine ==="
input double   InpMaxSpreadPoints = 20;           // Maximum Spread (points)
input int      InpMagicNumber = 123456;           // Magic Number
input string   InpTradeComment = "ORB_EA";        // Trade Comment

// General Settings
input group "=== General Settings ==="
input bool     InpEnableLogging = true;           // Enable Detailed Logging

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                  |
//+------------------------------------------------------------------+

// Trade object
CTrade trade;

// Opening Range Variables
datetime g_orStartTime = 0;
datetime g_orEndTime = 0;
double g_orHigh = 0;
double g_orLow = 0;
bool g_orDefined = false;
bool g_breakoutProcessed = false;

// Regime Engine Variables
double g_currentATR = 0;
double g_avgATR = 0;
double g_volatilityRatio = 0;
int g_atrHandle = INVALID_HANDLE;
int g_htfMAHandle = INVALID_HANDLE;

// Risk Engine Variables
double g_currentRiskPercent = 0;
int g_consecutiveLosses = 0;
double g_dailyPnL = 0;
double g_weeklyPnL = 0;
datetime g_lastDayReset = 0;
datetime g_lastWeekReset = 0;
double g_startDayBalance = 0;
double g_startWeekBalance = 0;
bool g_tradingPaused = false;

// Position tracking
ulong g_currentTicket = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
   // Set trade parameters
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(10);
   trade.SetTypeFilling(ORDER_FILLING_FOK);
   
   // Initialize ATR indicator
   g_atrHandle = iATR(_Symbol, PERIOD_CURRENT, InpATRPeriod);
   if(g_atrHandle == INVALID_HANDLE)
   {
      Print("Failed to create ATR indicator");
      return INIT_FAILED;
   }
   
   // Initialize HTF MA indicator if needed
   if(InpUseHTFFilter)
   {
      g_htfMAHandle = iMA(_Symbol, InpHTF, InpHTFMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
      if(g_htfMAHandle == INVALID_HANDLE)
      {
         Print("Failed to create HTF MA indicator");
         return INIT_FAILED;
      }
   }
   
   // Initialize risk variables
   g_currentRiskPercent = InpRiskPercent;
   g_lastDayReset = TimeCurrent();
   g_lastWeekReset = TimeCurrent();
   g_startDayBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   g_startWeekBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   
   Print("TSM Opening Range Breakout EA initialized successfully");
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Release indicators
   if(g_atrHandle != INVALID_HANDLE)
      IndicatorRelease(g_atrHandle);
   if(g_htfMAHandle != INVALID_HANDLE)
      IndicatorRelease(g_htfMAHandle);
   
   Print("TSM Opening Range Breakout EA deinitialized");
}

//+------------------------------------------------------------------+
//| Expert tick function                                               |
//+------------------------------------------------------------------+
void OnTick()
{
   // Update risk engine daily/weekly resets
   RiskEngine_UpdatePeriodStats();
   
   // Check if trading is paused
   if(g_tradingPaused)
   {
      if(InpEnableLogging)
         Print("Trading paused due to risk limits");
      return;
   }
   
   // Update regime engine
   if(!RegimeEngine_Update())
   {
      if(InpEnableLogging)
         Print("Regime conditions not favorable");
      return;
   }
   
   // Update opening range
   SignalEngine_UpdateOR();
   
   // Check for signals if OR is defined and not yet processed
   if(g_orDefined && !g_breakoutProcessed)
   {
      int signal = SignalEngine_CheckBreakout();
      
      if(signal != 0)
      {
         // Check execution conditions
         if(ExecutionEngine_CheckConditions())
         {
            // Calculate position size
            double lots = RiskEngine_CalculateLots(signal);
            
            if(lots > 0)
            {
               // Execute trade
               ExecutionEngine_OpenPosition(signal, lots);
               g_breakoutProcessed = true;
            }
         }
      }
   }
   
   // Manage existing position
   if(g_currentTicket > 0)
   {
      ExecutionEngine_ManagePosition();
   }
}

//+------------------------------------------------------------------+
//| SIGNAL ENGINE - Opening Range Breakout Logic                      |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Update Opening Range                                               |
//+------------------------------------------------------------------+
void SignalEngine_UpdateOR()
{
   datetime currentTime = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(currentTime, dt);
   
   // Calculate OR period times for today
   datetime todayORStart = StringToTime(StringFormat("%04d.%02d.%02d %02d:%02d",
                                        dt.year, dt.mon, dt.day,
                                        InpORStartHour, InpORStartMinute));
   
   datetime todayOREnd = todayORStart + InpORPeriodMinutes * 60;
   
   // Reset if new day
   if(currentTime >= todayOREnd && (g_orEndTime != todayOREnd || g_orStartTime != todayORStart))
   {
      g_orStartTime = todayORStart;
      g_orEndTime = todayOREnd;
      g_orHigh = 0;
      g_orLow = 0;
      g_orDefined = false;
      g_breakoutProcessed = false;
      
      if(InpEnableLogging)
         Print("New OR period: ", TimeToString(g_orStartTime), " to ", TimeToString(g_orEndTime));
   }
   
   // Build OR during the period
   if(currentTime >= g_orStartTime && currentTime < g_orEndTime)
   {
      double high = iHigh(_Symbol, PERIOD_CURRENT, 0);
      double low = iLow(_Symbol, PERIOD_CURRENT, 0);
      
      if(g_orHigh == 0 || high > g_orHigh)
         g_orHigh = high;
      
      if(g_orLow == 0 || low < g_orLow)
         g_orLow = low;
   }
   
   // Define OR after period ends
   if(currentTime >= g_orEndTime && !g_orDefined && g_orHigh > 0 && g_orLow > 0)
   {
      g_orDefined = true;
      double orRange = g_orHigh - g_orLow;
      
      if(InpEnableLogging)
         Print("OR Defined - High: ", g_orHigh, " Low: ", g_orLow, " Range: ", orRange / _Point, " points");
      
      // Check range compression filter
      if(InpRangeCompressionFilter > 0 && g_currentATR > 0)
      {
         double rangeATRRatio = orRange / g_currentATR;
         if(rangeATRRatio < InpRangeCompressionFilter)
         {
            if(InpEnableLogging)
               Print("OR range too compressed. Range/ATR: ", rangeATRRatio);
            g_orDefined = false;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check for breakout signal                                          |
//+------------------------------------------------------------------+
int SignalEngine_CheckBreakout()
{
   if(!g_orDefined)
      return 0;
   
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   // Check for bullish breakout
   if(currentPrice > g_orHigh + InpMinBreakoutPoints * point)
   {
      if(InpEnableLogging)
         Print("Bullish breakout detected at ", currentPrice);
      return 1; // Buy signal
   }
   
   // Check for bearish breakout
   if(currentPrice < g_orLow - InpMinBreakoutPoints * point)
   {
      if(InpEnableLogging)
         Print("Bearish breakout detected at ", currentPrice);
      return -1; // Sell signal
   }
   
   return 0; // No signal
}

//+------------------------------------------------------------------+
//| REGIME ENGINE - Market Conditions Detection                       |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Update regime conditions                                           |
//+------------------------------------------------------------------+
bool RegimeEngine_Update()
{
   // Update ATR
   double atrBuffer[];
   ArraySetAsSeries(atrBuffer, true);
   
   if(CopyBuffer(g_atrHandle, 0, 0, InpATRAvgPeriod + 1, atrBuffer) <= 0)
   {
      Print("Failed to copy ATR buffer");
      return false;
   }
   
   g_currentATR = atrBuffer[0];
   
   // Calculate average ATR
   g_avgATR = 0;
   for(int i = 0; i < InpATRAvgPeriod; i++)
   {
      g_avgATR += atrBuffer[i];
   }
   g_avgATR /= InpATRAvgPeriod;
   
   // Calculate volatility ratio
   if(g_avgATR > 0)
      g_volatilityRatio = g_currentATR / g_avgATR;
   else
      g_volatilityRatio = 1.0;
   
   // Check volatility limits
   if(g_volatilityRatio < InpMinVolatilityRatio)
   {
      if(InpEnableLogging)
         Print("Volatility too low. Ratio: ", g_volatilityRatio);
      return false;
   }
   
   if(g_volatilityRatio > InpMaxVolatilityRatio)
   {
      if(InpEnableLogging)
         Print("Volatility too high. Ratio: ", g_volatilityRatio);
      
      // Reduce risk instead of blocking
      double reductionFactor = InpMaxVolatilityRatio / g_volatilityRatio;
      g_currentRiskPercent = MathMin(InpRiskPercent * reductionFactor, InpMaxRiskPercent);
   }
   else
   {
      g_currentRiskPercent = InpRiskPercent;
   }
   
   // Check higher timeframe filter
   if(InpUseHTFFilter)
   {
      double maBuffer[];
      ArraySetAsSeries(maBuffer, true);
      
      if(CopyBuffer(g_htfMAHandle, 0, 0, 2, maBuffer) <= 0)
      {
         Print("Failed to copy HTF MA buffer");
         return false;
      }
      
      double htfPrice = iClose(_Symbol, InpHTF, 0);
      double htfMA = maBuffer[0];
      
      // Store HTF trend direction (1 = bullish, -1 = bearish)
      // This will be used in signal filtering
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Get HTF trend direction                                            |
//+------------------------------------------------------------------+
int RegimeEngine_GetHTFTrend()
{
   if(!InpUseHTFFilter)
      return 0; // No filter
   
   double maBuffer[];
   ArraySetAsSeries(maBuffer, true);
   
   if(CopyBuffer(g_htfMAHandle, 0, 0, 1, maBuffer) <= 0)
      return 0;
   
   double htfPrice = iClose(_Symbol, InpHTF, 0);
   double htfMA = maBuffer[0];
   
   if(htfPrice > htfMA)
      return 1; // Bullish
   else if(htfPrice < htfMA)
      return -1; // Bearish
   
   return 0;
}

//+------------------------------------------------------------------+
//| RISK ENGINE - Adaptive Risk Management                            |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Update daily and weekly statistics                                 |
//+------------------------------------------------------------------+
void RiskEngine_UpdatePeriodStats()
{
   datetime currentTime = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(currentTime, dt);
   
   // Reset daily stats
   MqlDateTime lastDayDt;
   TimeToStruct(g_lastDayReset, lastDayDt);
   
   if(dt.day != lastDayDt.day || dt.mon != lastDayDt.mon || dt.year != lastDayDt.year)
   {
      g_lastDayReset = currentTime;
      g_startDayBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      g_dailyPnL = 0;
      
      if(InpEnableLogging)
         Print("Daily stats reset. Start balance: ", g_startDayBalance);
   }
   
   // Reset weekly stats
   if(dt.day_of_week == 1 && dt.day_of_week != lastDayDt.day_of_week) // Monday
   {
      g_lastWeekReset = currentTime;
      g_startWeekBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      g_weeklyPnL = 0;
      g_tradingPaused = false; // Reset pause
      
      if(InpEnableLogging)
         Print("Weekly stats reset. Start balance: ", g_startWeekBalance);
   }
   
   // Update PnL
   double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   g_dailyPnL = currentBalance - g_startDayBalance;
   g_weeklyPnL = currentBalance - g_startWeekBalance;
   
   // Check daily loss limit
   if(InpDailyLossPercent > 0)
   {
      double dailyLossLimit = -g_startDayBalance * InpDailyLossPercent / 100.0;
      if(g_dailyPnL < dailyLossLimit)
      {
         g_tradingPaused = true;
         if(InpEnableLogging)
            Print("Daily loss limit reached. PnL: ", g_dailyPnL);
      }
   }
   
   // Check weekly loss limit
   if(InpWeeklyLossPercent > 0)
   {
      double weeklyLossLimit = -g_startWeekBalance * InpWeeklyLossPercent / 100.0;
      if(g_weeklyPnL < weeklyLossLimit)
      {
         g_tradingPaused = true;
         if(InpEnableLogging)
            Print("Weekly loss limit reached. PnL: ", g_weeklyPnL);
      }
   }
}

//+------------------------------------------------------------------+
//| Calculate lot size based on risk                                   |
//+------------------------------------------------------------------+
double RiskEngine_CalculateLots(int signal)
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   
   // Determine stop loss distance
   double slDistance = 0;
   
   if(InpStopLossPoints > 0)
   {
      slDistance = InpStopLossPoints * point;
   }
   else
   {
      // Use OR range as stop loss
      slDistance = g_orHigh - g_orLow;
   }
   
   if(slDistance <= 0)
   {
      Print("Invalid stop loss distance");
      return 0;
   }
   
   // Check drawdown and adjust risk
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double drawdownPercent = (balance - equity) / balance * 100.0;
   
   double adjustedRisk = g_currentRiskPercent;
   
   if(drawdownPercent > InpDrawdownReducePercent)
   {
      adjustedRisk = g_currentRiskPercent * InpRiskReductionFactor;
      if(InpEnableLogging)
         Print("Risk reduced due to drawdown. DD: ", drawdownPercent, "% New Risk: ", adjustedRisk, "%");
   }
   
   // Check consecutive losses
   if(g_consecutiveLosses >= InpMaxConsecutiveLosses)
   {
      if(InpEnableLogging)
         Print("Maximum consecutive losses reached: ", g_consecutiveLosses);
      return 0;
   }
   
   // Calculate risk amount
   double riskAmount = balance * adjustedRisk / 100.0;
   
   // Calculate lot size
   double slPoints = slDistance / point;
   double lots = riskAmount / (slPoints * tickValue);
   
   // Normalize lot size
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   lots = MathFloor(lots / lotStep) * lotStep;
   lots = MathMax(lots, minLot);
   lots = MathMin(lots, maxLot);
   
   if(InpEnableLogging)
      Print("Calculated lots: ", lots, " Risk: ", adjustedRisk, "% SL Distance: ", slPoints, " points");
   
   return lots;
}

//+------------------------------------------------------------------+
//| Update consecutive losses counter                                  |
//+------------------------------------------------------------------+
void RiskEngine_UpdateConsecutiveLosses(bool isWin)
{
   if(isWin)
      g_consecutiveLosses = 0;
   else
      g_consecutiveLosses++;
   
   if(InpEnableLogging)
      Print("Consecutive losses: ", g_consecutiveLosses);
}

//+------------------------------------------------------------------+
//| EXECUTION ENGINE - Order Management                                |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Check execution conditions                                         |
//+------------------------------------------------------------------+
bool ExecutionEngine_CheckConditions()
{
   // Check if already in position
   if(PositionSelectByTicket(g_currentTicket))
   {
      if(InpEnableLogging)
         Print("Already in position");
      return false;
   }
   
   // Check spread
   double spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double maxSpread = InpMaxSpreadPoints * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   if(spread > maxSpread)
   {
      if(InpEnableLogging)
         Print("Spread too high: ", spread / SymbolInfoDouble(_Symbol, SYMBOL_POINT), " points");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Open position                                                      |
//+------------------------------------------------------------------+
void ExecutionEngine_OpenPosition(int signal, double lots)
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   // Determine entry price
   double entryPrice = 0;
   double sl = 0;
   double tp = 0;
   
   // Calculate SL and TP
   double slDistance = 0;
   
   if(InpStopLossPoints > 0)
   {
      slDistance = InpStopLossPoints * point;
   }
   else
   {
      slDistance = g_orHigh - g_orLow;
   }
   
   double tpDistance = slDistance * InpTakeProfitRatio;
   
   // Check HTF alignment
   int htfTrend = RegimeEngine_GetHTFTrend();
   if(InpUseHTFFilter && htfTrend != 0 && htfTrend != signal)
   {
      if(InpEnableLogging)
         Print("Signal not aligned with HTF trend. Signal: ", signal, " HTF: ", htfTrend);
      return;
   }
   
   bool result = false;
   
   if(signal > 0) // Buy
   {
      entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      sl = entryPrice - slDistance;
      tp = entryPrice + tpDistance;
      
      result = trade.Buy(lots, _Symbol, entryPrice, sl, tp, InpTradeComment);
   }
   else if(signal < 0) // Sell
   {
      entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      sl = entryPrice + slDistance;
      tp = entryPrice - tpDistance;
      
      result = trade.Sell(lots, _Symbol, entryPrice, sl, tp, InpTradeComment);
   }
   
   if(result)
   {
      g_currentTicket = trade.ResultOrder();
      
      if(InpEnableLogging)
         Print("Position opened. Ticket: ", g_currentTicket, " Type: ", (signal > 0 ? "BUY" : "SELL"),
               " Lots: ", lots, " Entry: ", entryPrice, " SL: ", sl, " TP: ", tp);
   }
   else
   {
      Print("Failed to open position. Error: ", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| Manage existing position                                           |
//+------------------------------------------------------------------+
void ExecutionEngine_ManagePosition()
{
   if(!PositionSelectByTicket(g_currentTicket))
   {
      // Position closed
      if(InpEnableLogging)
         Print("Position closed. Ticket: ", g_currentTicket);
      
      // Check if it was a loss or win
      if(HistorySelectByPosition(g_currentTicket))
      {
         ulong dealTicket = 0;
         for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
         {
            dealTicket = HistoryDealGetTicket(i);
            if(HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID) == g_currentTicket)
            {
               double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
               if(profit != 0)
               {
                  RiskEngine_UpdateConsecutiveLosses(profit > 0);
                  break;
               }
            }
         }
      }
      
      g_currentTicket = 0;
      return;
   }
   
   // Additional position management logic can be added here
   // (trailing stops, partial closes, etc.)
}

//+------------------------------------------------------------------+

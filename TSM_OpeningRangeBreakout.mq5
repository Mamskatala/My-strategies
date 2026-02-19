//+------------------------------------------------------------------+
//|                                  TSM_OpeningRangeBreakout.mq5    |
//|               TSM Opening Range Breakout – P.J. Kaufman          |
//|                    Production-Grade Multi-Symbol                  |
//|              Adaptive EA with Regime Monitor & Risk Control      |
//+------------------------------------------------------------------+
#property copyright "Trading Strategy - P.J. Kaufman ORB"
#property link      ""
#property version   "1.00"
#property description "Adaptive Opening Range Breakout with Regime Monitor, Self-Regulation, and Live Protection"

#include "Include/NotificationManager.mqh"
#include "Include/TradeExecution.mqh"
#include "Include/AdaptiveRiskController.mqh"

//--- Trade Direction Filter
enum ENUM_TRADE_DIRECTION
{
   TRADE_BOTH,       // Both Buy and Sell
   TRADE_BUY_ONLY,   // Buy Only
   TRADE_SELL_ONLY    // Sell Only
};

//--- Input parameters
input group "=== Trade Direction ==="
input ENUM_TRADE_DIRECTION TradeDirection = TRADE_BOTH;  // Trade direction filter

input group "=== Opening Range Settings ==="
input int    ORStartHour = 9;              // Opening range start hour
input int    ORStartMinute = 30;           // Opening range start minute
input int    ORDurationMinutes = 30;       // Opening range duration (minutes)
input int    SessionEndHour = 16;          // Session end hour (stop trading)

input group "=== Multi-Symbol Settings ==="
input string TradingSymbols = "NDAQ,NAS100,US100"; // Symbols to trade (comma-separated)
input bool   UseCurrentSymbolOnly = false;          // If true, ignore TradingSymbols

input group "=== Breakout Settings ==="
input double BreakoutBufferATR = 0.10;     // Breakout buffer as ATR fraction
input int    MaxSpreadPoints = 2500;       // Max spread in points
input double MinORRangeATR = 0.3;          // Min opening range as ATR fraction
input double MaxORRangeATR = 3.0;          // Max opening range as ATR fraction

input group "=== Risk Management (Adaptive) ==="
input double NormalRiskPercent = 0.5;      // Risk % in Normal mode
input double CautionRiskPercent = 0.25;    // Risk % in Caution mode
input double RewardRiskRatio = 2.0;        // Reward:Risk ratio
input int    MaxDailyTrades = 2;           // Max trades per day per symbol
input int    MagicNumber = 54321;          // Magic number for orders

input group "=== Adaptive Risk Controller ==="
input int    RollingTradeWindow = 20;      // Rolling performance window (trades)
input int    ATRLookback = 50;             // ATR averaging lookback (bars)
input double ATRSpikeThreshold = 1.5;      // ATR spike threshold (multiplier)
input double ATRCollapseThreshold = 0.5;   // ATR collapse threshold (multiplier)
input double MaxDrawdownPercent = 5.0;     // Max drawdown % before defensive
input int    ConsecLossesPause = 2;        // Consecutive losses for temp pause
input int    ConsecLossesStop = 3;         // Consecutive losses for daily stop
input double MinWinRate = 0.40;            // Min rolling win rate
input double MinProfitFactor = 0.8;        // Min rolling profit factor
input int    MaxFalseBreakouts = 3;        // Max false breakouts before defensive

input group "=== Multi-Timeframe Confirmation ==="
input bool   UseMTFConfirmation = true;    // Enable multi-timeframe confirmation
input ENUM_TIMEFRAMES MTF_Timeframe = PERIOD_H1; // Higher timeframe for trend
input int    MTF_MAPeriod = 50;            // MA period on higher timeframe

input group "=== Indicator Settings ==="
input int    ATRPeriod = 14;               // ATR period

input group "=== Notifications ==="
input bool   EnableAlerts = true;           // Enable popup alerts
input bool   EnablePushNotifications = false; // Enable push to mobile
input bool   EnableEmailNotifications = false; // Enable email alerts

input group "=== Debugging ==="
input bool   EnableLogging = true;          // Enable detailed logging
input bool   EnableVisualMarkers = true;    // Enable chart markers

//--- Opening Range State
enum ENUM_ORB_STATE
{
   ORB_WAITING_SESSION,    // Waiting for session open
   ORB_BUILDING_RANGE,     // Building opening range
   ORB_WAITING_BREAKOUT,   // Waiting for breakout
   ORB_SESSION_DONE        // Session complete
};

//--- Symbol Data Structure
struct SymbolORBData
{
   string symbol;
   ENUM_ORB_STATE state;

   // Opening range
   double orHigh;
   double orLow;
   double orMid;
   datetime orStartTime;
   datetime orEndTime;
   bool orEstablished;

   // Trade tracking
   int dailyTradeCount;
   datetime lastTradeDate;
   bool tradeExecutedOnBreakout;  // Track if breakout already traded

   // ATR
   int atrHandle;
   int mtfMAHandle;
   datetime lastBarTime;
};

//--- Global objects
SymbolORBData g_symbolData[];
CNotificationManager g_notifier;
CTradeExecutor g_executor;
CAdaptiveRiskController g_riskCtrl;
bool g_isBacktest = false;

//+------------------------------------------------------------------+
//| Initialize symbols for multi-symbol support                      |
//+------------------------------------------------------------------+
bool InitializeSymbols()
{
   if(UseCurrentSymbolOnly)
   {
      ArrayResize(g_symbolData, 1);
      InitSymbolData(g_symbolData[0], _Symbol);
      Print("Single-symbol mode: ", _Symbol);
      return (g_symbolData[0].atrHandle != INVALID_HANDLE);
   }

   string symbols[];
   int count = StringSplit(TradingSymbols, ',', symbols);

   if(count <= 0)
   {
      Print("ERROR: No symbols found in TradingSymbols input");
      return false;
   }

   ArrayResize(g_symbolData, count);
   for(int i = 0; i < count; i++)
   {
      StringTrimLeft(symbols[i]);
      StringTrimRight(symbols[i]);
      InitSymbolData(g_symbolData[i], symbols[i]);

      if(g_symbolData[i].atrHandle == INVALID_HANDLE)
      {
         Print("ERROR: Cannot initialize ATR for ", symbols[i]);
         return false;
      }
      Print("Initialized symbol [", i, "]: ", symbols[i]);
   }

   Print("Multi-symbol mode: ", count, " symbols configured");
   return true;
}

//+------------------------------------------------------------------+
//| Initialize single symbol data                                    |
//+------------------------------------------------------------------+
void InitSymbolData(SymbolORBData &data, string symbol)
{
   data.symbol = symbol;
   data.state = ORB_WAITING_SESSION;
   data.orHigh = 0;
   data.orLow = 0;
   data.orMid = 0;
   data.orStartTime = 0;
   data.orEndTime = 0;
   data.orEstablished = false;
   data.dailyTradeCount = 0;
   data.lastTradeDate = 0;
   data.tradeExecutedOnBreakout = false;
   data.lastBarTime = 0;

   data.atrHandle = iATR(symbol, PERIOD_M5, ATRPeriod);
   data.mtfMAHandle = INVALID_HANDLE;
   if(UseMTFConfirmation)
      data.mtfMAHandle = iMA(symbol, MTF_Timeframe, MTF_MAPeriod, 0, MODE_SMA, PRICE_CLOSE);
}

//+------------------------------------------------------------------+
//| Expert initialization                                            |
//+------------------------------------------------------------------+
int OnInit()
{
   g_isBacktest = MQLInfoInteger(MQL_TESTER);

   if(g_isBacktest)
      Print("Running in STRATEGY TESTER mode");
   else
      Print("Running in LIVE/DEMO mode");

   // Initialize shared modules
   g_notifier.Init("TSM_ORB", EnableAlerts, EnablePushNotifications, EnableEmailNotifications);
   g_executor.Init(MagicNumber, 10, EnableLogging);
   g_riskCtrl.Init(NormalRiskPercent, CautionRiskPercent, RollingTradeWindow,
                   ATRLookback, ATRSpikeThreshold, ATRCollapseThreshold,
                   MaxDrawdownPercent, ConsecLossesPause, ConsecLossesStop,
                   MinWinRate, MinProfitFactor, MaxFalseBreakouts, EnableLogging);

   // Initialize symbols
   if(!InitializeSymbols())
   {
      Print("ERROR: Failed to initialize symbols");
      return INIT_FAILED;
   }

   Print("========================================");
   Print("TSM Opening Range Breakout initialized");
   Print("Trade direction: ", EnumToString(TradeDirection));
   Print("OR window: ", ORStartHour, ":", (ORStartMinute < 10 ? "0" : ""), ORStartMinute,
         " + ", ORDurationMinutes, " min");
   Print("Session end: ", SessionEndHour, ":00");
   Print("MTF Confirmation: ", (UseMTFConfirmation ? "ON" : "OFF"));
   Print("Symbols: ", ArraySize(g_symbolData));
   Print("========================================");

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   for(int i = 0; i < ArraySize(g_symbolData); i++)
   {
      if(g_symbolData[i].atrHandle != INVALID_HANDLE)
         IndicatorRelease(g_symbolData[i].atrHandle);
      if(g_symbolData[i].mtfMAHandle != INVALID_HANDLE)
         IndicatorRelease(g_symbolData[i].mtfMAHandle);
   }

   if(EnableVisualMarkers)
      ObjectsDeleteAll(0, "ORB_");

   Print("TSM Opening Range Breakout deinitialized");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   for(int s = 0; s < ArraySize(g_symbolData); s++)
      ProcessSymbol(s);
}

//+------------------------------------------------------------------+
//| OnTradeTransaction - Monitor closed trades for performance       |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
   {
      // Check if this is a closing deal for our EA
      if(trans.deal_type == DEAL_TYPE_BUY || trans.deal_type == DEAL_TYPE_SELL)
      {
         ulong dealTicket = trans.deal;
         if(dealTicket > 0)
         {
            if(HistoryDealSelect(dealTicket))
            {
               long magic = HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
               long entry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);

               if(magic == MagicNumber && entry == DEAL_ENTRY_OUT)
               {
                  double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
                  g_riskCtrl.RecordTrade(profit);

                  if(EnableLogging)
                     Print("[PERF] Trade closed: profit=", DoubleToString(profit, 2),
                           " | ", g_riskCtrl.GetStatsString());

                  // Detect false breakout (quick loss)
                  if(profit < 0)
                  {
                     double volume = HistoryDealGetDouble(dealTicket, DEAL_VOLUME);
                     if(volume > 0)
                        g_riskCtrl.RecordFalseBreakout();
                  }
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Process individual symbol                                        |
//+------------------------------------------------------------------+
void ProcessSymbol(int idx)
{
   // New bar check on M5
   datetime currentBarTime = iTime(g_symbolData[idx].symbol, PERIOD_M5, 0);

   if(currentBarTime == g_symbolData[idx].lastBarTime)
      return;

   g_symbolData[idx].lastBarTime = currentBarTime;

   // Get current time
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);

   // Daily reset
   datetime currentDate = iTime(g_symbolData[idx].symbol, PERIOD_D1, 0);
   if(currentDate != g_symbolData[idx].lastTradeDate && g_symbolData[idx].lastTradeDate != 0)
   {
      g_symbolData[idx].state = ORB_WAITING_SESSION;
      g_symbolData[idx].dailyTradeCount = 0;
      g_symbolData[idx].orEstablished = false;
      g_symbolData[idx].tradeExecutedOnBreakout = false;
      g_riskCtrl.ResetDaily();

      if(EnableLogging)
         Print("=== NEW TRADING DAY: ", g_symbolData[idx].symbol, " | ",
               TimeToString(currentDate, TIME_DATE), " ===");
   }

   // Update regime on every new candle
   g_riskCtrl.UpdateRegime(g_symbolData[idx].symbol, g_symbolData[idx].atrHandle, PERIOD_M5);

   // Log state
   if(EnableLogging && !g_isBacktest)
   {
      Print("=== ", g_symbolData[idx].symbol, " | ", TimeToString(TimeCurrent()),
            " | State: ", EnumToString(g_symbolData[idx].state),
            " | ", g_riskCtrl.GetStatsString(), " ===");
   }

   // State machine
   switch(g_symbolData[idx].state)
   {
      case ORB_WAITING_SESSION:
         CheckSessionStart(idx, dt);
         break;

      case ORB_BUILDING_RANGE:
         BuildOpeningRange(idx, dt);
         break;

      case ORB_WAITING_BREAKOUT:
         CheckBreakout(idx, dt);
         break;

      case ORB_SESSION_DONE:
         // Nothing to do - wait for next day
         break;
   }
}

//+------------------------------------------------------------------+
//| Check if session start time reached                              |
//+------------------------------------------------------------------+
void CheckSessionStart(int idx, MqlDateTime &dt)
{
   int currentMinutes = dt.hour * 60 + dt.min;
   int orStartMinutes = ORStartHour * 60 + ORStartMinute;

   if(currentMinutes >= orStartMinutes && currentMinutes < orStartMinutes + ORDurationMinutes)
   {
      g_symbolData[idx].state = ORB_BUILDING_RANGE;
      g_symbolData[idx].orHigh = -DBL_MAX;
      g_symbolData[idx].orLow = DBL_MAX;
      g_symbolData[idx].orStartTime = TimeCurrent();
      g_symbolData[idx].orEndTime = g_symbolData[idx].orStartTime + ORDurationMinutes * 60;
      g_symbolData[idx].orEstablished = false;

      if(EnableLogging)
         Print(">>> [", g_symbolData[idx].symbol, "] SESSION STARTED - Building opening range");
   }
}

//+------------------------------------------------------------------+
//| Build opening range from price action                            |
//+------------------------------------------------------------------+
void BuildOpeningRange(int idx, MqlDateTime &dt)
{
   int currentMinutes = dt.hour * 60 + dt.min;
   int orEndMinutes = ORStartHour * 60 + ORStartMinute + ORDurationMinutes;

   // Track high and low during OR period
   double high = iHigh(g_symbolData[idx].symbol, PERIOD_M5, 0);
   double low = iLow(g_symbolData[idx].symbol, PERIOD_M5, 0);

   if(high > g_symbolData[idx].orHigh)
      g_symbolData[idx].orHigh = high;
   if(low < g_symbolData[idx].orLow)
      g_symbolData[idx].orLow = low;

   // Check if OR period is complete
   if(currentMinutes >= orEndMinutes)
   {
      g_symbolData[idx].orMid = (g_symbolData[idx].orHigh + g_symbolData[idx].orLow) / 2.0;
      double orRange = g_symbolData[idx].orHigh - g_symbolData[idx].orLow;

      // Validate OR range against ATR
      double atr[];
      ArraySetAsSeries(atr, true);
      if(CopyBuffer(g_symbolData[idx].atrHandle, 0, 0, 1, atr) <= 0)
      {
         if(EnableLogging)
            Print("ERROR [", g_symbolData[idx].symbol, "]: Failed to copy ATR buffer");
         g_symbolData[idx].state = ORB_SESSION_DONE;
         return;
      }

      double atrValue = atr[0];

      if(orRange < MinORRangeATR * atrValue)
      {
         if(EnableLogging)
            Print(">>> [", g_symbolData[idx].symbol, "] OR range too tight (",
                  DoubleToString(orRange, _Digits), " < ",
                  DoubleToString(MinORRangeATR * atrValue, _Digits), ") → SKIP");
         g_riskCtrl.RecordFalseBreakout();  // Tight range = unfavorable
         g_symbolData[idx].state = ORB_SESSION_DONE;
         return;
      }

      if(orRange > MaxORRangeATR * atrValue)
      {
         if(EnableLogging)
            Print(">>> [", g_symbolData[idx].symbol, "] OR range too wide (",
                  DoubleToString(orRange, _Digits), " > ",
                  DoubleToString(MaxORRangeATR * atrValue, _Digits), ") → SKIP");
         g_symbolData[idx].state = ORB_SESSION_DONE;
         return;
      }

      g_symbolData[idx].orEstablished = true;
      g_symbolData[idx].state = ORB_WAITING_BREAKOUT;

      if(EnableLogging)
      {
         Print(">>> [", g_symbolData[idx].symbol, "] OPENING RANGE ESTABLISHED");
         Print("  High: ", DoubleToString(g_symbolData[idx].orHigh, _Digits));
         Print("  Low:  ", DoubleToString(g_symbolData[idx].orLow, _Digits));
         Print("  Range: ", DoubleToString(orRange, _Digits));
         Print("  Mid:  ", DoubleToString(g_symbolData[idx].orMid, _Digits));
      }

      g_notifier.Send(g_symbolData[idx].symbol,
         "📊 Opening Range: H=" + DoubleToString(g_symbolData[idx].orHigh, _Digits) +
         " L=" + DoubleToString(g_symbolData[idx].orLow, _Digits));

      if(EnableVisualMarkers)
         DrawOpeningRange(idx);
   }
}

//+------------------------------------------------------------------+
//| Check for breakout of opening range                              |
//+------------------------------------------------------------------+
void CheckBreakout(int idx, MqlDateTime &dt)
{
   // Check session end
   if(dt.hour >= SessionEndHour)
   {
      g_symbolData[idx].state = ORB_SESSION_DONE;
      if(EnableLogging)
         Print(">>> [", g_symbolData[idx].symbol, "] Session ended");
      return;
   }

   // Check max daily trades
   if(g_symbolData[idx].dailyTradeCount >= MaxDailyTrades)
   {
      g_symbolData[idx].state = ORB_SESSION_DONE;
      return;
   }

   // Skip if already have open position
   if(g_executor.CountOpenPositions(g_symbolData[idx].symbol) > 0)
      return;

   // ADAPTIVE CHECK: Is trading allowed?
   if(!g_riskCtrl.IsTradingAllowed())
   {
      if(EnableLogging && !g_isBacktest)
         Print("[ADAPTIVE] Trading blocked: ", g_riskCtrl.GetStatsString());
      return;
   }

   // Get ATR for buffer calculation
   double atr[];
   ArraySetAsSeries(atr, true);
   if(CopyBuffer(g_symbolData[idx].atrHandle, 0, 0, 1, atr) <= 0)
      return;

   double atrValue = atr[0];
   double buffer = BreakoutBufferATR * atrValue;

   // Get current prices
   double ask = SymbolInfoDouble(g_symbolData[idx].symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(g_symbolData[idx].symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(g_symbolData[idx].symbol, SYMBOL_POINT);
   int spread = (int)((ask - bid) / point);

   // Spread check
   if(spread > MaxSpreadPoints)
      return;

   // Multi-timeframe confirmation
   int mtfTrend = 0;  // 0=neutral, 1=bullish, -1=bearish
   if(UseMTFConfirmation && g_symbolData[idx].mtfMAHandle != INVALID_HANDLE)
   {
      double ma[];
      ArraySetAsSeries(ma, true);
      if(CopyBuffer(g_symbolData[idx].mtfMAHandle, 0, 0, 1, ma) > 0)
      {
         double currentPrice = (ask + bid) / 2.0;
         if(currentPrice > ma[0])
            mtfTrend = 1;   // Bullish
         else
            mtfTrend = -1;  // Bearish
      }
   }

   // Check BULLISH breakout
   if(TradeDirection != TRADE_SELL_ONLY && ask > g_symbolData[idx].orHigh + buffer)
   {
      // MTF check: don't buy if higher timeframe is bearish
      if(UseMTFConfirmation && mtfTrend == -1)
      {
         if(EnableLogging)
            Print("[MTF] Bullish breakout blocked: HTF trend is bearish");
         return;
      }

      ExecuteBreakoutTrade(idx, ORDER_TYPE_BUY, ask, atrValue);
   }
   // Check BEARISH breakout
   else if(TradeDirection != TRADE_BUY_ONLY && bid < g_symbolData[idx].orLow - buffer)
   {
      // MTF check: don't sell if higher timeframe is bullish
      if(UseMTFConfirmation && mtfTrend == 1)
      {
         if(EnableLogging)
            Print("[MTF] Bearish breakout blocked: HTF trend is bullish");
         return;
      }

      ExecuteBreakoutTrade(idx, ORDER_TYPE_SELL, bid, atrValue);
   }
}

//+------------------------------------------------------------------+
//| Execute breakout trade with adaptive risk                        |
//+------------------------------------------------------------------+
void ExecuteBreakoutTrade(int idx, ENUM_ORDER_TYPE orderType, double price, double atrValue)
{
   // Get adaptive risk
   double riskPct = g_riskCtrl.GetCurrentRiskPercent();
   if(riskPct <= 0)
   {
      if(EnableLogging)
         Print("[ADAPTIVE] Trade blocked: risk=0 (defensive mode)");
      return;
   }

   // Calculate SL and TP
   double orRange = g_symbolData[idx].orHigh - g_symbolData[idx].orLow;
   double stopLoss, takeProfit;

   if(orderType == ORDER_TYPE_BUY)
   {
      stopLoss = g_symbolData[idx].orLow;
      takeProfit = price + (price - stopLoss) * RewardRiskRatio;
   }
   else
   {
      stopLoss = g_symbolData[idx].orHigh;
      takeProfit = price - (stopLoss - price) * RewardRiskRatio;
   }

   // Calculate lot size with adaptive risk
   double lotSize = g_executor.CalculateLotSize(g_symbolData[idx].symbol, riskPct, price, stopLoss);

   if(lotSize <= 0)
   {
      if(EnableLogging)
         Print("ERROR [", g_symbolData[idx].symbol, "]: Invalid lot size calculation");
      return;
   }

   // Execute trade
   string direction = (orderType == ORDER_TYPE_BUY ? "BUY" : "SELL");
   string comment = "ORB_" + direction + "_" + EnumToString(g_riskCtrl.GetCurrentRegime());

   if(g_executor.ExecuteOrder(g_symbolData[idx].symbol, orderType, lotSize, stopLoss, takeProfit, comment))
   {
      g_symbolData[idx].dailyTradeCount++;
      g_symbolData[idx].lastTradeDate = iTime(g_symbolData[idx].symbol, PERIOD_D1, 0);

      if(EnableLogging)
      {
         Print("========================================");
         Print("✅ ORB TRADE [", g_symbolData[idx].symbol, "] ", direction);
         Print("  Regime: ", EnumToString(g_riskCtrl.GetCurrentRegime()));
         Print("  Risk: ", DoubleToString(riskPct, 2), "%");
         Print("  Lot: ", DoubleToString(lotSize, 2));
         Print("  Price: ", DoubleToString(price, _Digits));
         Print("  SL: ", DoubleToString(stopLoss, _Digits));
         Print("  TP: ", DoubleToString(takeProfit, _Digits));
         Print("  R:R: 1:", DoubleToString(RewardRiskRatio, 1));
         Print("  OR High: ", DoubleToString(g_symbolData[idx].orHigh, _Digits));
         Print("  OR Low: ", DoubleToString(g_symbolData[idx].orLow, _Digits));
         Print("========================================");
      }

      g_notifier.Send(g_symbolData[idx].symbol,
         "✅ ORB " + direction +
         " | Risk: " + DoubleToString(riskPct, 2) + "%" +
         " | Lot: " + DoubleToString(lotSize, 2) +
         " | SL: " + DoubleToString(stopLoss, _Digits) +
         " | TP: " + DoubleToString(takeProfit, _Digits));
   }
   else
   {
      g_notifier.Send(g_symbolData[idx].symbol,
         "❌ ORB " + direction + " FAILED");
   }
}

//+------------------------------------------------------------------+
//| Draw opening range on chart                                      |
//+------------------------------------------------------------------+
void DrawOpeningRange(int idx)
{
   string objName = "ORB_Range_" + g_symbolData[idx].symbol + "_" +
                    TimeToString(g_symbolData[idx].orStartTime);

   if(ObjectFind(0, objName) >= 0)
      ObjectDelete(0, objName);

   datetime endTime = g_symbolData[idx].orStartTime + SessionEndHour * 3600;

   ObjectCreate(0, objName, OBJ_RECTANGLE, 0,
      g_symbolData[idx].orStartTime, g_symbolData[idx].orHigh,
      endTime, g_symbolData[idx].orLow);

   ObjectSetInteger(0, objName, OBJPROP_COLOR, clrDodgerBlue);
   ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_DOT);
   ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, objName, OBJPROP_BACK, true);
   ObjectSetInteger(0, objName, OBJPROP_FILL, true);

   // Mid line
   string midName = "ORB_Mid_" + g_symbolData[idx].symbol + "_" +
                    TimeToString(g_symbolData[idx].orStartTime);

   if(ObjectFind(0, midName) >= 0)
      ObjectDelete(0, midName);

   ObjectCreate(0, midName, OBJ_TREND, 0,
      g_symbolData[idx].orStartTime, g_symbolData[idx].orMid,
      endTime, g_symbolData[idx].orMid);

   ObjectSetInteger(0, midName, OBJPROP_COLOR, clrYellow);
   ObjectSetInteger(0, midName, OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, midName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, midName, OBJPROP_RAY_RIGHT, false);

   // Label
   string labelName = "ORB_Label_" + g_symbolData[idx].symbol + "_" +
                      TimeToString(g_symbolData[idx].orStartTime);

   if(ObjectFind(0, labelName) >= 0)
      ObjectDelete(0, labelName);

   ObjectCreate(0, labelName, OBJ_TEXT, 0,
      g_symbolData[idx].orStartTime, g_symbolData[idx].orHigh);
   ObjectSetString(0, labelName, OBJPROP_TEXT, "ORB " + g_symbolData[idx].symbol);
   ObjectSetInteger(0, labelName, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 9);
   ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
}
//+------------------------------------------------------------------+

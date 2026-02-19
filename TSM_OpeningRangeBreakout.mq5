//+------------------------------------------------------------------+
//|                                    TSM_OpeningRangeBreakout.mq5 |
//|                        TSM Opening Range Breakout - P.J. Kaufman |
//|                                     Production-Grade Multi-Symbol |
//+------------------------------------------------------------------+
#property copyright "TSM Opening Range Breakout - P.J. Kaufman"
#property link      ""
#property version   "1.00"
#property description "TSM Opening Range Breakout - P.J. Kaufman"

//--- Input parameters
input group "=== Opening Range Settings ==="
input int    ORBStartHour       = 9;          // Opening range start hour
input int    ORBStartMinute     = 30;         // Opening range start minute
input int    ORBDurationBars    = 6;          // Number of M5 bars for opening range (30 min)
input double BreakoutBuffer     = 0.0;        // Buffer beyond range for breakout (in points)

input group "=== Trading Session ==="
input int    SessionEndHour     = 16;         // Session end hour (close all positions)
input int    SessionEndMinute   = 0;          // Session end minute
input bool   CloseAtSessionEnd  = true;       // Close positions at session end

input group "=== Multi-Symbol Settings ==="
input string TradingSymbols         = "NDAQ,NAS100,US100"; // Symbols to trade (comma separated)
input bool   UseCurrentSymbolOnly   = true;                // If true, ignore TradingSymbols

input group "=== Direction Filter ==="
input bool   TradeBullish       = true;       // Allow long breakouts
input bool   TradeBearish       = true;       // Allow short breakouts
input bool   TradeFirstBreakout = true;       // Only trade first breakout of the day

input group "=== Risk Management ==="
input double RiskPercent        = 1.0;        // Risk per trade (%)
input double RewardRiskRatio    = 2.0;        // Reward:Risk ratio
input int    MaxDailyTrades     = 2;          // Max trades per day per symbol
input int    MagicNumber        = 54321;      // Magic number for orders

input group "=== Spread Filter ==="
input int    MaxSpreadPoints    = 2500;       // Max spread in points

input group "=== Indicator Settings ==="
input int    ATRPeriod          = 14;         // ATR period for volatility filter
input double MinATRMult         = 0.3;        // Min opening range as ATR multiple
input double MaxATRMult         = 5.0;        // Max opening range as ATR multiple

input group "=== Notifications ==="
input bool   EnableAlerts              = true;  // Enable popup alerts
input bool   EnablePushNotifications   = false; // Enable push to mobile
input bool   EnableEmailNotifications  = false; // Enable email alerts

input group "=== Debugging ==="
input bool   EnableLogging        = true;     // Enable detailed logging
input bool   EnableVisualMarkers  = true;     // Enable chart markers

//--- ORB State Machine
enum ENUM_ORB_STATE
{
   WAITING_SESSION,      // Waiting for session open
   BUILDING_RANGE,       // Building the opening range
   WATCHING_BREAKOUT,    // Opening range set, watching for breakout
   SESSION_DONE          // Session complete for today
};

//--- Multi-Symbol Data Structure
struct SymbolORBData
{
   string            symbol;
   ENUM_ORB_STATE    state;
   double            rangeHigh;
   double            rangeLow;
   datetime          rangeStartTime;
   int               rangeBarsCollected;
   int               dailyTradeCount;
   datetime          lastTradeDate;
   int               atrHandle;
   datetime          lastBarTime;
};

//--- Global variables
SymbolORBData symbolDataArray[];
bool isBacktest = false;

//+------------------------------------------------------------------+
//| Initialize symbols for multi-symbol support                      |
//+------------------------------------------------------------------+
bool InitializeSymbols()
{
   if(UseCurrentSymbolOnly)
   {
      ArrayResize(symbolDataArray, 1);
      symbolDataArray[0].symbol            = _Symbol;
      symbolDataArray[0].state             = WAITING_SESSION;
      symbolDataArray[0].rangeHigh         = 0;
      symbolDataArray[0].rangeLow          = 0;
      symbolDataArray[0].rangeStartTime    = 0;
      symbolDataArray[0].rangeBarsCollected = 0;
      symbolDataArray[0].dailyTradeCount   = 0;
      symbolDataArray[0].lastTradeDate     = 0;
      symbolDataArray[0].lastBarTime       = 0;

      symbolDataArray[0].atrHandle = iATR(_Symbol, PERIOD_M5, ATRPeriod);
      if(symbolDataArray[0].atrHandle == INVALID_HANDLE)
      {
         Print("ERROR: Cannot initialize ATR for ", _Symbol);
         return false;
      }

      Print("Single-symbol mode: ", _Symbol);
      return true;
   }

   // Parse TradingSymbols (separated by commas)
   string symbols[];
   int count = StringSplit(TradingSymbols, ',', symbols);

   if(count <= 0)
   {
      Print("ERROR: No symbols found in TradingSymbols input");
      return false;
   }

   ArrayResize(symbolDataArray, count);
   for(int i = 0; i < count; i++)
   {
      StringTrimLeft(symbols[i]);
      StringTrimRight(symbols[i]);

      symbolDataArray[i].symbol            = symbols[i];
      symbolDataArray[i].state             = WAITING_SESSION;
      symbolDataArray[i].rangeHigh         = 0;
      symbolDataArray[i].rangeLow          = 0;
      symbolDataArray[i].rangeStartTime    = 0;
      symbolDataArray[i].rangeBarsCollected = 0;
      symbolDataArray[i].dailyTradeCount   = 0;
      symbolDataArray[i].lastTradeDate     = 0;
      symbolDataArray[i].lastBarTime       = 0;

      symbolDataArray[i].atrHandle = iATR(symbols[i], PERIOD_M5, ATRPeriod);
      if(symbolDataArray[i].atrHandle == INVALID_HANDLE)
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
//| Send notification (Alert, Push, Email)                           |
//+------------------------------------------------------------------+
void SendNotificationAlert(string message)
{
   // Skip notifications in Strategy Tester
   if(isBacktest)
      return;

   if(EnableAlerts)
      Alert(message);

   if(EnablePushNotifications)
      SendNotification(message);

   if(EnableEmailNotifications)
      SendMail("TSM ORB Alert", message);
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   isBacktest = MQLInfoInteger(MQL_TESTER);

   if(isBacktest)
      Print("Running in STRATEGY TESTER mode");
   else
      Print("Running in LIVE/DEMO mode");

   if(!InitializeSymbols())
   {
      Print("ERROR: Failed to initialize symbols");
      return INIT_FAILED;
   }

   Print("========================================");
   Print("TSM Opening Range Breakout initialized");
   Print("Timeframe: M5");
   Print("Opening range: ", ORBStartHour, ":", (ORBStartMinute < 10 ? "0" : ""), ORBStartMinute,
         " (", ORBDurationBars * 5, " min)");
   Print("Session end: ", SessionEndHour, ":", (SessionEndMinute < 10 ? "0" : ""), SessionEndMinute);
   Print("Symbols: ", ArraySize(symbolDataArray));
   Print("========================================");

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   for(int i = 0; i < ArraySize(symbolDataArray); i++)
   {
      if(symbolDataArray[i].atrHandle != INVALID_HANDLE)
         IndicatorRelease(symbolDataArray[i].atrHandle);
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
   for(int s = 0; s < ArraySize(symbolDataArray); s++)
   {
      ProcessSymbol(s);
   }
}

//+------------------------------------------------------------------+
//| Check if current time matches opening range start                |
//+------------------------------------------------------------------+
bool IsORBStartBar(const MqlDateTime &dt)
{
   return (dt.hour == ORBStartHour && dt.min == ORBStartMinute);
}

//+------------------------------------------------------------------+
//| Check if current time is past the opening range                  |
//+------------------------------------------------------------------+
bool IsPastORBPeriod(const MqlDateTime &dt)
{
   int currentMinutes = dt.hour * 60 + dt.min;
   int endMinutes     = ORBStartHour * 60 + ORBStartMinute + ORBDurationBars * 5;

   return (currentMinutes >= endMinutes);
}

//+------------------------------------------------------------------+
//| Check if session has ended                                       |
//+------------------------------------------------------------------+
bool IsSessionEnd(const MqlDateTime &dt)
{
   int currentMinutes = dt.hour * 60 + dt.min;
   int endMinutes     = SessionEndHour * 60 + SessionEndMinute;

   return (currentMinutes >= endMinutes);
}

//+------------------------------------------------------------------+
//| Process individual symbol                                        |
//+------------------------------------------------------------------+
void ProcessSymbol(int idx)
{
   // Check if new bar formed on M5
   datetime currentBarTime = iTime(symbolDataArray[idx].symbol, PERIOD_M5, 0);

   if(currentBarTime == symbolDataArray[idx].lastBarTime)
      return;

   symbolDataArray[idx].lastBarTime = currentBarTime;

   MqlDateTime dt;
   TimeToStruct(currentBarTime, dt);

   // Reset state at start of new trading day
   datetime currentDate = iTime(symbolDataArray[idx].symbol, PERIOD_D1, 0);
   if(currentDate != symbolDataArray[idx].lastTradeDate)
   {
      if(symbolDataArray[idx].lastTradeDate != 0)
      {
         symbolDataArray[idx].state             = WAITING_SESSION;
         symbolDataArray[idx].rangeHigh         = 0;
         symbolDataArray[idx].rangeLow          = 0;
         symbolDataArray[idx].rangeBarsCollected = 0;
         symbolDataArray[idx].dailyTradeCount   = 0;
         if(EnableLogging)
            Print("=== NEW TRADING DAY: ", symbolDataArray[idx].symbol, " | ",
                  TimeToString(currentDate, TIME_DATE), " ===");
      }
      symbolDataArray[idx].lastTradeDate = currentDate;
   }

   // Close positions at session end
   if(IsSessionEnd(dt) && CloseAtSessionEnd)
   {
      ClosePositionsForSymbol(idx);
      if(symbolDataArray[idx].state != SESSION_DONE)
      {
         symbolDataArray[idx].state = SESSION_DONE;
         if(EnableLogging)
            Print("SESSION END [", symbolDataArray[idx].symbol, "]: All positions closed");
      }
      return;
   }

   if(EnableLogging && !isBacktest)
   {
      Print("=== ", symbolDataArray[idx].symbol, " | ", TimeToString(TimeCurrent()), " ===");
      Print("State: ", EnumToString(symbolDataArray[idx].state));
   }

   // State machine
   switch(symbolDataArray[idx].state)
   {
      case WAITING_SESSION:
         if(IsORBStartBar(dt))
         {
            // Start building the opening range
            symbolDataArray[idx].state = BUILDING_RANGE;
            symbolDataArray[idx].rangeStartTime    = currentBarTime;
            symbolDataArray[idx].rangeBarsCollected = 0;

            if(EnableLogging)
               Print(">>> STATE CHANGE [", symbolDataArray[idx].symbol,
                     "]: WAITING_SESSION -> BUILDING_RANGE");
         }
         break;

      case BUILDING_RANGE:
         if(IsPastORBPeriod(dt))
         {
            // Calculate range from completed bars in the ORB window
            double highs[], lows[];
            ArraySetAsSeries(highs, true);
            ArraySetAsSeries(lows, true);

            int copied_h = CopyHigh(symbolDataArray[idx].symbol, PERIOD_M5, 1, ORBDurationBars, highs);
            int copied_l = CopyLow(symbolDataArray[idx].symbol, PERIOD_M5, 1, ORBDurationBars, lows);

            if(copied_h < ORBDurationBars || copied_l < ORBDurationBars)
            {
               if(EnableLogging)
                  Print("ERROR [", symbolDataArray[idx].symbol,
                        "]: Failed to copy bar data for range (got ", copied_h, "/", copied_l,
                        ", need ", ORBDurationBars, ")");
               symbolDataArray[idx].state = SESSION_DONE;
               break;
            }

            symbolDataArray[idx].rangeHigh = highs[ArrayMaximum(highs)];
            symbolDataArray[idx].rangeLow  = lows[ArrayMinimum(lows)];
            symbolDataArray[idx].rangeBarsCollected = ORBDurationBars;

            // Validate opening range against ATR
            if(ValidateOpeningRange(idx))
            {
               symbolDataArray[idx].state = WATCHING_BREAKOUT;

               double rangeSize = symbolDataArray[idx].rangeHigh - symbolDataArray[idx].rangeLow;

               if(EnableLogging)
               {
                  Print(">>> STATE CHANGE [", symbolDataArray[idx].symbol,
                        "]: BUILDING_RANGE -> WATCHING_BREAKOUT");
                  Print("  Range High: ", DoubleToString(symbolDataArray[idx].rangeHigh, _Digits));
                  Print("  Range Low:  ", DoubleToString(symbolDataArray[idx].rangeLow, _Digits));
                  Print("  Range Size: ", DoubleToString(rangeSize, _Digits));
               }

               SendNotificationAlert("Opening Range Set [" + symbolDataArray[idx].symbol +
                     "] H: " + DoubleToString(symbolDataArray[idx].rangeHigh, _Digits) +
                     " L: " + DoubleToString(symbolDataArray[idx].rangeLow, _Digits));

               if(EnableVisualMarkers)
                  DrawOpeningRange(idx);
            }
            else
            {
               symbolDataArray[idx].state = SESSION_DONE;
               if(EnableLogging)
                  Print(">>> RANGE REJECTED [", symbolDataArray[idx].symbol,
                        "]: Failed ATR validation, skipping today");
            }
         }
         break;

      case WATCHING_BREAKOUT:
         if(!IsSessionEnd(dt))
         {
            CheckBreakout(idx);
         }
         break;

      case SESSION_DONE:
         // Nothing to do until next day
         break;
   }
}

//+------------------------------------------------------------------+
//| Validate opening range size against ATR                          |
//+------------------------------------------------------------------+
bool ValidateOpeningRange(int idx)
{
   double atr[];
   ArraySetAsSeries(atr, true);
   if(CopyBuffer(symbolDataArray[idx].atrHandle, 0, 1, 1, atr) <= 0)
   {
      if(EnableLogging)
         Print("ERROR [", symbolDataArray[idx].symbol, "]: Failed to copy ATR buffer");
      return false;
   }
   double atrValue = atr[0];
   double rangeSize = symbolDataArray[idx].rangeHigh - symbolDataArray[idx].rangeLow;

   if(rangeSize < MinATRMult * atrValue)
   {
      if(EnableLogging)
         Print("  REJECTED [", symbolDataArray[idx].symbol, "]: Range too small (",
               DoubleToString(rangeSize, _Digits), " < ",
               DoubleToString(MinATRMult * atrValue, _Digits), ")");
      return false;
   }

   if(rangeSize > MaxATRMult * atrValue)
   {
      if(EnableLogging)
         Print("  REJECTED [", symbolDataArray[idx].symbol, "]: Range too large (",
               DoubleToString(rangeSize, _Digits), " > ",
               DoubleToString(MaxATRMult * atrValue, _Digits), ")");
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Check for breakout above or below the opening range              |
//+------------------------------------------------------------------+
void CheckBreakout(int idx)
{
   // Skip if max daily trades reached
   if(symbolDataArray[idx].dailyTradeCount >= MaxDailyTrades)
      return;

   // Skip if position already open for this symbol
   if(HasOpenPosition(idx))
      return;

   // If only first breakout allowed and we already traded
   if(TradeFirstBreakout && symbolDataArray[idx].dailyTradeCount > 0)
      return;

   // Check spread
   double ask = SymbolInfoDouble(symbolDataArray[idx].symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(symbolDataArray[idx].symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(symbolDataArray[idx].symbol, SYMBOL_POINT);

   if(point <= 0)
      return;

   int currentSpread = (int)((ask - bid) / point);
   if(currentSpread > MaxSpreadPoints)
   {
      if(EnableLogging && !isBacktest)
         Print("  SPREAD FILTER [", symbolDataArray[idx].symbol, "]: ",
               currentSpread, " > ", MaxSpreadPoints);
      return;
   }

   double bufferValue = BreakoutBuffer * point;

   // Bullish breakout: close above opening range high
   double close0 = iClose(symbolDataArray[idx].symbol, PERIOD_M5, 1);

   if(TradeBullish && close0 > (symbolDataArray[idx].rangeHigh + bufferValue))
   {
      if(EnableLogging)
         Print("BREAKOUT UP [", symbolDataArray[idx].symbol, "]: Close ",
               DoubleToString(close0, _Digits), " > Range High ",
               DoubleToString(symbolDataArray[idx].rangeHigh, _Digits));

      ExecuteBreakoutTrade(idx, ORDER_TYPE_BUY);
      return;
   }

   // Bearish breakout: close below opening range low
   if(TradeBearish && close0 < (symbolDataArray[idx].rangeLow - bufferValue))
   {
      if(EnableLogging)
         Print("BREAKOUT DOWN [", symbolDataArray[idx].symbol, "]: Close ",
               DoubleToString(close0, _Digits), " < Range Low ",
               DoubleToString(symbolDataArray[idx].rangeLow, _Digits));

      ExecuteBreakoutTrade(idx, ORDER_TYPE_SELL);
      return;
   }
}

//+------------------------------------------------------------------+
//| Check if there is an open position for this symbol               |
//+------------------------------------------------------------------+
bool HasOpenPosition(int idx)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == symbolDataArray[idx].symbol)
      {
         if(PositionGetInteger(POSITION_MAGIC) == MagicNumber)
            return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Execute breakout trade                                           |
//+------------------------------------------------------------------+
void ExecuteBreakoutTrade(int idx, ENUM_ORDER_TYPE orderType)
{
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount     = accountBalance * (RiskPercent / 100.0);
   double point          = SymbolInfoDouble(symbolDataArray[idx].symbol, SYMBOL_POINT);

   // Entry price
   double entryPrice;
   if(orderType == ORDER_TYPE_BUY)
      entryPrice = SymbolInfoDouble(symbolDataArray[idx].symbol, SYMBOL_ASK);
   else
      entryPrice = SymbolInfoDouble(symbolDataArray[idx].symbol, SYMBOL_BID);

   // Stop loss at opposite side of opening range
   double stopLoss;
   if(orderType == ORDER_TYPE_BUY)
      stopLoss = symbolDataArray[idx].rangeLow;
   else
      stopLoss = symbolDataArray[idx].rangeHigh;

   // Take profit based on risk:reward ratio
   double slDistance = MathAbs(entryPrice - stopLoss);
   double tpDistance = slDistance * RewardRiskRatio;

   double takeProfit;
   if(orderType == ORDER_TYPE_BUY)
      takeProfit = entryPrice + tpDistance;
   else
      takeProfit = entryPrice - tpDistance;

   // Calculate lot size
   double tickValue = SymbolInfoDouble(symbolDataArray[idx].symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(symbolDataArray[idx].symbol, SYMBOL_TRADE_TICK_SIZE);

   if(tickSize <= 0 || point <= 0 || tickValue <= 0)
   {
      if(EnableLogging)
         Print("ERROR [", symbolDataArray[idx].symbol, "]: Invalid tickSize, tickValue, or point");
      return;
   }

   double slPoints = slDistance / point;
   if(slPoints <= 0)
   {
      if(EnableLogging)
         Print("ERROR [", symbolDataArray[idx].symbol, "]: SL distance is zero");
      return;
   }

   double lotSize = riskAmount / (slPoints * tickValue / tickSize);

   // Normalize lot size
   double minLot  = SymbolInfoDouble(symbolDataArray[idx].symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(symbolDataArray[idx].symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(symbolDataArray[idx].symbol, SYMBOL_VOLUME_STEP);

   if(lotStep > 0)
      lotSize = MathFloor(lotSize / lotStep) * lotStep;

   lotSize = MathMax(minLot, MathMin(maxLot, lotSize));

   // Execute trade
   string comment = "ORB_" + (orderType == ORDER_TYPE_BUY ? "BUY" : "SELL");

   MqlTradeRequest request = {};
   MqlTradeResult  result  = {};

   request.action   = TRADE_ACTION_DEAL;
   request.symbol   = symbolDataArray[idx].symbol;
   request.volume   = lotSize;
   request.type     = orderType;
   request.price    = entryPrice;
   request.sl       = stopLoss;
   request.tp       = takeProfit;
   request.deviation = 10;
   request.magic    = MagicNumber;
   request.comment  = comment;

   if(OrderSend(request, result))
   {
      if(result.retcode == TRADE_RETCODE_DONE || result.retcode == TRADE_RETCODE_PLACED)
      {
         symbolDataArray[idx].dailyTradeCount++;

         if(EnableLogging)
         {
            Print("========================================");
            Print("TRADE EXECUTED [", symbolDataArray[idx].symbol, "]!");
            Print("  Type: ", (orderType == ORDER_TYPE_BUY ? "BUY" : "SELL"));
            Print("  Price: ", DoubleToString(entryPrice, _Digits));
            Print("  Lot size: ", DoubleToString(lotSize, 2));
            Print("  Stop loss: ", DoubleToString(stopLoss, _Digits));
            Print("  Take profit: ", DoubleToString(takeProfit, _Digits));
            Print("  Risk: $", DoubleToString(riskAmount, 2));
            Print("  R:R ratio: 1:", DoubleToString(RewardRiskRatio, 1));
            Print("========================================");
         }

         string tradeType = (orderType == ORDER_TYPE_BUY ? "BUY" : "SELL");
         SendNotificationAlert("TRADE EXECUTED [" + symbolDataArray[idx].symbol + "] - " + tradeType +
               " | Price: " + DoubleToString(entryPrice, _Digits) +
               " | Lot: " + DoubleToString(lotSize, 2) +
               " | SL: " + DoubleToString(stopLoss, _Digits) +
               " | TP: " + DoubleToString(takeProfit, _Digits));

         if(EnableVisualMarkers)
            MarkBreakout(idx, orderType, entryPrice);
      }
      else
      {
         if(EnableLogging)
            Print("ERROR [", symbolDataArray[idx].symbol, "]: Order failed - ",
                  result.comment, " (", result.retcode, ")");

         SendNotificationAlert("TRADE FAILED [" + symbolDataArray[idx].symbol + "] - " +
               result.comment + " (Code: " + IntegerToString(result.retcode) + ")");
      }
   }
   else
   {
      if(EnableLogging)
         Print("ERROR [", symbolDataArray[idx].symbol, "]: OrderSend failed - ", GetLastError());

      SendNotificationAlert("ORDER SEND FAILED [" + symbolDataArray[idx].symbol + "] - Error: " +
            IntegerToString(GetLastError()));
   }
}

//+------------------------------------------------------------------+
//| Close all positions for a symbol                                 |
//+------------------------------------------------------------------+
void ClosePositionsForSymbol(int idx)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == symbolDataArray[idx].symbol)
      {
         if(PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         {
            ulong ticket = PositionGetInteger(POSITION_TICKET);
            double volume = PositionGetDouble(POSITION_VOLUME);
            ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

            MqlTradeRequest request = {};
            MqlTradeResult  result  = {};

            request.action   = TRADE_ACTION_DEAL;
            request.symbol   = symbolDataArray[idx].symbol;
            request.volume   = volume;
            request.type     = (posType == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
            request.price    = (posType == POSITION_TYPE_BUY) ?
                               SymbolInfoDouble(symbolDataArray[idx].symbol, SYMBOL_BID) :
                               SymbolInfoDouble(symbolDataArray[idx].symbol, SYMBOL_ASK);
            request.position = ticket;
            request.deviation = 10;
            request.magic    = MagicNumber;
            request.comment  = "ORB_CLOSE";

            if(OrderSend(request, result))
            {
               if(result.retcode == TRADE_RETCODE_DONE || result.retcode == TRADE_RETCODE_PLACED)
               {
                  if(EnableLogging)
                     Print("CLOSED position [", symbolDataArray[idx].symbol, "] ticket: ", ticket);
               }
               else
               {
                  if(EnableLogging)
                     Print("ERROR closing position [", symbolDataArray[idx].symbol,
                           "] ticket: ", ticket, " retcode: ", result.retcode);
               }
            }
            else
            {
               if(EnableLogging)
                  Print("ERROR closing position [", symbolDataArray[idx].symbol,
                        "] ticket: ", ticket, " error: ", GetLastError());
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Draw opening range rectangle on chart                            |
//+------------------------------------------------------------------+
void DrawOpeningRange(int idx)
{
   string objName = "ORB_Range_" + symbolDataArray[idx].symbol + "_" +
                    TimeToString(symbolDataArray[idx].rangeStartTime);

   if(ObjectFind(0, objName) >= 0)
      ObjectDelete(0, objName);

   datetime endTime = symbolDataArray[idx].rangeStartTime +
                      ORBDurationBars * PeriodSeconds(PERIOD_M5);

   ObjectCreate(0, objName, OBJ_RECTANGLE, 0,
                symbolDataArray[idx].rangeStartTime, symbolDataArray[idx].rangeHigh,
                endTime, symbolDataArray[idx].rangeLow);

   ObjectSetInteger(0, objName, OBJPROP_COLOR, clrDodgerBlue);
   ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, objName, OBJPROP_BACK, true);
   ObjectSetInteger(0, objName, OBJPROP_FILL, true);

   // Draw breakout levels as horizontal lines extending to session end
   MqlDateTime dtEnd;
   TimeToStruct(symbolDataArray[idx].rangeStartTime, dtEnd);
   dtEnd.hour = SessionEndHour;
   dtEnd.min  = SessionEndMinute;
   datetime sessionEnd = StructToTime(dtEnd);

   // High breakout line
   string highLine = "ORB_High_" + symbolDataArray[idx].symbol + "_" +
                     TimeToString(symbolDataArray[idx].rangeStartTime);
   if(ObjectFind(0, highLine) >= 0)
      ObjectDelete(0, highLine);

   ObjectCreate(0, highLine, OBJ_TREND, 0,
                endTime, symbolDataArray[idx].rangeHigh,
                sessionEnd, symbolDataArray[idx].rangeHigh);
   ObjectSetInteger(0, highLine, OBJPROP_COLOR, clrLimeGreen);
   ObjectSetInteger(0, highLine, OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, highLine, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, highLine, OBJPROP_RAY_RIGHT, false);

   // Low breakout line
   string lowLine = "ORB_Low_" + symbolDataArray[idx].symbol + "_" +
                    TimeToString(symbolDataArray[idx].rangeStartTime);
   if(ObjectFind(0, lowLine) >= 0)
      ObjectDelete(0, lowLine);

   ObjectCreate(0, lowLine, OBJ_TREND, 0,
                endTime, symbolDataArray[idx].rangeLow,
                sessionEnd, symbolDataArray[idx].rangeLow);
   ObjectSetInteger(0, lowLine, OBJPROP_COLOR, clrRed);
   ObjectSetInteger(0, lowLine, OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, lowLine, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, lowLine, OBJPROP_RAY_RIGHT, false);
}

//+------------------------------------------------------------------+
//| Mark breakout trade on chart                                     |
//+------------------------------------------------------------------+
void MarkBreakout(int idx, ENUM_ORDER_TYPE orderType, double price)
{
   string objName = "ORB_Entry_" + symbolDataArray[idx].symbol + "_" +
                    TimeToString(TimeCurrent());

   if(ObjectFind(0, objName) >= 0)
      ObjectDelete(0, objName);

   ObjectCreate(0, objName, OBJ_ARROW, 0, TimeCurrent(), price);

   if(orderType == ORDER_TYPE_BUY)
   {
      ObjectSetInteger(0, objName, OBJPROP_ARROWCODE, 233); // Up arrow
      ObjectSetInteger(0, objName, OBJPROP_COLOR, clrLimeGreen);
   }
   else
   {
      ObjectSetInteger(0, objName, OBJPROP_ARROWCODE, 234); // Down arrow
      ObjectSetInteger(0, objName, OBJPROP_COLOR, clrRed);
   }

   ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2);

   string labelName = objName + "_Label";
   if(ObjectFind(0, labelName) >= 0)
      ObjectDelete(0, labelName);

   ObjectCreate(0, labelName, OBJ_TEXT, 0, TimeCurrent(), price);
   ObjectSetString(0, labelName, OBJPROP_TEXT,
                   "ORB " + (orderType == ORDER_TYPE_BUY ? "BUY" : "SELL"));
   ObjectSetInteger(0, labelName, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 10);
   ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
}
//+------------------------------------------------------------------+

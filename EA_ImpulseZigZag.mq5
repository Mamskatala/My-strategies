//+------------------------------------------------------------------+
//|                                            EA_ImpulseZigZag.mq5 |
//|                                  OBR (Order Block Reversal) EA  |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Trading Strategy"
#property link      ""
#property version   "2.00"
#property description "Captures daily OBR micro-edge with simplified pattern detection"

//--- Input parameters
input group "=== Trading Hours ==="
input int    EntryHour = 16;                 // Entry hour (start of session)
input int    EntryMinute = 30;               // Entry minute
input int    EndHour = 22;                   // End hour (end of session)
input bool   TradeBullish = true;            // Allow bullish trades
input bool   TradeBearish = true;            // Allow bearish trades

input group "=== Multi-Symbol Settings ==="
input string TradingSymbols = "NDAQ,NAS100,US100"; // Symboles à trader (séparés par virgule)
input bool   UseCurrentSymbolOnly = false;         // Si true, ignorer TradingSymbols

input group "=== Impulse Candle Settings ==="
input double ImpulseMinATRMult = 0.60;       // Min ATR multiplier (assouplir de 0.85 → 0.60)
input double ImpulseMaxATRMult = 4.0;        // Max ATR multiplier (increased from 3.0)
input double ImpulseBodyPercent = 35.0;      // Min body % (assouplir de 50% → 35%)
input int    MaxSpreadPoints = 2500;         // Max spread in points (augmenter de 1500 → 2500)

input group "=== Pullback Settings ==="
input int    PullbackMaxBars = 36;           // Max bars for pullback (24 → 36 bars = 3 heures)
input double PullbackMinRetrace = 0.30;      // Min retracement (40% → 30%)
input double PullbackMaxRetrace = 0.70;      // Max retracement (60% → 70%)

input group "=== Trigger Settings ==="
input int    TriggerBufferPoints = 5;        // Trigger buffer in points

input group "=== Risk Management ==="
input double RiskPercent = 1.0;              // Risk per trade (%)
input double RewardRiskRatio = 2.0;          // Reward:Risk ratio
input int    MaxDailyTrades = 1;             // Max trades per day
input int    MagicNumber = 12345;            // Magic number for orders

input group "=== Indicator Settings ==="
input int    ATRPeriod = 14;                 // ATR period

input group "=== Notifications ==="
input bool   EnableAlerts = true;            // Enable popup alerts
input bool   EnablePushNotifications = false; // Enable push to mobile
input bool   EnableEmailNotifications = false; // Enable email alerts

input group "=== Debugging ==="
input bool   EnableLogging = true;           // Enable detailed logging
input bool   EnableVisualMarkers = true;     // Enable chart markers

//--- OBR State Machine
enum ENUM_OBR_STATE
{
   WAITING_IMPULSE,     // Scan for order block
   WAITING_PULLBACK,    // Wait for retracement to OB
   WAITING_TRIGGER      // Wait for continuation break
};

//--- Multi-Symbol Data Structure
struct SymbolOBRData
{
   string symbol;
   ENUM_OBR_STATE state;
   datetime impulseBarTime;
   double impulseHigh, impulseLow, impulseRange;
   int impulseDirection;
   bool pullbackDetected;
   int pullbackBarIndex;
   double pullbackPrice;
   datetime pullbackBarTime;
   double triggerLevel;
   ENUM_ORDER_TYPE triggerType;
   bool tradeExecutedToday;
   datetime lastTradeDate;
   int atrHandle;
   datetime lastBarTime;
};

//--- Global variables
SymbolOBRData symbolDataArray[];
bool isBacktest = false;

//--- Impulse detection statistics
static int rejectedRangeSmall = 0;
static int rejectedRangeLarge = 0;
static int rejectedBodySmall = 0;
static int rejectedSpread = 0;
static int totalBarsScanned = 0;

//+------------------------------------------------------------------+
//| Initialize symbols for multi-symbol support                      |
//+------------------------------------------------------------------+
bool InitializeSymbols()
{
   if(UseCurrentSymbolOnly)
   {
      ArrayResize(symbolDataArray, 1);
      symbolDataArray[0].symbol = _Symbol;
      symbolDataArray[0].state = WAITING_IMPULSE;
      symbolDataArray[0].tradeExecutedToday = false;
      symbolDataArray[0].lastTradeDate = 0;
      symbolDataArray[0].pullbackDetected = false;
      symbolDataArray[0].impulseDirection = 0;
      symbolDataArray[0].lastBarTime = 0;
      
      // Initialize ATR for this symbol
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
      // Trim whitespace
      StringTrimLeft(symbols[i]);
      StringTrimRight(symbols[i]);
      
      symbolDataArray[i].symbol = symbols[i];
      symbolDataArray[i].state = WAITING_IMPULSE;
      symbolDataArray[i].tradeExecutedToday = false;
      symbolDataArray[i].lastTradeDate = 0;
      symbolDataArray[i].pullbackDetected = false;
      symbolDataArray[i].impulseDirection = 0;
      symbolDataArray[i].lastBarTime = 0;
      
      // Initialize ATR for each symbol
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
//| Send notification (Alert, Push, Email)                          |
//+------------------------------------------------------------------+
void SendNotificationAlert(string message)
{
   string fullMessage = "[" + _Symbol + "] " + message;
   
   // Popup alert
   if(EnableAlerts)
      Alert(fullMessage);
   
   // Push notification to mobile
   if(EnablePushNotifications)
      SendNotification(fullMessage);
   
   // Email notification
   if(EnableEmailNotifications)
      SendMail("EA_ImpulseZigZag Alert - " + _Symbol, fullMessage);
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Detect if running in Strategy Tester
   isBacktest = MQLInfoInteger(MQL_TESTER);
   
   if(isBacktest)
      Print("Running in STRATEGY TESTER mode");
   else
      Print("Running in LIVE/DEMO mode");
   
   // Initialize symbols
   if(!InitializeSymbols())
   {
      Print("ERROR: Failed to initialize symbols");
      return INIT_FAILED;
   }
   
   Print("========================================");
   Print("EA_ImpulseZigZag initialized successfully");
   Print("Timeframe: M5");
   Print("Entry window: ", EntryHour, ":", (EntryMinute < 10 ? "0" : ""), EntryMinute, " - ", EndHour, ":00");
   Print("Session duration: ", (EndHour - EntryHour), " hours");
   Print("Symbols: ", ArraySize(symbolDataArray));
   Print("========================================");
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Release ATR handles for all symbols
   for(int i = 0; i < ArraySize(symbolDataArray); i++)
   {
      if(symbolDataArray[i].atrHandle != INVALID_HANDLE)
         IndicatorRelease(symbolDataArray[i].atrHandle);
   }
   
   // Clean up visual objects
   if(EnableVisualMarkers)
      ObjectsDeleteAll(0, "Impulse_");
   
   Print("EA_ImpulseZigZag deinitialized");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Loop through all symbols
   for(int s = 0; s < ArraySize(symbolDataArray); s++)
   {
      ProcessSymbol(s);
   }
}

//+------------------------------------------------------------------+
//| Process individual symbol                                        |
//+------------------------------------------------------------------+
void ProcessSymbol(int symbolIndex)
{
   SymbolOBRData &data = symbolDataArray[symbolIndex];
   
   // Check if new bar formed on M5
   datetime currentBarTime = iTime(data.symbol, PERIOD_M5, 0);
   
   if(currentBarTime == data.lastBarTime)
      return;  // Wait for new bar
   
   data.lastBarTime = currentBarTime;
   
   // Get current time
   MqlDateTime dt_now;
   TimeToStruct(TimeCurrent(), dt_now);
   
   // Reset daily trade flag at start of new day
   datetime currentDate = iTime(data.symbol, PERIOD_D1, 0);
   if(currentDate != data.lastTradeDate && data.lastTradeDate != 0)
   {
      data.tradeExecutedToday = false;
      data.state = WAITING_IMPULSE;
      if(EnableLogging)
         Print("=== NEW TRADING DAY: ", data.symbol, " | ", TimeToString(currentDate, TIME_DATE), " ===");
   }
   
   // Check if we're in entry window
   bool isEntryTime = (dt_now.hour >= EntryHour && dt_now.hour < EndHour);
   
   // Debug output - log at each new M5 bar
   if(EnableLogging && !isBacktest)
   {
      Print("=== ", data.symbol, " | ", TimeToString(TimeCurrent()), " ===");
      Print("State: ", EnumToString(data.state));
      Print("Entry window: ", (isEntryTime ? "OPEN" : "CLOSED"));
   }
   
   // Skip if already traded today
   if(data.tradeExecutedToday)
      return;
   
   // Skip if position already open
   if(PositionSelect(data.symbol))
      return;
   
   // Skip if outside entry window
   if(!isEntryTime)
      return;
   
   // State machine
   switch(data.state)
   {
      case WAITING_IMPULSE:
         if(DetectImpulseCandle(symbolIndex))
         {
            data.state = WAITING_PULLBACK;
            data.pullbackDetected = false;
            if(EnableLogging)
               Print(">>> STATE CHANGE [", data.symbol, "]: WAITING_IMPULSE -> WAITING_PULLBACK");
         }
         break;
         
      case WAITING_PULLBACK:
         if(DetectPullback(symbolIndex))
         {
            data.state = WAITING_TRIGGER;
            CalculateTriggerLevel(symbolIndex);
            if(EnableLogging)
               Print(">>> STATE CHANGE [", data.symbol, "]: WAITING_PULLBACK -> WAITING_TRIGGER");
         }
         else if(CheckPullbackTimeout(symbolIndex))
         {
            data.state = WAITING_IMPULSE;
            if(EnableLogging)
               Print(">>> TIMEOUT [", data.symbol, "]: Pullback took too long, resetting to WAITING_IMPULSE");
         }
         break;
         
      case WAITING_TRIGGER:
         if(CheckTrigger(symbolIndex))
         {
            ExecuteTrade(symbolIndex);
            data.state = WAITING_IMPULSE;
         }
         else if(CheckTriggerTimeout(symbolIndex))
         {
            data.state = WAITING_IMPULSE;
            if(EnableLogging)
               Print(">>> TIMEOUT [", data.symbol, "]: Trigger not hit, resetting to WAITING_IMPULSE");
         }
         break;
   }
}

//+------------------------------------------------------------------+
//| Detect impulse candle (Order Block)                             |
//+------------------------------------------------------------------+
bool DetectImpulseCandle(int symbolIndex)
{
   SymbolOBRData &data = symbolDataArray[symbolIndex];
   
   // Get ATR value
   double atr[];
   ArraySetAsSeries(atr, true);
   if(CopyBuffer(data.atrHandle, 0, 1, 1, atr) <= 0)
   {
      if(EnableLogging)
         Print("ERROR [", data.symbol, "]: Failed to copy ATR buffer");
      return false;
   }
   double atrValue = atr[0];
   
   // Get bar 1 data (completed bar)
   double high1 = iHigh(data.symbol, PERIOD_M5, 1);
   double low1 = iLow(data.symbol, PERIOD_M5, 1);
   double open1 = iOpen(data.symbol, PERIOD_M5, 1);
   double close1 = iClose(data.symbol, PERIOD_M5, 1);
   datetime time1 = iTime(data.symbol, PERIOD_M5, 1);
   
   double range = high1 - low1;
   double body = MathAbs(close1 - open1);
   double bodyPercent = (range > 0) ? (body / range * 100.0) : 0;
   
   // Get current spread
   double ask = SymbolInfoDouble(data.symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(data.symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(data.symbol, SYMBOL_POINT);
   int currentSpread = (int)((ask - bid) / point);
   
   // Determine direction
   bool isBullish = (close1 > open1);
   bool isBearish = (close1 < open1);
   
   // Increment total bars scanned
   totalBarsScanned++;
   
   if(EnableLogging && !isBacktest)
   {
      Print("=== SCANNING FOR IMPULSE [", data.symbol, "] (Bar[1]: ", TimeToString(time1), ") ===");
      Print("  Range: ", DoubleToString(range, _Digits), " | ATR: ", DoubleToString(atrValue, _Digits));
      Print("  Min required: ", DoubleToString(ImpulseMinATRMult * atrValue, _Digits));
      Print("  Max allowed: ", DoubleToString(ImpulseMaxATRMult * atrValue, _Digits));
      Print("  Body %: ", DoubleToString(bodyPercent, 2), " (min: ", DoubleToString(ImpulseBodyPercent, 2), ")");
      Print("  Spread: ", currentSpread, " points (max: ", MaxSpreadPoints, ")");
      Print("  Direction: ", (isBullish ? "BULLISH" : (isBearish ? "BEARISH" : "DOJI")));
   }
   
   // Validation 1: Range vs ATR
   if(range < (ImpulseMinATRMult * atrValue))
   {
      rejectedRangeSmall++;
      if(EnableLogging && !isBacktest)
         Print("  ❌ REJECTED: Range too small (", DoubleToString(range, _Digits), " < ", 
               DoubleToString(ImpulseMinATRMult * atrValue, _Digits), ")");
      PrintDetectionStats();
      return false;
   }
   
   if(range > (ImpulseMaxATRMult * atrValue))
   {
      rejectedRangeLarge++;
      if(EnableLogging && !isBacktest)
         Print("  ❌ REJECTED: Range too large (", DoubleToString(range, _Digits), " > ", 
               DoubleToString(ImpulseMaxATRMult * atrValue, _Digits), ")");
      PrintDetectionStats();
      return false;
   }
   
   // Validation 2: Body percentage
   if(bodyPercent < ImpulseBodyPercent)
   {
      rejectedBodySmall++;
      if(EnableLogging && !isBacktest)
         Print("  ❌ REJECTED: Body too small (", DoubleToString(bodyPercent, 2), "% < ", 
               DoubleToString(ImpulseBodyPercent, 2), "%)");
      PrintDetectionStats();
      return false;
   }
   
   // Validation 3: Spread
   if(currentSpread > MaxSpreadPoints)
   {
      rejectedSpread++;
      if(EnableLogging && !isBacktest)
         Print("  ❌ REJECTED: Spread too wide (", currentSpread, " > ", MaxSpreadPoints, ")");
      PrintDetectionStats();
      return false;
   }
   
   // Validation 4: Direction matches settings
   if(isBullish && !TradeBullish)
   {
      if(EnableLogging && !isBacktest)
         Print("  ❌ REJECTED: Bullish impulse but TradeBullish = false");
      return false;
   }
   
   if(isBearish && !TradeBearish)
   {
      if(EnableLogging && !isBacktest)
         Print("  ❌ REJECTED: Bearish impulse but TradeBearish = false");
      return false;
   }
   
   if(!isBullish && !isBearish)
   {
      if(EnableLogging && !isBacktest)
         Print("  ❌ REJECTED: Doji candle (no clear direction)");
      return false;
   }
   
   // All validations passed - impulse detected!
   data.impulseBarTime = time1;
   data.impulseHigh = high1;
   data.impulseLow = low1;
   data.impulseRange = range;
   data.impulseDirection = isBullish ? 1 : -1;
   
   if(EnableLogging)
   {
      Print("  ✅ IMPULSE CANDLE DETECTED [", data.symbol, "]!");
      Print("  Direction: ", (data.impulseDirection == 1 ? "BULLISH" : "BEARISH"));
      Print("  High: ", DoubleToString(data.impulseHigh, _Digits));
      Print("  Low: ", DoubleToString(data.impulseLow, _Digits));
      Print("  Range: ", DoubleToString(data.impulseRange, _Digits));
   }
   
   // Send notification
   string direction = (data.impulseDirection == 1 ? "BULLISH" : "BEARISH");
   SendNotificationAlert("🎯 Impulse Candle Detected [" + data.symbol + "] - " + direction + 
                        " | Range: " + DoubleToString(data.impulseRange, _Digits));
   
   // Draw visual marker
   if(EnableVisualMarkers)
      MarkImpulseCandle(symbolIndex);
   
   return true;
}

//+------------------------------------------------------------------+
//| Print impulse detection statistics                               |
//+------------------------------------------------------------------+
void PrintDetectionStats()
{
   // Print summary every 100 bars
   if(totalBarsScanned % 100 == 0 && EnableLogging && !isBacktest)
   {
      Print("=== IMPULSE DETECTION STATS (last 100 bars) ===");
      Print("Range too small: ", rejectedRangeSmall);
      Print("Range too large: ", rejectedRangeLarge);
      Print("Body too small: ", rejectedBodySmall);
      Print("Spread too wide: ", rejectedSpread);
      
      // Reset counters
      rejectedRangeSmall = 0;
      rejectedRangeLarge = 0;
      rejectedBodySmall = 0;
      rejectedSpread = 0;
   }
}

//+------------------------------------------------------------------+
//| Detect pullback into sweet spot                                 |
//+------------------------------------------------------------------+
bool DetectPullback(int symbolIndex)
{
   SymbolOBRData &data = symbolDataArray[symbolIndex];
   
   if(data.pullbackDetected)
      return true;
   
   // Calculate sweet spot zone (30-70% retracement into impulse)
   double sweetSpotHigh, sweetSpotLow;
   
   if(data.impulseDirection == 1)  // Bullish OB
   {
      sweetSpotHigh = data.impulseHigh - (data.impulseRange * PullbackMinRetrace);
      sweetSpotLow = data.impulseHigh - (data.impulseRange * PullbackMaxRetrace);
   }
   else  // Bearish OB
   {
      sweetSpotLow = data.impulseLow + (data.impulseRange * PullbackMinRetrace);
      sweetSpotHigh = data.impulseLow + (data.impulseRange * PullbackMaxRetrace);
   }
   
   // Scan recent bars for pullback into sweet spot
   int barsToCheck = PullbackMaxBars;
   
   for(int i = 1; i <= barsToCheck; i++)
   {
      double high_i = iHigh(data.symbol, PERIOD_M5, i);
      double low_i = iLow(data.symbol, PERIOD_M5, i);
      double close_i = iClose(data.symbol, PERIOD_M5, i);
      
      if(data.impulseDirection == 1)  // Bullish - look for dip into sweet spot then rejection up
      {
         // Check if price dipped into sweet spot and closed back above it
         if(low_i <= sweetSpotLow && close_i >= sweetSpotHigh)
         {
            data.pullbackDetected = true;
            data.pullbackBarIndex = i;
            data.pullbackPrice = close_i;
            data.pullbackBarTime = iTime(data.symbol, PERIOD_M5, i);
            
            if(EnableLogging)
            {
               Print("=== PULLBACK DETECTED [", data.symbol, "] ===");
               Print("  Direction: BULLISH");
               Print("  Sweet spot: ", DoubleToString(sweetSpotLow, _Digits), " - ", 
                     DoubleToString(sweetSpotHigh, _Digits));
               Print("  Pullback low: ", DoubleToString(low_i, _Digits));
               Print("  Rejection close: ", DoubleToString(close_i, _Digits));
               Print("  Bar index: ", i);
            }
            
            // Send notification
            SendNotificationAlert("📉 Pullback Detected [" + data.symbol + "] - BULLISH | Price: " + 
                                DoubleToString(close_i, _Digits));
            
            return true;
         }
      }
      else  // Bearish - look for rally into sweet spot then rejection down
      {
         // Check if price rallied into sweet spot and closed back below it
         if(high_i >= sweetSpotHigh && close_i <= sweetSpotLow)
         {
            data.pullbackDetected = true;
            data.pullbackBarIndex = i;
            data.pullbackPrice = close_i;
            data.pullbackBarTime = iTime(data.symbol, PERIOD_M5, i);
            
            if(EnableLogging)
            {
               Print("=== PULLBACK DETECTED [", data.symbol, "] ===");
               Print("  Direction: BEARISH");
               Print("  Sweet spot: ", DoubleToString(sweetSpotLow, _Digits), " - ", 
                     DoubleToString(sweetSpotHigh, _Digits));
               Print("  Pullback high: ", DoubleToString(high_i, _Digits));
               Print("  Rejection close: ", DoubleToString(close_i, _Digits));
               Print("  Bar index: ", i);
            }
            
            // Send notification
            SendNotificationAlert("📈 Pullback Detected [" + data.symbol + "] - BEARISH | Price: " + 
                                DoubleToString(close_i, _Digits));
            
            return true;
         }
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Check if pullback timeout exceeded                              |
//+------------------------------------------------------------------+
bool CheckPullbackTimeout(int symbolIndex)
{
   SymbolOBRData &data = symbolDataArray[symbolIndex];
   
   datetime currentTime = TimeCurrent();
   int barsSinceImpulse = Bars(data.symbol, PERIOD_M5, data.impulseBarTime, currentTime);
   
   if(barsSinceImpulse > PullbackMaxBars)
   {
      if(EnableLogging)
         Print("TIMEOUT [", data.symbol, "]: ", barsSinceImpulse, " bars since impulse (max: ", PullbackMaxBars, ")");
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Calculate trigger level for entry                               |
//+------------------------------------------------------------------+
void CalculateTriggerLevel(int symbolIndex)
{
   SymbolOBRData &data = symbolDataArray[symbolIndex];
   double point = SymbolInfoDouble(data.symbol, SYMBOL_POINT);
   
   if(data.impulseDirection == 1)  // Bullish OBR
   {
      // Trigger = break of pullback rejection high
      double rejectionHigh = iHigh(data.symbol, PERIOD_M5, data.pullbackBarIndex);
      data.triggerLevel = rejectionHigh + (TriggerBufferPoints * point);
      data.triggerType = ORDER_TYPE_BUY;
      
      if(EnableLogging)
         Print("🎯 TRIGGER BUY [", data.symbol, "]: Break of ", DoubleToString(rejectionHigh, _Digits), 
               " + buffer = ", DoubleToString(data.triggerLevel, _Digits));
   }
   else  // Bearish OBR
   {
      // Trigger = break of pullback rejection low
      double rejectionLow = iLow(data.symbol, PERIOD_M5, data.pullbackBarIndex);
      data.triggerLevel = rejectionLow - (TriggerBufferPoints * point);
      data.triggerType = ORDER_TYPE_SELL;
      
      if(EnableLogging)
         Print("🎯 TRIGGER SELL [", data.symbol, "]: Break of ", DoubleToString(rejectionLow, _Digits), 
               " - buffer = ", DoubleToString(data.triggerLevel, _Digits));
   }
}

//+------------------------------------------------------------------+
//| Check if trigger level hit                                      |
//+------------------------------------------------------------------+
bool CheckTrigger(int symbolIndex)
{
   SymbolOBRData &data = symbolDataArray[symbolIndex];
   
   double bid = SymbolInfoDouble(data.symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(data.symbol, SYMBOL_ASK);
   
   if(data.triggerType == ORDER_TYPE_BUY)
   {
      if(ask >= data.triggerLevel)
      {
         if(EnableLogging)
            Print("✅ TRIGGER HIT [", data.symbol, "]: Ask (", DoubleToString(ask, _Digits), 
                  ") >= Trigger (", DoubleToString(data.triggerLevel, _Digits), ")");
         
         // Send notification
         SendNotificationAlert("🚀 Trigger Hit [" + data.symbol + "] - BUY | Price: " + DoubleToString(ask, _Digits) + 
                             " | Trigger: " + DoubleToString(data.triggerLevel, _Digits));
         
         return true;
      }
   }
   else  // SELL
   {
      if(bid <= data.triggerLevel)
      {
         if(EnableLogging)
            Print("✅ TRIGGER HIT [", data.symbol, "]: Bid (", DoubleToString(bid, _Digits), 
                  ") <= Trigger (", DoubleToString(data.triggerLevel, _Digits), ")");
         
         // Send notification
         SendNotificationAlert("🚀 Trigger Hit [" + data.symbol + "] - SELL | Price: " + DoubleToString(bid, _Digits) + 
                             " | Trigger: " + DoubleToString(data.triggerLevel, _Digits));
         
         return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Check if trigger timeout exceeded                               |
//+------------------------------------------------------------------+
bool CheckTriggerTimeout(int symbolIndex)
{
   SymbolOBRData &data = symbolDataArray[symbolIndex];
   
   datetime currentTime = TimeCurrent();
   int barsSincePullback = Bars(data.symbol, PERIOD_M5, data.pullbackBarTime, currentTime);
   
   // Allow same timeout as pullback (generous)
   if(barsSincePullback > PullbackMaxBars)
   {
      if(EnableLogging)
         Print("TIMEOUT [", data.symbol, "]: ", barsSincePullback, " bars since pullback (max: ", PullbackMaxBars, ")");
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Execute trade                                                    |
//+------------------------------------------------------------------+
void ExecuteTrade(int symbolIndex)
{
   SymbolOBRData &data = symbolDataArray[symbolIndex];
   
   // Calculate position size based on risk
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = accountBalance * (RiskPercent / 100.0);
   
   // Calculate stop loss
   double stopLoss;
   if(data.triggerType == ORDER_TYPE_BUY)
      stopLoss = data.impulseLow;  // SL below impulse low
   else
      stopLoss = data.impulseHigh;  // SL above impulse high
   
   // Calculate take profit
   double point = SymbolInfoDouble(data.symbol, SYMBOL_POINT);
   double slDistance = MathAbs(data.triggerLevel - stopLoss);
   double tpDistance = slDistance * RewardRiskRatio;
   
   double takeProfit;
   if(data.triggerType == ORDER_TYPE_BUY)
      takeProfit = data.triggerLevel + tpDistance;
   else
      takeProfit = data.triggerLevel - tpDistance;
   
   // Calculate lot size
   double tickValue = SymbolInfoDouble(data.symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(data.symbol, SYMBOL_TRADE_TICK_SIZE);
   double slPoints = slDistance / point;
   
   // Validate values before calculation
   if(tickSize <= 0 || slPoints <= 0)
   {
      if(EnableLogging)
         Print("ERROR [", data.symbol, "]: Invalid tickSize (", tickSize, ") or slPoints (", slPoints, ")");
      return;
   }
   
   double lotSize = riskAmount / (slPoints * tickValue / tickSize);
   
   // Normalize lot size
   double minLot = SymbolInfoDouble(data.symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(data.symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(data.symbol, SYMBOL_VOLUME_STEP);
   lotSize = MathFloor(lotSize / lotStep) * lotStep;
   lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
   
   // Prepare trade request
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = data.symbol;
   request.volume = lotSize;
   request.type = data.triggerType;
   request.price = (data.triggerType == ORDER_TYPE_BUY) ? 
                   SymbolInfoDouble(data.symbol, SYMBOL_ASK) : 
                   SymbolInfoDouble(data.symbol, SYMBOL_BID);
   request.sl = stopLoss;
   request.tp = takeProfit;
   request.deviation = 10;
   request.magic = MagicNumber;
   request.comment = "OBR_" + (data.triggerType == ORDER_TYPE_BUY ? "BUY" : "SELL");
   
   // Send order
   if(OrderSend(request, result))
   {
      if(result.retcode == TRADE_RETCODE_DONE || result.retcode == TRADE_RETCODE_PLACED)
      {
         data.tradeExecutedToday = true;
         data.lastTradeDate = iTime(data.symbol, PERIOD_D1, 0);
         
         if(EnableLogging)
         {
            Print("========================================");
            Print("✅ TRADE EXECUTED [", data.symbol, "]!");
            Print("  Type: ", (data.triggerType == ORDER_TYPE_BUY ? "BUY" : "SELL"));
            Print("  Price: ", DoubleToString(request.price, _Digits));
            Print("  Lot size: ", DoubleToString(lotSize, 2));
            Print("  Stop loss: ", DoubleToString(stopLoss, _Digits));
            Print("  Take profit: ", DoubleToString(takeProfit, _Digits));
            Print("  Risk: $", DoubleToString(riskAmount, 2));
            Print("  R:R ratio: 1:", DoubleToString(RewardRiskRatio, 1));
            Print("========================================");
         }
         
         // Send success notification
         string tradeType = (data.triggerType == ORDER_TYPE_BUY ? "BUY" : "SELL");
         SendNotificationAlert("✅ TRADE EXECUTED [" + data.symbol + "] - " + tradeType + 
                             " | Price: " + DoubleToString(request.price, _Digits) + 
                             " | Lot: " + DoubleToString(lotSize, 2) + 
                             " | SL: " + DoubleToString(stopLoss, _Digits) + 
                             " | TP: " + DoubleToString(takeProfit, _Digits));
      }
      else
      {
         if(EnableLogging)
            Print("ERROR [", data.symbol, "]: Order failed - ", result.comment, " (", result.retcode, ")");
         
         // Send error notification
         SendNotificationAlert("❌ TRADE FAILED [" + data.symbol + "] - " + result.comment + " (Code: " + 
                             IntegerToString(result.retcode) + ")");
      }
   }
   else
   {
      if(EnableLogging)
         Print("ERROR [", data.symbol, "]: OrderSend failed - ", GetLastError());
      
      // Send error notification
      SendNotificationAlert("❌ ORDER SEND FAILED [" + data.symbol + "] - Error: " + IntegerToString(GetLastError()));
   }
}

//+------------------------------------------------------------------+
//| Mark impulse candle on chart                                    |
//+------------------------------------------------------------------+
void MarkImpulseCandle(int symbolIndex)
{
   SymbolOBRData &data = symbolDataArray[symbolIndex];
   string objName = "Impulse_" + data.symbol + "_" + TimeToString(data.impulseBarTime);
   
   // Delete if exists
   if(ObjectFind(0, objName) >= 0)
      ObjectDelete(0, objName);
   
   // Create rectangle
   ObjectCreate(0, objName, OBJ_RECTANGLE, 0, 
                data.impulseBarTime, data.impulseHigh,
                data.impulseBarTime + PeriodSeconds(PERIOD_M5), data.impulseLow);
   
   // Set properties
   ObjectSetInteger(0, objName, OBJPROP_COLOR, (data.impulseDirection == 1 ? clrLimeGreen : clrRed));
   ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, objName, OBJPROP_BACK, true);
   ObjectSetInteger(0, objName, OBJPROP_FILL, true);
   
   // Add text label
   string labelName = objName + "_Label";
   if(ObjectFind(0, labelName) >= 0)
      ObjectDelete(0, labelName);
   
   ObjectCreate(0, labelName, OBJ_TEXT, 0, data.impulseBarTime, data.impulseHigh);
   ObjectSetString(0, labelName, OBJPROP_TEXT, "OB " + (data.impulseDirection == 1 ? "↑" : "↓"));
   ObjectSetInteger(0, labelName, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 10);
   ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
}
//+------------------------------------------------------------------+

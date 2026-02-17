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

input group "=== Impulse Candle Settings ==="
input double ImpulseMinATRMult = 1.2;        // Min ATR multiplier (1.2 for M5 index trading)
input double ImpulseMaxATRMult = 4.0;        // Max ATR multiplier (increased from 3.0)
input double ImpulseBodyPercent = 50.0;      // Min body % (relaxed from 60%)
input int    MaxSpreadPoints = 1500;          // Max spread in points (1500 for indices like NDAQ)

input group "=== Pullback Settings ==="
input int    PullbackMaxBars = 24;           // Max bars for pullback (2 hours on M5)
input double PullbackMinRetrace = 0.40;      // Min retracement into impulse
input double PullbackMaxRetrace = 0.60;      // Max retracement (sweet spot zone)

input group "=== Trigger Settings ==="
input int    TriggerBufferPoints = 5;        // Trigger buffer in points

input group "=== Risk Management ==="
input double RiskPercent = 1.0;              // Risk per trade (%)
input double RewardRiskRatio = 2.0;          // Reward:Risk ratio
input int    MaxDailyTrades = 1;             // Max trades per day
input int    MagicNumber = 12345;            // Magic number for orders

input group "=== Indicator Settings ==="
input int    ATRPeriod = 14;                 // ATR period

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

//--- Global variables
ENUM_OBR_STATE obrState = WAITING_IMPULSE;
bool tradeExecutedToday = false;
datetime lastTradeDate = 0;

// Impulse candle tracking
datetime impulseBarTime = 0;
double impulseHigh = 0;
double impulseLow = 0;
double impulseRange = 0;
int impulseDirection = 0;  // 1 = bullish, -1 = bearish

// Pullback tracking
bool pullbackDetected = false;
int pullbackBarIndex = 0;
double pullbackPrice = 0;
datetime pullbackBarTime = 0;

// Trigger tracking
double triggerLevel = 0;
ENUM_ORDER_TYPE triggerType = ORDER_TYPE_BUY;

// ATR handle
int atrHandle = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Initialize ATR indicator
   atrHandle = iATR(_Symbol, PERIOD_M5, ATRPeriod);
   if(atrHandle == INVALID_HANDLE)
   {
      Print("ERROR: Failed to create ATR indicator");
      return INIT_FAILED;
   }
   
   Print("========================================");
   Print("EA_ImpulseZigZag initialized successfully");
   Print("Symbol: ", _Symbol);
   Print("Timeframe: M5");
   Print("Entry window: ", EntryHour, ":", (EntryMinute < 10 ? "0" : ""), EntryMinute, " - ", EndHour, ":00");
   Print("Session duration: ", (EndHour - EntryHour), " hours");
   Print("========================================");
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Release ATR handle
   if(atrHandle != INVALID_HANDLE)
      IndicatorRelease(atrHandle);
   
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
   // Check if new bar formed on M5
   static datetime lastBarTime = 0;
   datetime currentBarTime = iTime(_Symbol, PERIOD_M5, 0);
   
   if(currentBarTime == lastBarTime)
      return;  // Wait for new bar
   
   lastBarTime = currentBarTime;
   
   // Get current time
   MqlDateTime dt_now;
   TimeToStruct(TimeCurrent(), dt_now);
   
   // Reset daily trade flag at start of new day
   datetime currentDate = iTime(_Symbol, PERIOD_D1, 0);
   if(currentDate != lastTradeDate && lastTradeDate != 0)
   {
      tradeExecutedToday = false;
      obrState = WAITING_IMPULSE;
      if(EnableLogging)
         Print("=== NEW TRADING DAY: ", TimeToString(currentDate, TIME_DATE), " ===");
   }
   
   // Check if we're in entry window
   bool isEntryTime = (dt_now.hour >= EntryHour && dt_now.hour < EndHour);
   
   // Debug output
   static datetime lastDebugTime = 0;
   datetime currentMinute = iTime(_Symbol, PERIOD_M15, 0);
   if(EnableLogging && currentMinute != lastDebugTime)  // Log every 15 min
   {
      lastDebugTime = currentMinute;
      Print("DEBUG [", TimeToString(TimeCurrent()), "]");
      Print("  State: ", EnumToString(obrState));
      Print("  Entry window: ", (isEntryTime ? "OPEN" : "CLOSED"));
      Print("  Trade today: ", (tradeExecutedToday ? "YES" : "NO"));
      Print("  Position open: ", (PositionSelect(_Symbol) ? "YES" : "NO"));
   }
   
   // Skip if already traded today
   if(tradeExecutedToday)
      return;
   
   // Skip if position already open
   if(PositionSelect(_Symbol))
      return;
   
   // Skip if outside entry window
   if(!isEntryTime)
      return;
   
   // State machine
   switch(obrState)
   {
      case WAITING_IMPULSE:
         if(DetectImpulseCandle())
         {
            obrState = WAITING_PULLBACK;
            pullbackDetected = false;
            if(EnableLogging)
               Print(">>> STATE CHANGE: WAITING_IMPULSE -> WAITING_PULLBACK");
         }
         break;
         
      case WAITING_PULLBACK:
         if(DetectPullback())
         {
            obrState = WAITING_TRIGGER;
            CalculateTriggerLevel();
            if(EnableLogging)
               Print(">>> STATE CHANGE: WAITING_PULLBACK -> WAITING_TRIGGER");
         }
         else if(CheckPullbackTimeout())
         {
            obrState = WAITING_IMPULSE;
            if(EnableLogging)
               Print(">>> TIMEOUT: Pullback took too long, resetting to WAITING_IMPULSE");
         }
         break;
         
      case WAITING_TRIGGER:
         if(CheckTrigger())
         {
            ExecuteTrade();
            obrState = WAITING_IMPULSE;
         }
         else if(CheckTriggerTimeout())
         {
            obrState = WAITING_IMPULSE;
            if(EnableLogging)
               Print(">>> TIMEOUT: Trigger not hit, resetting to WAITING_IMPULSE");
         }
         break;
   }
}

//+------------------------------------------------------------------+
//| Detect impulse candle (Order Block)                             |
//+------------------------------------------------------------------+
bool DetectImpulseCandle()
{
   // Get ATR value
   double atr[];
   ArraySetAsSeries(atr, true);
   if(CopyBuffer(atrHandle, 0, 1, 1, atr) <= 0)
   {
      if(EnableLogging)
         Print("ERROR: Failed to copy ATR buffer");
      return false;
   }
   double atrValue = atr[0];
   
   // Get bar 1 data (completed bar)
   double high1 = iHigh(_Symbol, PERIOD_M5, 1);
   double low1 = iLow(_Symbol, PERIOD_M5, 1);
   double open1 = iOpen(_Symbol, PERIOD_M5, 1);
   double close1 = iClose(_Symbol, PERIOD_M5, 1);
   datetime time1 = iTime(_Symbol, PERIOD_M5, 1);
   
   double range = high1 - low1;
   double body = MathAbs(close1 - open1);
   double bodyPercent = (range > 0) ? (body / range * 100.0) : 0;
   
   // Get current spread
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int currentSpread = (int)((ask - bid) / point);
   
   // Determine direction
   bool isBullish = (close1 > open1);
   bool isBearish = (close1 < open1);
   
   if(EnableLogging)
   {
      Print("=== SCANNING FOR IMPULSE (Bar[1]: ", TimeToString(time1), ") ===");
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
      if(EnableLogging)
         Print("  ❌ REJECTED: Range too small (", DoubleToString(range, _Digits), " < ", 
               DoubleToString(ImpulseMinATRMult * atrValue, _Digits), ")");
      return false;
   }
   
   if(range > (ImpulseMaxATRMult * atrValue))
   {
      if(EnableLogging)
         Print("  ❌ REJECTED: Range too large (", DoubleToString(range, _Digits), " > ", 
               DoubleToString(ImpulseMaxATRMult * atrValue, _Digits), ")");
      return false;
   }
   
   // Validation 2: Body percentage
   if(bodyPercent < ImpulseBodyPercent)
   {
      if(EnableLogging)
         Print("  ❌ REJECTED: Body too small (", DoubleToString(bodyPercent, 2), "% < ", 
               DoubleToString(ImpulseBodyPercent, 2), "%)");
      return false;
   }
   
   // Validation 3: Spread
   if(currentSpread > MaxSpreadPoints)
   {
      if(EnableLogging)
         Print("  ❌ REJECTED: Spread too wide (", currentSpread, " > ", MaxSpreadPoints, ")");
      return false;
   }
   
   // Validation 4: Direction matches settings
   if(isBullish && !TradeBullish)
   {
      if(EnableLogging)
         Print("  ❌ REJECTED: Bullish impulse but TradeBullish = false");
      return false;
   }
   
   if(isBearish && !TradeBearish)
   {
      if(EnableLogging)
         Print("  ❌ REJECTED: Bearish impulse but TradeBearish = false");
      return false;
   }
   
   if(!isBullish && !isBearish)
   {
      if(EnableLogging)
         Print("  ❌ REJECTED: Doji candle (no clear direction)");
      return false;
   }
   
   // All validations passed - impulse detected!
   impulseBarTime = time1;
   impulseHigh = high1;
   impulseLow = low1;
   impulseRange = range;
   impulseDirection = isBullish ? 1 : -1;
   
   if(EnableLogging)
   {
      Print("  ✅ IMPULSE CANDLE DETECTED!");
      Print("  Direction: ", (impulseDirection == 1 ? "BULLISH" : "BEARISH"));
      Print("  High: ", DoubleToString(impulseHigh, _Digits));
      Print("  Low: ", DoubleToString(impulseLow, _Digits));
      Print("  Range: ", DoubleToString(impulseRange, _Digits));
   }
   
   // Draw visual marker
   if(EnableVisualMarkers)
      MarkImpulseCandle();
   
   return true;
}

//+------------------------------------------------------------------+
//| Detect pullback into sweet spot                                 |
//+------------------------------------------------------------------+
bool DetectPullback()
{
   if(pullbackDetected)
      return true;
   
   // Calculate sweet spot zone (40-60% retracement into impulse)
   double sweetSpotHigh, sweetSpotLow;
   
   if(impulseDirection == 1)  // Bullish OB
   {
      sweetSpotHigh = impulseHigh - (impulseRange * PullbackMinRetrace);
      sweetSpotLow = impulseHigh - (impulseRange * PullbackMaxRetrace);
   }
   else  // Bearish OB
   {
      sweetSpotLow = impulseLow + (impulseRange * PullbackMinRetrace);
      sweetSpotHigh = impulseLow + (impulseRange * PullbackMaxRetrace);
   }
   
   // Scan recent bars for pullback into sweet spot
   int barsToCheck = PullbackMaxBars;
   
   for(int i = 1; i <= barsToCheck; i++)
   {
      double high_i = iHigh(_Symbol, PERIOD_M5, i);
      double low_i = iLow(_Symbol, PERIOD_M5, i);
      double close_i = iClose(_Symbol, PERIOD_M5, i);
      
      if(impulseDirection == 1)  // Bullish - look for dip into sweet spot then rejection up
      {
         // Check if price dipped into sweet spot and closed back above it
         if(low_i <= sweetSpotLow && close_i >= sweetSpotHigh)
         {
            pullbackDetected = true;
            pullbackBarIndex = i;
            pullbackPrice = close_i;
            pullbackBarTime = iTime(_Symbol, PERIOD_M5, i);
            
            if(EnableLogging)
            {
               Print("=== PULLBACK DETECTED ===");
               Print("  Direction: BULLISH");
               Print("  Sweet spot: ", DoubleToString(sweetSpotLow, _Digits), " - ", 
                     DoubleToString(sweetSpotHigh, _Digits));
               Print("  Pullback low: ", DoubleToString(low_i, _Digits));
               Print("  Rejection close: ", DoubleToString(close_i, _Digits));
               Print("  Bar index: ", i);
            }
            
            return true;
         }
      }
      else  // Bearish - look for rally into sweet spot then rejection down
      {
         // Check if price rallied into sweet spot and closed back below it
         if(high_i >= sweetSpotHigh && close_i <= sweetSpotLow)
         {
            pullbackDetected = true;
            pullbackBarIndex = i;
            pullbackPrice = close_i;
            pullbackBarTime = iTime(_Symbol, PERIOD_M5, i);
            
            if(EnableLogging)
            {
               Print("=== PULLBACK DETECTED ===");
               Print("  Direction: BEARISH");
               Print("  Sweet spot: ", DoubleToString(sweetSpotLow, _Digits), " - ", 
                     DoubleToString(sweetSpotHigh, _Digits));
               Print("  Pullback high: ", DoubleToString(high_i, _Digits));
               Print("  Rejection close: ", DoubleToString(close_i, _Digits));
               Print("  Bar index: ", i);
            }
            
            return true;
         }
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Check if pullback timeout exceeded                              |
//+------------------------------------------------------------------+
bool CheckPullbackTimeout()
{
   datetime currentTime = TimeCurrent();
   int barsSinceImpulse = Bars(_Symbol, PERIOD_M5, impulseBarTime, currentTime);
   
   if(barsSinceImpulse > PullbackMaxBars)
   {
      if(EnableLogging)
         Print("TIMEOUT: ", barsSinceImpulse, " bars since impulse (max: ", PullbackMaxBars, ")");
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Calculate trigger level for entry                               |
//+------------------------------------------------------------------+
void CalculateTriggerLevel()
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   if(impulseDirection == 1)  // Bullish OBR
   {
      // Trigger = break of pullback rejection high
      double rejectionHigh = iHigh(_Symbol, PERIOD_M5, pullbackBarIndex);
      triggerLevel = rejectionHigh + (TriggerBufferPoints * point);
      triggerType = ORDER_TYPE_BUY;
      
      if(EnableLogging)
         Print("🎯 TRIGGER BUY: Break of ", DoubleToString(rejectionHigh, _Digits), 
               " + buffer = ", DoubleToString(triggerLevel, _Digits));
   }
   else  // Bearish OBR
   {
      // Trigger = break of pullback rejection low
      double rejectionLow = iLow(_Symbol, PERIOD_M5, pullbackBarIndex);
      triggerLevel = rejectionLow - (TriggerBufferPoints * point);
      triggerType = ORDER_TYPE_SELL;
      
      if(EnableLogging)
         Print("🎯 TRIGGER SELL: Break of ", DoubleToString(rejectionLow, _Digits), 
               " - buffer = ", DoubleToString(triggerLevel, _Digits));
   }
}

//+------------------------------------------------------------------+
//| Check if trigger level hit                                      |
//+------------------------------------------------------------------+
bool CheckTrigger()
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   if(triggerType == ORDER_TYPE_BUY)
   {
      if(ask >= triggerLevel)
      {
         if(EnableLogging)
            Print("✅ TRIGGER HIT: Ask (", DoubleToString(ask, _Digits), 
                  ") >= Trigger (", DoubleToString(triggerLevel, _Digits), ")");
         return true;
      }
   }
   else  // SELL
   {
      if(bid <= triggerLevel)
      {
         if(EnableLogging)
            Print("✅ TRIGGER HIT: Bid (", DoubleToString(bid, _Digits), 
                  ") <= Trigger (", DoubleToString(triggerLevel, _Digits), ")");
         return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Check if trigger timeout exceeded                               |
//+------------------------------------------------------------------+
bool CheckTriggerTimeout()
{
   datetime currentTime = TimeCurrent();
   int barsSincePullback = Bars(_Symbol, PERIOD_M5, pullbackBarTime, currentTime);
   
   // Allow same timeout as pullback (generous)
   if(barsSincePullback > PullbackMaxBars)
   {
      if(EnableLogging)
         Print("TIMEOUT: ", barsSincePullback, " bars since pullback (max: ", PullbackMaxBars, ")");
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Execute trade                                                    |
//+------------------------------------------------------------------+
void ExecuteTrade()
{
   // Calculate position size based on risk
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = accountBalance * (RiskPercent / 100.0);
   
   // Calculate stop loss
   double stopLoss;
   if(triggerType == ORDER_TYPE_BUY)
      stopLoss = impulseLow;  // SL below impulse low
   else
      stopLoss = impulseHigh;  // SL above impulse high
   
   // Calculate take profit
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double slDistance = MathAbs(triggerLevel - stopLoss);
   double tpDistance = slDistance * RewardRiskRatio;
   
   double takeProfit;
   if(triggerType == ORDER_TYPE_BUY)
      takeProfit = triggerLevel + tpDistance;
   else
      takeProfit = triggerLevel - tpDistance;
   
   // Calculate lot size
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double slPoints = slDistance / point;
   
   // Validate values before calculation
   if(tickSize <= 0 || slPoints <= 0)
   {
      if(EnableLogging)
         Print("ERROR: Invalid tickSize (", tickSize, ") or slPoints (", slPoints, ")");
      return;
   }
   
   double lotSize = riskAmount / (slPoints * tickValue / tickSize);
   
   // Normalize lot size
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   lotSize = MathFloor(lotSize / lotStep) * lotStep;
   lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
   
   // Prepare trade request
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = lotSize;
   request.type = triggerType;
   request.price = (triggerType == ORDER_TYPE_BUY) ? 
                   SymbolInfoDouble(_Symbol, SYMBOL_ASK) : 
                   SymbolInfoDouble(_Symbol, SYMBOL_BID);
   request.sl = stopLoss;
   request.tp = takeProfit;
   request.deviation = 10;
   request.magic = MagicNumber;
   request.comment = "OBR_" + (triggerType == ORDER_TYPE_BUY ? "BUY" : "SELL");
   
   // Send order
   if(OrderSend(request, result))
   {
      if(result.retcode == TRADE_RETCODE_DONE || result.retcode == TRADE_RETCODE_PLACED)
      {
         tradeExecutedToday = true;
         lastTradeDate = iTime(_Symbol, PERIOD_D1, 0);
         
         if(EnableLogging)
         {
            Print("========================================");
            Print("✅ TRADE EXECUTED!");
            Print("  Type: ", (triggerType == ORDER_TYPE_BUY ? "BUY" : "SELL"));
            Print("  Price: ", DoubleToString(request.price, _Digits));
            Print("  Lot size: ", DoubleToString(lotSize, 2));
            Print("  Stop loss: ", DoubleToString(stopLoss, _Digits));
            Print("  Take profit: ", DoubleToString(takeProfit, _Digits));
            Print("  Risk: $", DoubleToString(riskAmount, 2));
            Print("  R:R ratio: 1:", DoubleToString(RewardRiskRatio, 1));
            Print("========================================");
         }
      }
      else
      {
         if(EnableLogging)
            Print("ERROR: Order failed - ", result.comment, " (", result.retcode, ")");
      }
   }
   else
   {
      if(EnableLogging)
         Print("ERROR: OrderSend failed - ", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| Mark impulse candle on chart                                    |
//+------------------------------------------------------------------+
void MarkImpulseCandle()
{
   string objName = "Impulse_" + TimeToString(impulseBarTime);
   
   // Delete if exists
   if(ObjectFind(0, objName) >= 0)
      ObjectDelete(0, objName);
   
   // Create rectangle
   ObjectCreate(0, objName, OBJ_RECTANGLE, 0, 
                impulseBarTime, impulseHigh,
                impulseBarTime + PeriodSeconds(PERIOD_M5), impulseLow);
   
   // Set properties
   ObjectSetInteger(0, objName, OBJPROP_COLOR, (impulseDirection == 1 ? clrLimeGreen : clrRed));
   ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, objName, OBJPROP_BACK, true);
   ObjectSetInteger(0, objName, OBJPROP_FILL, true);
   
   // Add text label
   string labelName = objName + "_Label";
   if(ObjectFind(0, labelName) >= 0)
      ObjectDelete(0, labelName);
   
   ObjectCreate(0, labelName, OBJ_TEXT, 0, impulseBarTime, impulseHigh);
   ObjectSetString(0, labelName, OBJPROP_TEXT, "OB " + (impulseDirection == 1 ? "↑" : "↓"));
   ObjectSetInteger(0, labelName, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 10);
   ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
}
//+------------------------------------------------------------------+

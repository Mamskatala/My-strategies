//+------------------------------------------------------------------+
//|                                          EA_ImpulseZigZag.mq5    |
//|                        EA MT5 Pro - Impulse & ZigZag Structure   |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "EA MT5 Pro"
#property link      ""
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| ENUMERATIONS                                                     |
//+------------------------------------------------------------------+
enum ENUM_ARROW_MODE
{
   ARROW_CONTINUATION,  // Continuation mode
   ARROW_REVERSAL       // Reversal mode
};

enum ENUM_TRADE_DIRECTION
{
   BOTH,                // Both directions
   BUY_ONLY,            // Buy only
   SELL_ONLY            // Sell only
};

enum ENUM_SL_MODE
{
   SL_ON_IMPULSE_EXTREME,    // SL on impulse extreme
   SL_ON_PULLBACK_EXTREME    // SL on pullback extreme
};

enum ENUM_TP_MODE
{
   TP_RISK_REWARD,      // Risk/Reward ratio
   TP_FIXED_POINTS      // Fixed points
};

enum ENUM_ZIGZAG_STATE
{
   WAITING_IMPULSE,     // Waiting for impulse detection
   WAITING_PULLBACK1,   // Waiting for first pullback
   WAITING_PULLBACK2,   // Waiting for second pullback
   WAITING_TRIGGER      // Waiting for trigger
};

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                 |
//+------------------------------------------------------------------+
// Mode de Trading
input ENUM_ARROW_MODE ArrowMode = ARROW_CONTINUATION;     // Arrow Mode
input ENUM_TRADE_DIRECTION TradeDirection = BOTH;         // Trade Direction

// Horaire d'Entrée
input int EntryHour = 16;                                 // Entry Hour (server time)
input int EntryMinute = 30;                               // Entry Minute
input bool OneTradePerDay = true;                         // One Trade Per Day

// Détection Bougie Impulsive
input int    ImpulseLookbackBars = 20;                    // Impulse Lookback Bars
input double ImpulseMinATRMult = 1.8;                     // Min ATR Multiplier
input double ImpulseMaxATRMult = 3.0;                     // Max ATR Multiplier (news filter)
input int    ATRPeriod = 14;                              // ATR Period
input double ImpulseBodyPercent = 60.0;                   // Body Percent Minimum

// Structure ZigZag (Pullback)
input double PullbackMinRetrace = 0.35;                   // Pullback Min Retrace (35%)
input double PullbackMaxRetrace = 0.65;                   // Pullback Max Retrace (65%)
input int    PullbackMaxBars = 6;                         // Pullback Max Bars
input int    TriggerBufferPoints = 10;                    // Trigger Buffer Points

// Risk Management
input double RiskPercent = 1.0;                           // Risk Percent
input double FixedLot = 0.0;                              // Fixed Lot (0=auto)
input ENUM_SL_MODE SLMode = SL_ON_IMPULSE_EXTREME;        // Stop Loss Mode
input ENUM_TP_MODE TPMode = TP_RISK_REWARD;               // Take Profit Mode
input double RiskRewardRatio = 2.0;                       // Risk/Reward Ratio
input int    FixedTPPoints = 500;                         // Fixed TP Points

// Filtres de Sécurité
input int  MaxSpreadPoints = 30;                          // Max Spread Points
input bool UseVolatilityFilter = true;                    // Use Volatility Filter
input int  MagicNumber = 888999;                          // Magic Number

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                 |
//+------------------------------------------------------------------+
int handleATR = INVALID_HANDLE;
double atr[];

// Impulse detection variables
bool impulseDetected = false;
int impulseBarIndex = -1;
datetime impulseBarTime = 0;
double impulseHigh = 0.0;
double impulseLow = 0.0;
double impulseClose = 0.0;
double impulseOpen = 0.0;
double impulseRange = 0.0;
int impulseDirection = 0; // 1 = BULLISH, -1 = BEARISH

// Pullback variables
bool pullback1Detected = false;
bool pullback2Detected = false;
int pullback1BarIndex = -1;
int pullback2BarIndex = -1;
double pullback1High = 0.0;
double pullback1Low = 0.0;
double pullback2High = 0.0;
double pullback2Low = 0.0;

// State machine
ENUM_ZIGZAG_STATE zigzagState = WAITING_IMPULSE;

// Trade execution
bool tradeExecutedToday = false;
int lastTradedDate = 0;
double triggerLevel = 0.0;
int triggerType = 0; // ORDER_TYPE_BUY or ORDER_TYPE_SELL

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Verify M5 timeframe
   if(_Period != PERIOD_M5)
   {
      Print("ERROR: EA must be attached to M5 timeframe");
      return INIT_FAILED;
   }
   
   // Create ATR indicator handle
   handleATR = iATR(_Symbol, PERIOD_M5, ATRPeriod);
   if(handleATR == INVALID_HANDLE)
   {
      Print("ERROR: Failed to create ATR indicator handle");
      return INIT_FAILED;
   }
   
   // Set array as series
   ArraySetAsSeries(atr, true);
   
   // Initialize variables
   impulseDetected = false;
   impulseBarIndex = -1;
   zigzagState = WAITING_IMPULSE;
   tradeExecutedToday = false;
   lastTradedDate = 0;
   
   // Print configuration
   Print("════════════════════════════════════════");
   Print("EA IMPULSE ZIGZAG - INITIALIZED");
   Print("════════════════════════════════════════");
   Print("Symbol: ", _Symbol);
   Print("Timeframe: M5");
   Print("Arrow Mode: ", EnumToString(ArrowMode));
   Print("Trade Direction: ", EnumToString(TradeDirection));
   Print("Entry Time: ", IntegerToString(EntryHour), ":", IntegerToString(EntryMinute));
   Print("ATR Period: ", ATRPeriod);
   Print("Risk Percent: ", RiskPercent, "%");
   Print("Magic Number: ", MagicNumber);
   Print("════════════════════════════════════════");
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(handleATR != INVALID_HANDLE)
      IndicatorRelease(handleATR);
   
   Print("EA IMPULSE ZIGZAG - Deinitialized. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // === STEP 1: PRELIMINARY CHECKS ===
   
   // Check date for daily reset
   MqlDateTime dt_current;
   TimeToStruct(TimeCurrent(), dt_current);
   int date_actuelle = dt_current.year * 10000 + dt_current.mon * 100 + dt_current.day;
   
   if(date_actuelle != lastTradedDate)
   {
      tradeExecutedToday = false;
      impulseDetected = false;
      zigzagState = WAITING_IMPULSE;
      Print("New day - Trading status reset");
   }
   
   // Check if already traded today
   if(OneTradePerDay && tradeExecutedToday)
      return;
   
   // Check if position already open
   if(PositionSelect(_Symbol))
      return;
   
   // === STEP 2: CHECK ENTRY TIME ===
   MqlDateTime dt_now;
   TimeToStruct(TimeCurrent(), dt_now);
   bool isEntryTime = (dt_now.hour == EntryHour && dt_now.min == EntryMinute);
   
   // === STEP 3: STATE MACHINE ===
   switch(zigzagState)
   {
      case WAITING_IMPULSE:
         if(isEntryTime)
         {
            if(DetectImpulseCandle())
            {
               zigzagState = WAITING_PULLBACK1;
               Print("Impulse detected - Waiting for pullback");
            }
         }
         break;
      
      case WAITING_PULLBACK1:
         {
            int barsSinceImpulse = iBarShift(_Symbol, PERIOD_M5, impulseBarTime, false);
            
            if(barsSinceImpulse > PullbackMaxBars)
            {
               Print("Timeout pullback - Abandoning");
               ResetZigzagState();
               return;
            }
            
            if(DetectPullback1())
            {
               zigzagState = WAITING_PULLBACK2;
               Print("Pullback 1 detected - Waiting for pullback 2");
            }
         }
         break;
      
      case WAITING_PULLBACK2:
         {
            int barsSinceImpulse = iBarShift(_Symbol, PERIOD_M5, impulseBarTime, false);
            
            if(barsSinceImpulse > PullbackMaxBars)
            {
               Print("Timeout zigzag complete - Abandoning");
               ResetZigzagState();
               return;
            }
            
            if(DetectPullback2() && ZigZagValid())
            {
               zigzagState = WAITING_TRIGGER;
               CalculateTriggerLevel();
               Print("ZigZag complete - Waiting for trigger");
            }
         }
         break;
      
      case WAITING_TRIGGER:
         CheckTriggerAndExecute();
         break;
   }
}

//+------------------------------------------------------------------+
//| Detect Impulse Candle                                            |
//+------------------------------------------------------------------+
bool DetectImpulseCandle()
{
   // Get closed candle data (index 1)
   impulseOpen = iOpen(_Symbol, PERIOD_M5, 1);
   impulseHigh = iHigh(_Symbol, PERIOD_M5, 1);
   impulseLow = iLow(_Symbol, PERIOD_M5, 1);
   impulseClose = iClose(_Symbol, PERIOD_M5, 1);
   impulseBarTime = iTime(_Symbol, PERIOD_M5, 1);
   
   // Get ATR value
   if(CopyBuffer(handleATR, 0, 1, 1, atr) <= 0)
   {
      Print("ERROR: Failed to copy ATR buffer");
      return false;
   }
   double atrValue = atr[0];
   
   // Calculate candle metrics
   impulseRange = impulseHigh - impulseLow;
   double impulseBody = MathAbs(impulseClose - impulseOpen);
   double bodyPercent = (impulseRange > 0) ? (impulseBody / impulseRange) * 100.0 : 0.0;
   
   // === STRICT VALIDATION ===
   
   // Check range within ATR limits
   if(impulseRange < (ImpulseMinATRMult * atrValue))
   {
      Print("Range too small: ", impulseRange, " < min: ", ImpulseMinATRMult * atrValue);
      return false;
   }
   
   if(impulseRange > (ImpulseMaxATRMult * atrValue))
   {
      Print("Range excessive (news?): ", impulseRange, " > max: ", ImpulseMaxATRMult * atrValue);
      return false;
   }
   
   // Check body percentage
   if(bodyPercent < ImpulseBodyPercent)
   {
      Print("Body too weak: ", bodyPercent, "%");
      return false;
   }
   
   // Check spread
   long currentSpread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(currentSpread > MaxSpreadPoints)
   {
      Print("Spread too high: ", currentSpread);
      return false;
   }
   
   // Determine impulse direction
   if(impulseClose > impulseOpen)
      impulseDirection = 1; // BULLISH
   else
      impulseDirection = -1; // BEARISH
   
   // Check trade direction compatibility
   if(TradeDirection == BUY_ONLY && impulseDirection == -1)
   {
      Print("Bearish impulse but BUY_ONLY configured");
      return false;
   }
   
   if(TradeDirection == SELL_ONLY && impulseDirection == 1)
   {
      Print("Bullish impulse but SELL_ONLY configured");
      return false;
   }
   
   // All validations passed
   impulseDetected = true;
   impulseBarIndex = 1;
   
   Print("=== IMPULSE CANDLE DETECTED ===");
   Print("Direction: ", (impulseDirection == 1 ? "BULLISH" : "BEARISH"));
   Print("Range: ", impulseRange, " Points");
   Print("Body: ", bodyPercent, "%");
   Print("ATR: ", atrValue);
   
   return true;
}

//+------------------------------------------------------------------+
//| Detect Pullback 1                                                |
//+------------------------------------------------------------------+
bool DetectPullback1()
{
   int currentBar = 0; // Current bar index is 0
   int barsSinceImpulse = currentBar + impulseBarIndex;
   
   if(barsSinceImpulse < 1)
      return false; // Too early
   
   if(impulseDirection == -1) // BEARISH impulse - looking for bullish pullback
   {
      // Calculate retracement levels
      double retraceMin = impulseLow + (impulseRange * PullbackMinRetrace);
      double retraceMax = impulseLow + (impulseRange * PullbackMaxRetrace);
      
      // Scan bars for Higher High
      pullback1High = 0.0;
      pullback1BarIndex = -1;
      
      for(int i = 2; i <= (impulseBarIndex + barsSinceImpulse); i++)
      {
         double currentHigh = iHigh(_Symbol, PERIOD_M5, i);
         
         if(currentHigh >= retraceMin && currentHigh <= retraceMax)
         {
            if(currentHigh > pullback1High)
            {
               pullback1High = currentHigh;
               pullback1Low = iLow(_Symbol, PERIOD_M5, i);
               pullback1BarIndex = i;
            }
         }
      }
      
      if(pullback1High > 0)
      {
         pullback1Detected = true;
         Print("Pullback 1 detected at: ", pullback1High, " bar: ", pullback1BarIndex);
         return true;
      }
   }
   else if(impulseDirection == 1) // BULLISH impulse - looking for bearish pullback
   {
      // Calculate retracement levels
      double retraceMax = impulseHigh - (impulseRange * PullbackMinRetrace);
      double retraceMin = impulseHigh - (impulseRange * PullbackMaxRetrace);
      
      // Scan for Lower Low
      pullback1Low = 999999.0;
      pullback1BarIndex = -1;
      
      for(int i = 2; i <= (impulseBarIndex + barsSinceImpulse); i++)
      {
         double currentLow = iLow(_Symbol, PERIOD_M5, i);
         
         if(currentLow >= retraceMin && currentLow <= retraceMax)
         {
            if(currentLow < pullback1Low)
            {
               pullback1Low = currentLow;
               pullback1High = iHigh(_Symbol, PERIOD_M5, i);
               pullback1BarIndex = i;
            }
         }
      }
      
      if(pullback1Low < 999999.0)
      {
         pullback1Detected = true;
         Print("Pullback 1 detected at: ", pullback1Low);
         return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Detect Pullback 2                                                |
//+------------------------------------------------------------------+
bool DetectPullback2()
{
   if(!pullback1Detected)
      return false;
   
   if(impulseDirection == -1) // BEARISH - looking for 2nd bullish pullback
   {
      pullback2High = 0.0;
      pullback2BarIndex = -1;
      
      for(int i = 2; i <= pullback1BarIndex - 1; i++)
      {
         double currentHigh = iHigh(_Symbol, PERIOD_M5, i);
         double currentLow = iLow(_Symbol, PERIOD_M5, i);
         
         if(i < pullback1BarIndex - 1)
         {
            double previousLow = iLow(_Symbol, PERIOD_M5, i + 1);
            
            if(currentHigh < pullback1High && currentHigh > pullback2High)
            {
               if(currentLow < previousLow) // Confirmation of rejection
               {
                  pullback2High = currentHigh;
                  pullback2Low = currentLow;
                  pullback2BarIndex = i;
               }
            }
         }
      }
      
      if(pullback2High > 0)
      {
         pullback2Detected = true;
         Print("Pullback 2 detected at: ", pullback2High, " (lower than PB1: ", pullback1High, ")");
         return true;
      }
   }
   else if(impulseDirection == 1) // BULLISH - looking for 2nd bearish pullback
   {
      pullback2Low = 999999.0;
      pullback2BarIndex = -1;
      
      for(int i = 2; i <= pullback1BarIndex - 1; i++)
      {
         double currentLow = iLow(_Symbol, PERIOD_M5, i);
         double currentHigh = iHigh(_Symbol, PERIOD_M5, i);
         
         if(i < pullback1BarIndex - 1)
         {
            double previousHigh = iHigh(_Symbol, PERIOD_M5, i + 1);
            
            if(currentLow > pullback1Low && currentLow < pullback2Low)
            {
               if(currentHigh > previousHigh) // Confirmation of rejection
               {
                  pullback2Low = currentLow;
                  pullback2High = currentHigh;
                  pullback2BarIndex = i;
               }
            }
         }
      }
      
      if(pullback2Low < 999999.0)
      {
         pullback2Detected = true;
         Print("Pullback 2 detected at: ", pullback2Low, " (higher than PB1: ", pullback1Low, ")");
         return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Validate ZigZag Structure                                        |
//+------------------------------------------------------------------+
bool ZigZagValid()
{
   if(impulseDirection == -1) // BEARISH
   {
      // Check decreasing order of highs
      if(pullback2High >= pullback1High)
      {
         Print("Invalid ZigZag: PB2 >= PB1");
         return false;
      }
      
      // Check for clear rejection between PB1 and PB2
      double lowBetween = 999999.0;
      for(int i = pullback2BarIndex; i <= pullback1BarIndex; i++)
      {
         lowBetween = MathMin(lowBetween, iLow(_Symbol, PERIOD_M5, i));
      }
      
      if(lowBetween >= pullback1Low)
      {
         Print("No clear rejection between PB1 and PB2");
         return false;
      }
      
      Print("=== BEARISH ZIGZAG VALID ===");
      Print("Impulse Low: ", impulseLow);
      Print("Pullback1 High: ", pullback1High);
      Print("Rejection Low: ", lowBetween);
      Print("Pullback2 High: ", pullback2High, " (< PB1)");
   }
   else if(impulseDirection == 1) // BULLISH
   {
      // Check increasing order of lows
      if(pullback2Low <= pullback1Low)
      {
         Print("Invalid ZigZag: PB2 <= PB1");
         return false;
      }
      
      // Check for rejection
      double highBetween = 0.0;
      for(int i = pullback2BarIndex; i <= pullback1BarIndex; i++)
      {
         highBetween = MathMax(highBetween, iHigh(_Symbol, PERIOD_M5, i));
      }
      
      if(highBetween <= pullback1High)
      {
         Print("No clear rejection between PB1 and PB2");
         return false;
      }
      
      Print("=== BULLISH ZIGZAG VALID ===");
      Print("Impulse High: ", impulseHigh);
      Print("Pullback1 Low: ", pullback1Low);
      Print("Rejection High: ", highBetween);
      Print("Pullback2 Low: ", pullback2Low, " (> PB1)");
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Calculate Trigger Level                                          |
//+------------------------------------------------------------------+
void CalculateTriggerLevel()
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   if(ArrowMode == ARROW_CONTINUATION)
   {
      if(impulseDirection == -1) // BEARISH
      {
         // Trigger = break of lowest low between PB1 and PB2
         double lowBetween = 999999.0;
         for(int i = pullback2BarIndex; i <= pullback1BarIndex; i++)
         {
            lowBetween = MathMin(lowBetween, iLow(_Symbol, PERIOD_M5, i));
         }
         
         triggerLevel = lowBetween - (TriggerBufferPoints * point);
         triggerType = ORDER_TYPE_SELL;
         Print("Trigger SELL at: ", triggerLevel);
      }
      else if(impulseDirection == 1) // BULLISH
      {
         // Trigger = break of highest high between PB1 and PB2
         double highBetween = 0.0;
         for(int i = pullback2BarIndex; i <= pullback1BarIndex; i++)
         {
            highBetween = MathMax(highBetween, iHigh(_Symbol, PERIOD_M5, i));
         }
         
         triggerLevel = highBetween + (TriggerBufferPoints * point);
         triggerType = ORDER_TYPE_BUY;
         Print("Trigger BUY at: ", triggerLevel);
      }
   }
   else if(ArrowMode == ARROW_REVERSAL)
   {
      if(impulseDirection == -1) // BEARISH
      {
         // Wait for reclaim + break of impulse high
         double impulseMid = impulseLow + (impulseRange / 2.0);
         triggerLevel = impulseHigh + (TriggerBufferPoints * point);
         triggerType = ORDER_TYPE_BUY;
         Print("Trigger REVERSAL BUY at: ", triggerLevel, " (after reclaim mid: ", impulseMid, ")");
      }
      else if(impulseDirection == 1) // BULLISH
      {
         // Wait for inverse reclaim + break of low
         double impulseMid = impulseHigh - (impulseRange / 2.0);
         triggerLevel = impulseLow - (TriggerBufferPoints * point);
         triggerType = ORDER_TYPE_SELL;
         Print("Trigger REVERSAL SELL at: ", triggerLevel, " (after reclaim mid: ", impulseMid, ")");
      }
   }
}

//+------------------------------------------------------------------+
//| Check Trigger and Execute                                        |
//+------------------------------------------------------------------+
void CheckTriggerAndExecute()
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   // Check timeout
   int barsSinceImpulse = iBarShift(_Symbol, PERIOD_M5, impulseBarTime, false);
   if(barsSinceImpulse > PullbackMaxBars + 3)
   {
      Print("Timeout trigger - Abandoning");
      ResetZigzagState();
      return;
   }
   
   if(ArrowMode == ARROW_CONTINUATION)
   {
      if(triggerType == ORDER_TYPE_BUY)
      {
         if(ask >= triggerLevel)
         {
            Print("🟢 BUY TRIGGER ACTIVATED!");
            ExecuteTrade(ORDER_TYPE_BUY);
         }
      }
      else if(triggerType == ORDER_TYPE_SELL)
      {
         if(bid <= triggerLevel)
         {
            Print("🔴 SELL TRIGGER ACTIVATED!");
            ExecuteTrade(ORDER_TYPE_SELL);
         }
      }
   }
   else if(ArrowMode == ARROW_REVERSAL)
   {
      if(triggerType == ORDER_TYPE_BUY)
      {
         double impulseMid = impulseLow + ((impulseHigh - impulseLow) / 2.0);
         
         if(bid > impulseMid && ask >= triggerLevel)
         {
            Print("🟢 REVERSAL BUY TRIGGER ACTIVATED!");
            ExecuteTrade(ORDER_TYPE_BUY);
         }
      }
      else if(triggerType == ORDER_TYPE_SELL)
      {
         double impulseMid = impulseHigh - ((impulseHigh - impulseLow) / 2.0);
         
         if(ask < impulseMid && bid <= triggerLevel)
         {
            Print("🔴 REVERSAL SELL TRIGGER ACTIVATED!");
            ExecuteTrade(ORDER_TYPE_SELL);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Execute Trade                                                    |
//+------------------------------------------------------------------+
bool ExecuteTrade(ENUM_ORDER_TYPE orderType)
{
   // Final spread check
   long currentSpread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(currentSpread > MaxSpreadPoints)
   {
      Print("Spread too high at trigger moment");
      return false;
   }
   
   // Get entry price
   double entryPrice;
   if(orderType == ORDER_TYPE_BUY)
      entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   else
      entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Calculate Stop Loss
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double stopLoss;
   
   if(SLMode == SL_ON_IMPULSE_EXTREME)
   {
      if(orderType == ORDER_TYPE_BUY)
         stopLoss = impulseLow - (TriggerBufferPoints * point);
      else
         stopLoss = impulseHigh + (TriggerBufferPoints * point);
   }
   else // SL_ON_PULLBACK_EXTREME
   {
      if(orderType == ORDER_TYPE_BUY)
         stopLoss = MathMin(pullback1Low, pullback2Low) - (TriggerBufferPoints * point);
      else
         stopLoss = MathMax(pullback1High, pullback2High) + (TriggerBufferPoints * point);
   }
   
   stopLoss = NormalizeDouble(stopLoss, digits);
   double slDistance = MathAbs(entryPrice - stopLoss);
   
   // Calculate Take Profit
   double takeProfit;
   double tpDistance;
   
   if(TPMode == TP_RISK_REWARD)
   {
      tpDistance = slDistance * RiskRewardRatio;
      
      if(orderType == ORDER_TYPE_BUY)
         takeProfit = entryPrice + tpDistance;
      else
         takeProfit = entryPrice - tpDistance;
   }
   else // TP_FIXED_POINTS
   {
      tpDistance = FixedTPPoints * point;
      
      if(orderType == ORDER_TYPE_BUY)
         takeProfit = entryPrice + tpDistance;
      else
         takeProfit = entryPrice - tpDistance;
   }
   
   takeProfit = NormalizeDouble(takeProfit, digits);
   
   // Calculate lot size
   double lotSize;
   
   if(FixedLot > 0)
   {
      lotSize = FixedLot;
   }
   else
   {
      double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      double riskAmount = accountBalance * (RiskPercent / 100.0);
      
      double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      
      lotSize = (riskAmount * tickSize) / (slDistance * tickValue);
   }
   
   // Normalize lot
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   lotSize = MathMax(lotSize, minLot);
   lotSize = MathMin(lotSize, maxLot);
   lotSize = MathFloor(lotSize / lotStep) * lotStep;
   
   // Check stops level
   long stopsLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double stopsLevelPrice = stopsLevel * point;
   
   if(MathAbs(entryPrice - stopLoss) < stopsLevelPrice)
   {
      Print("SL too close (stops level): ", stopsLevelPrice);
      return false;
   }
   
   if(MathAbs(entryPrice - takeProfit) < stopsLevelPrice)
   {
      Print("TP too close (stops level): ", stopsLevelPrice);
      return false;
   }
   
   // Prepare request
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = lotSize;
   request.type = orderType;
   request.price = entryPrice;
   request.sl = stopLoss;
   request.tp = takeProfit;
   request.deviation = 10;
   request.magic = MagicNumber;
   request.comment = "ImpulseZigZag_" + EnumToString(ArrowMode);
   request.type_filling = ORDER_FILLING_FOK;
   
   // Send order
   bool success = OrderSend(request, result);
   
   if(!success)
   {
      request.type_filling = ORDER_FILLING_IOC;
      success = OrderSend(request, result);
   }
   
   if(!success)
   {
      request.type_filling = ORDER_FILLING_RETURN;
      success = OrderSend(request, result);
   }
   
   // Check result
   if(success && (result.retcode == TRADE_RETCODE_DONE || result.retcode == TRADE_RETCODE_PLACED))
   {
      Print("════════════════════════════════════════");
      Print("✅ TRADE EXECUTED!");
      Print("════════════════════════════════════════");
      Print("Type: ", (orderType == ORDER_TYPE_BUY ? "BUY" : "SELL"));
      Print("Ticket: ", result.order);
      Print("Price: ", entryPrice);
      Print("Lot: ", lotSize);
      Print("SL: ", stopLoss, " (", slDistance / point, " points)");
      Print("TP: ", takeProfit, " (", tpDistance / point, " points)");
      Print("R:R: 1:", NormalizeDouble(tpDistance / slDistance, 2));
      Print("════════════════════════════════════════");
      
      MqlDateTime dt_current;
      TimeToStruct(TimeCurrent(), dt_current);
      int date_actuelle = dt_current.year * 10000 + dt_current.mon * 100 + dt_current.day;
      
      tradeExecutedToday = true;
      lastTradedDate = date_actuelle;
      ResetZigzagState();
      
      return true;
   }
   else
   {
      Print("❌ EXECUTION ERROR");
      Print("Retcode: ", result.retcode);
      Print("Comment: ", result.comment);
      return false;
   }
}

//+------------------------------------------------------------------+
//| Reset ZigZag State                                               |
//+------------------------------------------------------------------+
void ResetZigzagState()
{
   impulseDetected = false;
   pullback1Detected = false;
   pullback2Detected = false;
   zigzagState = WAITING_IMPULSE;
   impulseBarIndex = -1;
   pullback1High = 0.0;
   pullback1Low = 0.0;
   pullback2High = 0.0;
   pullback2Low = 0.0;
   triggerLevel = 0.0;
   Print("ZigZag state reset");
}
//+------------------------------------------------------------------+

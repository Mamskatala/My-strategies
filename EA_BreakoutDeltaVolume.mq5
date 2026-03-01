//+------------------------------------------------------------------+
//|                                      EA_BreakoutDeltaVolume.mq5 |
//|                        Breakout EA with Delta Volume Confirmation |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Breakout EA with Delta Volume"
#property link      ""
#property version   "1.00"

//--- Input parameters
input group "=== Breakout Settings ==="
input int      BOoption = 1;              // Breakout Option (1=Fixed Point, 2=Volatility)
input double   FixedPoint = 1.6;          // Fixed Point Range (for option 1)
input int      VolPeriod = 20;            // Volatility Period (for option 2)
input double   BreakoutFactor = 1.0;      // Breakout Factor (for option 2)

input group "=== Trading Rules ==="
input bool     HoldOvernight = false;     // Hold Positions Overnight
input bool     PrecedeByInsideDay = false;// Require Inside Day Before Trading
input double   LotSize = 0.1;             // Lot Size
input int      MagicNumber = 123456;      // Magic Number
input int      Slippage = 10;             // Slippage in points

input group "=== Delta Volume Filter ==="
input bool     UseDeltaFilter = true;     // Use Delta Volume Filter
input int      DeltaResetPeriod = 1;      // Delta Reset (0=never, 1=daily, 2=weekly)
input double   MinDeltaThreshold = 0;     // Minimum Delta for Entry (0=disabled)

input group "=== Time Settings ==="
input int      SessionEndHour = 17;       // Session End Hour (for EOD exit)
input int      SessionEndMinute = 0;      // Session End Minute

//--- Global variables
int      handleDelta;
double   deltaBuffer[];
double   cumulativeDeltaBuffer[];
datetime currentDate;
datetime previousDate;
double   todayOpen;
double   todayHigh;
double   todayLow;
double   yesterdayHigh;
double   yesterdayLow;
double   dayBeforeYesterdayHigh;
double   dayBeforeYesterdayLow;
bool     isInsideDay;
double   breakoutLevel;
bool     longOrderPlaced;
bool     shortOrderPlaced;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Create Delta Volume indicator handle
   if(UseDeltaFilter)
   {
      handleDelta = iCustom(_Symbol, _Period, "DeltaVolume", DeltaResetPeriod);
      if(handleDelta == INVALID_HANDLE)
      {
         Print("Error creating Delta Volume indicator");
         return(INIT_FAILED);
      }
   }
   
   //--- Initialize arrays
   ArraySetAsSeries(deltaBuffer, true);
   ArraySetAsSeries(cumulativeDeltaBuffer, true);
   
   //--- Initialize variables
   currentDate = 0;
   previousDate = 0;
   todayOpen = 0;
   todayHigh = 0;
   todayLow = 0;
   yesterdayHigh = 0;
   yesterdayLow = 0;
   dayBeforeYesterdayHigh = 0;
   dayBeforeYesterdayLow = 0;
   isInsideDay = false;
   longOrderPlaced = false;
   shortOrderPlaced = false;
   
   Print("EA initialized successfully");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- Release indicator handle
   if(handleDelta != INVALID_HANDLE)
      IndicatorRelease(handleDelta);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Check if new bar
   static datetime lastBarTime = 0;
   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   
   //--- Get current date
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   currentDate = StringToTime(IntegerToString(dt.year) + "." + 
                              IntegerToString(dt.mon) + "." + 
                              IntegerToString(dt.day));
   
   //--- Check for new day
   if(currentDate != previousDate && previousDate != 0)
   {
      OnNewDay();
   }
   
   //--- Initialize on first run
   if(previousDate == 0)
   {
      previousDate = currentDate;
      InitializeDayData();
   }
   
   //--- Update today's high and low
   double currentHigh = iHigh(_Symbol, _Period, 0);
   double currentLow = iLow(_Symbol, _Period, 0);
   if(currentHigh > todayHigh) todayHigh = currentHigh;
   if(currentLow < todayLow || todayLow == 0) todayLow = currentLow;
   
   //--- Check trading conditions
   if(currentBarTime != lastBarTime)
   {
      lastBarTime = currentBarTime;
      
      //--- Check for end of day exit
      if(!HoldOvernight)
      {
         CheckEndOfDayExit();
      }
      
      //--- Check for breakout entries
      CheckBreakoutEntry();
   }
}

//+------------------------------------------------------------------+
//| New day event handler                                            |
//+------------------------------------------------------------------+
void OnNewDay()
{
   //--- Update historical data
   dayBeforeYesterdayHigh = yesterdayHigh;
   dayBeforeYesterdayLow = yesterdayLow;
   yesterdayHigh = todayHigh;
   yesterdayLow = todayLow;
   
   //--- Check for inside day
   if(yesterdayHigh < dayBeforeYesterdayHigh && yesterdayLow > dayBeforeYesterdayLow)
      isInsideDay = true;
   else
      isInsideDay = false;
   
   //--- Reset order flags
   longOrderPlaced = false;
   shortOrderPlaced = false;
   
   //--- Initialize today's data
   InitializeDayData();
   
   //--- Close positions if not holding overnight
   if(!HoldOvernight && PositionsTotal() > 0)
   {
      CloseAllPositions("New Day - Not Holding Overnight");
   }
   
   //--- Update previous date
   previousDate = currentDate;
   
   Print("New day detected. Inside day: ", isInsideDay);
}

//+------------------------------------------------------------------+
//| Initialize day data                                              |
//+------------------------------------------------------------------+
void InitializeDayData()
{
   todayOpen = iOpen(_Symbol, _Period, 0);
   todayHigh = iHigh(_Symbol, _Period, 0);
   todayLow = iLow(_Symbol, _Period, 0);
   
   //--- Calculate breakout level
   if(BOoption == 1)
   {
      // Fixed point breakout
      breakoutLevel = FixedPoint * _Point;
   }
   else
   {
      // Volatility-based breakout
      double atr = CalculateATR(VolPeriod);
      breakoutLevel = atr * BreakoutFactor;
   }
   
   Print("Day initialized. Open: ", todayOpen, " Breakout Level: ", breakoutLevel);
}

//+------------------------------------------------------------------+
//| Calculate Average True Range                                     |
//+------------------------------------------------------------------+
double CalculateATR(int period)
{
   double atr = 0;
   int handle = iATR(_Symbol, _Period, period);
   
   if(handle != INVALID_HANDLE)
   {
      double atrBuffer[];
      ArraySetAsSeries(atrBuffer, true);
      if(CopyBuffer(handle, 0, 0, 1, atrBuffer) > 0)
      {
         atr = atrBuffer[0];
      }
      IndicatorRelease(handle);
   }
   
   return atr;
}

//+------------------------------------------------------------------+
//| Check breakout entry conditions                                  |
//+------------------------------------------------------------------+
void CheckBreakoutEntry()
{
   //--- Check if inside day filter is required
   if(PrecedeByInsideDay && !isInsideDay)
      return;
   
   //--- Get current price
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   //--- Get Delta Volume data if filter is enabled
   bool deltaBullish = true;
   bool deltaBearish = true;
   
   if(UseDeltaFilter)
   {
      if(!GetDeltaData())
         return;
      
      //--- Check delta direction
      deltaBullish = (cumulativeDeltaBuffer[0] > MinDeltaThreshold);
      deltaBearish = (cumulativeDeltaBuffer[0] < -MinDeltaThreshold);
      
      //--- Additional confirmation: recent delta should align with direction
      if(deltaBuffer[0] < 0) deltaBullish = false;
      if(deltaBuffer[0] > 0) deltaBearish = false;
   }
   
   //--- Calculate breakout levels
   double longEntryLevel = todayOpen + breakoutLevel;
   double shortEntryLevel = todayOpen - breakoutLevel;
   
   //--- Check for long entry
   if(!longOrderPlaced && deltaBullish)
   {
      if(currentPrice >= longEntryLevel)
      {
         int currentPosition = GetPositionType();
         
         if(currentPosition <= 0) // No position or short position
         {
            if(currentPosition == -1) // Close short first
               CloseAllPositions("Reverse to Long");
            
            if(OpenBuyOrder())
            {
               longOrderPlaced = true;
               Print("Long entry at ", ask, " (Breakout level: ", longEntryLevel, ")");
            }
         }
      }
   }
   
   //--- Check for short entry
   if(!shortOrderPlaced && deltaBearish)
   {
      if(currentPrice <= shortEntryLevel)
      {
         int currentPosition = GetPositionType();
         
         if(currentPosition >= 0) // No position or long position
         {
            if(currentPosition == 1) // Close long first
               CloseAllPositions("Reverse to Short");
            
            if(OpenSellOrder())
            {
               shortOrderPlaced = true;
               Print("Short entry at ", currentPrice, " (Breakout level: ", shortEntryLevel, ")");
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Get Delta Volume data                                            |
//+------------------------------------------------------------------+
bool GetDeltaData()
{
   if(handleDelta == INVALID_HANDLE)
      return false;
   
   //--- Copy delta buffers
   if(CopyBuffer(handleDelta, 0, 0, 3, deltaBuffer) < 3)
      return false;
   if(CopyBuffer(handleDelta, 1, 0, 3, cumulativeDeltaBuffer) < 3)
      return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| Get current position type                                        |
//+------------------------------------------------------------------+
int GetPositionType()
{
   // Returns: 1 = long, -1 = short, 0 = no position
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol)
      {
         if(PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         {
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
               return 1;
            else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
               return -1;
         }
      }
   }
   return 0;
}

//+------------------------------------------------------------------+
//| Open buy order                                                   |
//+------------------------------------------------------------------+
bool OpenBuyOrder()
{
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = LotSize;
   request.type = ORDER_TYPE_BUY;
   request.price = NormalizeDouble(ask, digits);
   request.deviation = Slippage;
   request.magic = MagicNumber;
   request.comment = "BOup";
   
   if(OrderSend(request, result))
   {
      if(result.retcode == TRADE_RETCODE_DONE || result.retcode == TRADE_RETCODE_PLACED)
      {
         Print("Buy order successful. Price: ", result.price);
         return true;
      }
   }
   
   Print("Buy order failed. Error: ", result.retcode);
   return false;
}

//+------------------------------------------------------------------+
//| Open sell order                                                  |
//+------------------------------------------------------------------+
bool OpenSellOrder()
{
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = LotSize;
   request.type = ORDER_TYPE_SELL;
   request.price = NormalizeDouble(bid, digits);
   request.deviation = Slippage;
   request.magic = MagicNumber;
   request.comment = "BOdown";
   
   if(OrderSend(request, result))
   {
      if(result.retcode == TRADE_RETCODE_DONE || result.retcode == TRADE_RETCODE_PLACED)
      {
         Print("Sell order successful. Price: ", result.price);
         return true;
      }
   }
   
   Print("Sell order failed. Error: ", result.retcode);
   return false;
}

//+------------------------------------------------------------------+
//| Check end of day exit                                            |
//+------------------------------------------------------------------+
void CheckEndOfDayExit()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   
   //--- Check if it's time to exit
   int currentTimeMinutes = dt.hour * 60 + dt.min;
   int exitTimeMinutes = SessionEndHour * 60 + SessionEndMinute;
   
   if(currentTimeMinutes >= exitTimeMinutes)
   {
      CloseAllPositions("End of Day Exit");
   }
}

//+------------------------------------------------------------------+
//| Close all positions                                              |
//+------------------------------------------------------------------+
void CloseAllPositions(string reason)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol)
      {
         if(PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         {
            ulong ticket = PositionGetInteger(POSITION_TICKET);
            MqlTradeRequest request = {};
            MqlTradeResult result = {};
            
            request.action = TRADE_ACTION_DEAL;
            request.position = ticket;
            request.symbol = _Symbol;
            request.volume = PositionGetDouble(POSITION_VOLUME);
            request.deviation = Slippage;
            request.magic = MagicNumber;
            request.comment = reason;
            
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
            {
               request.type = ORDER_TYPE_SELL;
               request.price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            }
            else
            {
               request.type = ORDER_TYPE_BUY;
               request.price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            }
            
            if(OrderSend(request, result))
            {
               Print("Position closed. Reason: ", reason);
            }
            else
            {
               Print("Failed to close position. Error: ", result.retcode);
            }
         }
      }
   }
}
//+------------------------------------------------------------------+

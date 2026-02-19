//+------------------------------------------------------------------+
//|                                           TradeExecution.mqh     |
//|                        Shared Trade Execution Utilities          |
//+------------------------------------------------------------------+
#ifndef TRADE_EXECUTION_MQH
#define TRADE_EXECUTION_MQH

//+------------------------------------------------------------------+
//| Trade Execution Helper Class                                     |
//+------------------------------------------------------------------+
class CTradeExecutor
{
private:
   int m_magicNumber;
   int m_slippage;
   bool m_enableLogging;
   string m_symbol;

public:
   CTradeExecutor() : m_magicNumber(0), m_slippage(10), m_enableLogging(true), m_symbol("") {}

   void Init(int magic, int slippage, bool logging)
   {
      m_magicNumber = magic;
      m_slippage = slippage;
      m_enableLogging = logging;
   }

   //--- Overloaded Init for EA_VolumeDeltaBreakout compatibility
   bool Init(string symbol, int magicNumber, int slippage)
   {
      if(symbol == "" || magicNumber < 0 || slippage < 0)
         return false;
      m_symbol = symbol;
      m_magicNumber = magicNumber;
      m_slippage = slippage;
      m_enableLogging = true;
      return true;
   }

   //--- Calculate lot size based on risk
   double CalculateLotSize(string symbol, double riskPercent, double entryPrice, double stopLoss)
   {
      double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      double riskAmount = accountBalance * (riskPercent / 100.0);

      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      double slDistance = MathAbs(entryPrice - stopLoss);
      double slPoints = slDistance / point;

      if(tickSize <= 0 || slPoints <= 0 || tickValue <= 0)
      {
         if(m_enableLogging)
            Print("ERROR [", symbol, "]: Invalid tickSize (", tickSize, ") or slPoints (", slPoints, ") or tickValue (", tickValue, ")");
         return 0;
      }

      double lotSize = riskAmount / (slPoints * tickValue / tickSize);

      // Normalize lot size
      double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
      double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
      double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

      if(lotStep <= 0) lotStep = 0.01;
      lotSize = MathFloor(lotSize / lotStep) * lotStep;
      lotSize = MathMax(minLot, MathMin(maxLot, lotSize));

      return lotSize;
   }

   //--- Execute a market order
   bool ExecuteOrder(string symbol, ENUM_ORDER_TYPE orderType, double lotSize,
                     double stopLoss, double takeProfit, string comment)
   {
      if(lotSize <= 0)
      {
         if(m_enableLogging)
            Print("ERROR [", symbol, "]: Invalid lot size: ", lotSize);
         return false;
      }

      MqlTradeRequest request = {};
      MqlTradeResult result = {};

      request.action = TRADE_ACTION_DEAL;
      request.symbol = symbol;
      request.volume = lotSize;
      request.type = orderType;
      request.price = (orderType == ORDER_TYPE_BUY) ?
                      SymbolInfoDouble(symbol, SYMBOL_ASK) :
                      SymbolInfoDouble(symbol, SYMBOL_BID);
      request.sl = stopLoss;
      request.tp = takeProfit;
      request.deviation = m_slippage;
      request.magic = m_magicNumber;
      request.comment = comment;

      if(OrderSend(request, result))
      {
         if(result.retcode == TRADE_RETCODE_DONE || result.retcode == TRADE_RETCODE_PLACED)
         {
            if(m_enableLogging)
            {
               Print("========================================");
               Print("✅ TRADE EXECUTED [", symbol, "]!");
               Print("  Type: ", (orderType == ORDER_TYPE_BUY ? "BUY" : "SELL"));
               Print("  Price: ", DoubleToString(request.price, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)));
               Print("  Lot size: ", DoubleToString(lotSize, 2));
               Print("  Stop loss: ", DoubleToString(stopLoss, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)));
               Print("  Take profit: ", DoubleToString(takeProfit, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)));
               Print("========================================");
            }
            return true;
         }
         else
         {
            if(m_enableLogging)
               Print("ERROR [", symbol, "]: Order failed - ", result.comment, " (", result.retcode, ")");
         }
      }
      else
      {
         if(m_enableLogging)
            Print("ERROR [", symbol, "]: OrderSend failed - ", GetLastError());
      }

      return false;
   }

   //--- Count open positions for a symbol with this magic number
   int CountOpenPositions(string symbol)
   {
      int count = 0;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(PositionGetSymbol(i) == symbol)
         {
            if(PositionGetInteger(POSITION_MAGIC) == m_magicNumber)
               count++;
         }
      }
      return count;
   }

   int GetMagicNumber() const { return m_magicNumber; }

private:
   string GetActiveSymbol() const { return (m_symbol != "") ? m_symbol : _Symbol; }

public:
   //--- Execute buy order (returns ticket or -1 on failure)
   int ExecuteBuy(double lots, double stopLoss, double takeProfit)
   {
      string symbol = GetActiveSymbol();

      MqlTradeRequest request = {};
      MqlTradeResult result = {};

      request.action = TRADE_ACTION_DEAL;
      request.symbol = symbol;
      request.volume = lots;
      request.type = ORDER_TYPE_BUY;
      request.price = SymbolInfoDouble(symbol, SYMBOL_ASK);
      request.sl = NormalizeDouble(stopLoss, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
      request.tp = NormalizeDouble(takeProfit, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
      request.deviation = m_slippage;
      request.magic = m_magicNumber;
      request.comment = "VolumeBreakout BUY";

      if(OrderSend(request, result))
      {
         if(result.retcode == TRADE_RETCODE_DONE || result.retcode == TRADE_RETCODE_PLACED)
         {
            if(m_enableLogging)
               Print("BUY order executed successfully. Ticket: ", result.order);
            return (int)result.order;
         }
      }

      if(m_enableLogging)
         Print("Failed to execute BUY order. Error: ", GetLastError(),
               ", Return code: ", result.retcode);
      return -1;
   }

   //--- Execute sell order (returns ticket or -1 on failure)
   int ExecuteSell(double lots, double stopLoss, double takeProfit)
   {
      string symbol = GetActiveSymbol();

      MqlTradeRequest request = {};
      MqlTradeResult result = {};

      request.action = TRADE_ACTION_DEAL;
      request.symbol = symbol;
      request.volume = lots;
      request.type = ORDER_TYPE_SELL;
      request.price = SymbolInfoDouble(symbol, SYMBOL_BID);
      request.sl = NormalizeDouble(stopLoss, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
      request.tp = NormalizeDouble(takeProfit, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
      request.deviation = m_slippage;
      request.magic = m_magicNumber;
      request.comment = "VolumeBreakout SELL";

      if(OrderSend(request, result))
      {
         if(result.retcode == TRADE_RETCODE_DONE || result.retcode == TRADE_RETCODE_PLACED)
         {
            if(m_enableLogging)
               Print("SELL order executed successfully. Ticket: ", result.order);
            return (int)result.order;
         }
      }

      if(m_enableLogging)
         Print("Failed to execute SELL order. Error: ", GetLastError(),
               ", Return code: ", result.retcode);
      return -1;
   }
};

#endif

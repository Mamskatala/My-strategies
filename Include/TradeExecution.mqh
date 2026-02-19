//+------------------------------------------------------------------+
//|                                             TradeExecution.mqh |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| Trade Executor Class                                             |
//+------------------------------------------------------------------+
class CTradeExecutor
{
private:
   CTrade m_trade;
   string m_symbol;
   int m_magicNumber;
   int m_slippage;
   ENUM_ORDER_TYPE_FILLING m_fillingMode;
   
   //--- execution statistics
   int m_totalOrders;
   int m_successfulOrders;
   int m_failedOrders;
   datetime m_lastOrderTime;
   
public:
   //--- Constructor
   CTradeExecutor()
   {
      m_symbol = "";
      m_magicNumber = 0;
      m_slippage = 3;
      m_fillingMode = ORDER_FILLING_FOK;
      m_totalOrders = 0;
      m_successfulOrders = 0;
      m_failedOrders = 0;
      m_lastOrderTime = 0;
   }
   
   //--- Destructor
   ~CTradeExecutor()
   {
   }
   
   //--- Initialize trade executor
   bool Init(string symbol, int magicNumber, int slippage)
   {
      m_symbol = symbol;
      m_magicNumber = magicNumber;
      m_slippage = slippage;
      
      //--- set up CTrade object
      m_trade.SetExpertMagicNumber(m_magicNumber);
      m_trade.SetDeviationInPoints(m_slippage);
      m_trade.SetTypeFilling(m_fillingMode);
      m_trade.SetAsyncMode(false);
      
      //--- determine best filling mode for this symbol
      m_fillingMode = GetBestFillingMode();
      m_trade.SetTypeFilling(m_fillingMode);
      
      return true;
   }
   
   //--- Get best filling mode for symbol
   ENUM_ORDER_TYPE_FILLING GetBestFillingMode()
   {
      int filling = (int)SymbolInfoInteger(m_symbol, SYMBOL_FILLING_MODE);
      
      if((filling & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK)
         return ORDER_FILLING_FOK;
      else if((filling & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC)
         return ORDER_FILLING_IOC;
      else
         return ORDER_FILLING_RETURN;
   }
   
   //--- Execute buy order
   int ExecuteBuy(double lots, double stopLoss, double takeProfit)
   {
      m_totalOrders++;
      
      //--- get current ask price
      double price = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
      
      //--- normalize prices
      int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
      price = NormalizeDouble(price, digits);
      stopLoss = NormalizeDouble(stopLoss, digits);
      takeProfit = NormalizeDouble(takeProfit, digits);
      
      //--- validate parameters
      if(lots <= 0)
      {
         Print("Invalid lot size for BUY order: ", lots);
         m_failedOrders++;
         return -1;
      }
      
      //--- execute buy order
      bool result = m_trade.Buy(lots, m_symbol, price, stopLoss, takeProfit, 
                                "VolumeBreakout BUY");
      
      if(result)
      {
         m_successfulOrders++;
         m_lastOrderTime = TimeCurrent();
         
         int ticket = (int)m_trade.ResultOrder();
         Print("BUY order executed successfully. Ticket: ", ticket);
         return ticket;
      }
      else
      {
         m_failedOrders++;
         Print("Failed to execute BUY order. Error: ", GetLastError(), 
               ", Return code: ", m_trade.ResultRetcode());
         return -1;
      }
   }
   
   //--- Execute sell order
   int ExecuteSell(double lots, double stopLoss, double takeProfit)
   {
      m_totalOrders++;
      
      //--- get current bid price
      double price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      
      //--- normalize prices
      int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
      price = NormalizeDouble(price, digits);
      stopLoss = NormalizeDouble(stopLoss, digits);
      takeProfit = NormalizeDouble(takeProfit, digits);
      
      //--- validate parameters
      if(lots <= 0)
      {
         Print("Invalid lot size for SELL order: ", lots);
         m_failedOrders++;
         return -1;
      }
      
      //--- execute sell order
      bool result = m_trade.Sell(lots, m_symbol, price, stopLoss, takeProfit, 
                                 "VolumeBreakout SELL");
      
      if(result)
      {
         m_successfulOrders++;
         m_lastOrderTime = TimeCurrent();
         
         int ticket = (int)m_trade.ResultOrder();
         Print("SELL order executed successfully. Ticket: ", ticket);
         return ticket;
      }
      else
      {
         m_failedOrders++;
         Print("Failed to execute SELL order. Error: ", GetLastError(), 
               ", Return code: ", m_trade.ResultRetcode());
         return -1;
      }
   }
   
   //--- Close position by ticket
   bool ClosePosition(int ticket)
   {
      if(!PositionSelectByTicket(ticket))
      {
         Print("Position not found: ", ticket);
         return false;
      }
      
      bool result = m_trade.PositionClose(ticket);
      
      if(result)
      {
         Print("Position closed successfully. Ticket: ", ticket);
         return true;
      }
      else
      {
         Print("Failed to close position. Ticket: ", ticket, 
               ", Error: ", GetLastError());
         return false;
      }
   }
   
   //--- Modify position
   bool ModifyPosition(int ticket, double newStopLoss, double newTakeProfit)
   {
      if(!PositionSelectByTicket(ticket))
      {
         Print("Position not found: ", ticket);
         return false;
      }
      
      //--- normalize prices
      int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
      newStopLoss = NormalizeDouble(newStopLoss, digits);
      newTakeProfit = NormalizeDouble(newTakeProfit, digits);
      
      bool result = m_trade.PositionModify(ticket, newStopLoss, newTakeProfit);
      
      if(result)
      {
         Print("Position modified successfully. Ticket: ", ticket);
         return true;
      }
      else
      {
         Print("Failed to modify position. Ticket: ", ticket, 
               ", Error: ", GetLastError());
         return false;
      }
   }
   
   //--- Get execution statistics
   void GetStatistics(int &total, int &successful, int &failed, double &successRate)
   {
      total = m_totalOrders;
      successful = m_successfulOrders;
      failed = m_failedOrders;
      
      if(total > 0)
         successRate = (successful * 100.0) / total;
      else
         successRate = 0;
   }
   
   //--- Set slippage
   void SetSlippage(int slippage)
   {
      m_slippage = slippage;
      m_trade.SetDeviationInPoints(m_slippage);
   }
   
   //--- Get last order time
   datetime GetLastOrderTime() const
   {
      return m_lastOrderTime;
   }
};
//+------------------------------------------------------------------+

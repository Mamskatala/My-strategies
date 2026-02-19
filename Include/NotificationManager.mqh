//+------------------------------------------------------------------+
//|                                          NotificationManager.mqh |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Notification Manager Class                                       |
//+------------------------------------------------------------------+
class CNotificationManager
{
private:
   string m_symbol;
   int m_magicNumber;
   bool m_enabled;
   datetime m_lastNotificationTime;
   int m_notificationInterval;  // seconds between notifications
   
public:
   //--- Constructor
   CNotificationManager()
   {
      m_symbol = "";
      m_magicNumber = 0;
      m_enabled = false;
      m_lastNotificationTime = 0;
      m_notificationInterval = 60;  // default 1 minute
   }
   
   //--- Destructor
   ~CNotificationManager()
   {
   }
   
   //--- Initialize notification manager
   bool Init(string symbol, int magicNumber, bool enabled)
   {
      m_symbol = symbol;
      m_magicNumber = magicNumber;
      m_enabled = enabled;
      m_lastNotificationTime = 0;
      
      return true;
   }
   
   //--- Enable/disable notifications
   void SetEnabled(bool enabled)
   {
      m_enabled = enabled;
   }
   
   //--- Check if notifications are enabled
   bool IsEnabled() const
   {
      return m_enabled;
   }
   
   //--- Set notification interval
   void SetNotificationInterval(int seconds)
   {
      m_notificationInterval = seconds;
   }
   
   //--- Send notification
   bool SendNotification(string message)
   {
      if(!m_enabled)
         return false;
      
      //--- check notification interval
      datetime currentTime = TimeCurrent();
      if(currentTime - m_lastNotificationTime < m_notificationInterval)
         return false;
      
      //--- prepare message
      string fullMessage = StringFormat("[%s][Magic:%d] %s", m_symbol, m_magicNumber, message);
      
      //--- send to terminal
      Print(fullMessage);
      
      //--- send push notification if enabled
      if(TerminalInfoInteger(TERMINAL_NOTIFICATIONS_ENABLED))
      {
         SendNotification(fullMessage);
      }
      
      //--- send email if configured
      if(TerminalInfoInteger(TERMINAL_EMAIL_ENABLED))
      {
         string subject = StringFormat("MT5 Alert: %s", m_symbol);
         SendMail(subject, fullMessage);
      }
      
      m_lastNotificationTime = currentTime;
      return true;
   }
   
   //--- Send trade notification
   bool SendTradeNotification(string action, int ticket, double lots, double price, 
                              double sl, double tp)
   {
      if(!m_enabled)
         return false;
      
      string message = StringFormat("%s: Ticket=%d, Lots=%.2f, Price=%.5f, SL=%.5f, TP=%.5f",
                                    action, ticket, lots, price, sl, tp);
      
      return SendNotification(message);
   }
   
   //--- Send alert notification
   bool SendAlert(string alertMessage)
   {
      if(!m_enabled)
         return false;
      
      string fullMessage = StringFormat("[ALERT][%s] %s", m_symbol, alertMessage);
      
      Alert(fullMessage);
      Print(fullMessage);
      
      return true;
   }
   
   //--- Send error notification
   bool SendError(string errorMessage)
   {
      if(!m_enabled)
         return false;
      
      string fullMessage = StringFormat("[ERROR][%s] %s", m_symbol, errorMessage);
      
      Print(fullMessage);
      
      return SendNotification(fullMessage);
   }
   
   //--- Send warning notification
   bool SendWarning(string warningMessage)
   {
      if(!m_enabled)
         return false;
      
      string fullMessage = StringFormat("[WARNING][%s] %s", m_symbol, warningMessage);
      
      Print(fullMessage);
      
      return true;
   }
   
   //--- Send performance report
   bool SendPerformanceReport(int totalTrades, int winningTrades, int losingTrades,
                             double totalProfit, double totalLoss, double winRate)
   {
      if(!m_enabled)
         return false;
      
      string message = StringFormat("Performance Report: Trades=%d, Wins=%d, Losses=%d, Profit=%.2f, Loss=%.2f, Win Rate=%.1f%%",
                                    totalTrades, winningTrades, losingTrades, 
                                    totalProfit, totalLoss, winRate);
      
      return SendNotification(message);
   }
};
//+------------------------------------------------------------------+

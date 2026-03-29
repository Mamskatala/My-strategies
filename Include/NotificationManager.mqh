//+------------------------------------------------------------------+
//|                                        NotificationManager.mqh   |
//|                        Shared Notification/Alert Manager         |
//+------------------------------------------------------------------+
#ifndef NOTIFICATION_MANAGER_MQH
#define NOTIFICATION_MANAGER_MQH

//+------------------------------------------------------------------+
//| Notification Manager Class                                       |
//+------------------------------------------------------------------+
class CNotificationManager
{
private:
   bool m_enableAlerts;
   bool m_enablePush;
   bool m_enableEmail;
   string m_eaName;

public:
   CNotificationManager() : m_enableAlerts(true), m_enablePush(false), m_enableEmail(false), m_eaName("EA") {}

   void Init(string eaName, bool alerts, bool push, bool email)
   {
      m_eaName = eaName;
      m_enableAlerts = alerts;
      m_enablePush = push;
      m_enableEmail = email;
   }

   //--- Overloaded Init for EA_VolumeDeltaBreakout compatibility
   bool Init(string symbol, int magicNumber, bool enabled)
   {
      m_eaName = symbol + "_" + IntegerToString(magicNumber);
      m_enableAlerts = enabled;
      m_enablePush = false;
      m_enableEmail = enabled;
      return true;
   }

   void Send(string symbol, string message)
   {
      string fullMessage = "[" + symbol + "] " + message;

      if(m_enableAlerts)
         Alert(fullMessage);

      if(m_enablePush)
         ::SendNotification(fullMessage);

      if(m_enableEmail)
         SendMail(m_eaName + " Alert - " + symbol, fullMessage);
   }

   //--- SendNotification wrapper (sends via alerts/email based on config)
   bool SendNotification(string message)
   {
      string fullMessage = "[" + m_eaName + "] " + message;

      if(m_enableAlerts)
      {
         Print(fullMessage);
         Alert(fullMessage);
      }

      if(m_enablePush)
         ::SendNotification(fullMessage);

      if(m_enableEmail && TerminalInfoInteger(TERMINAL_EMAIL_ENABLED))
         SendMail(m_eaName + " Alert", fullMessage);

      return true;
   }
};

#endif

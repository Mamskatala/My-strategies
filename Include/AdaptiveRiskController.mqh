//+------------------------------------------------------------------+
//|                                      AdaptiveRiskController.mqh |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Adaptive Risk Controller Class                                   |
//+------------------------------------------------------------------+
class CAdaptiveRiskController
{
private:
   double m_maxRiskPercent;
   bool m_adaptiveEnabled;
   string m_symbol;
   
   //--- risk parameters
   double m_currentRiskPercent;
   double m_minRiskPercent;
   double m_riskMultiplier;
   
   //--- performance tracking
   int m_consecutiveWins;
   int m_consecutiveLosses;
   int m_totalTrades;
   double m_winRate;
   
   //--- drawdown tracking
   double m_maxDrawdown;
   double m_currentDrawdown;
   double m_peakBalance;
   
public:
   //--- Constructor
   CAdaptiveRiskController()
   {
      m_maxRiskPercent = 2.0;
      m_adaptiveEnabled = false;
      m_currentRiskPercent = 1.0;
      m_minRiskPercent = 0.5;
      m_riskMultiplier = 1.0;
      m_consecutiveWins = 0;
      m_consecutiveLosses = 0;
      m_totalTrades = 0;
      m_winRate = 0;
      m_maxDrawdown = 0;
      m_currentDrawdown = 0;
      m_peakBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   }
   
   //--- Destructor
   ~CAdaptiveRiskController()
   {
   }
   
   //--- Initialize risk controller
   bool Init(double maxRiskPercent, bool adaptiveEnabled)
   {
      m_maxRiskPercent = maxRiskPercent;
      m_adaptiveEnabled = adaptiveEnabled;
      m_currentRiskPercent = maxRiskPercent / 2.0;  // start conservative
      m_minRiskPercent = maxRiskPercent / 4.0;
      m_riskMultiplier = 1.0;
      
      m_symbol = _Symbol;
      m_peakBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      
      return true;
   }
   
   //--- Calculate lot size based on risk
   double CalculateLotSize(double riskAmount, double stopLossPoints)
   {
      if(stopLossPoints <= 0)
         return 0;
      
      //--- get symbol info
      double tickValue = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      
      //--- validate symbol info
      if(tickValue <= 0 || tickSize <= 0 || point <= 0)
      {
         Print("Invalid symbol information: tickValue=", tickValue, ", tickSize=", tickSize, ", point=", point);
         return 0;
      }
      
      //--- calculate lot size
      double pointValue = tickValue * (point / tickSize);
      
      //--- protect against division by zero
      if(pointValue <= 0)
      {
         Print("Invalid point value: ", pointValue);
         return 0;
      }
      
      double lots = riskAmount / (stopLossPoints * pointValue);
      
      //--- normalize to lot step
      double minLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
      double maxLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);
      double lotStep = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);
      
      lots = MathMax(minLot, MathMin(maxLot, MathFloor(lots / lotStep) * lotStep));
      
      return lots;
   }
   
   //--- Update after trade result
   void UpdateAfterTrade(bool isWin, double profit)
   {
      m_totalTrades++;
      
      if(isWin)
      {
         m_consecutiveWins++;
         m_consecutiveLosses = 0;
         
         //--- increase risk after consecutive wins (if adaptive)
         if(m_adaptiveEnabled && m_consecutiveWins >= 3)
         {
            m_currentRiskPercent = MathMin(m_maxRiskPercent, 
                                          m_currentRiskPercent * 1.1);
         }
      }
      else
      {
         m_consecutiveLosses++;
         m_consecutiveWins = 0;
         
         //--- decrease risk after consecutive losses (if adaptive)
         if(m_adaptiveEnabled && m_consecutiveLosses >= 2)
         {
            m_currentRiskPercent = MathMax(m_minRiskPercent, 
                                          m_currentRiskPercent * 0.8);
         }
      }
      
      //--- update drawdown
      UpdateDrawdown();
      
      //--- adjust risk based on drawdown
      if(m_adaptiveEnabled)
      {
         AdjustRiskForDrawdown();
      }
   }
   
   //--- Update drawdown calculation
   void UpdateDrawdown()
   {
      double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      
      //--- update peak balance
      if(currentBalance > m_peakBalance)
      {
         m_peakBalance = currentBalance;
         m_currentDrawdown = 0;
      }
      else
      {
         //--- calculate current drawdown
         if(m_peakBalance > 0)
            m_currentDrawdown = ((m_peakBalance - currentBalance) / m_peakBalance) * 100.0;
         else
            m_currentDrawdown = 0;
         
         //--- update max drawdown
         if(m_currentDrawdown > m_maxDrawdown)
            m_maxDrawdown = m_currentDrawdown;
      }
   }
   
   //--- Adjust risk based on drawdown
   void AdjustRiskForDrawdown()
   {
      //--- reduce risk if drawdown is high
      if(m_currentDrawdown > 15.0)
      {
         m_currentRiskPercent = m_minRiskPercent;
      }
      else if(m_currentDrawdown > 10.0)
      {
         m_currentRiskPercent = MathMax(m_minRiskPercent, 
                                       m_maxRiskPercent * 0.5);
      }
      else if(m_currentDrawdown > 5.0)
      {
         m_currentRiskPercent = MathMax(m_minRiskPercent, 
                                       m_maxRiskPercent * 0.75);
      }
   }
   
   //--- Get current risk percent
   double GetCurrentRiskPercent() const
   {
      return m_currentRiskPercent;
   }
   
   //--- Set max risk percent
   void SetMaxRiskPercent(double maxRisk)
   {
      m_maxRiskPercent = maxRisk;
      if(m_currentRiskPercent > maxRisk)
         m_currentRiskPercent = maxRisk;
   }
   
   //--- Enable/disable adaptive risk
   void SetAdaptiveEnabled(bool enabled)
   {
      m_adaptiveEnabled = enabled;
      
      if(!enabled)
         m_currentRiskPercent = m_maxRiskPercent;
   }
   
   //--- Get drawdown info
   void GetDrawdownInfo(double &current, double &maximum) const
   {
      current = m_currentDrawdown;
      maximum = m_maxDrawdown;
   }
   
   //--- Get performance info
   void GetPerformanceInfo(int &wins, int &losses, double &winRate) const
   {
      wins = m_consecutiveWins;
      losses = m_consecutiveLosses;
      
      if(m_totalTrades > 0)
         winRate = m_winRate;
      else
         winRate = 0;
   }
   
   //--- Check if should trade based on risk limits
   bool ShouldTrade() const
   {
      //--- don't trade if drawdown is too high
      if(m_currentDrawdown > 20.0)
         return false;
      
      //--- don't trade after too many consecutive losses
      if(m_consecutiveLosses >= 5)
         return false;
      
      return true;
   }
   
   //--- Reset risk controller
   void Reset()
   {
      m_currentRiskPercent = m_maxRiskPercent / 2.0;
      m_consecutiveWins = 0;
      m_consecutiveLosses = 0;
      m_peakBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      m_currentDrawdown = 0;
   }
};
//+------------------------------------------------------------------+

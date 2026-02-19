//+------------------------------------------------------------------+
//|                                     AdaptiveRiskController.mqh   |
//|              Regime Monitor + Adaptive Risk Controller           |
//+------------------------------------------------------------------+
#ifndef ADAPTIVE_RISK_CONTROLLER_MQH
#define ADAPTIVE_RISK_CONTROLLER_MQH

//--- Risk regime enumeration
enum ENUM_RISK_REGIME
{
   REGIME_NORMAL,       // Normal - favorable conditions
   REGIME_CAUTION,      // Caution - uncertain conditions
   REGIME_DEFENSIVE     // Defensive - hostile conditions, no trading
};

//--- Trade result record for rolling performance
struct TradeRecord
{
   double profit;
   bool   isWin;
   datetime time;
};

//+------------------------------------------------------------------+
//| Adaptive Risk Controller Class                                   |
//+------------------------------------------------------------------+
class CAdaptiveRiskController
{
private:
   //--- Configuration
   double m_normalRisk;            // Risk % in normal mode (default 0.5)
   double m_cautionRisk;           // Risk % in caution mode (default 0.25)
   int    m_rollingWindow;         // Number of trades for rolling stats
   int    m_atrLookback;           // ATR averaging lookback
   double m_atrSpikeThreshold;     // ATR spike multiplier threshold
   double m_atrCollapseThreshold;  // ATR collapse multiplier threshold
   double m_maxDrawdownPercent;    // Max drawdown % threshold
   int    m_maxConsecLossesPause;  // Consecutive losses for pause
   int    m_maxConsecLossesStop;   // Consecutive losses for daily stop
   double m_minWinRate;            // Minimum win rate threshold
   double m_minProfitFactor;       // Minimum profit factor threshold
   int    m_maxFalseBreakouts;     // Max false breakouts before defensive

   //--- State
   ENUM_RISK_REGIME m_currentRegime;
   TradeRecord m_tradeHistory[];
   int    m_totalTrades;
   int    m_consecutiveLosses;
   bool   m_pauseActive;
   bool   m_dailyStopActive;
   double m_peakBalance;
   double m_currentDrawdown;
   double m_lastATRRatio;
   int    m_falseBreakoutCount;
   bool   m_enableLogging;

public:
   CAdaptiveRiskController()
   {
      m_normalRisk = 0.5;
      m_cautionRisk = 0.25;
      m_rollingWindow = 20;
      m_atrLookback = 50;
      m_atrSpikeThreshold = 1.5;
      m_atrCollapseThreshold = 0.5;
      m_maxDrawdownPercent = 5.0;
      m_maxConsecLossesPause = 2;
      m_maxConsecLossesStop = 3;
      m_minWinRate = 0.40;
      m_minProfitFactor = 0.8;
      m_maxFalseBreakouts = 3;
      m_currentRegime = REGIME_NORMAL;
      m_totalTrades = 0;
      m_consecutiveLosses = 0;
      m_pauseActive = false;
      m_dailyStopActive = false;
      m_peakBalance = 0;
      m_currentDrawdown = 0;
      m_lastATRRatio = 1.0;
      m_falseBreakoutCount = 0;
      m_enableLogging = true;
   }

   void Init(double normalRisk, double cautionRisk, int rollingWindow,
             int atrLookback, double atrSpike, double atrCollapse,
             double maxDD, int consecPause, int consecStop,
             double minWR, double minPF, int maxFB, bool logging)
   {
      m_normalRisk = normalRisk;
      m_cautionRisk = cautionRisk;
      m_rollingWindow = rollingWindow;
      m_atrLookback = atrLookback;
      m_atrSpikeThreshold = atrSpike;
      m_atrCollapseThreshold = atrCollapse;
      m_maxDrawdownPercent = maxDD;
      m_maxConsecLossesPause = consecPause;
      m_maxConsecLossesStop = consecStop;
      m_minWinRate = minWR;
      m_minProfitFactor = minPF;
      m_maxFalseBreakouts = maxFB;
      m_enableLogging = logging;
      m_peakBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   }

   //================================================================
   // REGIME MONITOR - Called on every new candle
   //================================================================
   void UpdateRegime(string symbol, int atrHandle, ENUM_TIMEFRAMES period)
   {
      ENUM_RISK_REGIME newRegime = REGIME_NORMAL;

      //--- A. Dynamic Volatility Control
      double atrRatio = CalculateATRRatio(symbol, atrHandle, period);
      m_lastATRRatio = atrRatio;

      if(atrRatio > m_atrSpikeThreshold)
      {
         newRegime = REGIME_CAUTION;
         if(m_enableLogging)
            Print("[REGIME] ATR SPIKE detected (ratio: ", DoubleToString(atrRatio, 2), ") → CAUTION");
      }
      else if(atrRatio < m_atrCollapseThreshold)
      {
         newRegime = REGIME_DEFENSIVE;
         if(m_enableLogging)
            Print("[REGIME] ATR COLLAPSE detected (ratio: ", DoubleToString(atrRatio, 2), ") → DEFENSIVE");
      }

      //--- B. Rolling Performance Check
      if(newRegime < REGIME_CAUTION)  // Only escalate, never de-escalate within same check
      {
         ENUM_RISK_REGIME perfRegime = CheckPerformance();
         if(perfRegime > newRegime)
            newRegime = perfRegime;
      }

      //--- C. Unfavorable Market Detection
      if(newRegime < REGIME_DEFENSIVE)
      {
         if(m_falseBreakoutCount >= m_maxFalseBreakouts)
         {
            newRegime = REGIME_DEFENSIVE;
            if(m_enableLogging)
               Print("[REGIME] Excessive false breakouts (", m_falseBreakoutCount, ") → DEFENSIVE");
         }
      }

      //--- D. Drawdown Check
      UpdateDrawdown();
      if(m_currentDrawdown > m_maxDrawdownPercent)
      {
         newRegime = REGIME_DEFENSIVE;
         if(m_enableLogging)
            Print("[REGIME] Drawdown exceeded (", DoubleToString(m_currentDrawdown, 2), "%) → DEFENSIVE");
      }

      //--- Update regime if changed
      if(newRegime != m_currentRegime)
      {
         if(m_enableLogging)
            Print("[REGIME CHANGE] ", EnumToString(m_currentRegime), " → ", EnumToString(newRegime));
         m_currentRegime = newRegime;
      }
   }

   //--- Check if trading is allowed
   bool IsTradingAllowed()
   {
      if(m_currentRegime == REGIME_DEFENSIVE)
         return false;
      if(m_dailyStopActive)
         return false;
      if(m_pauseActive)
         return false;
      return true;
   }

   //--- Get current risk percentage
   double GetCurrentRiskPercent()
   {
      switch(m_currentRegime)
      {
         case REGIME_NORMAL:  return m_normalRisk;
         case REGIME_CAUTION: return m_cautionRisk;
         case REGIME_DEFENSIVE: return 0;
      }
      return 0;
   }

   //--- Record a completed trade
   void RecordTrade(double profit)
   {
      TradeRecord record;
      record.profit = profit;
      record.isWin = (profit > 0);
      record.time = TimeCurrent();

      int size = ArraySize(m_tradeHistory);
      ArrayResize(m_tradeHistory, size + 1);
      m_tradeHistory[size] = record;
      m_totalTrades++;

      // Update consecutive losses
      if(profit <= 0)
      {
         m_consecutiveLosses++;

         // Live protection: consecutive loss rules
         if(m_consecutiveLosses >= m_maxConsecLossesStop)
         {
            m_dailyStopActive = true;
            if(m_enableLogging)
               Print("[PROTECTION] ", m_consecutiveLosses, " consecutive losses → DAILY STOP");
         }
         else if(m_consecutiveLosses >= m_maxConsecLossesPause)
         {
            m_pauseActive = true;
            if(m_enableLogging)
               Print("[PROTECTION] ", m_consecutiveLosses, " consecutive losses → PAUSE");
         }
      }
      else
      {
         m_consecutiveLosses = 0;
         m_pauseActive = false;  // Reset pause on a win
      }
   }

   //--- Record a false breakout
   void RecordFalseBreakout()
   {
      m_falseBreakoutCount++;
      if(m_enableLogging)
         Print("[REGIME] False breakout recorded (total: ", m_falseBreakoutCount, ")");
   }

   //--- Daily reset
   void ResetDaily()
   {
      m_dailyStopActive = false;
      m_pauseActive = false;
      m_falseBreakoutCount = 0;
      // Don't reset consecutive losses - they carry over for regime assessment
   }

   //--- Getters
   ENUM_RISK_REGIME GetCurrentRegime() const { return m_currentRegime; }
   int GetConsecutiveLosses() const { return m_consecutiveLosses; }
   double GetDrawdown() const { return m_currentDrawdown; }
   double GetATRRatio() const { return m_lastATRRatio; }
   bool IsPaused() const { return m_pauseActive; }
   bool IsDailyStopped() const { return m_dailyStopActive; }

   //--- Get rolling stats as string for logging
   string GetStatsString()
   {
      double winRate = 0, expectancy = 0, profitFactor = 0;
      CalculateRollingStats(winRate, expectancy, profitFactor);
      return StringFormat("Regime=%s | Risk=%.2f%% | WR=%.1f%% | PF=%.2f | Exp=%.2f | ConsecL=%d | DD=%.2f%%",
         EnumToString(m_currentRegime), GetCurrentRiskPercent(),
         winRate * 100, profitFactor, expectancy,
         m_consecutiveLosses, m_currentDrawdown);
   }

private:
   //--- Calculate ATR ratio (current vs average)
   double CalculateATRRatio(string symbol, int atrHandle, ENUM_TIMEFRAMES period)
   {
      double atrBuffer[];
      ArraySetAsSeries(atrBuffer, true);

      int barsNeeded = m_atrLookback + 1;
      if(CopyBuffer(atrHandle, 0, 0, barsNeeded, atrBuffer) < barsNeeded)
         return 1.0;  // Default ratio if data unavailable

      double currentATR = atrBuffer[0];
      double sumATR = 0;
      for(int i = 1; i < barsNeeded; i++)
         sumATR += atrBuffer[i];

      double avgATR = sumATR / m_atrLookback;
      if(avgATR <= 0) return 1.0;

      return currentATR / avgATR;
   }

   //--- Calculate rolling performance stats
   void CalculateRollingStats(double &winRate, double &expectancy, double &profitFactor)
   {
      int size = ArraySize(m_tradeHistory);
      int startIdx = MathMax(0, size - m_rollingWindow);
      int count = size - startIdx;

      if(count == 0)
      {
         winRate = 0.5;  // Neutral default
         expectancy = 0;
         profitFactor = 1.0;
         return;
      }

      int wins = 0;
      double totalProfit = 0, totalLoss = 0, totalPnL = 0;

      for(int i = startIdx; i < size; i++)
      {
         if(m_tradeHistory[i].isWin)
         {
            wins++;
            totalProfit += m_tradeHistory[i].profit;
         }
         else
         {
            totalLoss += MathAbs(m_tradeHistory[i].profit);
         }
         totalPnL += m_tradeHistory[i].profit;
      }

      winRate = (double)wins / count;
      expectancy = totalPnL / count;
      profitFactor = (totalLoss > 0) ? (totalProfit / totalLoss) : ((totalProfit > 0) ? 99.0 : 0);
   }

   //--- Check performance and return suggested regime
   ENUM_RISK_REGIME CheckPerformance()
   {
      double winRate = 0, expectancy = 0, profitFactor = 0;
      CalculateRollingStats(winRate, expectancy, profitFactor);

      int tradeCount = ArraySize(m_tradeHistory);
      if(tradeCount < 5)
         return REGIME_NORMAL;  // Not enough data

      if(winRate < m_minWinRate && profitFactor < m_minProfitFactor)
      {
         if(m_enableLogging)
            Print("[REGIME] Poor performance: WR=", DoubleToString(winRate * 100, 1),
                  "% PF=", DoubleToString(profitFactor, 2), " → CAUTION");
         return REGIME_CAUTION;
      }

      if(expectancy < 0 && winRate < 0.30)
      {
         if(m_enableLogging)
            Print("[REGIME] Negative expectancy with low WR → DEFENSIVE");
         return REGIME_DEFENSIVE;
      }

      return REGIME_NORMAL;
   }

   //--- Update drawdown tracking
   void UpdateDrawdown()
   {
      double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      if(currentBalance > m_peakBalance)
         m_peakBalance = currentBalance;

      if(m_peakBalance > 0)
         m_currentDrawdown = ((m_peakBalance - currentBalance) / m_peakBalance) * 100.0;
      else
         m_currentDrawdown = 0;
   }
};

#endif

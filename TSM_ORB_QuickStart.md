# TSM Opening Range Breakout - Quick Start Guide

## Installation

1. **Download the EA:**
   - Download `TSM_OpeningRangeBreakout.mq5` from the repository

2. **Install in MetaTrader 5:**
   - Copy the file to: `[MT5 Data Folder]/MQL5/Experts/`
   - Restart MetaTrader 5 or refresh the Navigator

3. **Compile the EA:**
   - Open MetaEditor (F4 in MT5)
   - Open `TSM_OpeningRangeBreakout.mq5`
   - Click Compile (F7)
   - Verify no errors

## Basic Setup

### Step 1: Attach to Chart
1. Open the instrument chart (e.g., EURUSD)
2. Drag the EA from Navigator to the chart
3. Enable "Allow live trading" and "Allow DLL imports"
4. Click OK

### Step 2: Configure Basic Parameters

**For Conservative Trading (Recommended for beginners):**
```
Opening Range Settings:
- OR Period: 60 minutes
- Start Hour: 9
- Start Minute: 0

Risk Engine:
- Risk per Trade: 0.5%
- Max Consecutive Losses: 3
- Daily Loss Limit: 2%
- Weekly Loss Limit: 4%

Regime Engine:
- Min Volatility Ratio: 0.5
- Max Volatility Ratio: 2.0
- Use HTF Filter: Yes
```

**For Moderate Trading:**
```
Risk Engine:
- Risk per Trade: 1.0%
- Daily Loss Limit: 3%
- Weekly Loss Limit: 5%

Regime Engine:
- Min Volatility Ratio: 0.3
- Max Volatility Ratio: 2.5
```

### Step 3: Monitor the EA

**Check the Experts Tab** for logs:
- OR range definition messages
- Trade signals
- Risk adjustments
- Trade executions

**Example Log Output:**
```
2026.02.19 09:00:00 TSM Opening Range Breakout EA initialized successfully
2026.02.19 09:00:00 New OR period: 2026.02.19 09:00 to 2026.02.19 10:00
2026.02.19 10:00:00 OR Defined - High: 1.10500 Low: 1.10350 Range: 150 points
2026.02.19 10:15:00 Bullish breakout detected at 1.10520
2026.02.19 10:15:00 Calculated lots: 0.10 Risk: 1.0% SL Distance: 150 points
2026.02.19 10:15:00 Position opened. Ticket: 12345 Type: BUY Lots: 0.10
```

## Understanding the Strategy

### 1. Opening Range Phase (First Hour)
- **9:00 - 10:00**: EA tracks the high and low of the first hour
- No trades during this period
- Range is defined at 10:00

### 2. Breakout Phase (After OR)
- **After 10:00**: EA waits for breakout
- **Buy Signal**: Price > OR High + 10 points
- **Sell Signal**: Price < OR Low - 10 points

### 3. Position Management
- **Stop Loss**: Placed at opposite end of OR range
- **Take Profit**: 2x the stop loss distance (default)
- **One trade per day** (per breakout direction)

## Common Scenarios

### Scenario 1: Successful Trade
```
09:00 - OR starts tracking
10:00 - OR defined: High=1.1050, Low=1.1035 (15 points range)
10:15 - Price breaks above 1.1051 (OR High + 10 points)
      - EA opens BUY position
      - SL at 1.1035 (15 points)
      - TP at 1.1065 (30 points, 2:1 ratio)
11:30 - TP hit, profit = $30
```

### Scenario 2: Volatility Too Low
```
09:00 - OR starts
10:00 - OR defined: Range = 5 points
      - ATR = 20 points
      - Range/ATR = 0.25 (below 0.5 threshold)
      - EA blocks trading: "OR range too compressed"
```

### Scenario 3: Daily Limit Reached
```
Trade 1: Loss -$50
Trade 2: Loss -$40
Trade 3: Loss -$60
Total daily loss: -$150 (3% of $5000 balance)
EA pauses: "Daily loss limit reached"
Trading resumes tomorrow
```

## Parameter Guide

### Critical Parameters to Adjust

**1. Risk Per Trade (InpRiskPercent)**
- Conservative: 0.5%
- Moderate: 1.0%
- Aggressive: 1.5-2.0%
- Never exceed 2% per trade

**2. Opening Range Period (InpORPeriodMinutes)**
- 30 minutes: More trades, less reliable
- 60 minutes: Balanced (recommended)
- 90 minutes: Fewer trades, more reliable

**3. Min Breakout Points (InpMinBreakoutPoints)**
- Low volatility pairs: 5-10 points
- Medium volatility: 10-15 points
- High volatility: 15-20 points

**4. Max Spread Points (InpMaxSpreadPoints)**
- Major pairs: 10-20 points
- Exotic pairs: 30-50 points
- Indices: 20-30 points

### Advanced Parameters

**Volatility Ratios:**
- Tight range: Min=0.5, Max=2.0 (safer, fewer trades)
- Wide range: Min=0.3, Max=2.5 (more trades, riskier)

**HTF Filter:**
- Enable for trending markets
- Disable for ranging markets
- Test both in backtest

## Troubleshooting

### Problem: No trades being taken

**Possible Causes:**
1. **Volatility too low/high**
   - Check: ATR/ATR_avg ratio in logs
   - Solution: Adjust Min/Max Volatility Ratio

2. **Spread too high**
   - Check: Current spread in Market Watch
   - Solution: Increase InpMaxSpreadPoints

3. **HTF filter blocking**
   - Check: HTF trend vs signal direction
   - Solution: Disable HTF filter or use lower timeframe

4. **Risk limits exceeded**
   - Check: Daily/weekly P&L
   - Solution: Wait for reset or adjust limits

### Problem: Too many losing trades

**Solutions:**
1. Increase minimum breakout distance
2. Enable HTF filter for trend alignment
3. Increase range compression filter
4. Reduce trading during low volatility periods
5. Optimize OR period length

### Problem: Compilation errors

**Common Issues:**
1. **Missing Trade.mqh**
   - Ensure MT5 installation is complete
   - File should be in: MQL5/Include/Trade/

2. **Syntax errors**
   - Update to latest MT5 build
   - Check for proper file encoding (UTF-8)

## Backtesting

### Recommended Settings

**Strategy Tester Configuration:**
```
Mode: Every tick based on real ticks
Period: 1 year minimum
Deposit: $10,000
Leverage: 1:100
Spread: Current or Average
```

**Optimization Parameters:**
- OR Period: 30, 60, 90
- Risk%: 0.5, 1.0, 1.5
- Min Volatility: 0.2, 0.3, 0.4, 0.5
- TP Ratio: 1.5, 2.0, 2.5, 3.0

### Evaluation Metrics

**Must Check:**
- Profit Factor: > 1.5 minimum
- Win Rate: > 40% acceptable
- Max Drawdown: < 15% preferred
- Recovery Factor: > 3.0 good
- Sharpe Ratio: > 1.0 good

## Live Trading Checklist

Before going live:
- [ ] Backtested for minimum 1 year
- [ ] Forward tested on demo for 1 month
- [ ] Profit factor > 1.5
- [ ] Max drawdown acceptable
- [ ] Risk per trade ≤ 1%
- [ ] Daily/weekly limits configured
- [ ] VPS or stable connection
- [ ] Sufficient account balance (min $1000)
- [ ] Emergency stop procedures known

## Tips for Success

1. **Start Small:** Begin with 0.5% risk per trade
2. **One Pair:** Master one instrument before adding more
3. **Monitor Daily:** Check logs daily for first month
4. **Keep Records:** Track performance manually
5. **Be Patient:** Give strategy time to work (minimum 3 months)
6. **Don't Interfere:** Let EA work without manual intervention
7. **Review Weekly:** Analyze trades and adjust if needed
8. **Respect Limits:** Never override risk limits

## Support

For issues or questions:
1. Check documentation thoroughly
2. Review logs for error messages
3. Test on demo account first
4. Verify parameter settings

## Next Steps

After successful demo testing:
1. Start with single pair (EURUSD recommended)
2. Use conservative risk settings
3. Run for 1-3 months
4. Track results in trading journal
5. Gradually optimize parameters
6. Consider adding more instruments
7. Scale position sizes slowly

---

**Remember:** Patience and discipline are key to success with any automated trading system.

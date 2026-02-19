# TSM Opening Range Breakout - Documentation

## Overview

TSM Opening Range Breakout is a production-grade Expert Advisor (EA) for MetaTrader 5 that implements the Opening Range Breakout strategy with a professional, modular architecture.

## Architecture

The EA is structured into 4 independent engines for maximum flexibility and maintainability:

### 1. Signal Engine
**Responsibility:** Opening Range Breakout logic

**Features:**
- Defines opening range based on configurable time period
- Tracks high and low during the opening range period
- Detects breakouts above/below the range
- Filters false breakouts in compressed ranges
- Minimum breakout distance filter

**Key Functions:**
- `SignalEngine_UpdateOR()` - Updates the opening range
- `SignalEngine_CheckBreakout()` - Detects breakout signals

### 2. Regime Engine
**Responsibility:** Market condition detection

**Features:**
- ATR-based volatility measurement
- Compares current ATR to moving average
- Blocks trades in low volatility (compression)
- Reduces risk in extreme volatility (expansion)
- Higher timeframe trend alignment filter
- Adaptive regime-based risk adjustment

**Key Functions:**
- `RegimeEngine_Update()` - Updates market regime
- `RegimeEngine_GetHTFTrend()` - Gets higher timeframe trend

**Volatility States:**
- **Low Volatility** (ATR/ATR_avg < min threshold): Trading blocked
- **Normal Volatility**: Normal risk applied
- **High Volatility** (ATR/ATR_avg > max threshold): Risk reduced

### 3. Risk Engine
**Responsibility:** Adaptive risk management

**Features:**
- Dynamic position sizing based on % of capital
- Automatic lot calculation based on stop loss distance
- Drawdown-based risk reduction
- Consecutive loss protection (pauses after X losses)
- Daily loss limit (stops trading for the day)
- Weekly loss limit (stops trading for the week)
- Volatility-adjusted risk sizing

**Key Functions:**
- `RiskEngine_CalculateLots()` - Calculates position size
- `RiskEngine_UpdatePeriodStats()` - Updates daily/weekly statistics
- `RiskEngine_UpdateConsecutiveLosses()` - Tracks consecutive losses

**Protection Mechanisms:**
1. **Drawdown Protection**: Reduces risk by 50% (configurable) when drawdown exceeds threshold
2. **Consecutive Loss Protection**: Stops trading after X consecutive losses
3. **Daily Limit**: Stops trading when daily loss exceeds X% of starting balance
4. **Weekly Limit**: Stops trading when weekly loss exceeds X% of starting balance

### 4. Execution Engine
**Responsibility:** Order execution and management

**Features:**
- Market order execution with proper error handling
- Spread filtering (blocks trades when spread too high)
- Automatic stop loss and take profit placement
- Position tracking and monitoring
- Trade statistics collection

**Key Functions:**
- `ExecutionEngine_CheckConditions()` - Validates execution conditions
- `ExecutionEngine_OpenPosition()` - Opens new positions
- `ExecutionEngine_ManagePosition()` - Manages open positions

## Configuration Parameters

### Opening Range Settings
- `InpORPeriodMinutes` (60): Duration of opening range in minutes
- `InpORStartHour` (9): Opening range start hour
- `InpORStartMinute` (0): Opening range start minute

### Signal Engine
- `InpMinBreakoutPoints` (10): Minimum points for valid breakout
- `InpUseFalseBreakoutFilter` (true): Enable false breakout filtering
- `InpRangeCompressionFilter` (0.5): Minimum range/ATR ratio (0=disabled)

### Regime Engine
- `InpATRPeriod` (14): ATR calculation period
- `InpATRAvgPeriod` (20): ATR averaging period
- `InpMinVolatilityRatio` (0.3): Minimum ATR/ATR_avg ratio
- `InpMaxVolatilityRatio` (2.5): Maximum ATR/ATR_avg ratio
- `InpUseHTFFilter` (true): Enable higher timeframe filter
- `InpHTF` (PERIOD_H1): Higher timeframe for trend alignment
- `InpHTFMAPeriod` (50): Moving average period for HTF

### Risk Engine
- `InpRiskPercent` (1.0): Risk per trade (% of balance)
- `InpMaxRiskPercent` (2.0): Maximum risk per trade
- `InpStopLossPoints` (0): Fixed stop loss in points (0=use OR range)
- `InpTakeProfitRatio` (2.0): Take profit / stop loss ratio
- `InpMaxConsecutiveLosses` (3): Maximum consecutive losses allowed
- `InpDailyLossPercent` (3.0): Daily loss limit (%)
- `InpWeeklyLossPercent` (5.0): Weekly loss limit (%)
- `InpDrawdownReducePercent` (10.0): Drawdown threshold for risk reduction
- `InpRiskReductionFactor` (0.5): Risk reduction multiplier

### Execution Engine
- `InpMaxSpreadPoints` (20): Maximum spread allowed (points)
- `InpMagicNumber` (123456): Magic number for trade identification
- `InpTradeComment` ("ORB_EA"): Comment for trades

### General
- `InpEnableLogging` (true): Enable detailed logging

## Strategy Logic

### Opening Range Definition
1. At configured start time (e.g., 9:00), begin tracking high/low
2. Continue tracking for configured period (e.g., 60 minutes)
3. At end of period, opening range is defined

### Entry Signals
**Long (Buy):**
- Price breaks above OR high + minimum breakout distance
- Volatility within acceptable range
- Higher timeframe trend is bullish (if filter enabled)
- Spread is acceptable
- Risk limits not exceeded

**Short (Sell):**
- Price breaks below OR low - minimum breakout distance
- Volatility within acceptable range
- Higher timeframe trend is bearish (if filter enabled)
- Spread is acceptable
- Risk limits not exceeded

### Position Sizing
```
Risk Amount = Balance × Risk%
Stop Loss Distance = OR Range (or fixed points)
Lot Size = Risk Amount / (SL Distance × Tick Value)
```

### Stop Loss Placement
- **Buy**: Entry - OR Range (or fixed points)
- **Sell**: Entry + OR Range (or fixed points)

### Take Profit Placement
- TP Distance = SL Distance × TP Ratio
- Default ratio is 2:1 (risk:reward)

## Risk Management Features

### 1. Volatility-Based Risk Adjustment
When market volatility (ATR/ATR_avg) exceeds maximum threshold, risk is automatically reduced:
```
Adjusted Risk = Base Risk × (Max Ratio / Current Ratio)
```

### 2. Drawdown Protection
When account drawdown exceeds threshold (default 10%):
```
Adjusted Risk = Base Risk × Reduction Factor (default 0.5)
```

### 3. Consecutive Loss Protection
After X consecutive losses (default 3), trading stops until manual reset or new period.

### 4. Daily/Weekly Limits
- Trading pauses when daily loss exceeds limit
- Trading pauses when weekly loss exceeds limit
- Automatic reset at start of new period

## Best Practices

### Recommended Settings for Different Markets

**Forex Major Pairs (EUR/USD, GBP/USD):**
```
OR Period: 60 minutes
Risk: 1%
Min Volatility Ratio: 0.3
Max Volatility Ratio: 2.5
Max Spread: 20 points
```

**Forex Exotic Pairs:**
```
OR Period: 60 minutes
Risk: 0.5-1%
Min Volatility Ratio: 0.5
Max Volatility Ratio: 2.0
Max Spread: 50 points
```

**Indices:**
```
OR Period: 30-60 minutes
Risk: 1-2%
Min Volatility Ratio: 0.4
Max Volatility Ratio: 2.5
Max Spread: 30 points
```

### Optimization Guidelines

1. **Opening Range Period**: Test 30, 60, 90 minutes
2. **Risk Per Trade**: Start conservative (0.5-1%)
3. **Volatility Ratios**: Optimize based on backtests
4. **HTF Filter**: Test with/without and different periods
5. **TP Ratio**: Test 1.5, 2.0, 2.5, 3.0

## Advantages of Modular Architecture

1. **Maintainability**: Each engine can be modified independently
2. **Testability**: Individual engines can be tested separately
3. **Flexibility**: Easy to add/remove features
4. **Clarity**: Clear separation of concerns
5. **Scalability**: Easy to extend with new functionality

## Code Quality Features

- **No code duplication**: Reusable functions
- **Clear naming**: Descriptive variable and function names
- **Proper error handling**: Checks for invalid conditions
- **Comprehensive logging**: Detailed trade and error logs
- **Organized structure**: Logical grouping of related code

## Future Enhancements (Optional)

Potential improvements that can be added:
- Trailing stop functionality
- Partial position closing
- Multiple timeframe confirmation
- Session-specific parameters
- Machine learning regime detection
- Portfolio-level risk management

## Testing Checklist

Before live trading:
- [ ] Backtest on historical data (minimum 1 year)
- [ ] Forward test on demo account (minimum 1 month)
- [ ] Verify all input parameters work correctly
- [ ] Test in different market conditions
- [ ] Verify risk limits are respected
- [ ] Monitor logs for any errors
- [ ] Start with minimum position size

## Support & Maintenance

This EA is designed for professional traders and requires:
- Understanding of opening range breakout strategies
- Knowledge of risk management
- Experience with MetaTrader 5
- Ability to optimize parameters for specific instruments

## Disclaimer

This EA is provided for educational and research purposes. Trading involves risk of loss. Always test thoroughly on demo accounts before live trading.

---

**Version:** 2.00  
**Last Updated:** 2026-02-19  
**Compatible with:** MetaTrader 5 Build 3000+

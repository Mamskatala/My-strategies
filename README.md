# My Trading Strategies

This repository contains professional-grade trading strategies and Expert Advisors for MetaTrader 5.

## Contents

### TSM Opening Range Breakout (ORB) EA

A production-ready Expert Advisor implementing the Opening Range Breakout strategy with advanced risk management and modular architecture.

**Key Features:**
- ✅ Modular architecture (4 independent engines)
- ✅ Adaptive risk management based on volatility
- ✅ Market regime detection and filtering
- ✅ Comprehensive drawdown protection
- ✅ Daily and weekly loss limits
- ✅ Higher timeframe trend alignment
- ✅ False breakout filtering
- ✅ Professional code structure

**Files:**
- `TSM_OpeningRangeBreakout.mq5` - Main EA file
- `TSM_ORB_Documentation.md` - Complete documentation
- `TSM_ORB_QuickStart.md` - Quick start guide

**Quick Start:**
1. Copy `TSM_OpeningRangeBreakout.mq5` to MT5 Experts folder
2. Compile in MetaEditor
3. Attach to chart
4. Configure parameters (see Quick Start Guide)
5. Enable auto-trading

**Documentation:**
- [Complete Documentation](TSM_ORB_Documentation.md) - Architecture, features, configuration
- [Quick Start Guide](TSM_ORB_QuickStart.md) - Installation, setup, examples

## Architecture Overview

The ORB EA uses a modular design with 4 independent engines:

1. **Signal Engine** - Opening Range detection and breakout signals
2. **Regime Engine** - Market condition analysis and volatility filtering
3. **Risk Engine** - Adaptive position sizing and drawdown protection
4. **Execution Engine** - Order management and trade execution

This separation allows for:
- Easy maintenance and updates
- Independent testing of components
- Clear code organization
- Flexible parameter optimization

## Requirements

- MetaTrader 5 Build 3000+
- Understanding of opening range breakout strategies
- Basic knowledge of risk management
- Minimum account balance: $1000 (recommended)

## Disclaimer

Trading involves substantial risk of loss. These strategies are provided for educational purposes. Always test thoroughly on demo accounts before live trading.

---

### Legacy Indicators

**KAMA Indicator** (TradeStation format - for reference only)
```
inputs:period(8), fast(3), slow(30);
vars: efratio(0), smooth(1), fastend(.666), slowend(.0645), diff(0), signal(0), noise(0);
vars: KAMA(0), adate(" "), MA(0);

// calculate efficiency ratio 
if currentbar = 1 then begin
    KAMA = close;
    fastend = 2/(fast + 1);
    slowend = 2/(slow + 1);
end
else begin
    efratio = 1;
    diff = absvalue(close - close[1]);
    signal = absvalue(close - close[period]);
    noise = summation(diff,period);
    if noise <> 0 then efratio = signal / noise;
    smooth = power(efratio*(fastend - slowend) + slowend,2);
    KAMA = KAMA[1] + smooth*(close - KAMA[1]);
end;
// ADAPTIVE MOVING AVERAGE
Plot1(KAMA,"KAMA");
```

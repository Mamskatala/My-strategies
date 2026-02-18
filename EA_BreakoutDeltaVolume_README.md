# EA Breakout with Delta Volume - Documentation

## Overview
This Expert Advisor (EA) implements a breakout trading strategy with Delta Volume confirmation for MetaTrader 5. It combines classic breakout logic with volume analysis to improve trade entry quality.

## Files
1. **DeltaVolume.mq5** - Custom indicator for Delta Volume and Cumulative Delta
2. **EA_BreakoutDeltaVolume.mq5** - Expert Advisor with integrated breakout strategy

## Strategy Description

### Breakout Logic
The EA monitors the opening price of each trading day and waits for a breakout above or below a defined threshold. Two breakout methods are supported:

1. **Fixed Point Breakout** (BOoption = 1)
   - Entry occurs when price breaks above/below today's open by a fixed number of points
   - Configurable via `FixedPoint` parameter

2. **Volatility-Based Breakout** (BOoption = 2)
   - Entry occurs when price breaks above/below today's open by a multiple of ATR (Average True Range)
   - Configurable via `VolPeriod` and `BreakoutFactor` parameters

### Delta Volume Filter
The EA uses a custom Delta Volume indicator to confirm trend direction before entering trades:

- **Delta**: Represents the difference between buying and selling pressure on each bar
  - Positive delta = more buying pressure (bullish)
  - Negative delta = more selling pressure (bearish)

- **Cumulative Delta**: Running sum of delta values
  - Rising cumulative delta = sustained buying pressure
  - Falling cumulative delta = sustained selling pressure

### Trading Rules

1. **Long Entry**:
   - Price breaks above (Today's Open + Breakout Level)
   - Delta Volume is positive (bullish confirmation)
   - Recent delta bar is positive
   - Inside day filter is satisfied (if enabled)

2. **Short Entry**:
   - Price breaks below (Today's Open - Breakout Level)
   - Delta Volume is negative (bearish confirmation)
   - Recent delta bar is negative
   - Inside day filter is satisfied (if enabled)

3. **Position Management**:
   - Only one position at a time
   - Positions can be reversed when opposite breakout occurs
   - Optional overnight holding
   - End-of-day exit if `HoldOvernight = false`

4. **Inside Day Filter** (Optional):
   - If enabled (`PrecedeByInsideDay = true`), trades only occur after an inside day
   - Inside day = Yesterday's High < Day Before Yesterday's High AND Yesterday's Low > Day Before Yesterday's Low

## Parameters

### Breakout Settings
- **BOoption** (1 or 2): Breakout method
  - 1 = Fixed Point Range Breakout
  - 2 = Volatility-Based Breakout
- **FixedPoint** (default: 1.6): Fixed point range in price units (for option 1)
- **VolPeriod** (default: 20): ATR period for volatility calculation (for option 2)
- **BreakoutFactor** (default: 1.0): Multiplier for ATR-based breakout (for option 2)

### Trading Rules
- **HoldOvernight** (default: false): Keep positions overnight or close at EOD
- **PrecedeByInsideDay** (default: false): Require inside day before trading
- **LotSize** (default: 0.1): Position size in lots
- **MagicNumber** (default: 123456): Unique identifier for EA orders
- **Slippage** (default: 10): Maximum slippage in points

### Delta Volume Filter
- **UseDeltaFilter** (default: true): Enable/disable Delta Volume confirmation
- **DeltaResetPeriod** (0, 1, or 2): Cumulative Delta reset frequency
  - 0 = Never reset
  - 1 = Daily reset
  - 2 = Weekly reset
- **MinDeltaThreshold** (default: 0): Minimum cumulative delta for entry (0 = disabled)

### Time Settings
- **SessionEndHour** (default: 17): Hour for end-of-day exit (24-hour format)
- **SessionEndMinute** (default: 0): Minute for end-of-day exit

## Delta Volume Indicator

### Calculation Method
Since true order flow data is not available on MT5 for most instruments, the indicator uses an approximation based on price action:

1. **Bullish Bars** (Close > Open):
   - Delta = Tick Volume × Close Position Ratio
   - Close Position = (Close - Low) / (High - Low)
   - Assumes buying pressure based on where the bar closed within its range

2. **Bearish Bars** (Close < Open):
   - Delta = -Tick Volume × Close Position Ratio
   - Close Position = (High - Close) / (High - Low)
   - Assumes selling pressure based on where the bar closed within its range

3. **Doji Bars** (Close = Open):
   - Delta = 0 (neutral)

### Visualization
The indicator displays three elements in a separate window:
1. **Color-Coded Histogram**: Delta values for each bar
   - Green bars = Positive delta (buying pressure)
   - Red bars = Negative delta (selling pressure)
2. **Blue Line**: Cumulative Delta (trend indicator)
3. **Gray Dotted Line**: Zero reference line

## Usage Instructions

1. **Install the Indicator**:
   - Copy `DeltaVolume.mq5` to `MQL5/Indicators/` folder
   - Compile the indicator in MetaEditor
   - Restart MT5 or refresh Navigator

2. **Install the EA**:
   - Copy `EA_BreakoutDeltaVolume.mq5` to `MQL5/Experts/` folder
   - Compile the EA in MetaEditor

3. **Apply to Chart**:
   - Open a chart for your desired instrument and timeframe
   - Drag the EA onto the chart
   - Configure parameters according to your preferences
   - Enable AutoTrading

4. **Recommended Settings for Testing**:
   - Start with **BOoption = 2** (volatility-based) for adaptability
   - Use **VolPeriod = 20** and **BreakoutFactor = 1.0**
   - Keep **UseDeltaFilter = true** for better entry quality
   - Set **HoldOvernight = false** for intraday trading
   - Use small **LotSize** (0.01-0.1) for initial testing

## Important Notes

1. **Backtesting**: The EA can be backtested in MT5 Strategy Tester. Use quality tick data for best results.

2. **Timeframes**: Works on any timeframe, but is designed primarily for intraday trading on M15, M30, or H1.

3. **Instruments**: Can be used on any instrument (Forex, Indices, Commodities, etc.)

4. **Volume Data**: Delta calculation is approximate. For futures/stocks with real volume data, the indicator could be enhanced to use actual volume.

5. **Risk Management**: Always use appropriate lot sizes and risk management. This EA does not include stop-loss or take-profit by default.

## Customization

The code is written in a clear, modular structure to allow easy customization:

- Add stop-loss and take-profit levels
- Modify Delta calculation for instruments with real volume data
- Add additional filters (time filters, trend filters, etc.)
- Implement trailing stops
- Add more sophisticated position management

## Support

For questions, issues, or enhancements, please refer to the repository documentation or contact the developer.

---

**Disclaimer**: This EA is provided for educational purposes. Always test thoroughly on a demo account before using real money. Past performance does not guarantee future results.

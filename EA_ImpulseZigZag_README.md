# EA MT5 Pro - Impulse & ZigZag Structure Trading System

## Overview

**EA_ImpulseZigZag.mq5** is a professional Expert Advisor for MetaTrader 5 that implements a sophisticated trading strategy based on:
1. Detection of impulse candles at specific times
2. ZigZag pullback structure identification (2 legs)
3. Strict trigger-based trade execution

## Key Features

- ✅ **Timeframe**: M5 (5-minute charts) - mandatory
- ✅ **State Machine**: Robust state-based logic for pattern detection
- ✅ **Risk Management**: Dynamic position sizing based on account risk
- ✅ **Multiple Modes**: Continuation and Reversal trading modes
- ✅ **Safety Filters**: Spread, volatility, and stops level validation
- ✅ **Professional Logging**: Detailed console output for debugging

## Installation

1. Copy `EA_ImpulseZigZag.mq5` to your MetaTrader 5 `Experts` folder:
   - Windows: `C:\Users\[Username]\AppData\Roaming\MetaQuotes\Terminal\[Instance]\MQL5\Experts\`
   - Mac: `~/Library/Application Support/MetaQuotes/Terminal/[Instance]/MQL5/Experts/`

2. Open MetaTrader 5 and compile the EA (F7 or Tools > MetaEditor)

3. Attach to an M5 chart (drag and drop from Navigator panel)

## Configuration Parameters

### Trading Mode

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `ArrowMode` | Enum | ARROW_CONTINUATION | Continuation or Reversal mode |
| `TradeDirection` | Enum | BOTH | BOTH, BUY_ONLY, or SELL_ONLY |

### Entry Timing

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `EntryHour` | int | 16 | Hour for impulse detection (server time) |
| `EntryMinute` | int | 30 | Minute for impulse detection |
| `OneTradePerDay` | bool | true | Limit to one trade per day |

### Impulse Detection

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `ImpulseLookbackBars` | int | 20 | Lookback period (reserved for future use) |
| `ImpulseMinATRMult` | double | 1.8 | Minimum candle range (1.8 × ATR) |
| `ImpulseMaxATRMult` | double | 3.0 | Maximum candle range (3.0 × ATR) - news filter |
| `ATRPeriod` | int | 14 | ATR calculation period |
| `ImpulseBodyPercent` | double | 60.0 | Minimum body percentage (60%) |

### ZigZag Structure

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `PullbackMinRetrace` | double | 0.35 | Minimum retracement (35%) |
| `PullbackMaxRetrace` | double | 0.65 | Maximum retracement (65%) |
| `PullbackMaxBars` | int | 6 | Maximum bars for structure formation |
| `TriggerBufferPoints` | int | 10 | Trigger buffer in points |

### Risk Management

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `RiskPercent` | double | 1.0 | Risk per trade (% of account) |
| `FixedLot` | double | 0.0 | Fixed lot size (0 = auto calculation) |
| `SLMode` | Enum | SL_ON_IMPULSE_EXTREME | Stop loss placement mode |
| `TPMode` | Enum | TP_RISK_REWARD | Take profit mode |
| `RiskRewardRatio` | double | 2.0 | Risk/Reward ratio (when TPMode = TP_RISK_REWARD) |
| `FixedTPPoints` | int | 500 | Fixed TP in points (when TPMode = TP_FIXED_POINTS) |

### Safety Filters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `MaxSpreadPoints` | int | 30 | Maximum allowed spread |
| `UseVolatilityFilter` | bool | true | Enable volatility filter (reserved for future use) |
| `MagicNumber` | int | 888999 | Unique identifier for EA trades |

## Trading Logic

### State Machine

The EA operates through a 4-state machine:

1. **WAITING_IMPULSE**: Monitors for impulse candle at specified entry time
2. **WAITING_PULLBACK1**: Detects first pullback (retracement)
3. **WAITING_PULLBACK2**: Detects second pullback (lower high/higher low)
4. **WAITING_TRIGGER**: Awaits price trigger for trade execution

### Impulse Candle Validation

An impulse candle must satisfy:
- ✅ Range between 1.8× and 3.0× ATR
- ✅ Body ≥ 60% of total range
- ✅ Spread ≤ configured maximum
- ✅ Direction compatible with TradeDirection setting

### ZigZag Structure Validation

For **BEARISH** impulse (looking for SELL continuation):
- Pullback 1: Higher high within 35-65% retracement
- Pullback 2: Lower high (below PB1) with rejection
- Trigger: Break below the low between PB1 and PB2

For **BULLISH** impulse (looking for BUY continuation):
- Pullback 1: Lower low within 35-65% retracement
- Pullback 2: Higher low (above PB1) with rejection
- Trigger: Break above the high between PB1 and PB2

### Reversal Mode

When `ArrowMode = ARROW_REVERSAL`:
- For BEARISH impulse: Wait for reclaim above mid-point, then BUY on break of impulse high
- For BULLISH impulse: Wait for reclaim below mid-point, then SELL on break of impulse low

## Risk Management

### Position Sizing

If `FixedLot = 0` (automatic):
```
Risk Amount = Account Balance × (RiskPercent / 100)
Lot Size = (Risk Amount × Tick Size) / (SL Distance × Tick Value)
```

Lot size is automatically normalized to broker's:
- Minimum lot
- Maximum lot
- Lot step

### Stop Loss Options

- **SL_ON_IMPULSE_EXTREME**: Places SL beyond impulse candle extreme
- **SL_ON_PULLBACK_EXTREME**: Places SL beyond the extreme of pullbacks

### Take Profit Options

- **TP_RISK_REWARD**: TP = Entry ± (SL Distance × RiskRewardRatio)
- **TP_FIXED_POINTS**: TP = Entry ± FixedTPPoints

## Safety Features

- ✅ Timeframe validation (must be M5)
- ✅ Daily trade limit (optional)
- ✅ Spread filtering
- ✅ Stops level validation
- ✅ Multiple order filling modes (FOK → IOC → RETURN)
- ✅ Position conflict prevention

## Logging

The EA provides comprehensive console logging:

- **Initialization**: Configuration summary
- **Impulse Detection**: Direction, range, body %, ATR value
- **Pullback Detection**: Levels and validation status
- **ZigZag Validation**: Complete structure details
- **Trigger**: Exact trigger levels
- **Execution**: Full trade details (ticket, lots, SL, TP, R:R)
- **Errors**: Specific failure reasons

## Example Log Output

```
════════════════════════════════════════
EA IMPULSE ZIGZAG - INITIALIZED
════════════════════════════════════════
Symbol: EURUSD
Timeframe: M5
Arrow Mode: ARROW_CONTINUATION
Trade Direction: BOTH
Entry Time: 16:30
ATR Period: 14
Risk Percent: 1.0%
Magic Number: 888999
════════════════════════════════════════

=== IMPULSE CANDLE DETECTED ===
Direction: BEARISH
Range: 0.00045 Points
Body: 72.5%
ATR: 0.00025

Pullback 1 detected at: 1.09150 bar: 3

Pullback 2 detected at: 1.09120 (lower than PB1: 1.09150)

=== BEARISH ZIGZAG VALID ===
Impulse Low: 1.09000
Pullback1 High: 1.09150
Rejection Low: 1.09050
Pullback2 High: 1.09120 (< PB1)

Trigger SELL at: 1.09040

🔴 SELL TRIGGER ACTIVATED!

════════════════════════════════════════
✅ TRADE EXECUTED!
════════════════════════════════════════
Type: SELL
Ticket: 123456789
Price: 1.09038
Lot: 0.10
SL: 1.09170 (132 points)
TP: 1.08774 (264 points)
R:R: 1:2.00
════════════════════════════════════════
```

## Important Notes

### Timeframe Requirement
⚠️ **The EA ONLY works on M5 charts**. Attaching to any other timeframe will result in initialization failure.

### Server Time
- Entry time (`EntryHour`, `EntryMinute`) uses MT5 server time
- Ensure you know your broker's server time offset from your local time

### One Trade Per Day
- When enabled, the EA will execute maximum one trade per calendar day
- State resets at midnight (server time)

### Broker Compatibility
- Ensure your broker supports Market Execution
- Check your broker's minimum stops level
- Verify allowed order filling modes (EA tries FOK → IOC → RETURN)

## Troubleshooting

### "EA must be attached to M5 timeframe"
**Solution**: Attach EA to a 5-minute chart

### "Spread too high"
**Solution**: Increase `MaxSpreadPoints` or trade during lower spread hours

### "SL too close (stops level)"
**Solution**: 
- Increase `TriggerBufferPoints`
- Choose different `SLMode`
- Check broker's minimum stops level

### "Range too small" / "Range excessive"
**Solution**: Adjust `ImpulseMinATRMult` and `ImpulseMaxATRMult` based on market conditions

### "No clear rejection between PB1 and PB2"
**Solution**: Market didn't form a valid zigzag structure - wait for next opportunity

## Version History

### v1.00 (2026-02-17)
- Initial release
- Complete implementation of impulse + zigzag detection
- State machine architecture
- Continuation and reversal modes
- Comprehensive risk management
- Professional logging system

## Support & Disclaimer

This EA is provided as-is for educational and trading purposes. 

**Risk Warning**: Trading foreign exchange on margin carries a high level of risk and may not be suitable for all investors. Past performance is not indicative of future results. Always use proper risk management and never risk more than you can afford to lose.

## License

Copyright (c) 2026 EA MT5 Pro
All rights reserved.

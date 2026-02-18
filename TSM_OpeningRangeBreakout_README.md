# TSM Opening Range Breakout Expert Advisor

## Overview

This is a production-grade MetaTrader 5 Expert Advisor implementing the **TSM Opening Range Breakout** strategy by P.J. Kaufman. The strategy identifies the high and low prices during a specified opening period and trades breakouts beyond these levels.

## Strategy Description

### Concept

The Opening Range Breakout (ORB) strategy is based on the premise that the first period of trading (opening range) establishes key support and resistance levels for the day. When price breaks above or below this range, it often indicates strong directional momentum.

### Trading Rules

1. **Opening Range Calculation**: 
   - The EA identifies the high and low prices during a user-defined opening period (default: 30 minutes starting at 09:30)
   - This range is calculated once per day

2. **Entry Signals**:
   - **Long Entry**: Price breaks above the opening range high (plus a buffer in pips)
   - **Short Entry**: Price breaks below the opening range low (minus a buffer in pips)

3. **Exit Rules**:
   - Stop Loss: Either at the opposite end of the opening range or a fixed pip amount
   - Take Profit: Fixed pip amount from entry
   - Positions can be closed at end of trading day (optional)

4. **Risk Management**:
   - Fixed lot size or dynamic position sizing based on account risk percentage
   - Configurable stop loss and take profit levels

## Features

### Core Features

- ✅ Pure MQL5 implementation with `#property strict`
- ✅ Multi-symbol support using proper MQL5 classes
- ✅ Professional error handling and validation
- ✅ Organized input parameters with groups
- ✅ Clean, well-documented code

### Trading Features

- **Opening Range Detection**: Automatic calculation of daily opening range
- **Breakout Trading**: Enters positions on range breakouts with configurable buffer
- **First Breakout Only**: Optional setting to trade only the first breakout of the day
- **Flexible Stop Loss**: Use opening range or fixed pips
- **Take Profit**: Configurable take profit in pips
- **Trading Hours**: Restrict trading to specific hours
- **End of Day Management**: Optionally close all positions at end of trading session

### Risk Management

- **Fixed Lot Size**: Trade with a consistent position size
- **Dynamic Lot Sizing**: Calculate position size based on account risk percentage
- **Proper Stop Levels**: Automatic validation against broker's minimum stop distance
- **Magic Number**: Unique identifier for EA's trades

## Installation

1. Copy `TSM_OpeningRangeBreakout.mq5` to your MetaTrader 5 `Experts` folder:
   - Windows: `C:\Program Files\MetaTrader 5\MQL5\Experts\`
   - Or: `%APPDATA%\MetaQuotes\Terminal\<INSTANCE_ID>\MQL5\Experts\`

2. Open MetaEditor and compile the EA (F7 key)
   - Should compile with **zero errors** and **zero warnings**

3. Restart MetaTrader 5 or refresh the Navigator window

4. Drag the EA onto a chart to start trading

## Configuration

### Opening Range Settings

| Parameter | Default | Description |
|-----------|---------|-------------|
| `InpRangePeriodMinutes` | 30 | Length of opening range in minutes |
| `InpRangeStartHour` | 9 | Hour when opening range starts (24-hour format) |
| `InpRangeStartMinute` | 30 | Minute when opening range starts |

### Entry Settings

| Parameter | Default | Description |
|-----------|---------|-------------|
| `InpBreakoutPips` | 2.0 | Buffer in pips beyond opening range for entry |
| `InpTradeOnlyFirstBreak` | true | Trade only the first breakout of the day |

### Risk Management

| Parameter | Default | Description |
|-----------|---------|-------------|
| `InpLotSize` | 0.1 | Fixed lot size (if not using dynamic sizing) |
| `InpStopLossPips` | 50.0 | Stop loss in pips (if not using range stops) |
| `InpTakeProfitPips` | 100.0 | Take profit in pips |
| `InpUseRangeStops` | true | Use opening range as stop loss |
| `InpRiskPercent` | 1.0 | Risk per trade as % of account |
| `InpUseDynamicLots` | false | Enable dynamic position sizing |

### Trading Hours

| Parameter | Default | Description |
|-----------|---------|-------------|
| `InpTradingStartHour` | 9 | Hour when trading begins |
| `InpTradingEndHour` | 16 | Hour when trading ends |

### General Settings

| Parameter | Default | Description |
|-----------|---------|-------------|
| `InpMagicNumber` | 123456 | Unique identifier for EA trades |
| `InpTradeComment` | "TSM_ORB" | Comment added to trades |
| `InpCloseAtEndOfDay` | true | Close all positions at end of trading day |

## Usage Examples

### Example 1: Conservative Day Trading

```
Opening Range: 30 minutes (09:30 - 10:00)
Breakout Buffer: 2 pips
Trade Only First Break: Yes
Stop Loss: Use opening range
Take Profit: 100 pips
Close at End of Day: Yes
```

This setup trades only the first breakout with the stop at the opposite end of the range, suitable for conservative traders.

### Example 2: Aggressive Scalping

```
Opening Range: 15 minutes (09:30 - 09:45)
Breakout Buffer: 1 pip
Trade Only First Break: No
Stop Loss: 20 pips (fixed)
Take Profit: 40 pips
Close at End of Day: No
```

Shorter range with smaller stops for more frequent trading opportunities.

### Example 3: Risk-Based Position Sizing

```
Use Dynamic Lots: Yes
Risk Percent: 2.0%
Stop Loss: Use opening range
```

Automatically calculates position size to risk 2% of account on each trade.

## Technical Implementation

### MQL5 Classes Used

- `CTrade`: For executing trades
- `CPositionInfo`: For managing position information
- `CSymbolInfo`: For accessing symbol properties
- `CAccountInfo`: For account information

### Key Functions

- `OnInit()`: Initializes EA, validates parameters, sets up trading objects
- `OnTick()`: Main trading logic, called on every price tick
- `CalculateOpeningRange()`: Computes daily opening range high/low
- `CheckBreakoutSignals()`: Detects breakout conditions
- `OpenPosition()`: Executes trades with proper risk management
- `CalculateLotSize()`: Computes dynamic position size based on risk
- `ManagePositions()`: Manages open positions (placeholder for trailing stops, etc.)

### Code Structure

```
TSM_OpeningRangeBreakout.mq5
├── Properties & Includes
├── Input Parameters (grouped)
├── Global Variables & Structures
├── OnInit()
├── OnDeinit()
├── OnTick()
└── Helper Functions
    ├── ResetOpeningRange()
    ├── CalculateOpeningRange()
    ├── CheckBreakoutSignals()
    ├── OpenPosition()
    ├── CalculateLotSize()
    ├── HasPosition()
    ├── ManagePositions()
    ├── CloseAllPositions()
    └── IsWithinTradingHours()
```

## Performance Considerations

1. **New Bar Check**: EA only processes logic on new bar formation, reducing CPU usage
2. **Symbol Info Refresh**: Prices and symbol properties are refreshed before trading decisions
3. **Daily Reset**: Opening range is recalculated once per day
4. **Position Checks**: Efficient position checking prevents duplicate entries

## Risk Warnings

⚠️ **Important Disclaimers**:

- This EA is provided for educational purposes
- Past performance does not guarantee future results
- Always test on a demo account before live trading
- Use appropriate risk management (recommended: risk < 2% per trade)
- Markets can be unpredictable; losses are possible
- Adjust parameters based on your trading style and market conditions

## Troubleshooting

### EA doesn't open trades

1. Check if current time is within trading hours
2. Verify opening range has been calculated (check Experts log)
3. Ensure sufficient margin for trade
4. Check if symbol allows trading (some symbols restricted during certain hours)

### Compilation errors

1. Ensure all standard MQL5 libraries are present in MQL5\Include folder
2. Check MetaTrader 5 build version (requires modern MT5)
3. Verify file encoding is UTF-8

### Wrong stop loss levels

1. Check broker's minimum stop level (`symbolInfo.StopsLevel()`)
2. Verify opening range is being calculated correctly
3. Ensure `InpUseRangeStops` setting matches your preference

## Version History

### Version 1.00 (2026-02-18)
- Initial production release
- Core opening range breakout functionality
- Multi-symbol support
- Dynamic position sizing
- Comprehensive parameter controls
- Full error handling

## Support & Contribution

For issues, suggestions, or contributions, please use the GitHub repository.

## License

This Expert Advisor is provided as-is without warranty of any kind.

---

**Author**: Based on TSM Opening Range Breakout by P.J. Kaufman  
**Implementation**: Production-grade MQL5 conversion  
**Platform**: MetaTrader 5  
**Language**: MQL5 (strict mode)

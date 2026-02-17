# EA MT5 Pro - Quick Start Guide

## Prerequisites

- MetaTrader 5 platform installed
- Active trading account (demo or live)
- Basic understanding of forex trading and risk management

## Installation Steps

### 1. Locate Your MT5 Data Folder

**Windows:**
- Open MT5
- Go to `File` → `Open Data Folder`
- Navigate to `MQL5\Experts`

**Mac:**
- Open Finder
- Press `Cmd + Shift + G`
- Paste: `~/Library/Application Support/MetaQuotes/Terminal/`
- Find your terminal instance folder
- Navigate to `MQL5/Experts`

### 2. Copy the EA File

1. Download `EA_ImpulseZigZag.mq5`
2. Copy it to the `MQL5\Experts` folder
3. Restart MT5 or click `Refresh` in the Navigator panel

### 3. Compile the EA

1. Open MetaEditor (F4 or click icon in MT5 toolbar)
2. Find `EA_ImpulseZigZag.mq5` in the Navigator
3. Double-click to open
4. Press F7 or click `Compile` button
5. Check for "0 error(s), 0 warning(s)" in the Toolbox

## First Time Setup

### Step 1: Open an M5 Chart

1. In MT5, open a chart for your desired symbol (e.g., EURUSD)
2. **IMPORTANT**: Set timeframe to **M5 (5 minutes)**
   - Right-click chart → Timeframe → M5
   - Or use toolbar: M5 button

### Step 2: Attach the EA

1. In Navigator panel, expand `Expert Advisors`
2. Drag `EA_ImpulseZigZag` onto your M5 chart
3. Configuration window will appear

### Step 3: Configure Basic Settings

**For First Test (Conservative):**

```
Trading Mode:
- Arrow Mode: ARROW_CONTINUATION
- Trade Direction: BOTH

Entry Time:
- Entry Hour: 16 (adjust to your preferred server time)
- Entry Minute: 30
- One Trade Per Day: true

Risk Management:
- Risk Percent: 0.5 (start small!)
- Fixed Lot: 0.0 (auto sizing)
- Risk Reward Ratio: 2.0

Safety:
- Max Spread Points: 30
```

### Step 4: Enable Automated Trading

1. Click `Tools` → `Options` → `Expert Advisors`
2. Check: ✅ Allow automated trading
3. Check: ✅ Allow DLL imports (if needed)
4. Click OK

5. Click the `AutoTrading` button in MT5 toolbar (should turn green)

### Step 5: Verify EA is Running

Look for in the chart corner:
- EA name: "EA_ImpulseZigZag"
- Smiley face: 😊 (not ❌)

Check the `Experts` tab in Terminal (Ctrl+T):
```
════════════════════════════════════════
EA IMPULSE ZIGZAG - INITIALIZED
════════════════════════════════════════
Symbol: EURUSD
Timeframe: M5
...
```

## Understanding the Trading Process

### Phase 1: Waiting for Entry Time
- EA monitors the clock
- At configured time (e.g., 16:30), it checks for impulse candle
- **Console**: "New day - Trading status reset"

### Phase 2: Impulse Detection
- EA analyzes the just-closed M5 candle
- Validates: size (ATR), body %, spread
- **Console**: "=== IMPULSE CANDLE DETECTED ===" (if valid)

### Phase 3: ZigZag Formation
- EA waits for pullback patterns
- First pullback: 35-65% retracement
- Second pullback: lower high (bearish) or higher low (bullish)
- **Console**: "Pullback 1 detected..." → "Pullback 2 detected..."

### Phase 4: Trigger
- EA sets trigger level
- Waits for price to hit trigger
- **Console**: "🟢 BUY TRIGGER ACTIVATED!" or "🔴 SELL TRIGGER ACTIVATED!"

### Phase 5: Execution
- EA sends market order
- Sets SL and TP automatically
- **Console**: "✅ TRADE EXECUTED!"

## Monitoring Your EA

### What to Watch

**Terminal → Experts Tab:**
- Real-time EA log messages
- Impulse detections
- Trade execution confirmations

**Terminal → Trade Tab:**
- Active positions
- SL and TP levels

**Terminal → History Tab:**
- Closed trades
- Profit/loss

### Understanding Log Messages

**Normal Operation:**
```
New day - Trading status reset
Impulse detected - Waiting for pullback
Pullback 1 detected - Waiting for pullback 2
ZigZag complete - Waiting for trigger
🟢 BUY TRIGGER ACTIVATED!
✅ TRADE EXECUTED!
```

**No Trade Scenarios:**
```
Range too small: [value] < min: [value]
  → Candle not strong enough

Body too weak: [value]%
  → Not enough momentum

Spread too high: [value]
  → Wait for better market conditions

Timeout pullback - Abandoning
  → ZigZag didn't form in time
```

## Configuration for Different Scenarios

### Aggressive Trading (Higher Risk)
```
Risk Percent: 2.0
Impulse Min ATR Mult: 1.5
Pullback Max Bars: 8
Risk Reward Ratio: 1.5
```

### Conservative Trading (Lower Risk)
```
Risk Percent: 0.5
Impulse Min ATR Mult: 2.0
Pullback Max Bars: 5
Risk Reward Ratio: 3.0
One Trade Per Day: true
```

### Reversal Mode (Counter-Trend)
```
Arrow Mode: ARROW_REVERSAL
Risk Percent: 1.0
Risk Reward Ratio: 2.0
```

### Buy Only / Sell Only
```
Trade Direction: BUY_ONLY
  (or SELL_ONLY for bearish bias)
```

## Time Settings Tips

### Finding Your Broker's Server Time

1. In MT5, look at bottom-right corner
2. Note the displayed time
3. Compare with your local time
4. Calculate offset

**Example:**
- Your local time: 10:30 AM EST
- MT5 shows: 15:30
- Server offset: +5 hours (GMT+0)

### Popular Trading Times

**London Open:** 08:00 GMT → Adjust to your server time
**New York Open:** 13:00 GMT → Adjust to your server time
**Asian Session:** 00:00 GMT → Adjust to your server time

### Example Configuration for New York Open

If your server is GMT+2:
```
Entry Hour: 15 (13:00 GMT + 2 hours)
Entry Minute: 0
```

## Troubleshooting

### ❌ EA Not Initializing

**Error: "EA must be attached to M5 timeframe"**
- **Fix**: Change chart to M5 timeframe

**Error: "Failed to create ATR indicator handle"**
- **Fix**: Restart MT5, reattach EA

### 😐 EA Shows Sad Face

- Check AutoTrading is enabled (green button)
- Check chart is M5 timeframe
- Look in Experts tab for error messages

### 📊 No Trades Executing

**Possible Reasons:**
1. Not at entry time yet
2. No valid impulse detected
3. ZigZag structure not forming
4. Spread too high
5. Already traded today (if OneTradePerDay = true)

**What to Do:**
- Monitor Experts tab for messages
- Try different entry time
- Adjust impulse detection parameters
- Check spread during your trading session

### ⚠️ Order Rejected

**Common Retcodes:**
- `TRADE_RETCODE_INVALID_STOPS`: Adjust TriggerBufferPoints
- `TRADE_RETCODE_NO_MONEY`: Insufficient margin
- `TRADE_RETCODE_MARKET_CLOSED`: Outside trading hours

## Safety Checklist

✅ **Before Going Live:**

1. [ ] Tested on demo account for at least 1 week
2. [ ] Understand all parameter settings
3. [ ] Verified entry time matches your strategy
4. [ ] Set appropriate risk percent (0.5-1% recommended)
5. [ ] Checked broker's spread during your trading hours
6. [ ] Verified broker allows automated trading
7. [ ] Confirmed lot size calculations are correct
8. [ ] Know how to disable EA in emergency (AutoTrading button)

## Performance Optimization

### Weekly Review

Check:
- Win rate (aim for 40%+ with 2:1 R:R)
- Average trade quality
- False signals vs valid trades

### Parameter Tuning

**If too many false signals:**
- Increase `ImpulseMinATRMult` to 2.0
- Increase `ImpulseBodyPercent` to 70%

**If missing good trades:**
- Decrease `ImpulseMinATRMult` to 1.6
- Increase `PullbackMaxRetrace` to 0.70

**If stopped out too often:**
- Change `SLMode` to SL_ON_PULLBACK_EXTREME
- Adjust `RiskRewardRatio` to 1.5

## Getting Help

### Check Logs First
Always review the Experts tab for detailed information about why the EA made (or didn't make) a decision.

### Common Questions

**Q: Can I run this on multiple charts?**
A: Yes, but use different MagicNumber for each instance.

**Q: Can I change settings while EA is running?**
A: Yes, but must remove and reattach EA for changes to take effect.

**Q: Does it work on all symbols?**
A: Designed for forex pairs, but can work on indices, commodities, etc.

**Q: What's the minimum account size?**
A: Depends on broker, but $500+ recommended for proper risk management.

## Next Steps

1. ✅ Run on demo for 1-2 weeks
2. ✅ Keep trading journal of EA signals
3. ✅ Backtest on historical data (if available)
4. ✅ Fine-tune parameters for your symbol/timeframe
5. ✅ Start with small live account
6. ✅ Scale up gradually as you gain confidence

## Important Reminders

⚠️ **Never risk more than you can afford to lose**
⚠️ **Always use a stop loss (EA does this automatically)**
⚠️ **Monitor your trades, especially initially**
⚠️ **Markets can be unpredictable**
⚠️ **Past performance ≠ future results**

---

**Good luck with your trading!** 🚀

For detailed documentation, see `EA_ImpulseZigZag_README.md`

# MT5 Breakout EA - System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    MT5 BREAKOUT TRADING SYSTEM                   │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                     CUSTOM INDICATOR LAYER                       │
│                                                                  │
│  ┌────────────────────────────────────────────────────────┐    │
│  │              DeltaVolume.mq5                            │    │
│  │  ┌──────────────────────────────────────────────┐      │    │
│  │  │  INPUTS:                                      │      │    │
│  │  │  - ResetPeriod (0=never, 1=daily, 2=weekly) │      │    │
│  │  │  - DeltaColorPositive                        │      │    │
│  │  │  - DeltaColorNegative                        │      │    │
│  │  └──────────────────────────────────────────────┘      │    │
│  │                                                          │    │
│  │  ┌──────────────────────────────────────────────┐      │    │
│  │  │  CALCULATIONS:                                │      │    │
│  │  │  1. Price Action Analysis                    │      │    │
│  │  │     - Bullish: close > open                  │      │    │
│  │  │     - Bearish: close < open                  │      │    │
│  │  │  2. Delta = TickVolume × ClosePosition       │      │    │
│  │  │  3. Cumulative Delta (running sum)           │      │    │
│  │  └──────────────────────────────────────────────┘      │    │
│  │                                                          │    │
│  │  ┌──────────────────────────────────────────────┐      │    │
│  │  │  OUTPUTS:                                     │      │    │
│  │  │  - DeltaBuffer[] (histogram)                 │      │    │
│  │  │  - CumulativeDeltaBuffer[] (line)           │      │    │
│  │  │  - ZeroBuffer[] (reference)                 │      │    │
│  │  └──────────────────────────────────────────────┘      │    │
│  └────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
                              ▼
                    [Indicator Data Feed]
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    EXPERT ADVISOR LAYER                          │
│                                                                  │
│  ┌────────────────────────────────────────────────────────┐    │
│  │         EA_BreakoutDeltaVolume.mq5                      │    │
│  │                                                          │    │
│  │  ┌──────────────────────────────────────────────┐      │    │
│  │  │  BREAKOUT SETTINGS:                           │      │    │
│  │  │  - BOoption (1=Fixed, 2=Volatility)          │      │    │
│  │  │  - FixedPoint / VolPeriod                    │      │    │
│  │  │  - BreakoutFactor                            │      │    │
│  │  └──────────────────────────────────────────────┘      │    │
│  │                                                          │    │
│  │  ┌──────────────────────────────────────────────┐      │    │
│  │  │  TRADING LOGIC:                               │      │    │
│  │  │                                               │      │    │
│  │  │  1. Monitor Daily Open Price                 │      │    │
│  │  │  2. Calculate Breakout Levels:               │      │    │
│  │  │     - Long: Open + BreakoutLevel             │      │    │
│  │  │     - Short: Open - BreakoutLevel            │      │    │
│  │  │                                               │      │    │
│  │  │  3. Check Delta Confirmation:                │      │    │
│  │  │     ┌─────────────────────────────┐          │      │    │
│  │  │     │ IF UseDeltaFilter = true:   │          │      │    │
│  │  │     │ - Long: CumDelta > 0        │          │      │    │
│  │  │     │ - Short: CumDelta < 0       │          │      │    │
│  │  │     │ - Recent Delta aligns       │          │      │    │
│  │  │     └─────────────────────────────┘          │      │    │
│  │  │                                               │      │    │
│  │  │  4. Optional Inside Day Filter               │      │    │
│  │  │  5. Entry Execution                          │      │    │
│  │  │  6. Position Management                      │      │    │
│  │  │  7. End-of-Day Exit (if enabled)             │      │    │
│  │  └──────────────────────────────────────────────┘      │    │
│  └────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
                              ▼
                      [Trade Execution]
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                        MT5 BROKER                                │
└─────────────────────────────────────────────────────────────────┘


═══════════════════════════════════════════════════════════════════
                         TRADING FLOW
═══════════════════════════════════════════════════════════════════

NEW DAY
  │
  ├─► Store Yesterday's High/Low
  │
  ├─► Check Inside Day Condition
  │   (Yesterday H < Day Before H AND Yesterday L > Day Before L)
  │
  ├─► Initialize Today's Data
  │   - Today Open
  │   - Breakout Level (Fixed or ATR-based)
  │
  └─► Reset Order Flags

EVERY TICK
  │
  ├─► Update Today's High/Low
  │
  ├─► Check Delta Volume Indicator
  │   - Get Delta Values
  │   - Get Cumulative Delta
  │
  ├─► Check Breakout Levels
  │   │
  │   ├─► LONG SIGNAL?
  │   │   Price >= Open + BreakoutLevel
  │   │   AND CumulativeDelta > 0 (bullish)
  │   │   AND Recent Delta > 0
  │   │   AND Inside Day OK (if required)
  │   │   → OPEN LONG POSITION
  │   │
  │   └─► SHORT SIGNAL?
  │       Price <= Open - BreakoutLevel
  │       AND CumulativeDelta < 0 (bearish)
  │       AND Recent Delta < 0
  │       AND Inside Day OK (if required)
  │       → OPEN SHORT POSITION
  │
  └─► Check End-of-Day Exit
      If Time >= SessionEnd AND HoldOvernight = false
      → CLOSE ALL POSITIONS


═══════════════════════════════════════════════════════════════════
                        FILE DEPENDENCIES
═══════════════════════════════════════════════════════════════════

EA_BreakoutDeltaVolume.mq5  ──requires──►  DeltaVolume.mq5
                                               │
                                               └─► Must be compiled
                                                   and in Indicators
                                                   folder


═══════════════════════════════════════════════════════════════════
                      INSTALLATION DIAGRAM
═══════════════════════════════════════════════════════════════════

1. Copy Files:
   DeltaVolume.mq5 ──────────► MQL5/Indicators/
   EA_BreakoutDeltaVolume.mq5 ► MQL5/Experts/

2. Compile (F7):
   DeltaVolume.mq5 ──────────► DeltaVolume.ex5
   EA_BreakoutDeltaVolume.mq5 ► EA_BreakoutDeltaVolume.ex5

3. Apply:
   Chart ◄─── Drag EA ◄─── Navigator/Expert Advisors

4. Configure:
   - Set Breakout Options
   - Set Delta Filter Options
   - Set Trading Rules
   - Enable AutoTrading

5. Monitor:
   - Check Delta Volume window
   - Monitor EA logs (Experts tab)
   - Review positions in Terminal


═══════════════════════════════════════════════════════════════════
                    KEY FEATURES SUMMARY
═══════════════════════════════════════════════════════════════════

✓ Two Breakout Methods (Fixed Point / Volatility)
✓ Delta Volume Confirmation
✓ Cumulative Delta Trend Analysis
✓ Inside Day Filter
✓ Hold Overnight Option
✓ End-of-Day Exit Logic
✓ Position Reversal Support
✓ Magic Number Support
✓ Configurable Slippage
✓ Professional Error Handling
✓ Comprehensive Logging

```

**Status: PRODUCTION READY** ✅

# TSM Opening Range Breakout - Architecture Diagram

## System Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                         OnTick() - Main Loop                     │
└─────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Risk Engine: Update Stats                     │
│  • Check daily/weekly P&L                                        │
│  • Reset counters if new period                                  │
│  • Pause trading if limits exceeded                              │
└─────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
                            Is Paused? ───YES──> Exit
                                  │
                                  NO
                                  ▼
┌─────────────────────────────────────────────────────────────────┐
│                  Regime Engine: Market Analysis                  │
│  • Calculate current ATR                                         │
│  • Calculate average ATR (20-period)                             │
│  • Compute volatility ratio (ATR/ATR_avg)                        │
│  • Check if volatility in acceptable range                       │
│  • Adjust risk if volatility too high                            │
│  • Get higher timeframe trend direction                          │
└─────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
                       Conditions OK? ───NO──> Exit
                                  │
                                  YES
                                  ▼
┌─────────────────────────────────────────────────────────────────┐
│                 Signal Engine: Update OR & Check                 │
│  • Update Opening Range (OR)                                     │
│    - Track high/low during OR period                             │
│    - Define OR at end of period                                  │
│    - Apply range compression filter                              │
│  • Check for breakout                                            │
│    - Compare price to OR high/low                                │
│    - Generate buy/sell signal                                    │
└─────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
                       Signal Exists? ───NO──> Manage Position
                                  │
                                  YES
                                  ▼
┌─────────────────────────────────────────────────────────────────┐
│            Execution Engine: Check Conditions                     │
│  • Verify not already in position                                │
│  • Check spread (must be < max)                                  │
│  • Validate execution readiness                                  │
└─────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
                          Can Execute? ───NO──> Exit
                                  │
                                  YES
                                  ▼
┌─────────────────────────────────────────────────────────────────┐
│              Risk Engine: Calculate Position Size                 │
│  • Get base risk percentage                                      │
│  • Adjust for current volatility                                 │
│  • Adjust for account drawdown                                   │
│  • Check consecutive losses                                      │
│  • Calculate lot size:                                           │
│    Lots = (Balance × Risk%) / (SL × TickValue)                  │
│  • Normalize to broker limits                                    │
└─────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
                           Lots > 0? ───NO──> Exit
                                  │
                                  YES
                                  ▼
┌─────────────────────────────────────────────────────────────────┐
│              Execution Engine: Open Position                      │
│  • Verify HTF alignment with signal                              │
│  • Calculate SL and TP levels                                    │
│  • Execute market order (Buy/Sell)                               │
│  • Store position ticket                                         │
│  • Mark breakout as processed                                    │
└─────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────┐
│            Execution Engine: Manage Position                      │
│  • Monitor position status                                       │
│  • Detect when position closes                                   │
│  • Update consecutive losses counter                             │
│  • Reset position tracking                                       │
└─────────────────────────────────────────────────────────────────┘
```

## Module Interactions

```
┌──────────────────┐
│  Signal Engine   │──────┐
│  (ORB Logic)     │      │
└──────────────────┘      │
                          ▼
                    ┌──────────────┐
┌──────────────────┐│              │
│  Regime Engine   ││  OnTick()    │
│  (Market Filter) ││  Main Loop   │
└──────────────────┘│              │
                    └──────────────┘
┌──────────────────┐      │
│   Risk Engine    │      │
│  (Position Size) │◄─────┘
└──────────────────┘      │
                          │
┌──────────────────┐      │
│ Execution Engine │◄─────┘
│ (Order Mgmt)     │
└──────────────────┘
```

## Data Flow

```
Market Data ──> ATR Indicator ──> Regime Engine ──> Volatility Ratio
                                                   │
                                                   ▼
Price Action ──> Signal Engine ──> Breakout Signal ──> Execution Check
                      │                                     │
                      │                                     ▼
                      └──> OR Range ──> Risk Engine ──> Lot Size ──> Order
                                            │
Account Data ──────────────────────────────┘
```

## State Machine

```
┌─────────────┐
│  INIT       │
└──────┬──────┘
       │
       ▼
┌─────────────┐     New Day
│  WAITING    │◄────────────┐
│  FOR OR     │             │
└──────┬──────┘             │
       │ OR Period Start    │
       ▼                    │
┌─────────────┐             │
│  BUILDING   │             │
│  OR RANGE   │             │
└──────┬──────┘             │
       │ OR Period End      │
       ▼                    │
┌─────────────┐             │
│  OR         │             │
│  DEFINED    │             │
└──────┬──────┘             │
       │ Breakout Detected  │
       ▼                    │
┌─────────────┐             │
│  POSITION   │             │
│  OPEN       │             │
└──────┬──────┘             │
       │ Position Closed    │
       ▼                    │
┌─────────────┐             │
│  COMPLETE   │─────────────┘
└─────────────┘
```

## Risk Management Layers

```
Level 1: Spread Filter
   │
   ▼
Level 2: Volatility Filter (Regime Engine)
   │
   ▼
Level 3: Range Compression Filter
   │
   ▼
Level 4: HTF Alignment Filter
   │
   ▼
Level 5: Dynamic Position Sizing
   │
   ▼
Level 6: Drawdown Protection
   │
   ▼
Level 7: Consecutive Loss Protection
   │
   ▼
Level 8: Daily Loss Limit
   │
   ▼
Level 9: Weekly Loss Limit
   │
   ▼
Execute Trade
```

## Opening Range Timeline

```
Time:  09:00           10:00           10:15
       │               │               │
       ▼               ▼               ▼
       ┌───────────────┐
       │  OR Building  │
       │  Track H/L    │
       └───────────────┘
                       ┌───────────────┐
                       │  OR Defined   │
                       │  H: 1.1050    │
                       │  L: 1.1035    │
                       └───────────────┘
                                       ┌───────────────┐
                                       │  Breakout!    │
                                       │  Price: 1.1051│
                                       │  Open BUY     │
                                       └───────────────┘
```

## Volatility Regime Impact

```
ATR Ratio (Current/Avg)
  
  3.0+ │ ──────────────────────────── Extreme (Risk: 0.33×)
       │
  2.5  │ ──────────────────────────── High (Risk: Reduced)
       │                               
  2.0  │                               
       │ ████████████████████████████ Normal Range
  1.0  │ ████████████████████████████ (Risk: 1.0×)
       │ ████████████████████████████
  0.5  │                               
       │
  0.3  │ ──────────────────────────── Low (Trading Blocked)
       │
  0.0  └─────────────────────────────────────────────►

       Low Vol    Normal Vol    High Vol    Extreme
       (Blocked)  (Trade)       (Reduced)   (Minimal)
```

## Position Sizing Example

```
Account Balance: $10,000
Risk Percentage: 1.0%
Risk Amount: $100

Opening Range:
  High: 1.10500
  Low:  1.10350
  Range: 150 points

BUY Signal at: 1.10520

Stop Loss: 1.10350 (170 points)
Take Profit: 1.10860 (340 points, 2:1 ratio)

Calculation:
  Risk Amount: $100
  SL Points: 170
  Tick Value: $1 (for standard lot)
  
  Lots = $100 / (170 × $1)
  Lots = 0.59
  
  Normalized: 0.50 lots (after rounding)

Final Position:
  Type: BUY
  Lots: 0.50
  Entry: 1.10520
  SL: 1.10350 (-170 pts = -$85)
  TP: 1.10860 (+340 pts = +$170)
  R:R = 2:1
```

## Daily Risk Tracking

```
Day Start Balance: $10,000
Daily Loss Limit: 3% = $300

Trades:
  09:30 BUY  → Closed at Loss:  -$50  (Daily P&L: -$50)
  10:45 SELL → Closed at Loss:  -$80  (Daily P&L: -$130)
  11:30 BUY  → Closed at Win:   +$120 (Daily P&L: -$10)
  14:15 SELL → Closed at Loss:  -$60  (Daily P&L: -$70)
  15:00 BUY  → Closed at Loss:  -$90  (Daily P&L: -$160)
  16:30 SELL → Closed at Loss:  -$150 (Daily P&L: -$310) ← LIMIT HIT!
  
  EA pauses trading for rest of day
  
Next Day:
  Daily P&L reset to $0
  Trading resumed
```

## Consecutive Loss Protection

```
Trade Sequence:

#1: Loss → Counter = 1 → Continue
#2: Loss → Counter = 2 → Continue  
#3: Loss → Counter = 3 → STOP! (Max reached)
#4: Blocked (consecutive loss limit)
#5: Blocked (consecutive loss limit)
...

Next Signal After Win:
#6: Win → Counter = 0 → Resume normal trading
#7: Loss → Counter = 1 → Continue
#8: Win → Counter = 0 → Continue
```

## Module Responsibility Matrix

```
┌─────────────────┬──────────┬──────────┬──────────┬──────────┐
│                 │ Signal   │ Regime   │ Risk     │ Execution│
├─────────────────┼──────────┼──────────┼──────────┼──────────┤
│ Track OR        │    ✓     │          │          │          │
│ Detect Breakout │    ✓     │          │          │          │
│ Filter Range    │    ✓     │          │          │          │
├─────────────────┼──────────┼──────────┼──────────┼──────────┤
│ Calc ATR        │          │    ✓     │          │          │
│ Check Volatility│          │    ✓     │          │          │
│ HTF Filter      │          │    ✓     │          │          │
├─────────────────┼──────────┼──────────┼──────────┼──────────┤
│ Calc Lots       │          │          │    ✓     │          │
│ Track DD        │          │          │    ✓     │          │
│ Check Limits    │          │          │    ✓     │          │
│ Count Losses    │          │          │    ✓     │          │
├─────────────────┼──────────┼──────────┼──────────┼──────────┤
│ Check Spread    │          │          │          │    ✓     │
│ Place Order     │          │          │          │    ✓     │
│ Set SL/TP       │          │          │          │    ✓     │
│ Monitor Position│          │          │          │    ✓     │
└─────────────────┴──────────┴──────────┴──────────┴──────────┘
```

## Performance Characteristics

```
Execution Speed: < 50ms (typical)
Memory Usage: Minimal (few KB)
CPU Usage: Low (indicator-based)
Latency Sensitivity: Medium (market orders)
Scalability: Multi-symbol capable

Recommended VPS Specs:
  CPU: 1 core @ 2GHz
  RAM: 1GB
  Network: Stable, low latency
  OS: Windows Server
```

## Integration Points

```
MT5 Platform
     │
     ├─── Trade Library (CTrade)
     │     └─── Order Execution
     │
     ├─── Technical Indicators
     │     ├─── iATR (volatility)
     │     └─── iMA (trend filter)
     │
     ├─── Account Functions
     │     ├─── Balance/Equity
     │     └─── Trade History
     │
     └─── Symbol Information
           ├─── Spread
           ├─── Tick Value
           └─── Lot Limits
```

---

**Legend:**
- ✓ : Primary responsibility
- → : Data flow direction
- │ : Process continuation
- ▼ : Next step
- ◄ : Input source

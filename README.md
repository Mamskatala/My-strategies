# My Trading Strategies Repository

This repository contains professional trading strategies and Expert Advisors.

## Contents

### EA MT5 Pro - Impulse & ZigZag Structure Trading System

A professional MetaTrader 5 Expert Advisor that implements a sophisticated trading strategy based on:
1. **Impulse candle detection** at specific times with ATR validation
2. **ZigZag pullback structure** identification (2-leg pattern)
3. **Strict trigger-based** trade execution

**Main File:** `EA_ImpulseZigZag.mq5`

#### Quick Links
- 📖 [Complete Documentation](EA_ImpulseZigZag_README.md) - Full feature reference
- 🚀 [Quick Start Guide](QUICK_START_GUIDE.md) - Installation and setup
- ✅ [Technical Validation](TECHNICAL_VALIDATION.md) - Specification compliance
- 📊 [Implementation Summary](IMPLEMENTATION_SUMMARY.md) - Project overview

#### Key Features
- ✅ State machine architecture (4 states)
- ✅ Impulse validation (1.8-3.0x ATR, 60% body minimum)
- ✅ ZigZag structure detection (35-65% retracement)
- ✅ Dynamic position sizing with risk management
- ✅ Continuation and Reversal modes
- ✅ One trade per day enforcement (optional)
- ✅ Comprehensive logging and safety filters

#### Installation
1. Copy `EA_ImpulseZigZag.mq5` to your MT5 `Experts` folder
2. Open MetaEditor and compile (F7)
3. Attach to an M5 chart
4. Configure parameters and enable AutoTrading

See [Quick Start Guide](QUICK_START_GUIDE.md) for detailed instructions.

#### Requirements
- MetaTrader 5 platform
- M5 timeframe (mandatory)
- Broker supporting automated trading
- Demo account recommended for testing

## License
Copyright (c) 2026. All rights reserved.

## Disclaimer
Trading involves substantial risk of loss. Past performance is not indicative of future results. Always use proper risk management and never risk more than you can afford to lose.

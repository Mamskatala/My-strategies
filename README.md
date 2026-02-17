# My Trading Strategies Repository

This repository contains professional trading strategies and Expert Advisors.

## Contents

### EA MT5 Pro - Impulse & ZigZag Structure Trading System

A professional MetaTrader 5 Expert Advisor that implements a sophisticated trading strategy based on:
1. **Impulse candle detection** at specific times with ATR validation
2. **ZigZag pullback structure** identification (2-leg pattern)
3. **Strict trigger-based** trade execution

**Main File:** `EA_ImpulseZigZag.mq5`  
**Current Version:** v1.10 (Bug fix release)

#### 🆕 Latest Update (v1.10)
**Fixed:** Critical entry time detection bug - EA now works regardless of when it's attached!  
**Added:** Debug mode for detailed diagnostics (`DebugMode = true`)  
**See:** [FIX_SUMMARY.md](FIX_SUMMARY.md) for details

#### Quick Links
- 📖 [Complete Documentation](EA_ImpulseZigZag_README.md) - Full feature reference
- 🚀 [Quick Start Guide](QUICK_START_GUIDE.md) - Installation and setup
- 🔧 [Troubleshooting Guide (FR)](TROUBLESHOOTING_FR.md) - Si l'EA ne trade pas
- 📋 [Fix Summary](FIX_SUMMARY.md) - v1.10 bug fix details
- ✅ [Technical Validation](TECHNICAL_VALIDATION.md) - Specification compliance
- 📊 [Implementation Summary](IMPLEMENTATION_SUMMARY.md) - Project overview

#### Key Features
- ✅ State machine architecture (4 states)
- ✅ Impulse validation (1.8-3.0x ATR, 60% body minimum)
- ✅ ZigZag structure detection (35-65% retracement)
- ✅ Dynamic position sizing with risk management
- ✅ Continuation and Reversal modes
- ✅ One trade per day enforcement (optional)
- ✅ **Debug mode for diagnostics (NEW in v1.10)**
- ✅ Comprehensive logging and safety filters

#### Installation
1. Copy `EA_ImpulseZigZag.mq5` to your MT5 `Experts` folder
2. Open MetaEditor and compile (F7)
3. Attach to an M5 chart
4. Configure parameters (enable `DebugMode = true` for troubleshooting)
5. Enable AutoTrading

See [Quick Start Guide](QUICK_START_GUIDE.md) for detailed instructions.

#### Troubleshooting
**If the EA is not trading:**
1. Enable `DebugMode = true` in EA settings
2. Check the Experts tab for diagnostic messages
3. See [TROUBLESHOOTING_FR.md](TROUBLESHOOTING_FR.md) for solutions

#### Requirements
- MetaTrader 5 platform
- M5 timeframe (mandatory)
- Broker supporting automated trading
- Demo account recommended for testing

## Version History

### v1.10 (2026-02-17) - Bug Fix Release
- **CRITICAL FIX:** Entry time detection now checks closed candle timestamp
- **NEW:** DebugMode parameter for detailed diagnostics
- **IMPROVED:** Enhanced logging with ✓/✗ symbols
- **ADDED:** French troubleshooting guide

### v1.00 (2026-02-17) - Initial Release
- Complete EA implementation
- State machine architecture
- Impulse + ZigZag detection
- Risk management

## License
Copyright (c) 2026. All rights reserved.

## Disclaimer
Trading involves substantial risk of loss. Past performance is not indicative of future results. Always use proper risk management and never risk more than you can afford to lose.

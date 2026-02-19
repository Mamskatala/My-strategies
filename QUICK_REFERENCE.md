# TSM Opening Range Breakout - Quick Reference Card

## 🎯 What Is This?

A professional Expert Advisor (EA) for MetaTrader 5 that trades Opening Range Breakouts with advanced risk management.

## 📁 Files Overview

| File | Size | Purpose |
|------|------|---------|
| `TSM_OpeningRangeBreakout.mq5` | 23 KB | **Main EA** - Install this in MT5 |
| `TSM_ORB_QuickStart.md` | 6.9 KB | **Start here** - Installation & setup |
| `TSM_ORB_Documentation.md` | 8.8 KB | Complete feature reference |
| `TSM_ORB_Architecture.md` | 19 KB | System diagrams & flows |
| `TSM_ORB_Implementation.md` | 11 KB | Technical details |
| `PRE_COMPILATION_CHECKLIST.md` | 9.6 KB | Verification checklist |

## 🚀 Quick Start (3 Steps)

### 1. Install
```
Copy TSM_OpeningRangeBreakout.mq5 to:
[MT5 Data Folder]/MQL5/Experts/

Compile in MetaEditor (F7)
```

### 2. Configure (Conservative Settings)
```
Opening Range: 60 minutes starting at 9:00
Risk per Trade: 0.5%
Daily Limit: 2%
Max Consecutive Losses: 3
Use HTF Filter: Yes
```

### 3. Test
```
Backtest: EURUSD M5, 1 year
Demo Test: 1 month minimum
Live: Start with minimum lots
```

## 🏗️ Architecture (4 Engines)

### 1️⃣ Signal Engine
- Tracks opening range (first hour)
- Detects breakouts
- Filters false signals

### 2️⃣ Regime Engine
- Measures volatility (ATR)
- Blocks low volatility trades
- Reduces risk in high volatility
- Checks higher timeframe trend

### 3️⃣ Risk Engine
- Calculates position size (% of balance)
- Monitors drawdown
- Tracks consecutive losses
- Enforces daily/weekly limits

### 4️⃣ Execution Engine
- Checks spread
- Places orders
- Manages positions
- Monitors results

## 📊 How It Works

```
9:00 AM  ──► Track opening range (high/low)
10:00 AM ──► Range defined
10:15 AM ──► Price breaks above high ──► BUY signal
         ──► Check conditions ──► Execute trade
         ──► Set SL at range low, TP at 2x SL
```

## 🎛️ Key Parameters

### Most Important Settings

| Parameter | Conservative | Moderate | Aggressive |
|-----------|--------------|----------|------------|
| Risk % | 0.5% | 1.0% | 1.5% |
| Daily Limit | 2% | 3% | 4% |
| Weekly Limit | 4% | 5% | 7% |
| Max Losses | 2 | 3 | 4 |
| Min Volatility | 0.5 | 0.3 | 0.2 |

### Default Values
```
OR Period: 60 minutes
Start Time: 09:00
Min Breakout: 10 points
Risk: 1.0%
TP Ratio: 2:1
Daily Limit: 3%
Weekly Limit: 5%
Max Spread: 20 points
```

## 🛡️ Risk Protection (9 Layers)

1. **Spread Filter** - Blocks high spread
2. **Volatility Filter** - Blocks low volatility
3. **Range Compression** - Blocks tight ranges
4. **HTF Alignment** - Checks trend direction
5. **Dynamic Sizing** - Adjusts lot size
6. **Drawdown Reduction** - Reduces risk at 10% DD
7. **Consecutive Loss** - Stops after 3 losses
8. **Daily Limit** - Pauses at 3% loss
9. **Weekly Limit** - Pauses at 5% loss

## 📈 Expected Performance

### Good Results Look Like:
- Profit Factor: > 1.5
- Win Rate: > 40%
- Max Drawdown: < 15%
- Risk:Reward: 1:2 (default)

### When to Worry:
- Consecutive losses > 5
- Drawdown > 20%
- Profit factor < 1.0
- Win rate < 30%

## ⚠️ Important Rules

### DO:
✅ Test on demo first (1+ month)  
✅ Start with conservative risk (0.5%)  
✅ Monitor daily for first week  
✅ Respect all risk limits  
✅ Use VPS or stable connection  

### DON'T:
❌ Skip demo testing  
❌ Risk more than 2% per trade  
❌ Override risk limits  
❌ Use on exotic pairs without optimization  
❌ Interfere with open trades  

## 🔧 Troubleshooting

### No Trades?
- Check: Volatility ratio (logs)
- Check: Spread (Market Watch)
- Check: HTF filter alignment
- Solution: Review regime conditions

### Too Many Losses?
- Increase: Min breakout distance
- Enable: HTF filter
- Reduce: Risk percentage
- Check: Spread during entry

### Won't Compile?
- Check: MT5 build version (3000+)
- Check: Trade.mqh exists
- Update: MetaTrader 5
- Verify: File encoding (UTF-8)

## 📚 Documentation Guide

**New User?**  
→ Start with `TSM_ORB_QuickStart.md`

**Need Details?**  
→ Read `TSM_ORB_Documentation.md`

**Want to Understand Architecture?**  
→ See `TSM_ORB_Architecture.md`

**Developer?**  
→ Review `TSM_ORB_Implementation.md`

**Before Compiling?**  
→ Check `PRE_COMPILATION_CHECKLIST.md`

## 🎓 Learning Path

### Week 1: Understanding
- Read QuickStart guide
- Study Opening Range concept
- Review parameters

### Week 2: Testing
- Compile EA
- Run backtests (1 year)
- Optimize for your symbol

### Week 3-6: Demo
- Deploy to demo account
- Monitor daily
- Verify all features work

### Week 7+: Live
- Start with minimum risk
- Gradually increase if successful
- Never exceed 2% risk

## 💡 Pro Tips

1. **Start Small**: Begin with 0.5% risk, single pair
2. **Be Patient**: Give it 3+ months to prove itself
3. **Keep Records**: Track trades manually
4. **Don't Interfere**: Let the EA work
5. **Optimize Regularly**: Every 3-6 months
6. **Use VPS**: For 24/7 uptime
7. **Check Logs**: Daily for first month
8. **Respect Limits**: Never override risk controls

## 🎯 Success Criteria

Before going live, ensure:
- [ ] Backtested 1+ year (Profit Factor > 1.5)
- [ ] Demo tested 1+ month (positive results)
- [ ] All risk limits tested and working
- [ ] Comfortable with strategy
- [ ] VPS or stable connection ready
- [ ] Emergency procedures known
- [ ] Account balance sufficient ($1000+)

## 📞 Support Resources

**Documentation:**
- Quick Start: Setup and examples
- Full Docs: Complete feature guide
- Architecture: System diagrams
- Implementation: Technical details

**Testing:**
- Pre-Compilation Checklist
- Backtest recommendations
- Optimization guidelines

**Remember:** This EA is a tool. Success requires proper testing, configuration, and discipline.

## 🔑 Quick Commands

### MT5 MetaEditor
```
F7  - Compile
F5  - Start Strategy Tester
F4  - Open MetaEditor
```

### File Locations
```
EA: [MT5]/MQL5/Experts/TSM_OpeningRangeBreakout.mq5
Logs: [MT5]/MQL5/Logs/
Data: [MT5]/tester/
```

## 📊 Recommended Instruments

**Best for ORB Strategy:**
- EURUSD (most tested)
- GBPUSD (good volatility)
- USDJPY (Asian session)
- Major indices (volatility dependent)

**Optimize Parameters:**
- Each instrument is different
- Backtest before live use
- Consider session times
- Check spread costs

## ⏰ Time Considerations

**Default Opening Range:**
- Start: 09:00 (configurable)
- Duration: 60 minutes (configurable)
- Best for: European/US sessions

**Adjust for:**
- Your timezone
- Market sessions
- Instrument characteristics

---

## 📝 Version Info

**Version:** 2.00  
**Release Date:** 2026-02-19  
**Status:** Production Ready  
**Compatibility:** MT5 Build 3000+

## ✅ Final Checklist

Before first use:
- [ ] Read QuickStart guide
- [ ] Compile successfully
- [ ] Understand parameters
- [ ] Configure conservatively
- [ ] Backtest thoroughly
- [ ] Demo test adequately
- [ ] Start with minimum risk

---

**Remember:** Trading involves risk. Always test thoroughly before live trading. This EA is a professional tool that requires proper setup and monitoring.

**Good luck and trade safely! 🚀**

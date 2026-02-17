# KAMA - Kaufman's Adaptive Moving Average

This repository contains the KAMA (Kaufman's Adaptive Moving Average) indicator converted from TradeStation/EasyLanguage to Pine Script for TradingView.

## Files

- `KAMA_indicator.pine` - Complete Pine Script v5 implementation with information table
- `KAMA_indicator_simple.pine` - Simple version without the information table (cleaner chart)

## Original TradeStation Code

```easylanguage
inputs:period(8), fast(3), slow(30);
 	vars:		efratio(0), smooth(1), fastend(.666), slowend(.0645), diff(0), signal(0), noise(0);
   vars:    KAMA(0), adate(" "), MA(0);

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
		
	adate = ELdatetostring(date);
	if currentbar = 1 then
		print(file("c:\tradestation\KAMA_indicator.csv"), "Date,EFratio,MA,KAMA");
	MA = 2./smooth - 1;
	print(file("c:\tradestation\KAMA_indicator.csv"), adate, ",", efratio:8:4, ",", MA:6:2, ",", KAMA:8:3);
```

## How to Use on TradingView

1. Open TradingView and go to the Pine Editor
2. Copy the contents of `KAMA_indicator.pine`
3. Paste it into the Pine Editor
4. Click "Add to Chart"
5. Adjust the parameters as needed:
   - **Period** (default: 8) - The lookback period for efficiency ratio calculation
   - **Fast** (default: 3) - Fast EMA period
   - **Slow** (default: 30) - Slow EMA period

## Indicator Features

- **KAMA Line**: Blue line showing the adaptive moving average
- **Information Table**: Displays current values for:
  - KAMA value
  - Efficiency Ratio
  - Equivalent MA Period

## About KAMA

The Kaufman Adaptive Moving Average (KAMA) is a moving average designed to account for market noise and volatility. The indicator will closely follow prices when the price swings are relatively small and the noise is low. KAMA will adjust when the price swings widen and follow prices from a greater distance.

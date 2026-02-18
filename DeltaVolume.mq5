//+------------------------------------------------------------------+
//|                                                  DeltaVolume.mq5 |
//|                                        Custom Delta Volume Indicator |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Custom Delta Volume Indicator"
#property link      ""
#property version   "1.02"
#property indicator_separate_window
#property indicator_buffers 4
#property indicator_plots   3

//--- plot Delta
#property indicator_label1  "Delta"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
#property indicator_color1  clrLimeGreen,clrRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  3

//--- plot Cumulative Delta
#property indicator_label2  "Cumulative Delta"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrDodgerBlue
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

//--- plot Zero Line
#property indicator_label3  "Zero"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrGray
#property indicator_style3  STYLE_DOT
#property indicator_width3  1

//--- indicator buffers
double DeltaBuffer[];
double DeltaColorBuffer[];
double CumulativeDeltaBuffer[];
double ZeroBuffer[];

//--- input parameters
input int    ResetPeriod = 0;        // Reset Cumulative Delta (0=never, 1=daily, 2=weekly)

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- indicator buffers mapping
   // Plot 0: Delta histogram (uses buffer 0 for data, buffer 1 for colors)
   SetIndexBuffer(0, DeltaBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, DeltaColorBuffer, INDICATOR_COLOR_INDEX);
   
   // Plot 1: Cumulative Delta line
   SetIndexBuffer(2, CumulativeDeltaBuffer, INDICATOR_DATA);
   
   // Plot 2: Zero line
   SetIndexBuffer(3, ZeroBuffer, INDICATOR_DATA);
   
   //--- set arrays as time series (standard for MT5 indicators)
   ArraySetAsSeries(DeltaBuffer, true);
   ArraySetAsSeries(DeltaColorBuffer, true);
   ArraySetAsSeries(CumulativeDeltaBuffer, true);
   ArraySetAsSeries(ZeroBuffer, true);
   
   //--- set empty value for proper display
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, 0.0);
   
   //--- set index labels
   PlotIndexSetString(0, PLOT_LABEL, "Delta");
   PlotIndexSetString(1, PLOT_LABEL, "Cumulative Delta");
   PlotIndexSetString(2, PLOT_LABEL, "Zero");
   
   //--- set first bar index (start drawing from bar 1 to avoid issues)
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, 1);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, 1);
   PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, 0);
   
   //--- set indicator digits
   IndicatorSetInteger(INDICATOR_DIGITS, 0);
   
   //--- set indicator name
   IndicatorSetString(INDICATOR_SHORTNAME, "Delta Volume");
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   //--- check for bars count
   if(rates_total < 2)
      return 0;
   
   //--- set arrays as series
   ArraySetAsSeries(time, true);
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(tick_volume, true);
      
   //--- determine how many bars to calculate
   int limit;
   if(prev_calculated == 0)
   {
      limit = rates_total - 1;
      // Initialize all buffers with zero (not EMPTY_VALUE for histograms)
      for(int i = 0; i < rates_total; i++)
      {
         DeltaBuffer[i] = 0.0;
         DeltaColorBuffer[i] = 0;
         CumulativeDeltaBuffer[i] = 0.0;
         ZeroBuffer[i] = 0.0;
      }
   }
   else
   {
      limit = rates_total - prev_calculated;
   }
   
   //--- main calculation loop (from oldest to newest with time series)
   for(int i = limit; i >= 0; i--)
   {
      //--- Calculate Delta (approximation based on price action)
      // If close > open: bullish bar, delta is positive
      // If close < open: bearish bar, delta is negative
      // We use tick_volume as approximation since real volume data may not be available
      
      double delta = 0.0;
      
      if(close[i] > open[i])
      {
         // Bullish bar - assume buying pressure
         double range = high[i] - low[i];
         if(range > 0)
         {
            double close_position = (close[i] - low[i]) / range;
            delta = tick_volume[i] * close_position;
         }
         else
         {
            delta = tick_volume[i] * 0.5; // Neutral if no range
         }
      }
      else if(close[i] < open[i])
      {
         // Bearish bar - assume selling pressure
         double range = high[i] - low[i];
         if(range > 0)
         {
            double close_position = (high[i] - close[i]) / range;
            delta = -tick_volume[i] * close_position;
         }
         else
         {
            delta = -tick_volume[i] * 0.5; // Neutral if no range
         }
      }
      else
      {
         // Doji bar - neutral
         delta = 0;
      }
      
      DeltaBuffer[i] = delta;
      
      //--- Set color based on delta value
      // 0 = first color (green for positive), 1 = second color (red for negative)
      if(delta >= 0)
         DeltaColorBuffer[i] = 0; // Green
      else
         DeltaColorBuffer[i] = 1; // Red
      
      //--- Calculate Cumulative Delta
      if(i == rates_total - 1) // Oldest bar
      {
         CumulativeDeltaBuffer[i] = delta;
      }
      else
      {
         // Check for reset conditions
         bool shouldReset = false;
         
         if(ResetPeriod == 1) // Daily reset
         {
            MqlDateTime dt_current, dt_prev;
            TimeToStruct(time[i], dt_current);
            TimeToStruct(time[i+1], dt_prev); // Previous bar in time series
            if(dt_current.day != dt_prev.day)
               shouldReset = true;
         }
         else if(ResetPeriod == 2) // Weekly reset
         {
            MqlDateTime dt_current, dt_prev;
            TimeToStruct(time[i], dt_current);
            TimeToStruct(time[i+1], dt_prev);
            if(dt_current.day_of_week < dt_prev.day_of_week)
               shouldReset = true;
         }
         
         if(shouldReset)
            CumulativeDeltaBuffer[i] = delta;
         else
            CumulativeDeltaBuffer[i] = CumulativeDeltaBuffer[i+1] + delta; // Add to previous
      }
      
      //--- Zero line
      ZeroBuffer[i] = 0;
   }
   
   //--- return value of prev_calculated for next call
   return(rates_total);
}
//+------------------------------------------------------------------+

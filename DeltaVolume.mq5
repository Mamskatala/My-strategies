//+------------------------------------------------------------------+
//|                                                  DeltaVolume.mq5 |
//|                                        Custom Delta Volume Indicator |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Custom Delta Volume Indicator"
#property link      ""
#property version   "1.00"
#property indicator_separate_window
#property indicator_buffers 3
#property indicator_plots   3

//--- plot Delta
#property indicator_label1  "Delta"
#property indicator_type1   DRAW_HISTOGRAM
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- plot Cumulative Delta
#property indicator_label2  "Cumulative Delta"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrRed
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
   SetIndexBuffer(0, DeltaBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, CumulativeDeltaBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, ZeroBuffer, INDICATOR_DATA);
   
   //--- set index labels
   PlotIndexSetString(0, PLOT_LABEL, "Delta");
   PlotIndexSetString(1, PLOT_LABEL, "Cumulative Delta");
   PlotIndexSetString(2, PLOT_LABEL, "Zero");
   
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
      
   //--- starting position for calculation
   int start_pos = prev_calculated - 1;
   if(start_pos < 0)
      start_pos = 0;
   
   //--- main calculation loop
   for(int i = start_pos; i < rates_total; i++)
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
         double close_position = (close[i] - low[i]) / (range > 0 ? range : 1);
         delta = tick_volume[i] * close_position;
      }
      else if(close[i] < open[i])
      {
         // Bearish bar - assume selling pressure
         double range = high[i] - low[i];
         double close_position = (high[i] - close[i]) / (range > 0 ? range : 1);
         delta = -tick_volume[i] * close_position;
      }
      else
      {
         // Doji bar - neutral
         delta = 0;
      }
      
      DeltaBuffer[i] = delta;
      
      //--- Calculate Cumulative Delta
      if(i == 0)
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
            TimeToStruct(time[i-1], dt_prev);
            if(dt_current.day != dt_prev.day)
               shouldReset = true;
         }
         else if(ResetPeriod == 2) // Weekly reset
         {
            MqlDateTime dt_current, dt_prev;
            TimeToStruct(time[i], dt_current);
            TimeToStruct(time[i-1], dt_prev);
            if(dt_current.day_of_week < dt_prev.day_of_week)
               shouldReset = true;
         }
         
         if(shouldReset)
            CumulativeDeltaBuffer[i] = delta;
         else
            CumulativeDeltaBuffer[i] = CumulativeDeltaBuffer[i-1] + delta;
      }
      
      //--- Zero line
      ZeroBuffer[i] = 0;
   }
   
   //--- return value of prev_calculated for next call
   return(rates_total);
}
//+------------------------------------------------------------------+

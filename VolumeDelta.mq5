//+------------------------------------------------------------------+
//|                                           VolumeDelta.mq5        |
//|                              Custom Volume Delta Indicator       |
//|                                                                   |
//+------------------------------------------------------------------+
#property copyright "Volume Delta Indicator"
#property link      ""
#property version   "1.00"
#property indicator_separate_window
#property indicator_buffers 4
#property indicator_plots   3

//--- Plot Volume Delta
#property indicator_label1  "Volume Delta"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
#property indicator_color1  clrLime,clrRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Plot Cumulative Volume Delta
#property indicator_label2  "Cumulative VD"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrYellow
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

//--- Plot Zero Line
#property indicator_label3  "Zero"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrGray
#property indicator_style3  STYLE_DOT
#property indicator_width3  1

//--- Input parameters
input int    VDPeriod = 14;              // Period for cumulative calculation
input bool   ShowCumulative = true;      // Show cumulative volume delta
input double AlertThreshold = 1000.0;    // Alert threshold (0 = disabled)

//--- Indicator buffers
double VolumeDeltaBuffer[];              // Volume Delta values
double VolumeDeltaColors[];              // Color buffer
double CumulativeVDBuffer[];             // Cumulative Volume Delta
double ZeroBuffer[];                     // Zero line

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Indicator buffers mapping
   SetIndexBuffer(0, VolumeDeltaBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, VolumeDeltaColors, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, CumulativeVDBuffer, INDICATOR_DATA);
   SetIndexBuffer(3, ZeroBuffer, INDICATOR_DATA);
   
   //--- Set indicator digits
   IndicatorSetInteger(INDICATOR_DIGITS, 0);
   
   //--- Set plot visibility
   PlotIndexSetInteger(2, PLOT_DRAW_TYPE, ShowCumulative ? DRAW_LINE : DRAW_NONE);
   
   //--- Set indicator name
   IndicatorSetString(INDICATOR_SHORTNAME, "Volume Delta(" + IntegerToString(VDPeriod) + ")");
   
   //--- Initialize arrays
   ArraySetAsSeries(VolumeDeltaBuffer, true);
   ArraySetAsSeries(VolumeDeltaColors, true);
   ArraySetAsSeries(CumulativeVDBuffer, true);
   ArraySetAsSeries(ZeroBuffer, true);
   
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
   //--- Set arrays as series
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(tick_volume, true);
   ArraySetAsSeries(volume, true);
   
   //--- Calculate starting position
   int start = prev_calculated > 0 ? prev_calculated - 1 : 0;
   
   //--- Main calculation loop
   for(int i = start; i < rates_total; i++)
   {
      int pos = rates_total - 1 - i;
      
      //--- Calculate Volume Delta for current bar
      double vd = 0;
      
      // Use real volume if available, otherwise use tick volume
      long vol = (volume[pos] > 0) ? volume[pos] : tick_volume[pos];
      
      // Simple Volume Delta calculation
      // Positive if close > open (buying pressure)
      // Negative if close < open (selling pressure)
      if(close[pos] > open[pos])
      {
         vd = vol;  // Bullish bar - buying volume
      }
      else if(close[pos] < open[pos])
      {
         vd = -vol;  // Bearish bar - selling volume
      }
      else
      {
         vd = 0;  // Neutral bar - doji
      }
      
      //--- Store Volume Delta
      VolumeDeltaBuffer[pos] = vd;
      
      //--- Set color based on value
      VolumeDeltaColors[pos] = (vd >= 0) ? 0 : 1;  // 0=Green, 1=Red
      
      //--- Calculate Cumulative Volume Delta
      double cumulativeVD = 0;
      for(int j = 0; j < VDPeriod && (pos + j) < rates_total; j++)
      {
         long vol_j = (volume[pos + j] > 0) ? volume[pos + j] : tick_volume[pos + j];
         
         if(close[pos + j] > open[pos + j])
         {
            cumulativeVD += vol_j;
         }
         else if(close[pos + j] < open[pos + j])
         {
            cumulativeVD -= vol_j;
         }
      }
      
      CumulativeVDBuffer[pos] = cumulativeVD;
      
      //--- Zero line
      ZeroBuffer[pos] = 0;
      
      //--- Alert if threshold is crossed
      if(AlertThreshold > 0 && i == rates_total - 1)  // Only for the latest bar
      {
         static double lastVD = 0;
         
         if(lastVD <= AlertThreshold && cumulativeVD > AlertThreshold)
         {
            Alert("Volume Delta crossed above ", AlertThreshold, " on ", Symbol());
         }
         else if(lastVD >= -AlertThreshold && cumulativeVD < -AlertThreshold)
         {
            Alert("Volume Delta crossed below ", -AlertThreshold, " on ", Symbol());
         }
         
         lastVD = cumulativeVD;
      }
   }
   
   //--- Return value of prev_calculated for next call
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Get Volume Delta value for use in EA                             |
//+------------------------------------------------------------------+
double GetVolumeDelta(int shift = 0)
{
   return VolumeDeltaBuffer[shift];
}

//+------------------------------------------------------------------+
//| Get Cumulative Volume Delta value for use in EA                  |
//+------------------------------------------------------------------+
double GetCumulativeVolumeDelta(int shift = 0)
{
   return CumulativeVDBuffer[shift];
}

//+------------------------------------------------------------------+

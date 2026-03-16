//+------------------------------------------------------------------+
//|                          Gartley_EA.mq5                          |
//|     Expert Advisor - Gartley Pattern (Bearish & Bullish)         |
//|     Version 5.1 - Professional Filters Added                     |
//|     Tous les objets préfixés "Gartley_"                          |
//+------------------------------------------------------------------+
#property copyright "Gartley EA v5.1"
#property version   "5.10"
#property strict

//+------------------------------------------------------------------+
//| INPUTS                                                            |
//+------------------------------------------------------------------+
input group "=== TIMEFRAMES ACTIFS ==="
input bool   Use_M1   = true;
input bool   Use_M2   = true;
input bool   Use_M5   = true;
input bool   Use_M15  = true;
input bool   Use_M30  = true;
input bool   Use_H1   = true;
input bool   Use_H4   = true;

input group "=== DETECTION DU PATTERN ==="
input int    SwingLB_M1   = 3;
input int    SwingLB_M2   = 3;
input int    SwingLB_M5   = 3;
input int    SwingLB_M15  = 3;
input int    SwingLB_M30  = 3;
input int    SwingLB_H1   = 3;
input int    SwingLB_H4   = 4;
input int    MaxBars_M1   = 600;
input int    MaxBars_M2   = 600;
input int    MaxBars_M5   = 600;
input int    MaxBars_M15  = 400;
input int    MaxBars_M30  = 300;
input int    MaxBars_H1   = 260;
input int    MaxBars_H4   = 200;
input double FibTolerance = 0.06;
input bool   TradeBearish = true;
input bool   TradeBullish = true;

input group "=== RATIOS FIBONACCI ==="
input double AB_XA_Ratio  = 0.618;
input double CB_AB_1      = 0.382;
input double CB_AB_2      = 0.500;
input double CB_AB_3      = 0.618;
input double CB_AB_4      = 0.707;
input double CB_AB_5      = 0.786;
input double CB_AB_6      = 0.886;
input double CD_BC_1      = 1.130;
input double CD_BC_2      = 1.270;
input double CD_BC_3      = 1.410;
input double CD_BC_4      = 1.618;
input double DA_XA_Ratio  = 0.786;
input double DA_XA_Tol    = 0.06;

input group "=== GESTION DES TRADES ==="
input bool   UseAutoLot   = false;
input double RiskPercent  = 1.0;
input double Lot_M1   = 0.02;
input double Lot_M2   = 0.02;
input double Lot_M5   = 0.03;
input double Lot_M15  = 0.05;
input double Lot_M30  = 0.07;
input double Lot_H1   = 0.10;
input double Lot_H4   = 0.12;
input double SLpips_M1   = 8.0;
input double SLpips_M2   = 9.0;
input double SLpips_M5   = 12.0;
input double SLpips_M15  = 18.0;
input double SLpips_M30  = 22.0;
input double SLpips_H1   = 30.0;
input double SLpips_H4   = 45.0;
input double TP1_Ratio   = 0.382;
input double TP2_Ratio   = 0.618;
input bool   UseBreakEven = true;
input double BE_Pips     = 4.0;

input group "=== ENTREE ==="
input bool   RequireTurnAtD = false;
input double TurnConfirmPct = 0.002;
input int    MaxBarsAfterD  = 3;

input group "=== FILTRES ==="
input bool   UseHTF_Filter     = true;
input bool   UseSpreadFilter   = true;
input bool   UseSessionFilter  = true;
input bool   TradeAsianSession = false;
input bool   TradeEuroSession  = true;
input bool   TradeUSSession    = true;
input double MaxSpr_M1   = 12.0;
input double MaxSpr_M2   = 12.0;
input double MaxSpr_M5   = 15.0;
input double MaxSpr_M15  = 18.0;
input double MaxSpr_M30  = 20.0;
input double MaxSpr_H1   = 25.0;
input double MaxSpr_H4   = 30.0;

input group "=== MAX POSITIONS PAR TF ==="
input int    MaxPos_M1   = 1;
input int    MaxPos_M2   = 1;
input int    MaxPos_M5   = 1;
input int    MaxPos_M15  = 1;
input int    MaxPos_M30  = 1;
input int    MaxPos_H1   = 1;
input int    MaxPos_H4   = 1;

input group "=== AFFICHAGE ==="
input bool   DrawPattern     = true;
input bool   EnableAlerts    = true;
input color  BearLineColor   = clrRed;
input color  BullLineColor   = clrDodgerBlue;
input color  PRZ_Color       = clrGold;
input color  FibLabelColor   = clrWhite;
input int    LineWidth       = 2;

input group "=== MAGIC NUMBERS ==="
input int    Magic_M1   = 504001;
input int    Magic_M2   = 504002;
input int    Magic_M5   = 504005;
input int    Magic_M15  = 504015;
input int    Magic_M30  = 504030;
input int    Magic_H1   = 504101;
input int    Magic_H4   = 504104;

input group "=== PROFESSIONAL FILTERS ==="
input bool   UseProFilters          = true;
input double StrictFibTolerance     = 0.03;
input int    MinPivotBars           = 3;
input double MinPatternRangePips    = 20.0;
input double PRZ_ClusterPips        = 6.0;
input bool   UseCandleConfirm       = true;
input double WickToBodyRatio        = 1.5;
input double MinConfirmBodyPips     = 2.0;

//+------------------------------------------------------------------+
//| PREFIX UNIQUE POUR TOUS LES OBJETS                               |
//+------------------------------------------------------------------+
#define OBJ_PREFIX "Gartley_"

//+------------------------------------------------------------------+
//| STRUCTURES                                                        |
//+------------------------------------------------------------------+
struct GartleyPattern
{
   bool            isBearish;
   ENUM_TIMEFRAMES tf;
   int             barX, barA, barB, barC, barD;
   double          priceX, priceA, priceB, priceC, priceD;
   double          PRZ_high, PRZ_low;
   double          r_AB_XA, r_CB_AB, r_CD_BC, r_DA_XA;
   bool            isValid;
   bool            tradeEntered;
   bool            entryFailed;
   int             barsAfterD;
   int             magic;
   datetime        detectedTime;
   bool            confirmed;
};

//+------------------------------------------------------------------+
//| GLOBALS                                                           |
//+------------------------------------------------------------------+
GartleyPattern g_pat[];
int            g_patCount         = 0;
int            g_activePatIndex   = -1;   // index du pattern affiché
datetime       g_activePatTime    = 0;    // temps de détection du pattern affiché

datetime g_lastBar_M1=0, g_lastBar_M2=0, g_lastBar_M5=0, g_lastBar_M15=0;
datetime g_lastBar_M30=0, g_lastBar_H1=0, g_lastBar_H4=0;

double shP_M1[];  int shB_M1[];  int shC_M1=0;  double slP_M1[];  int slB_M1[];  int slC_M1=0;
double shP_M2[];  int shB_M2[];  int shC_M2=0;  double slP_M2[];  int slB_M2[];  int slC_M2=0;
double shP_M5[];  int shB_M5[];  int shC_M5=0;  double slP_M5[];  int slB_M5[];  int slC_M5=0;
double shP_M15[]; int shB_M15[]; int shC_M15=0; double slP_M15[]; int slB_M15[]; int slC_M15=0;
double shP_M30[]; int shB_M30[]; int shC_M30=0; double slP_M30[]; int slB_M30[]; int slC_M30=0;
double shP_H1[];  int shB_H1[];  int shC_H1=0;  double slP_H1[];  int slB_H1[];  int slC_H1=0;
double shP_H4[];  int shB_H4[];  int shC_H4=0;  double slP_H4[];  int slB_H4[];  int slC_H4=0;

//+------------------------------------------------------------------+
//| INIT / DEINIT                                                     |
//+------------------------------------------------------------------+
int OnInit()
{
   ArrayResize(g_pat, 0);
   g_patCount = 0;
   g_activePatIndex = -1;
   g_activePatTime  = 0;
   DeleteAllGartleyObjects();
   Print("===== Gartley EA v5.1 Professional Filters =====");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   DeleteAllGartleyObjects();
   Print("===== Gartley EA STOP =====");
}

//+------------------------------------------------------------------+
//| Supprime TOUS les objets préfixés "Gartley_"                     |
//+------------------------------------------------------------------+
void DeleteAllGartleyObjects()
{
   int total = ObjectsTotal(0, 0, -1);
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, 0, -1);
      if(StringFind(name, OBJ_PREFIX) == 0)
         ObjectDelete(0, name);
   }
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| PROFESSIONAL FILTERS                                              |
//+------------------------------------------------------------------+
bool PassStrictFibFilter(GartleyPattern &p)
{
   if(MathAbs(p.r_AB_XA - 0.618) > StrictFibTolerance) return false;

   double cmin = 0.382 - StrictFibTolerance;
   double cmax = 0.886 + StrictFibTolerance;
   if(p.r_CB_AB < cmin || p.r_CB_AB > cmax) return false;

   if(MathAbs(p.r_DA_XA - 0.786) > StrictFibTolerance) return false;

   return true;
}

bool PassPivotQualityFilter(GartleyPattern &p)
{
   if(MathAbs(p.barX - p.barA) < MinPivotBars) return false;
   if(MathAbs(p.barA - p.barB) < MinPivotBars) return false;
   if(MathAbs(p.barB - p.barC) < MinPivotBars) return false;
   if(MathAbs(p.barC - p.barD) < MinPivotBars) return false;

   double maxP = MathMax(MathMax(MathMax(MathMax(p.priceX, p.priceA), p.priceB), p.priceC), p.priceD);
   double minP = MathMin(MathMin(MathMin(MathMin(p.priceX, p.priceA), p.priceB), p.priceC), p.priceD);

   double pip = SymbolInfoDouble(Symbol(), SYMBOL_POINT) * 10.0;
   double rangePips = (maxP - minP) / pip;

   return (rangePips >= MinPatternRangePips);
}

bool PassPRZConfluenceFilter(GartleyPattern &p)
{
   double xa = (p.isBearish ? (p.priceX - p.priceA) : (p.priceA - p.priceX));
   if(xa <= 0.0) return false;

   double fib786 = p.isBearish
                   ? (p.priceA + xa * 0.786)
                   : (p.priceA - xa * 0.786);

   double bc = (p.isBearish ? (p.priceB - p.priceC) : (p.priceC - p.priceB));
   if(bc <= 0.0) return false;

   double ext127 = p.isBearish ? (p.priceC + bc * 1.27) : (p.priceC - bc * 1.27);
   double ext1618= p.isBearish ? (p.priceC + bc * 1.618): (p.priceC - bc * 1.618);

   double ab = (p.isBearish ? (p.priceB - p.priceA) : (p.priceA - p.priceB));
   double abcd = p.isBearish ? (p.priceC + ab) : (p.priceC - ab);

   double levels[3];
   levels[0] = fib786;
   levels[1] = (MathAbs(p.priceD - ext127) <= MathAbs(p.priceD - ext1618)) ? ext127 : ext1618;
   levels[2] = abcd;

   double maxL = MathMax(levels[0], MathMax(levels[1], levels[2]));
   double minL = MathMin(levels[0], MathMin(levels[1], levels[2]));

   double pip = SymbolInfoDouble(Symbol(), SYMBOL_POINT) * 10.0;
   double cluster = PRZ_ClusterPips * pip;

   return ((maxL - minL) <= cluster);
}

bool PassAllProFilters(GartleyPattern &p)
{
   if(!UseProFilters) return true;
   if(!PassStrictFibFilter(p)) return false;
   if(!PassPivotQualityFilter(p)) return false;
   if(!PassPRZConfluenceFilter(p)) return false;
   return true;
}

bool CandleConfirmOK(GartleyPattern &p)
{
   if(!UseCandleConfirm) return true;

   int shift = 1; // last closed candle
   double open = iOpen(Symbol(), p.tf, shift);
   double close = iClose(Symbol(), p.tf, shift);
   double high = iHigh(Symbol(), p.tf, shift);
   double low  = iLow(Symbol(), p.tf, shift);

   double body = MathAbs(close - open);
   double upper = high - MathMax(open, close);
   double lower = MathMin(open, close) - low;

   double pip = SymbolInfoDouble(Symbol(), SYMBOL_POINT) * 10.0;
   if(body < MinConfirmBodyPips * pip) return false;

   // Pin bar confirmation
   if(p.isBearish)
   {
      if(close < open && upper >= body * WickToBodyRatio && high >= p.priceD) return true;
   }
   else
   {
      if(close > open && lower >= body * WickToBodyRatio && low <= p.priceD) return true;
   }

   // Engulfing confirmation
   double o2 = iOpen(Symbol(), p.tf, shift + 1);
   double c2 = iClose(Symbol(), p.tf, shift + 1);
   if(p.isBearish && close < open && close < o2 && open > c2) return true;
   if(!p.isBearish && close > open && close > o2 && open < c2) return true;

   return false;
}

//+------------------------------------------------------------------+
//| ONTICK                                                            |
//+------------------------------------------------------------------+
void OnTick()
{
   ManageTrades();

   ProcessTF(PERIOD_M1,  Use_M1,  g_lastBar_M1,  SwingLB_M1,  MaxBars_M1,  shP_M1,  shB_M1,  shC_M1,  slP_M1,  slB_M1,  slC_M1);
   ProcessTF(PERIOD_M2,  Use_M2,  g_lastBar_M2,  SwingLB_M2,  MaxBars_M2,  shP_M2,  shB_M2,  shC_M2,  slP_M2,  slB_M2,  slC_M2);
   ProcessTF(PERIOD_M5,  Use_M5,  g_lastBar_M5,  SwingLB_M5,  MaxBars_M5,  shP_M5,  shB_M5,  shC_M5,  slP_M5,  slB_M5,  slC_M5);
   ProcessTF(PERIOD_M15, Use_M15, g_lastBar_M15, SwingLB_M15, MaxBars_M15, shP_M15, shB_M15, shC_M15, slP_M15, slB_M15, slC_M15);
   ProcessTF(PERIOD_M30, Use_M30, g_lastBar_M30, SwingLB_M30, MaxBars_M30, shP_M30, shB_M30, shC_M30, slP_M30, slB_M30, slC_M30);
   ProcessTF(PERIOD_H1,  Use_H1,  g_lastBar_H1,  SwingLB_H1,  MaxBars_H1,  shP_H1,  shB_H1,  shC_H1,  slP_H1,  slB_H1,  slC_H1);
   ProcessTF(PERIOD_H4,  Use_H4,  g_lastBar_H4,  SwingLB_H4,  MaxBars_H4,  shP_H4,  shB_H4,  shC_H4,  slP_H4,  slB_H4,  slC_H4);

   for(int i = 0; i < g_patCount; i++)
   {
      if(!g_pat[i].isValid || g_pat[i].tradeEntered || g_pat[i].entryFailed) continue;
      TryEntry(i);
   }
}

//+------------------------------------------------------------------+
//| ProcessTF                                                         |
//+------------------------------------------------------------------+
void ProcessTF(ENUM_TIMEFRAMES tf, bool enabled, datetime &lastBar,
               int swingLB, int maxBars,
               double &shP[], int &shB[], int &shCnt,
               double &slP[], int &slB[], int &slCnt)
{
   if(!enabled) return;
   datetime t = iTime(Symbol(), tf, 0);
   if(t == 0 || t == lastBar) return;
   lastBar = t;

   BuildSwings(tf, swingLB, maxBars, shP, shB, shCnt, slP, slB, slCnt);
   if(TradeBearish) ScanBearish(tf, shP, shB, shCnt, slP, slB, slCnt);
   if(TradeBullish) ScanBullish(tf, shP, shB, shCnt, slP, slB, slCnt);
}

//+------------------------------------------------------------------+
//| Swings                                                            |
//+------------------------------------------------------------------+
void BuildSwings(ENUM_TIMEFRAMES tf, int lb, int maxBars,
                 double &shP[], int &shB[], int &shCnt,
                 double &slP[], int &slB[], int &slCnt)
{
   int bars = Bars(Symbol(), tf);
   if(bars < lb * 2 + 10) return;

   shCnt = 0; slCnt = 0;
   ArrayResize(shP, 0); ArrayResize(shB, 0);
   ArrayResize(slP, 0); ArrayResize(slB, 0);

   int limit = MathMin(bars - lb - 2, maxBars * 3);
   for(int i = lb; i < limit; i++)
   {
      if(IsSwingHigh(tf, i, lb))
      {
         ArrayResize(shP, shCnt + 1); ArrayResize(shB, shCnt + 1);
         shP[shCnt] = iHigh(Symbol(), tf, i);
         shB[shCnt] = i;
         shCnt++;
      }
      if(IsSwingLow(tf, i, lb))
      {
         ArrayResize(slP, slCnt + 1); ArrayResize(slB, slCnt + 1);
         slP[slCnt] = iLow(Symbol(), tf, i);
         slB[slCnt] = i;
         slCnt++;
      }
   }
}

bool IsSwingHigh(ENUM_TIMEFRAMES tf, int bar, int lb)
{
   double h = iHigh(Symbol(), tf, bar);
   for(int j = 1; j <= lb; j++)
   {
      if(iHigh(Symbol(), tf, bar - j) > h) return false;
      if(iHigh(Symbol(), tf, bar + j) > h) return false;
   }
   return true;
}

bool IsSwingLow(ENUM_TIMEFRAMES tf, int bar, int lb)
{
   double l = iLow(Symbol(), tf, bar);
   for(int j = 1; j <= lb; j++)
   {
      if(iLow(Symbol(), tf, bar - j) < l) return false;
      if(iLow(Symbol(), tf, bar + j) < l) return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| ScanBearish                                                       |
//+------------------------------------------------------------------+
void ScanBearish(ENUM_TIMEFRAMES tf,
                 double &shP[], int &shB[], int shCnt,
                 double &slP[], int &slB[], int slCnt)
{
   for(int xi = 0; xi < shCnt; xi++)
   {
      double pX = shP[xi]; int bX = shB[xi];
      for(int ai = 0; ai < slCnt; ai++)
      {
         double pA = slP[ai]; int bA = slB[ai];
         if(bA >= bX || pA >= pX) continue;
         double XA = pX - pA;
         if(XA < _Point * 10) continue;

         for(int bi = 0; bi < shCnt; bi++)
         {
            double pB = shP[bi]; int bB = shB[bi];
            if(bB >= bA || pB >= pX || pB <= pA) continue;
            double BA = pB - pA;
            if(!RatioOK(BA / XA, AB_XA_Ratio, FibTolerance)) continue;

            for(int ci = 0; ci < slCnt; ci++)
            {
               double pC = slP[ci]; int bC = slB[ci];
               if(bC >= bB || pC <= pA || pC >= pB) continue;
               double CB = pB - pC;
               if(!CB_AB_OK(CB / BA)) continue;
               double BC = CB;

               double D_daxa = pA + XA * DA_XA_Ratio;
               double D_tol  = XA * DA_XA_Tol;

               for(int di = 0; di < shCnt; di++)
               {
                  int bD = shB[di];
                  if(bD >= bC || bD < 1) continue;
                  double hD = iHigh(Symbol(), tf, bD);
                  double lD = iLow(Symbol(),  tf, bD);
                  double pD = (hD + lD) * 0.5;
                  if(pD <= pC) continue;

                  double cd_hi = (hD - pC) / BC;
                  double cd_lo = (lD - pC) / BC;
                  if(!CD_BC_OK(cd_hi, cd_lo)) continue;

                  double da_hi = (hD - pA) / XA;
                  double da_lo = (lD - pA) / XA;
                  if(!DA_XA_OK(da_hi, da_lo)) continue;
                  if(PatExists(bX, bA, bB, bC, bD, true, tf)) continue;

                  GartleyPattern p;
                  FillPattern(p, true, tf, bX, bA, bB, bC, bD,
                              pX, pA, pB, pC, pD,
                              D_daxa - D_tol, D_daxa + D_tol,
                              BA/XA, CB/BA, (cd_hi+cd_lo)*0.5, (da_hi+da_lo)*0.5);
                  RegisterPattern(p);
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| ScanBullish                                                       |
//+------------------------------------------------------------------+
void ScanBullish(ENUM_TIMEFRAMES tf,
                 double &shP[], int &shB[], int shCnt,
                 double &slP[], int &slB[], int slCnt)
{
   for(int xi = 0; xi < slCnt; xi++)
   {
      double pX = slP[xi]; int bX = slB[xi];
      for(int ai = 0; ai < shCnt; ai++)
      {
         double pA = shP[ai]; int bA = shB[ai];
         if(bA >= bX || pA <= pX) continue;
         double XA = pA - pX;
         if(XA < _Point * 10) continue;

         for(int bi = 0; bi < slCnt; bi++)
         {
            double pB = slP[bi]; int bB = slB[bi];
            if(bB >= bA || pB <= pX || pB >= pA) continue;
            double AB = pA - pB;
            if(!RatioOK(AB / XA, AB_XA_Ratio, FibTolerance)) continue;

            for(int ci = 0; ci < shCnt; ci++)
            {
               double pC = shP[ci]; int bC = shB[ci];
               if(bC >= bB || pC >= pA || pC <= pB) continue;
               double CB = pC - pB;
               if(!CB_AB_OK(CB / AB)) continue;
               double BC = CB;

               double D_daxa = pA - XA * DA_XA_Ratio;
               double D_tol  = XA * DA_XA_Tol;

               for(int di = 0; di < slCnt; di++)
               {
                  int bD = slB[di];
                  if(bD >= bC || bD < 1) continue;
                  double hD = iHigh(Symbol(), tf, bD);
                  double lD = iLow(Symbol(),  tf, bD);
                  double pD = (hD + lD) * 0.5;
                  if(pD >= pC) continue;

                  double cd_hi = (pC - lD) / BC;
                  double cd_lo = (pC - hD) / BC;
                  if(!CD_BC_OK(cd_hi, cd_lo)) continue;

                  double da_hi = (pA - lD) / XA;
                  double da_lo = (pA - hD) / XA;
                  if(!DA_XA_OK(da_hi, da_lo)) continue;
                  if(PatExists(bX, bA, bB, bC, bD, false, tf)) continue;

                  GartleyPattern p;
                  FillPattern(p, false, tf, bX, bA, bB, bC, bD,
                              pX, pA, pB, pC, pD,
                              D_daxa - D_tol, D_daxa + D_tol,
                              AB/XA, CB/AB, (cd_hi+cd_lo)*0.5, (da_hi+da_lo)*0.5);
                  RegisterPattern(p);
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| FillPattern                                                       |
//+------------------------------------------------------------------+
void FillPattern(GartleyPattern &p,
                 bool bear, ENUM_TIMEFRAMES tf,
                 int bX, int bA, int bB, int bC, int bD,
                 double pX, double pA, double pB, double pC, double pD,
                 double przLo, double przHi,
                 double rAB, double rCB, double rCD, double rDA)
{
   p.isBearish    = bear;
   p.tf           = tf;
   p.barX = bX; p.barA = bA; p.barB = bB; p.barC = bC; p.barD = bD;
   p.priceX = pX; p.priceA = pA; p.priceB = pB; p.priceC = pC; p.priceD = pD;
   p.PRZ_low      = przLo;
   p.PRZ_high     = przHi;
   p.r_AB_XA      = rAB;
   p.r_CB_AB      = rCB;
   p.r_CD_BC      = rCD;
   p.r_DA_XA      = rDA;
   p.isValid      = true;
   p.tradeEntered = false;
   p.entryFailed  = false;
   p.barsAfterD   = 0;
   p.magic        = TFMagic(tf);
   p.detectedTime = TimeCurrent();
   p.confirmed    = false;
}

//+------------------------------------------------------------------+
//| RegisterPattern — ajoute + redessine si plus récent              |
//+------------------------------------------------------------------+
void RegisterPattern(GartleyPattern &p)
{
   if(!PassAllProFilters(p)) return;

   ArrayResize(g_pat, g_patCount + 1);
   g_pat[g_patCount] = p;
   int newIdx = g_patCount;
   g_patCount++;

   if(p.detectedTime >= g_activePatTime)
   {
      g_activePatIndex = newIdx;
      g_activePatTime  = p.detectedTime;

      if(DrawPattern)
         DrawActivePattern(p);
   }

   string msg = StringFormat("[%s] %s GARTLEY %s | D=%.5f | AB/XA=%.3f CB/AB=%.3f CD/BC=%.3f DA/XA=%.3f",
                             TFLabel(p.tf),
                             (p.isBearish ? "BEARISH" : "BULLISH"),
                             Symbol(), p.priceD,
                             p.r_AB_XA, p.r_CB_AB, p.r_CD_BC, p.r_DA_XA);
   Print(msg);
   if(EnableAlerts) Alert(msg);
}

//+------------------------------------------------------------------+
//| DESSIN — UN SEUL PATTERN ACTIF                                   |
//+------------------------------------------------------------------+
void DrawActivePattern(GartleyPattern &p)
{
   DeleteAllGartleyObjects();

   color lineClr = p.isBearish ? BearLineColor : BullLineColor;
   ENUM_TIMEFRAMES tf = p.tf;
   int digs = (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS);

   datetime tX = iTime(Symbol(), tf, p.barX);
   datetime tA = iTime(Symbol(), tf, p.barA);
   datetime tB = iTime(Symbol(), tf, p.barB);
   datetime tC = iTime(Symbol(), tf, p.barC);
   datetime tD = iTime(Symbol(), tf, p.barD);

   CreateTrendLine(OBJ_PREFIX + "XA", tX, p.priceX, tA, p.priceA, lineClr, STYLE_SOLID, LineWidth);
   CreateTrendLine(OBJ_PREFIX + "AB", tA, p.priceA, tB, p.priceB, lineClr, STYLE_SOLID, LineWidth);
   CreateTrendLine(OBJ_PREFIX + "BC", tB, p.priceB, tC, p.priceC, lineClr, STYLE_SOLID, LineWidth);
   CreateTrendLine(OBJ_PREFIX + "CD", tC, p.priceC, tD, p.priceD, lineClr, STYLE_SOLID, LineWidth);

   CreateTextObj(OBJ_PREFIX + "LBL_X", tX, p.priceX, "X", lineClr, 10);
   CreateTextObj(OBJ_PREFIX + "LBL_A", tA, p.priceA, "A", lineClr, 10);
   CreateTextObj(OBJ_PREFIX + "LBL_B", tB, p.priceB, "B", lineClr, 10);
   CreateTextObj(OBJ_PREFIX + "LBL_C", tC, p.priceC, "C", lineClr, 10);
   CreateTextObj(OBJ_PREFIX + "LBL_D", tD, p.priceD, "D", lineClr, 11);

   double fib618;
   if(p.isBearish)
      fib618 = p.priceA + (p.priceX - p.priceA) * 0.618;
   else
      fib618 = p.priceA - (p.priceA - p.priceX) * 0.618;

   CreateHLine(OBJ_PREFIX + "FIB_618", fib618, lineClr, STYLE_DOT, 1);
   CreateTextObj(OBJ_PREFIX + "FIB_618_LBL", tB, fib618,
                 "0.618 (" + DoubleToString(fib618, digs) + ")",
                 FibLabelColor, 8);

   double fib786;
   if(p.isBearish)
      fib786 = p.priceA + (p.priceX - p.priceA) * 0.786;
   else
      fib786 = p.priceA - (p.priceA - p.priceX) * 0.786;

   CreateHLine(OBJ_PREFIX + "FIB_786", fib786, PRZ_Color, STYLE_DOT, 1);
   CreateTextObj(OBJ_PREFIX + "FIB_786_LBL", tD, fib786,
                 "0.786 (" + DoubleToString(fib786, digs) + ")",
                 FibLabelColor, 8);

   double ext127, ext1618;
   if(p.isBearish)
   {
      ext127  = p.priceC + (p.priceB - p.priceC) * 1.27;
      ext1618 = p.priceC + (p.priceB - p.priceC) * 1.618;
   }
   else
   {
      ext127  = p.priceC - (p.priceC - p.priceB) * 1.27;
      ext1618 = p.priceC - (p.priceC - p.priceB) * 1.618;
   }

   double distTo127  = MathAbs(p.priceD - ext127);
   double distTo1618 = MathAbs(p.priceD - ext1618);

   if(distTo127 <= distTo1618)
   {
      CreateHLine(OBJ_PREFIX + "FIB_EXT", ext127, lineClr, STYLE_DASHDOT, 1);
      CreateTextObj(OBJ_PREFIX + "FIB_EXT_LBL", tC, ext127,
                    "1.27 (" + DoubleToString(ext127, digs) + ")",
                    FibLabelColor, 8);
   }
   else
   {
      CreateHLine(OBJ_PREFIX + "FIB_EXT", ext1618, lineClr, STYLE_DASHDOT, 1);
      CreateTextObj(OBJ_PREFIX + "FIB_EXT_LBL", tC, ext1618,
                    "1.618 (" + DoubleToString(ext1618, digs) + ")",
                    FibLabelColor, 8);
   }

   datetime przRight = tD + PeriodSeconds(tf) * 5;
   CreateRectangle(OBJ_PREFIX + "PRZ_ZONE", tC, p.PRZ_high, przRight, p.PRZ_low, PRZ_Color);

   if(p.isBearish)
   {
      CreateArrow(OBJ_PREFIX + "SIGNAL", tD, p.priceD, 234, BearLineColor, 16);
      CreateTextObj(OBJ_PREFIX + "SIGNAL_LBL", tD,
                    p.priceD + (p.priceX - p.priceA) * 0.03,
                    "SELL [" + TFLabel(tf) + "]",
                    BearLineColor, 12);
   }
   else
   {
      CreateArrow(OBJ_PREFIX + "SIGNAL", tD, p.priceD, 233, BullLineColor, 16);
      CreateTextObj(OBJ_PREFIX + "SIGNAL_LBL", tD,
                    p.priceD - (p.priceA - p.priceX) * 0.03,
                    "BUY [" + TFLabel(tf) + "]",
                    BullLineColor, 12);
   }

   string info = (p.isBearish ? "BEARISH" : "BULLISH") + " GARTLEY [" + TFLabel(tf) + "]\n" +
                 "AB/XA = " + DoubleToString(p.r_AB_XA, 3) + " (0.618)\n" +
                 "CB/AB = " + DoubleToString(p.r_CB_AB, 3) + "\n" +
                 "CD/BC = " + DoubleToString(p.r_CD_BC, 3) + "\n" +
                 "DA/XA = " + DoubleToString(p.r_DA_XA, 3) + " (0.786)\n" +
                 "PRZ = " + DoubleToString(p.PRZ_low, digs) + " - " + DoubleToString(p.PRZ_high, digs);
   CreateComment(OBJ_PREFIX + "INFO", info, lineClr);

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| OBJETS GRAPHIQUES — CRÉATION                                     |
//+------------------------------------------------------------------+
void CreateTrendLine(string name,
                     datetime t1, double p1,
                     datetime t2, double p2,
                     color clr, ENUM_LINE_STYLE style, int width)
{
   ObjectCreate(0, name, OBJ_TREND, 0, t1, p1, t2, p2);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
}

void CreateHLine(string name, double price,
                 color clr, ENUM_LINE_STYLE style, int width)
{
   ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
}

void CreateTextObj(string name, datetime t, double price,
                   string txt, color clr, int fontSize)
{
   ObjectCreate(0, name, OBJ_TEXT, 0, t, price);
   ObjectSetString(0,  name, OBJPROP_TEXT, txt);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0,  name, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT);
}

void CreateRectangle(string name,
                     datetime t1, double p1,
                     datetime t2, double p2,
                     color clr)
{
   ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, p1, t2, p2);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DOT);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_FILL, true);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

void CreateArrow(string name, datetime t, double price,
                 int arrowCode, color clr, int size)
{
   ObjectCreate(0, name, OBJ_ARROW, 0, t, price);
   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, arrowCode);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, size);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_CENTER);
}

void CreateComment(string name, string text, color clr)
{
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetString(0,  name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 10);
   ObjectSetString(0,  name, OBJPROP_FONT, "Consolas");
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, 15);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, 30);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
}

//+------------------------------------------------------------------+
//| ENTRY LOGIC                                                       |
//+------------------------------------------------------------------+
void TryEntry(int idx)
{
   GartleyPattern p = g_pat[idx];

   bool newBar = IsNewBarTF(p.tf);
   if(newBar) g_pat[idx].barsAfterD++;
   int elapsed = g_pat[idx].barsAfterD;

   if(elapsed > MaxBarsAfterD)
   {
      g_pat[idx].entryFailed = true;
      return;
   }

   if(UseCandleConfirm && !g_pat[idx].confirmed)
   {
      if(!newBar) return;
      if(!CandleConfirmOK(p)) return;
      g_pat[idx].confirmed = true;
   }

   if(UseSpreadFilter && !SpreadOK(p.tf)) return;
   if(UseSessionFilter && !InSession()) return;
   if(UseHTF_Filter && !HTFFilterOK(p)) return;
   if(CountPos(p.magic) >= TFMaxPos(p.tf)) return;

   double pt   = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
   double pip  = pt * 10.0;
   int    digs = (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS);
   double ask  = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   double bid  = SymbolInfoDouble(Symbol(), SYMBOL_BID);
   double slPips = TFSLPips(p.tf);
   double defLot = TFLot(p.tf);

   if(RequireTurnAtD)
   {
      double cls1 = iClose(Symbol(), p.tf, 1);
      if(p.isBearish && (p.priceD - cls1) / p.priceD < TurnConfirmPct) return;
      if(!p.isBearish && (cls1 - p.priceD) / p.priceD < TurnConfirmPct) return;
   }

   if(p.isBearish)
   {
      double sl = NormalizeDouble(p.priceD + slPips * pip, digs);
      if(sl <= bid) { g_pat[idx].entryFailed = true; return; }
      double AD  = p.priceD - p.priceA;
      double tp1 = NormalizeDouble(p.priceD - AD * TP1_Ratio, digs);
      double lots = CalcLots(sl, bid, defLot);
      int tk = PlaceTrade(ORDER_TYPE_SELL, lots, bid, sl, tp1,
                          OBJ_PREFIX + TFLabel(p.tf), p.magic);
      if(tk > 0) g_pat[idx].tradeEntered = true;
   }
   else
   {
      double sl = NormalizeDouble(p.priceD - slPips * pip, digs);
      if(sl >= ask) { g_pat[idx].entryFailed = true; return; }
      double AD  = p.priceA - p.priceD;
      double tp1 = NormalizeDouble(p.priceD + AD * TP1_Ratio, digs);
      double lots = CalcLots(sl, ask, defLot);
      int tk = PlaceTrade(ORDER_TYPE_BUY, lots, ask, sl, tp1,
                          OBJ_PREFIX + TFLabel(p.tf), p.magic);
      if(tk > 0) g_pat[idx].tradeEntered = true;
   }
}

//+------------------------------------------------------------------+
//| Trade Execution                                                   |
//+------------------------------------------------------------------+
double CalcLots(double sl, double entry, double defLot)
{
   if(!UseAutoLot) return defLot;
   double bal   = AccountInfoDouble(ACCOUNT_BALANCE);
   double risk  = bal * RiskPercent / 100.0;
   double tVal  = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
   double tSz   = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);
   double dist  = MathAbs(entry - sl);
   if(dist < _Point || tSz < _Point || tVal < _Point) return defLot;
   double lots = risk / (dist / tSz * tVal);
   double minL = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
   double maxL = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
   double stp  = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
   return MathMax(minL, MathMin(maxL, MathRound(lots / stp) * stp));
}

int PlaceTrade(ENUM_ORDER_TYPE type, double lots, double price,
               double sl, double tp, string comment, int magic)
{
   MqlTradeRequest req = {};
   MqlTradeResult  res = {};
   req.action       = TRADE_ACTION_DEAL;
   req.symbol       = Symbol();
   req.volume       = lots;
   req.type         = type;
   req.price        = price;
   req.sl           = sl;
   req.tp           = tp;
   req.comment      = comment;
   req.magic        = (ulong)magic;
   req.deviation    = 30;
   req.type_filling = ORDER_FILLING_IOC;
   if(!OrderSend(req, res))
   {
      req.type_filling = ORDER_FILLING_FOK;
      ResetLastError();
      if(!OrderSend(req, res)) return -1;
   }
   return (int)res.order;
}

bool SetSLTP(ulong ticket, double sl, double tp)
{
   MqlTradeRequest req = {};
   MqlTradeResult  res = {};
   req.action   = TRADE_ACTION_SLTP;
   req.position = ticket;
   req.symbol   = Symbol();
   req.sl       = sl;
   req.tp       = tp;
   return OrderSend(req, res);
}

//+------------------------------------------------------------------+
//| Break-even                                                        |
//+------------------------------------------------------------------+
void ManageTrades()
{
   if(!UseBreakEven) return;
   double pt  = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
   double pip = pt * 10.0;
   int    digs = (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS);

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(!PositionSelectByTicket(tk)) continue;
      if(PositionGetString(POSITION_SYMBOL) != Symbol()) continue;
      if(!IsOurMagic((int)PositionGetInteger(POSITION_MAGIC))) continue;

      double open = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl   = PositionGetDouble(POSITION_SL);
      double tp   = PositionGetDouble(POSITION_TP);
      if(tp <= 0.0) continue;
      long type   = PositionGetInteger(POSITION_TYPE);
      double bid  = SymbolInfoDouble(Symbol(), SYMBOL_BID);
      double ask  = SymbolInfoDouble(Symbol(), SYMBOL_ASK);

      if(type == POSITION_TYPE_SELL)
      {
         double d = open - tp;
         if(d > 0.0 && (open - bid) >= d)
         {
            double nsl = NormalizeDouble(open + BE_Pips * pip, digs);
            if(sl == 0.0 || nsl < sl - pt) SetSLTP(tk, nsl, tp);
         }
      }
      else if(type == POSITION_TYPE_BUY)
      {
         double d = tp - open;
         if(d > 0.0 && (ask - open) >= d)
         {
            double nsl = NormalizeDouble(open - BE_Pips * pip, digs);
            if(sl == 0.0 || nsl > sl + pt) SetSLTP(tk, nsl, tp);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Filters                                                           |
//+------------------------------------------------------------------+
bool SpreadOK(ENUM_TIMEFRAMES tf)
{
   double pt  = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
   double pip = pt * 10.0;
   double spr = (double)SymbolInfoInteger(Symbol(), SYMBOL_SPREAD) * pt / pip;
   return (spr <= TFMaxSpread(tf));
}

bool InSession()
{
   MqlDateTime dt;
   TimeToStruct(TimeGMT(), dt);
   int h = dt.hour;
   if(h >= 0  && h < 8  && TradeAsianSession) return true;
   if(h >= 7  && h < 16 && TradeEuroSession)  return true;
   if(h >= 13 && h < 22 && TradeUSSession)    return true;
   return false;
}

bool HTFFilterOK(GartleyPattern &p)
{
   ENUM_TIMEFRAMES htf = NextHTF(p.tf);
   if(htf == PERIOD_CURRENT) return true;
   int h20 = iMA(Symbol(), htf, 20, 0, MODE_EMA, PRICE_CLOSE);
   int h50 = iMA(Symbol(), htf, 50, 0, MODE_EMA, PRICE_CLOSE);
   double b20[1], b50[1];
   if(CopyBuffer(h20, 0, 1, 1, b20) <= 0) { IndicatorRelease(h20); IndicatorRelease(h50); return true; }
   if(CopyBuffer(h50, 0, 1, 1, b50) <= 0) { IndicatorRelease(h20); IndicatorRelease(h50); return true; }
   IndicatorRelease(h20);
   IndicatorRelease(h50);
   if(p.isBearish && b20[0] >= b50[0]) return false;
   if(!p.isBearish && b20[0] <= b50[0]) return false;
   return true;
}

//+------------------------------------------------------------------+
//| Fibonacci helpers                                                 |
//+------------------------------------------------------------------+
bool RatioOK(double v, double t, double tol) { return MathAbs(v - t) <= tol; }

bool CB_AB_OK(double r)
{
   double t[6] = {CB_AB_1, CB_AB_2, CB_AB_3, CB_AB_4, CB_AB_5, CB_AB_6};
   for(int i = 0; i < 6; i++)
      if(MathAbs(r - t[i]) <= FibTolerance) return true;
   return false;
}

bool CD_BC_OK(double hi, double lo)
{
   if(lo > hi) { double tmp = lo; lo = hi; hi = tmp; }
   double t[4] = {CD_BC_1, CD_BC_2, CD_BC_3, CD_BC_4};
   for(int i = 0; i < 4; i++)
   {
      if(lo <= t[i] && hi >= t[i])        return true;
      if(MathAbs(hi - t[i]) <= FibTolerance) return true;
      if(MathAbs(lo - t[i]) <= FibTolerance) return true;
   }
   return false;
}

bool DA_XA_OK(double hi, double lo)
{
   return (MathAbs(hi - DA_XA_Ratio) <= DA_XA_Tol * 2.0) ||
          (MathAbs(lo - DA_XA_Ratio) <= DA_XA_Tol * 2.0) ||
          (lo <= DA_XA_Ratio && hi >= DA_XA_Ratio);
}

//+------------------------------------------------------------------+
//| TF Mapping helpers                                                |
//+------------------------------------------------------------------+
string TFLabel(ENUM_TIMEFRAMES tf)
{
   if(tf == PERIOD_M1)  return "M1";
   if(tf == PERIOD_M2)  return "M2";
   if(tf == PERIOD_M5)  return "M5";
   if(tf == PERIOD_M15) return "M15";
   if(tf == PERIOD_M30) return "M30";
   if(tf == PERIOD_H1)  return "H1";
   if(tf == PERIOD_H4)  return "H4";
   return EnumToString(tf);
}

ENUM_TIMEFRAMES NextHTF(ENUM_TIMEFRAMES tf)
{
   if(tf == PERIOD_M1)  return PERIOD_M2;
   if(tf == PERIOD_M2)  return PERIOD_M5;
   if(tf == PERIOD_M5)  return PERIOD_M15;
   if(tf == PERIOD_M15) return PERIOD_M30;
   if(tf == PERIOD_M30) return PERIOD_H1;
   if(tf == PERIOD_H1)  return PERIOD_H4;
   return PERIOD_CURRENT;
}

int TFMagic(ENUM_TIMEFRAMES tf)
{
   if(tf == PERIOD_M1)  return Magic_M1;
   if(tf == PERIOD_M2)  return Magic_M2;
   if(tf == PERIOD_M5)  return Magic_M5;
   if(tf == PERIOD_M15) return Magic_M15;
   if(tf == PERIOD_M30) return Magic_M30;
   if(tf == PERIOD_H1)  return Magic_H1;
   return Magic_H4;
}

double TFLot(ENUM_TIMEFRAMES tf)
{
   if(tf == PERIOD_M1)  return Lot_M1;
   if(tf == PERIOD_M2)  return Lot_M2;
   if(tf == PERIOD_M5)  return Lot_M5;
   if(tf == PERIOD_M15) return Lot_M15;
   if(tf == PERIOD_M30) return Lot_M30;
   if(tf == PERIOD_H1)  return Lot_H1;
   return Lot_H4;
}

double TFSLPips(ENUM_TIMEFRAMES tf)
{
   if(tf == PERIOD_M1)  return SLpips_M1;
   if(tf == PERIOD_M2)  return SLpips_M2;
   if(tf == PERIOD_M5)  return SLpips_M5;
   if(tf == PERIOD_M15) return SLpips_M15;
   if(tf == PERIOD_M30) return SLpips_M30;
   if(tf == PERIOD_H1)  return SLpips_H1;
   return SLpips_H4;
}

double TFMaxSpread(ENUM_TIMEFRAMES tf)
{
   if(tf == PERIOD_M1)  return MaxSpr_M1;
   if(tf == PERIOD_M2)  return MaxSpr_M2;
   if(tf == PERIOD_M5)  return MaxSpr_M5;
   if(tf == PERIOD_M15) return MaxSpr_M15;
   if(tf == PERIOD_M30) return MaxSpr_M30;
   if(tf == PERIOD_H1)  return MaxSpr_H1;
   return MaxSpr_H4;
}

int TFMaxPos(ENUM_TIMEFRAMES tf)
{
   if(tf == PERIOD_M1)  return MaxPos_M1;
   if(tf == PERIOD_M2)  return MaxPos_M2;
   if(tf == PERIOD_M5)  return MaxPos_M5;
   if(tf == PERIOD_M15) return MaxPos_M15;
   if(tf == PERIOD_M30) return MaxPos_M30;
   if(tf == PERIOD_H1)  return MaxPos_H1;
   return MaxPos_H4;
}

bool IsOurMagic(int m)
{
   return (m == Magic_M1 || m == Magic_M2 || m == Magic_M5 ||
           m == Magic_M15 || m == Magic_M30 || m == Magic_H1 || m == Magic_H4);
}

bool IsNewBarTF(ENUM_TIMEFRAMES tf)
{
   static datetime lM1=0,lM2=0,lM5=0,lM15=0,lM30=0,lH1=0,lH4=0;
   datetime t = iTime(Symbol(), tf, 0);
   if(tf==PERIOD_M1)  { if(t!=lM1) { lM1=t;  return true; } return false; }
   if(tf==PERIOD_M2)  { if(t!=lM2) { lM2=t;  return true; } return false; }
   if(tf==PERIOD_M5)  { if(t!=lM5) { lM5=t;  return true; } return false; }
   if(tf==PERIOD_M15) { if(t!=lM15){ lM15=t; return true; } return false; }
   if(tf==PERIOD_M30) { if(t!=lM30){ lM30=t; return true; } return false; }
   if(tf==PERIOD_H1)  { if(t!=lH1) { lH1=t;  return true; } return false; }
   if(tf==PERIOD_H4)  { if(t!=lH4) { lH4=t;  return true; } return false; }
   return false;
}

bool PatExists(int bX, int bA, int bB, int bC, int bD, bool bear, ENUM_TIMEFRAMES tf)
{
   for(int i = 0; i < g_patCount; i++)
      if(g_pat[i].isBearish == bear && g_pat[i].tf == tf &&
         g_pat[i].barX == bX && g_pat[i].barA == bA && g_pat[i].barB == bB &&
         g_pat[i].barC == bC && g_pat[i].barD == bD) return true;
   return false;
}

int CountPos(int magic)
{
   int cnt = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong tk = PositionGetTicket(i);
      if(!PositionSelectByTicket(tk)) continue;
      if(PositionGetString(POSITION_SYMBOL) != Symbol()) continue;
      if(PositionGetInteger(POSITION_MAGIC) != (long)magic) continue;
      cnt++;
   }
   return cnt;
}
//+------------------------------------------------------------------+

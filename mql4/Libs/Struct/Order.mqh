//+------------------------------------------------------------------+
//|                                               MODE_DIRECTION.mqh |
//|                                                       Diogo Rolo |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Diogo Rolo"
#property link      "https://www.mql5.com"
#property strict
#include <F1rstMillion/Enum/MODE_DIRECTION.mqh>

struct Order{
   double sl;
   double entry;
   double tp;
   int strategyID;
   int expertID;
   MODE_DIRECTION direction;
   string symbol;
   string description;
};
//+------------------------------------------------------------------+
//|                                                      Library.mqh |
//|                                                       Diogo Rolo |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Diogo Rolo"
#property link      "https://www.mql5.com"
#property strict

#include <F1rstMillion/Library.mqh>
#include <F1rstMillion/Math.mqh>

bool isEngolfingBuy(int shift, ENUM_TIMEFRAMES timeframe){
   return iClose(_Symbol,timeframe,shift + 1) < iOpen(_Symbol,timeframe,shift + 1) &&
            iClose(_Symbol,timeframe,shift + 1) >= iOpen(_Symbol,timeframe,shift) && 
            iOpen(_Symbol,timeframe,shift + 1) <= iClose(_Symbol,timeframe,shift);
}

bool isEngolfingSell(int shift, ENUM_TIMEFRAMES timeframe){
   return iClose(_Symbol,timeframe,shift + 1) > iOpen(_Symbol,timeframe,shift + 1) &&
            iClose(_Symbol,timeframe,shift + 1) <= iOpen(_Symbol,timeframe,shift) && 
            iOpen(_Symbol,timeframe,shift + 1) >= iClose(_Symbol,timeframe,shift);
}

bool isHammer(int shift,double fiboLevel, ENUM_TIMEFRAMES timeframe){
   double fiboValue = fibonacci(iLow(_Symbol,timeframe,shift),iHigh(_Symbol,timeframe,shift),fiboLevel);
   return iClose(_Symbol,timeframe,shift) >= fiboValue && iOpen(_Symbol,timeframe,shift) >= fiboValue;
            
}

bool isStar(int shift,double fiboLevel, ENUM_TIMEFRAMES timeframe){
   double fiboValue = fibonacci(iHigh(_Symbol,timeframe,shift),iLow(_Symbol,timeframe,shift),fiboLevel);
   return iClose(_Symbol,timeframe,shift) <= fiboValue && iOpen(_Symbol,timeframe,shift) <= fiboValue;
            
}

double taHigh(int candel, int lenght, ENUM_TIMEFRAMES timeframe){
   double localHigh = iHigh(_Symbol,timeframe,candel);
   for(int i = candel + 1; i < candel + lenght; i++)
      if (iHigh(_Symbol,timeframe,i) > localHigh)
         localHigh = iHigh(_Symbol,timeframe,i);
   return localHigh;
}

double taLow(int candel, int lenght, ENUM_TIMEFRAMES timeframe){
   double localLow = iLow(_Symbol,timeframe,candel);
   for(int i = candel + 1; i < candel + lenght; i++)
      if (iLow(_Symbol,timeframe,i) < localLow)
         localLow = iLow(_Symbol,timeframe,i);
   return localLow;
}

double taPivotHigh(int lengthLeft, int lengthRight, int candel, ENUM_TIMEFRAMES timeframe){
   return taHigh(candel - lengthLeft, lengthLeft + lengthRight + 1, timeframe);
}

double taPivotLow(int lengthLeft, int lengthRight, int candel, ENUM_TIMEFRAMES timeframe){
   return taLow(candel - lengthLeft, lengthLeft + lengthRight + 1, timeframe);
}
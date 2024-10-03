//+------------------------------------------------------------------+
//|                                                       ZigZag.mqh |
//|                                                       Diogo Rolo |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Diogo Rolo"
#property link      "https://www.mql5.com"
#property strict

#include <F1rstMillion/Lists/DoubleArray.mqh>

int const MARGIN = 2;

class GoldMines{
private:
   datetime LastBar; //variable to allow the method @OnBar() excecute properly
   DoubleArray rsi;
   DoubleArray ma;
   int SIZE;
   int PERIOD;
   int BAND_LENGHT;
   int pointsFile;
   ENUM_TIMEFRAMES TIMEFRAME;
   double getRSI(int shift);
   double getMA(int shift);
   void OnBar(void);
   void OnCalculation(int shift);
   datetime time(int shift);
   double open(int shift);
   double high(int shift);
   double low(int shift);
   double close(int shift);
   long volume(int shift);
public:
   GoldMines();
   GoldMines(int rsiPeriod, int bandLenght, ENUM_TIMEFRAMES timeframe, int size);
   bool isAboveLevel(int shift);
   bool isBellowLevel(int shift);
   bool crossOver(int shift);
   bool crossUnder(int shift);
   bool touchAbove(int shift);
   bool touchBellow(int shift);
   bool isHighsDivergent(int firstPoint, int secundPoint);
   bool isLowsDivergent(int firstPoint, int secundPoint);
   void OnTick();
   void End();
};

GoldMines::GoldMines(void){}

GoldMines::GoldMines(int rsiPeriod, int bandLenght, ENUM_TIMEFRAMES timeframe, int size){
   PERIOD = rsiPeriod;
   BAND_LENGHT = bandLenght;
   TIMEFRAME = timeframe;
   SIZE = size;
   rsi = DoubleArray(SIZE, -1);
   ma = DoubleArray(SIZE, -1);
   for(int i = 100; i > 0; i--)
      OnCalculation(i);
   FileDelete("Backtesting_" +WindowExpertName()+ "\\PointsGoldMine.csv");
   pointsFile = FileOpen("Backtesting_" +WindowExpertName()+ "\\PointsGoldMine.csv",FILE_WRITE|FILE_CSV);
   FileWrite(pointsFile,"Time", "RSI","MA","BounceOver","BounceBellow");
}

double GoldMines::getRSI(int shift){
   return rsi.get(shift - 1);
}

double GoldMines::getMA(int shift){
   return ma.get(shift - 1);
}

bool GoldMines::isAboveLevel(int shift){
   return getMA(shift) <= getRSI(shift);
}

bool GoldMines::isBellowLevel(int shift){
   return getMA(shift) >= getRSI(shift);
}

bool GoldMines::crossOver(int shift){
   return isBellowLevel(shift + 1) && isAboveLevel(shift) && 
            !(getMA(shift) == getRSI(shift) && getMA(shift + 1) == getRSI(shift + 1));
}

bool GoldMines::crossUnder(int shift){
   return isAboveLevel(shift + 1) && isBellowLevel(shift) && 
            !(getMA(shift) == getRSI(shift) && getMA(shift + 1) == getRSI(shift + 1));
}

bool GoldMines::touchBellow(int shift){
   //return crossUnder(shift) && crossOver(shift - 1);
   bool found = false;
   if(shift > 1){
      found = crossUnder(shift) && crossOver(shift - 1);
      if(!found){
         bool foundLeft = crossUnder(shift);
         bool foundRight = crossOver(shift - 1);
         for(int i = 0; i < MARGIN && !found; i++){
            if(crossUnder(shift+i+1))
               foundLeft = true;
            if(shift > 2 + i && crossOver(shift-i-2))
               foundRight = true;
            found = foundLeft && foundRight;
         }
      }
   }
   return found;
}

bool GoldMines::touchAbove(int shift){
   //return crossOver(shift) && crossUnder(shift - 1);
   bool found = false;
   if(shift > 1){
      found = crossOver(shift) && crossUnder(shift - 1);
      if(!found){
         bool foundLeft = crossOver(shift);
         bool foundRight = crossUnder(shift - 1);
         for(int i = 0; i < MARGIN && !found; i++){
            if(crossOver(shift+i+1))
               foundLeft = true;
            if(shift > 2 + i && crossUnder(shift-i-2))
               foundRight = true;
            found = foundLeft && foundRight;
         }
      }
   }
   return found;
}

bool GoldMines::isHighsDivergent(int firstPoint,int secundPoint){
   return high(firstPoint) < high(secundPoint) && getRSI(firstPoint) > getRSI(secundPoint);
}

bool GoldMines::isLowsDivergent(int firstPoint,int secundPoint){
   return low(firstPoint) > low(secundPoint) && getRSI(firstPoint) < getRSI(secundPoint);
}

void GoldMines::OnTick(void){
   if(LastBar != time(0)){
      LastBar = time(0); 
      OnBar();
   }
}

void GoldMines::End(void){
   FileClose(pointsFile);
}

void GoldMines::OnBar(void){
   OnCalculation(1);
   FileWrite(pointsFile,time(MARGIN + 2),getRSI(MARGIN + 2),getMA(MARGIN + 2),touchAbove(MARGIN + 2),touchBellow(MARGIN + 2));
}
void GoldMines::OnCalculation(int shift){
   rsi.removeLast();
   rsi.addFirst(iRSI(_Symbol,TIMEFRAME,PERIOD,PRICE_CLOSE,shift));
   int indexOf = rsi.indexOf(-1);
   if(indexOf > BAND_LENGHT || indexOf == -1){
      double sum = 0;
      for(int i = 0; i < BAND_LENGHT; i++){
         sum += rsi.get(i);
      }
      sum /= BAND_LENGHT;
      ma.removeLast();
      ma.addFirst(sum);
   }
}

datetime GoldMines::time(int shift){return iTime(_Symbol,TIMEFRAME,shift);}
double GoldMines::open(int shift){return iOpen(_Symbol,TIMEFRAME,shift);}
double GoldMines::high(int shift){return iHigh(_Symbol,TIMEFRAME,shift);}
double GoldMines::low(int shift){return iLow(_Symbol,TIMEFRAME,shift);}
double GoldMines::close(int shift){return iClose(_Symbol,TIMEFRAME,shift);}
long GoldMines::volume(int shift){return iVolume(_Symbol,TIMEFRAME,shift);}
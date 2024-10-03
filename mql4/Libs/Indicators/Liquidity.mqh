//+------------------------------------------------------------------+
//|                                                         Bias.mqh |
//|                                                       Diogo Rolo |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Diogo Rolo"
#property link      "https://www.mql5.com"
#property strict

#include "ZigZag.mqh"


class LiquidityArray{
private:
   Points liquidity[];
   int size;
   int maxSize;
   void remove(int pos);
public:
   LiquidityArray();
   void add(Points &liq);
   Points removeAbove(double value);
   Points removeBellow(double value);
   void increment();
   bool contains(int candle);
   bool contains(double value);
   Points getLast();
   int getSize();
   Points get(int pos);
};

LiquidityArray::LiquidityArray(void){
   maxSize = 10;
   size = 0;
   ArrayResize(liquidity,maxSize);
}

void LiquidityArray::add(Points &liq){
   if(size == maxSize){
      maxSize += 10;
      ArrayResize(liquidity, maxSize);
   }
   liquidity[size++] = liq;
}

Points LiquidityArray::removeAbove(double value){
   Points null;
   null.candle = -1;
   null.value = -1;
   Points lastRemoved = null;
   for(int i = size - 1; i >= 0; i--){
      if(liquidity[i].value > value){
         lastRemoved = liquidity[i];
         remove(i);
      }
   }
   return lastRemoved;
}

Points LiquidityArray::removeBellow(double value){
   Points null;
   null.candle = -1;
   null.value = -1;
   Points lastRemoved = null;
   for(int i = size - 1; i >= 0; i--){
      if(liquidity[i].value < value){
         lastRemoved = liquidity[i];
         remove(i);
      }
   }
   return lastRemoved;
}

void LiquidityArray::remove(int pos){
   for(int i = pos; i < size-1; i++)
      liquidity[i] = liquidity[i+1];
   size--;
}

void LiquidityArray::increment(void){
   for(int i = 0; i < size; i++)
      liquidity[i].candle++;
}

bool LiquidityArray::contains(int candle){
   bool found = false;
   for(int i = 0; i < size && !found; i++){
      if(liquidity[i].candle == candle)
         found = true;
   }
   return found;
}

bool LiquidityArray::contains(double value){
   bool found = false;
   for(int i = 0; i < size && !found; i++){
      if(liquidity[i].value == value)
         found = true;
   }
   return found;
}

Points LiquidityArray::getLast(void){
   Points null;
   null.candle = -1;
   null.value = -1;
   if(size > 0)
      return liquidity[size-1];
   else
      return null;
}

int LiquidityArray::getSize(void){
   return size;
}

Points LiquidityArray::get(int pos){
   return liquidity[pos];
}

class Liquidity{
private:
   int pointsFile;
   datetime LastBar; //variable to allow the method @OnBar() excecute properly
   int LENGHT;
   LiquidityArray UpperLiquidity;
   LiquidityArray LowerLiquidity;
   Points LastUpperLiquidity;
   Points LastLowerLiquidity;
   bool isLastRemovedUpperLiq;
   ENUM_TIMEFRAMES TIMEFRAME;
   void initialize(int lenght, ENUM_TIMEFRAMES timeframe);
   void OnBar();
   void updateLiquidity();
   datetime time(int shift);
   double open(int shift);
   double high(int shift);
   double low(int shift);
   double close(int shift);
   long volume(int shift);

public:
   Liquidity();
   Liquidity(int lenght, ENUM_TIMEFRAMES timeframe);
   Liquidity(int lenght, ENUM_TIMEFRAMES timeframe, string fileId);
   void end();
   void OnTick();
   Points getUpperLiquidity();
   Points getLowerLiquidity();
   Points getPreviusUpperLiquidity();
   Points getPreviusLowerLiquidity();
   bool isLastRemovedUpper();
};

Liquidity::Liquidity(void){}

Liquidity::Liquidity(int localLenght, ENUM_TIMEFRAMES timeframe){
   initialize(localLenght,timeframe);
}

Liquidity::Liquidity(int localLenght, ENUM_TIMEFRAMES timeframe,string fileId){
   string name = "Backtesting_" +WindowExpertName()+ "\\PointsLiquidity_" + fileId + ".csv";
   FileDelete(name);
   pointsFile = FileOpen(name,FILE_WRITE|FILE_CSV);
   FileWrite(pointsFile,"Time", "Point 0", "Point 1","Point 2","Point 3","Upper","Lower");
   initialize(localLenght,timeframe);
}

void Liquidity::initialize(int lenght,ENUM_TIMEFRAMES timeframe){
   LENGHT = lenght;
   TIMEFRAME = timeframe;
   Points null;
   null.candle = -1;
   null.value = -1;
   LastLowerLiquidity = null;
   LastUpperLiquidity = null;
   isLastRemovedUpperLiq = false;
}

void Liquidity::end(void){
   
}

void Liquidity::OnTick(void){
   if(LastBar != time(0)){
      LastBar = time(0); 
      OnBar();
   }
}

void Liquidity::OnBar(void){
   UpperLiquidity.increment();
   LowerLiquidity.increment();
   
   updateLiquidity();
   
   Points upperRemoved = UpperLiquidity.removeBellow(Bid);
   Points lowerRemoved =  LowerLiquidity.removeAbove(Bid);
   
   if(upperRemoved.candle != -1 && lowerRemoved.candle != -1)
      isLastRemovedUpperLiq = open(1) < close(1);
   else if (upperRemoved.candle != -1)
      isLastRemovedUpperLiq = true;
   else if (lowerRemoved.candle != -1)
      isLastRemovedUpperLiq = false;
   
   if (upperRemoved.candle != -1)
      LastUpperLiquidity = upperRemoved;
   if (lowerRemoved.candle != -1)
      LastLowerLiquidity = lowerRemoved;
   
   string dataHighs = DoubleToStr(UpperLiquidity.getLast().value);
   string dataLows = DoubleToStr(LowerLiquidity.getLast().value);
   for(int i = 1; i < 5; i++){
      dataHighs += ";";
      if(i < UpperLiquidity.getSize())
         dataHighs += DoubleToStr(UpperLiquidity.get(UpperLiquidity.getSize() - i - 1).value);
      dataLows += ";";
      if(i < LowerLiquidity.getSize())
         dataLows += DoubleToStr(LowerLiquidity.get(LowerLiquidity.getSize() - i - 1).value);
   }
   FileWrite(pointsFile,time(1),dataHighs,dataLows);
}

void Liquidity::updateLiquidity(void){
   int candle = LENGHT + 1;
   double pivotHigh = taPivotHigh(LENGHT,LENGHT, candle, TIMEFRAME);
   double pivotLow = taPivotLow(LENGHT,LENGHT, candle, TIMEFRAME);
   Points high;
   high.candle = candle;
   high.value = high(candle);
   Points low;
   low.candle = candle;
   low.value = low(candle);
   if(pivotHigh == high.value && !UpperLiquidity.contains(high.value)){
      UpperLiquidity.add(high);
   }
   if(pivotLow == low.value && !LowerLiquidity.contains(low.value)){
      LowerLiquidity.add(low);
   }
}

Points Liquidity::getUpperLiquidity(void){
   return UpperLiquidity.getLast();
}

Points Liquidity::getLowerLiquidity(void){
   return LowerLiquidity.getLast();
}

Points Liquidity::getPreviusUpperLiquidity(void){
   return LastUpperLiquidity;
}

Points Liquidity::getPreviusLowerLiquidity(void){
   return LastLowerLiquidity;
}

bool Liquidity::isLastRemovedUpper(void){
   return isLastRemovedUpperLiq;
}

datetime Liquidity::time(int shift){return iTime(_Symbol,TIMEFRAME,shift);}
double Liquidity::open(int shift){return iOpen(_Symbol,TIMEFRAME,shift);}
double Liquidity::high(int shift){return iHigh(_Symbol,TIMEFRAME,shift);}
double Liquidity::low(int shift){return iLow(_Symbol,TIMEFRAME,shift);}
double Liquidity::close(int shift){return iClose(_Symbol,TIMEFRAME,shift);}
long Liquidity::volume(int shift){return iVolume(_Symbol,TIMEFRAME,shift);}
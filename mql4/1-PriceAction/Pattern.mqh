//+------------------------------------------------------------------+
//|                                                      Pattern.mqh |
//|                                                       Diogo Rolo |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Diogo Rolo"
#property link      ""
#property version   "1.00"
#property strict
#include "BarArray.mqh"
#include "Order.mqh"
#include "FractalArray.mqh"

const bool BUY = true;
const bool SELL = false;

const int MAX_FRACTALS = 8;

class Pattern{
private:
   Order order;
   bool thereIsAnyEntry;
   void calculateSmallPattern();
   void calculateBigPattern(ENUM_TIMEFRAMES timeframe);
   void checkPattern(bool type, double high, double low, double higherHigh, double lowerLow, double entry);
public:
   Pattern();
   bool thereIsEntry();
   Order getOrder();
};


Pattern::Pattern(){
   thereIsAnyEntry = false;
   calculateSmallPattern();
   //if(!thereIsAnyEntry)
      //calculateBigPattern(PERIOD_M15);
} 

void Pattern::calculateSmallPattern(){
   double high;
   double low;
   double higherHigh;
   double lowerLow;
   double entry;
   if(bars.getSize()>4){
      bool type = bars.getBarFromFinish(0).isBuy();
      if(type == BUY){
         low = MathMin( bars.getBarFromFinish(3).getLow() , bars.getBarFromFinish(2).getLow() );
         high = MathMax( bars.getBarFromFinish(2).getHigh() , bars.getBarFromFinish(1).getHigh() );
         lowerLow = MathMin( bars.getBarFromFinish(1).getLow() , bars.getBarFromFinish(0).getLow() );
         higherHigh = bars.getBarFromFinish(0).getHigh();
         //The same point of the @high but instead of the wick uses the body
         entry = MathMax(bars.getBarFromFinish(2).getClose() , bars.getBarFromFinish(1).getOpen());
      }
      else{
         high = MathMax( bars.getBarFromFinish(3).getHigh() , bars.getBarFromFinish(2).getHigh() );
         low = MathMin( bars.getBarFromFinish(2).getLow() , bars.getBarFromFinish(1).getLow() );
         higherHigh = MathMax( bars.getBarFromFinish(1).getHigh() , bars.getBarFromFinish(0).getHigh() );
         lowerLow = bars.getBarFromFinish(0).getLow();
         //The same point of the @low but instead of the wick uses the body
         entry = MathMin(bars.getBarFromFinish(2).getClose() , bars.getBarFromFinish(1).getOpen());
      }
   checkPattern(type,high,low,higherHigh,lowerLow,entry);
   }
}

void Pattern::calculateBigPattern(ENUM_TIMEFRAMES timeframe){
   FractalArray upFractals = FractalArray(MAX_FRACTALS);
   FractalArray downFractals = FractalArray(MAX_FRACTALS);
   for(int i=0;i<100 && (!downFractals.isFull() || !upFractals.isFull());i++){
      double downFractal = iFractals(_Symbol,timeframe,MODE_LOWER,i);
      double upFractal = iFractals(_Symbol,timeframe,MODE_UPPER,i);
      if(downFractal > 0 && !downFractals.isFull()){
         downFractals.add(downFractal,i);
      }
      if(upFractal > 0 && !upFractals.isFull()){
         upFractals.add(upFractal,i);
      }
   }
   bool type = false;
   double high;
   double low;
   double higherHigh;
   double lowerLow;
   double entry;
   int i = 0;
   int j = 0;
   int maxFractals = upFractals.getSize() + downFractals.getSize();
   FractalArray fractals = FractalArray(maxFractals);
   for(int k=0;k<maxFractals;k++){
      if(downFractals.getFractalPosition(j) == -1 || (upFractals.getFractalPosition(i) != -1 && upFractals.getFractalPosition(i) < downFractals.getFractalPosition(j))){
         fractals.add(upFractals.getFractal(i),1);
         i++;
      }
      else if(downFractals.getFractalPosition(i) == -1 || (upFractals.getFractalPosition(j) != -1 && upFractals.getFractalPosition(i) > downFractals.getFractalPosition(j))){
         fractals.add(downFractals.getFractal(j),-1);
         j++;
      }
      else{
         if(Open[upFractals.getFractalPosition(i)] < Close[upFractals.getFractalPosition(i)]){
            fractals.add(upFractals.getFractal(i),1);
            i++;
         }
         else{
            fractals.add(downFractals.getFractal(j),-1);
            j++;
         }
         
      }
   }
   fractals.reestructure();
   int size = fractals.getSize();
   if(size >= 4){
      bool dataMakeSense = true;
      if(fractals.getFractalPosition(0) == 1){
         type = BUY;
         higherHigh = fractals.getFractal(0);
         lowerLow = fractals.getFractal(1);
         high = fractals.getFractal(2);
         low = fractals.getFractal(3);
         entry = Close[upFractals.getFractalPosition(upFractals.find(high))];
      }
      else{
         type = SELL;
         lowerLow = fractals.getFractal(0);
         higherHigh = fractals.getFractal(1);
         low = fractals.getFractal(2);
         high = fractals.getFractal(3);
         entry = Close[downFractals.getFractalPosition(downFractals.find(low))];
      }
      checkPattern(type,high,low,higherHigh,lowerLow,entry);
   }
}

bool Pattern::thereIsEntry(){
   return thereIsAnyEntry;
}
Order Pattern::getOrder(){
   return order;
}

void Pattern::checkPattern(bool type, double high, double low, double higherHigh, double lowerLow, double entry){
   if(type == BUY){
      if(low > lowerLow && high < higherHigh && entry > low
         && higherHigh > (high-lowerLow) + high){
         int type = OP_BUYLIMIT;
         double sl = low;
         double tp = entry + RISK_RATIO * (entry-sl);
         order = Order(type,entry,sl,tp);
         thereIsAnyEntry = true;
      }
   }
   else{
      if(low > lowerLow && high < higherHigh && entry < high
         && lowerLow < low -(higherHigh-low)){
         int type = OP_SELLLIMIT;
         double sl = high;
         double tp = entry + RISK_RATIO * (entry-sl);
         order = Order(type,entry,sl,tp);
         thereIsAnyEntry = true;
      }
   }
}
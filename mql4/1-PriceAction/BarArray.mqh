//+------------------------------------------------------------------+
//|                                                      Pattern.mqh |
//|                                                       Diogo Rolo |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Diogo Rolo"
#property link      ""
#property version   "1.00"
#property strict
#include "Bar.mqh"
class BarArray{
private:
   Bar bar[];
   int size;
   void improvementOnBigMoviments();
public:
   BarArray();
   BarArray(double value);
   BarArray(int MaxSize, double value);
   void addUnfinishBar(Bar &newBar);
   void addUnfinishBar(double newValue);
   void changeUnfinishBar(double newValue);
   void add(Bar &newBar);
   void removeLast();
   void remove(int pos);
   Bar getBar(int pos);
   Bar getBarFromFinish(int pos);
   Bar getUnfinishBar();
   int getSize();
};

BarArray::BarArray(){
   ArrayResize(bar,10000);
   size = 0;
}
BarArray::BarArray(double value){
   ArrayResize(bar,10000);
   size = 0;
   addUnfinishBar(value);
}
BarArray::BarArray(int MaxSize,double value){
   ArrayResize(bar,MaxSize);
   size = 0;
   addUnfinishBar(value);
}
void BarArray::addUnfinishBar(Bar &newBar){
   bar[size] = newBar;
}
void BarArray::addUnfinishBar(double newValue){
   bar[size] = Bar(newValue);
}
void BarArray::changeUnfinishBar(double newValue){
   bar[size].changeBar(newValue);
}
void BarArray::add(Bar &newBar){
   if(size >=1 && newBar.isBuy() == bar[size-1].isBuy()){
      bar[size-1].changeBar(newBar.getClose(),newBar.getHigh(),newBar.getLow());
   }
   else
      bar[size++] = newBar;
   improvementOnBigMoviments();
   addUnfinishBar(newBar.getClose());
}
void BarArray::removeLast(){
   size--;
}
void BarArray::remove(int pos){
   for(int i = pos;i < size-1; i++){
      bar[i] = bar[i+1];
   }
   size--;
}
Bar BarArray::getBar(int pos){
   return bar[pos];
}
Bar BarArray::getBarFromFinish(int pos){
   return bar[size - pos - 1];
}
Bar BarArray::getUnfinishBar(){
   return bar[size];
}

void BarArray::improvementOnBigMoviments(){
   if(size >2){
      double firstSize = MathAbs(getBarFromFinish(0).getOpen() - getBarFromFinish(0).getClose());
      double secundSize = MathAbs(getBarFromFinish(1).getOpen() - getBarFromFinish(1).getClose());
      double thirthSize = MathAbs(getBarFromFinish(2).getOpen() - getBarFromFinish(2).getClose());
      if(secundSize*3 < firstSize && secundSize*3 < thirthSize){
         double close = getBarFromFinish(0).getClose();
         double high = MathMax(MathMax(
            getBarFromFinish(2).getHigh() , getBarFromFinish(1).getHigh()) , getBarFromFinish(0).getHigh());
         double low = MathMin(MathMin(
            getBarFromFinish(2).getLow() , getBarFromFinish(1).getLow()) , getBarFromFinish(0).getLow());
         removeLast();
         removeLast();
         bar[size-1].changeBar(close,high,low);
      }
      
   }
}
int BarArray::getSize(){
   return size;
}
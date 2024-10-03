//+------------------------------------------------------------------+
//|                                                         Bias.mqh |
//|                                                       Diogo Rolo |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Diogo Rolo"
#property link      "https://www.mql5.com"
#property strict

struct OrderBlock{
   int candle;
   double upperValue;
   double bottomValue;
   bool touched;
};

const int CANDLES_TO_BE_CONSIDER_MITIGATION = 5;

class OrderBlockArray{
private:
   OrderBlock OB[];
   int size;
   int maxSize;
   void remove(int pos);
public:
   OrderBlockArray();
   void add(OrderBlock &ob);
   void checkTouchAbove(double value);
   void checkTouchBellow(double value);
   void removeMitigatedOBs(double value);
   void increment();
   bool contains(int candle);
   OrderBlock getLast();
};

OrderBlockArray::OrderBlockArray(void){
   maxSize = 10;
   size = 0;
   ArrayResize(OB,maxSize);
}

void OrderBlockArray::add(OrderBlock &ob){
   if(size == maxSize){
      maxSize += 10;
      ArrayResize(OB, maxSize);
   }
   OB[size] = ob;
   size++;
}

void OrderBlockArray::checkTouchAbove(double value){
   for(int i = 0; i < size-1; i++){
      OrderBlock ob = OB[i];
      if(!ob.touched && ob.upperValue > value && ob.candle > CANDLES_TO_BE_CONSIDER_MITIGATION){
         ob.touched = true;
         OB[i] = ob;
      }
   }
}

void OrderBlockArray::checkTouchBellow(double value){
   for(int i = 0; i < size-1; i++){
      OrderBlock ob = OB[i];
      if(!ob.touched && ob.bottomValue < value && ob.candle > CANDLES_TO_BE_CONSIDER_MITIGATION){
         ob.touched = true;
         OB[i] = ob;
      }
   }
}

void OrderBlockArray::removeMitigatedOBs(double value){
   for(int i = size - 1; i >= 0; i--){
      OrderBlock ob = OB[i];
      if(ob.touched && (ob.bottomValue > value || ob.upperValue < value))
         remove(i);
   }
}

void OrderBlockArray::remove(int pos){
   for(int i = 0; i < size-1; i++)
      OB[i] = OB[i+1];
   size--;
}

void OrderBlockArray::increment(void){
   for(int i = 0; i < size; i++)
      OB[i].candle++;
}

bool OrderBlockArray::contains(int candle){
   bool found = false;
   for(int i = 0; i < size && !found; i++){
      if(OB[i].candle == candle)
         found = true;
   }
   return found;
}

OrderBlock OrderBlockArray::getLast(void){
   OrderBlock null;
   null.candle = -1;
   null.bottomValue = -1;
   null.upperValue = -1;
   null.touched = -1;
   if(size > 0)
      return OB[size-1];
   else
      return null;
}

class OrderBlocks{
private:
   datetime LastBar; //variable to allow the method @OnBar() excecute properly
   OrderBlockArray BullishOBs;
   OrderBlockArray BearishOBs;
   ENUM_TIMEFRAMES TIMEFRAME;
   void OnBar();
   void updateOBs();
   bool isBullishImbalance(int shift);
   bool isBearishImbalance(int shift);
   datetime time(int shift);
   double open(int shift);
   double high(int shift);
   double low(int shift);
   double close(int shift);
   long volume(int shift);

public:
   OrderBlocks();
   OrderBlocks(ENUM_TIMEFRAMES timeframe);
   void end();
   void OnTick();
   OrderBlock getBullishOB();
   OrderBlock getBearishOB();
};

OrderBlocks::OrderBlocks(void){}

OrderBlocks::OrderBlocks(ENUM_TIMEFRAMES timeframe){
   TIMEFRAME = timeframe;
}

void OrderBlocks::end(void){
   
}

void OrderBlocks::OnTick(void){
   if(LastBar != time(0)){
      LastBar = time(0); 
      OnBar();
   }
}

void OrderBlocks::OnBar(void){
   BullishOBs.increment();
   BearishOBs.increment();
   
   updateOBs();
   
   BullishOBs.checkTouchAbove(Bid);
   BearishOBs.checkTouchBellow(Bid);
   
   BullishOBs.removeMitigatedOBs(Bid);
   BearishOBs.removeMitigatedOBs(Bid);
}

void OrderBlocks::updateOBs(void){
   if(isBullishImbalance(2) && !isBullishImbalance(3) && high(3) > low(3)){
      OrderBlock ob;
      ob.candle = 3;
      ob.upperValue = high(3);
      ob.bottomValue = low(3);
      ob.touched = false;
      BullishOBs.add(ob);
   }
   if(isBearishImbalance(2) && !isBearishImbalance(3) && high(3) > low(3)){
      OrderBlock ob;
      ob.candle = 3;
      ob.upperValue = high(3);
      ob.bottomValue = low(3);
      ob.touched = false;
      BearishOBs.add(ob);
   }
   
}

bool OrderBlocks::isBullishImbalance(int shift){
   return open(shift) < close(shift) && high(shift+1) < low(shift-1) && high(shift+1) < close(shift) && open(shift) < low(shift-1);
}

bool OrderBlocks::isBearishImbalance(int shift){
   return open(shift) > close(shift) && low(shift+1) > high(shift-1) && low(shift+1) > close(shift) && open(shift) > high(shift-1);
}

OrderBlock OrderBlocks::getBullishOB(void){
   return BullishOBs.getLast();
}

OrderBlock OrderBlocks::getBearishOB(void){
   return BearishOBs.getLast();
}

datetime OrderBlocks::time(int shift){return iTime(_Symbol,TIMEFRAME,shift);}
double OrderBlocks::open(int shift){return iOpen(_Symbol,TIMEFRAME,shift);}
double OrderBlocks::high(int shift){return iHigh(_Symbol,TIMEFRAME,shift);}
double OrderBlocks::low(int shift){return iLow(_Symbol,TIMEFRAME,shift);}
double OrderBlocks::close(int shift){return iClose(_Symbol,TIMEFRAME,shift);}
long OrderBlocks::volume(int shift){return iVolume(_Symbol,TIMEFRAME,shift);}
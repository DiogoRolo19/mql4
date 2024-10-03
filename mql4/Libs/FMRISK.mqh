//+------------------------------------------------------------------+
//|                                                       Report.mqh |
//|                                                       Diogo Rolo |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Diogo Rolo"
#property link      ""
#property strict

#include <F1rstMillion/Library.mqh>

struct Strategy{
   string name;
   int repeatedTrades;
   int totalTrades;
};

class StrategiesArray{
   private:
      int size;
      int maxSize;
      void resize();
      Strategy array[];
      int getPos(string name);
      double ConvertValueContinuous(double x);
   public:
      StrategiesArray();
      double get(string name);
      void add(string name, int repeated, bool newOrder);
      void print();
};

StrategiesArray::StrategiesArray(void){maxSize=10;ArrayResize(array,maxSize);size = 0;}

double StrategiesArray::get(string name){
   Strategy strategy = array[getPos(name)];
   double ratio = strategy.totalTrades == 0 ? 0 : strategy.repeatedTrades * 1.0 / strategy.totalTrades;
   return ConvertValueContinuous(ratio);
}

double StrategiesArray::ConvertValueContinuous(double x){
    return 0.25 * MathPow(0.5, x - 2);
}

void StrategiesArray::add(string name, int repeated, bool newOrder){
   int pos = getPos(name);
   if(pos == -1){
      resize();
      Strategy strategy;
      strategy.name = name;
      strategy.repeatedTrades = repeated;
      strategy.totalTrades = newOrder ? 1 : 0;
      array[size++] = strategy;
   }
   else{
      Strategy strategy = array[pos];
      strategy.repeatedTrades += repeated;
      if(newOrder)
         strategy.totalTrades++;
      array[pos] = strategy;
   }
}


void StrategiesArray::resize(){
   if(size == maxSize){
      maxSize *= 2;
      ArrayResize(array,maxSize);
   }
}

int StrategiesArray::getPos(string name){
   int pos = -1;
   for(int i = 0; i < size && pos == -1;i++){
      if(array[i].name == name)
         pos = i;
   }
   return pos;
}

void StrategiesArray::print(void){
   for(int i = 0; i < size;i++)
      Print(array[i].name + " => " + (string) get(array[i].name) + " (" + (string) array[i].repeatedTrades + "/" + (string) array[i].totalTrades + ")");
}

struct FMRISKOrder{
   string name;
   int ticket;
   bool changed;
};

class FMRISK{
   private:
      StrategiesArray strategiesArray;
      int size;
      int maxSize;
      void resize();
      FMRISKOrder orders[];
      int getPos(int ticket);
      void remove(int pos);
   public:
      FMRISK();
      void addOrder(int ticket, string name);
      void OnTick();
      void OnDeinit();
};

FMRISK::FMRISK(void){strategiesArray = StrategiesArray();maxSize=10;ArrayResize(orders,maxSize);size = 0;}

void FMRISK::addOrder(int ticket, string name){
   resize();
   FMRISKOrder order;
   order.name = name;
   order.ticket = ticket;
   order.changed = false;
   orders[size++] = order;
   strategiesArray.add(name,0,true);
   if(OrderSelect(ticket,SELECT_BY_TICKET)){
      double sl = OrderStopLoss();
      for(int i = size - 2; i>=0; i--){
         if(OrderSelect(orders[i].ticket,SELECT_BY_TICKET)){
            if(isSameValue(sl,OrderStopLoss()) && OrderCloseTime() == 0){
               strategiesArray.add(name,1,false);
               strategiesArray.add(orders[i].name,1,false);
            } 
         }
         else
            remove(i);
      }
   }
}

void FMRISK::OnTick(void){
   for(int i = 0; i < size; i++){
      if(!orders[i].changed){
         double value = strategiesArray.get(orders[i].name);
         if(value != 1 && OrderSelect(orders[i].ticket,SELECT_BY_TICKET) && OrderType() != OP_BUY && OrderType() != OP_SELL){
            int originalTicket = orders[i].ticket;
            double lotSize = NormalizeDouble(OrderLots() * value,2);
            if(lotSize > 0){
               int ticket = OrderSend(OrderSymbol(),OrderType(),lotSize,OrderOpenPrice(),20,OrderStopLoss(),OrderTakeProfit(),NULL,OrderMagicNumber());
               orders[i].ticket = ticket;
            }
            bool deleted = OrderDelete(originalTicket);
            orders[i].changed = true;
         }
      }
   }
}

void FMRISK::OnDeinit(void){
   strategiesArray.print();
}

void FMRISK::resize(){
   if(size == maxSize){
      maxSize *= 2;
      ArrayResize(orders,maxSize);
   }
}

int FMRISK::getPos(int ticket){
   int pos = -1;
   for(int i = 0; i < size && pos == -1;i++){
      if(orders[i].ticket == ticket)
         pos = i;
   }
   return pos;
}

void FMRISK::remove(int pos){
   for(int i = pos; i < size-1;i++)
      orders[i] = orders[i+1];
   size--;
}
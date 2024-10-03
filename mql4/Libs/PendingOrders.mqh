//+------------------------------------------------------------------+
//|                                                         Bias.mqh |
//|                                                       Diogo Rolo |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Diogo Rolo"
#property link      "https://www.mql5.com"
#property strict

#include <F1rstMillion/Enum/MODE_DIRECTION.mqh>
#include <F1rstMillion/Struct/Order.mqh>

struct PendingOrder{
   Order order;
   double lotSize;
   bool valid;
   string name;
};

class PendingOrders{
private:
   PendingOrder array[];
   int size;
   int maxSize;
public:
   PendingOrders();
   void OnTick();
   void add(Order &order, double lotSize);
   void add(Order &order, double lotSize,string name);
   int getSize();
   PendingOrder pop();
};

void PendingOrders::OnTick(void){
   for(int i = 0; i < size; i++){
      if((array[i].order.direction == BUY && Bid < array[i].order.entry)||
            (array[i].order.direction == SELL && Ask > array[i].order.entry))
         array[i].valid = false;
   }
}

PendingOrders::PendingOrders(void){
   maxSize = 10;
   ArrayResize(array, maxSize);
   size = 0;
}

void PendingOrders::add(Order &order,double lotSize){
   add(order,lotSize,"");
}

void PendingOrders::add(Order &order,double lotSize,string name){
   if(size  == maxSize){
      maxSize *= 2;
      ArrayResize(array, maxSize);
   }
   PendingOrder po;
   po.order = order;
   po.lotSize = lotSize;
   po.valid = true;
   po.name = name;
   
   array[size++] = po;
}
int PendingOrders::getSize(void){
   return size;
}
PendingOrder PendingOrders::pop(void){
   size--;
   return array[size];
}
//+------------------------------------------------------------------+
//|                                                      Pattern.mqh |
//|                                                       Diogo Rolo |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Diogo Rolo"
#property link      ""
#property version   "1.00"
#property strict
#include "Order.mqh"
class PendingOrders{
private:
   Order order[];
   int size;
   void deleteOrder(int pos);
   void deleteOrdersAfterTp();
   void deleteExpiredOrders();
public:
   PendingOrders();
   void clear();
   void add(Order &order);
   Order getOrder(int pos);
   int getSize();
   void onTick();
   bool exists(Order &order);
};

PendingOrders::PendingOrders(){
   ArrayResize(order,20);
   size = 0;
}
void PendingOrders::clear(){
   size = 0;
}
void PendingOrders::add(Order &newOrder){
   order[size++] = newOrder;
}
Order PendingOrders::getOrder(int pos){
   return order[pos];
}
int PendingOrders::getSize(){
   return size;
}
void PendingOrders::onTick(){
   deleteOrdersAfterTp();
   deleteExpiredOrders();
}
void PendingOrders::deleteOrder(int pos){
   for(int i = pos;i < size-1; i++){
      order[i] = order[i+1];
   }
   size--;
}
void PendingOrders::deleteOrdersAfterTp(){
   for(int i = size-1; i >= 0; i--){
      double maxPrice = order[i].getEntry() + (order[i].getTp() - order[i].getEntry())*1.5;
      if((order[i].getType() == OP_BUYLIMIT && Ask > maxPrice) || (order[i].getType() == OP_SELLLIMIT && Bid < maxPrice))
         deleteOrder(i);
      }
}

void PendingOrders::deleteExpiredOrders(){
   for(int i = size-1; i >= 0; i--){
      bool isCall = order[i].getType() == OP_BUYLIMIT;
      double actualPrice = isCall?Bid:Ask;
      if((isCall && actualPrice < order[i].getEntry()) || (!isCall && actualPrice > order[i].getEntry()))
         deleteOrder(i);
   }
}

bool PendingOrders::exists(Order &findOrder){
   bool found = false;
   for(int i = 0; i < size && !found; i++){
      if(findOrder.isEqual(order[i]))
         found = true;
   }
   return found;
}
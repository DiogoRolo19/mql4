//+------------------------------------------------------------------+
//|                                                        Order.mqh |
//|                                                       Diogo Rolo |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Diogo Rolo"
#property link      ""
#property strict
class Order{
private:
   int type;
   double lotSize;
   double entry;
   double sl;
   double tp;
   double calculateLotSize(double slSize);
public:
   Order(int type,double entry,double sl,double tp);
   Order(Order &order);
   Order();
   int getType();
   double getLotSize();
   double getEntry();
   double getSl();
   double getTp();
   bool isEqual(Order &order);
};
Order::Order(){
   type = 0;
   entry = 0;
   sl = -1;
   tp = -1;
   lotSize = 0;
}
Order::Order(int orderType,double orderEntry,double orderSl,double orderTp){
   type = orderType;
   entry = orderEntry;
   sl = orderSl;
   tp = orderTp;
   lotSize = calculateLotSize(MathAbs(sl-entry));
}
Order::Order(Order &order){
   type = order.getType();
   entry = order.getEntry();
   sl = order.getSl();
   tp = order.getTp();
   lotSize = order.getLotSize();
}
int Order::getType(void){
   return type;
}
double Order::getLotSize(){
   return lotSize;
}
double Order::getEntry(){
   return entry;
}
double Order::getSl(){
   return sl;
}
double Order::getTp(){
   return tp;
}

double Order::calculateLotSize(double slSize){
   double tickValue = MarketInfo(_Symbol, MODE_TICKVALUE);
   return NormalizeDouble(AccountEquity() * RISK_PER_TRADE / slSize*Point / tickValue,2);
}

bool Order::isEqual(Order &order){
   return entry==order.getEntry() && type==order.getType() && sl==order.getSl();
}
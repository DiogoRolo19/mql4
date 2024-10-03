//+------------------------------------------------------------------+
//|                                                    Simulator.mqh |
//|                                                       Diogo Rolo |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Diogo Rolo"
#property link      "https://www.mql5.com"
#property strict

#include <F1rstMillion/Enum/MODE_DIRECTION.mqh>
#include <F1rstMillion/Struct/Order.mqh>
#include <F1rstMillion/Struct/InputsBias.mqh>
#include <F1rstMillion/Indicators/Bias.mqh>

struct Trade{
   bool isOpen;
   bool isClose;
   int ticket;
   int strategyID;
   MODE_DIRECTION direction;
   double entry;
   double sl;
   double tp;
   double lastPrice;
};

class Simulator{
private:
   Trade trades[];
   ENUM_TIMEFRAMES TIMEFRAME;
   int counter;
   int maxSize;
   bool TYPE_1A;
   bool TYPE_1B;
   bool TYPE_2A;
   bool TYPE_2B;
   bool TYPE_3A;
   bool TYPE_4A;
   bool TYPE_4B;
   double CANCEL_PENDING_ORDER;
   datetime LastBar; //variable to allow the method @OnBar() excecute properly
   void OnBar();
   void ordersHandler();
   void orderRegist(Order &order);
   bool isRepeatedOrder(Order &order);
   void cancelPendingOrdersAfterRiskReward();
   Bias bias;
   datetime time(int shift);
   double open(int shift);
   double high(int shift);
   double low(int shift);
   double close(int shift);
   long volume(int shift);
public:
   Simulator();
   Simulator(ENUM_TIMEFRAMES timeframe, int lenght, int lenghtLower,int legs,double entryFibo, double riskRatio, InputsBias &inputs, double cancelPendingOrder);
   void OnTick();
   void end();
   MODE_DIRECTION getDirection();
   double getTp(MODE_DIRECTION direction);
};

Simulator::Simulator(void){}

Simulator::Simulator(ENUM_TIMEFRAMES timeframe, int lenght, int lenghtLower,int legs,double entryFibo, double riskRatio, InputsBias &inputs, double cancelPendingOrder){
   TIMEFRAME = timeframe;
   counter = 0;
   maxSize = 100;
   ArrayResize(trades,maxSize);
   TYPE_1A = inputs.TYPE_1A;
   TYPE_1B = inputs.TYPE_1B;
   TYPE_2A = inputs.TYPE_2A;
   TYPE_2B = inputs.TYPE_2B;
   TYPE_3A = inputs.TYPE_3A;
   TYPE_4A = inputs.TYPE_4A;
   TYPE_4B = inputs.TYPE_4B;
   CANCEL_PENDING_ORDER = cancelPendingOrder;
   bias = Bias(lenght,lenghtLower,legs,entryFibo,riskRatio,TIMEFRAME);
}

void Simulator::OnTick(void){
   bias.OnTick();
   if(LastBar != time(0)){
      LastBar = time(0); 
      OnBar();
   }
   ordersHandler();
}

void Simulator::OnBar(void){   
   Order order;
   order.strategyID = -1;
   if(TYPE_1A && order.strategyID == -1)
      order = bias.enterType1a();
   if(TYPE_1B && order.strategyID == -1)
      order = bias.enterType1b();
   if(TYPE_2A && order.strategyID == -1)
      order = bias.enterType2a();
   if(TYPE_2B && order.strategyID == -1)
      order = bias.enterType2b();
   if(TYPE_3A && order.strategyID == -1)
      order = bias.enterType3a();
   if(TYPE_4A && order.strategyID == -1)
      order = bias.enterType4a();
   if(TYPE_4B && order.strategyID == -1)
      order = bias.enterType4b();
   if(order.strategyID != -1)
      orderRegist(order);
}

void Simulator::end(){
   bias.end();
}

void Simulator::ordersHandler(void){
   for(int i = 0; i < counter; i++){
      Trade trade = trades[i];
      if(!trade.isOpen && !trade.isClose){
         trade.lastPrice = Bid;
         if((Bid <= trade.entry && trade.direction == BUY) || (Bid >= trade.entry && trade.direction == SELL))
            trade.isOpen = true;
      }
      else if(trade.isOpen && !trade.isClose){
         trade.lastPrice = Bid;
         if((Bid >= trade.tp && Bid >= trade.sl)||(Bid <= trade.tp && Bid <= trade.sl))
            trade.isClose = true;
      }
      trades[i] = trade;
   }
}

void Simulator::orderRegist(Order &order){
   if(counter == maxSize){
      maxSize *= 2;
      ArrayResize(trades,maxSize);
   }
   double slSize = (order.direction == BUY)?(order.entry - order.sl):(order.sl-order.entry);
   bool isOrderValid = (order.direction == BUY)? Bid > order.entry: Bid < order.entry;
   if(slSize > 0 && isOrderValid && !isRepeatedOrder(order)){
      Trade trade;
      trade.isOpen = false;
      trade.isClose = false;
      trade.direction = order.direction;
      trade.entry = order.entry;
      trade.sl = order.sl;
      trade.tp = order.tp;
      trade.lastPrice = Bid;
      trade.strategyID = order.strategyID;
      trade.ticket = counter;
      trades[counter++] = trade;
   }
}

//Check if there is any repeated in the orders
bool Simulator::isRepeatedOrder(Order &order){
   bool repeated = false;
   for(int i = 0; i < counter && !repeated; i++){
      if(order.strategyID == trades[i].strategyID && order.sl == trades[i].sl && !trades[i].isClose)
         repeated = true;
   }
   return repeated;
}

MODE_DIRECTION Simulator::getDirection(void){
   MODE_DIRECTION direction = NO_DIRECTION;
   for(int i = 0; i < counter; i++){
      Trade trade = trades[i];
      if(trade.isOpen && !trade.isClose){
         if(trade.direction == BUY)
            direction = direction == BUY || direction == NO_DIRECTION ? BUY : BOTH_DIRECTIONS;
         else
            direction = direction == SELL || direction == NO_DIRECTION ? SELL : BOTH_DIRECTIONS;
      }
   }
   return direction;
}

double Simulator::getTp(MODE_DIRECTION direction){
   double tp = -1;
   for(int i = 0; i < counter; i++){
      Trade trade = trades[i];
      if(trade.isOpen && !trade.isClose && trade.direction == direction && (tp == -1 || (direction == BUY && trade.tp > tp)||(direction == SELL && trade.tp < tp)))
         tp = trade.tp;
   }
   return tp;
}

void Simulator::cancelPendingOrdersAfterRiskReward(void){
   for(int i = 0; i < counter; i++){
      Trade trade = trades[i];
      if(!trade.isOpen){
         double slSize = trade.entry - trade.sl;
         double maxPrice = trade.entry + slSize * CANCEL_PENDING_ORDER;
         if((trade.direction == BUY && Bid > maxPrice) || (trade.direction == BUY && Bid < maxPrice))
            trades[i].isClose = true;
      }
   }
}

datetime Simulator::time(int shift){return iTime(_Symbol,TIMEFRAME,shift);}
double Simulator::open(int shift){return iOpen(_Symbol,TIMEFRAME,shift);}
double Simulator::high(int shift){return iHigh(_Symbol,TIMEFRAME,shift);}
double Simulator::low(int shift){return iLow(_Symbol,TIMEFRAME,shift);}
double Simulator::close(int shift){return iClose(_Symbol,TIMEFRAME,shift);}
long Simulator::volume(int shift){return iVolume(_Symbol,TIMEFRAME,shift);}
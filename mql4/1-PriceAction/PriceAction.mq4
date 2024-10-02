//+-------------------------------------------------------------------+
//|                                                   PriceAction.mq4 |
//|                                                        Diogo Rolo |
//|                                                                   |
//+-------------------------------------------------------------------+
#property strict
#include "Pattern.mqh"
#include "BarArray.mqh"
#include "PendingOrders.mqh"


//+-------------------------------------------------------------------+
//| Expert inputs                                                     |
//+-------------------------------------------------------------------+

input const int RISK_RATIO = 4;
input const double RISK_PER_TRADE = 0.01;
input const int STARTING_TRADING_HOUR = 15;
input const int ENDING_TRADING_HOUR = 21;
input const int SLIPPAGE = 100;

//+-------------------------------------------------------------------+
//| Expert global variables                                           |
//+-------------------------------------------------------------------+

datetime LastBar; //variable to allow the method @OnBar() excecute properly
PendingOrders pendingOrders;//A vector to store all pending orders outside trading time
int tick;//variable to allow the method @OnTickBar() excecute properly
BarArray bars;
int today;
//+-------------------------------------------------------------------+
//| Expert constants                                                  |
//+-------------------------------------------------------------------+




//+-------------------------------------------------------------------+
//| Expert initialization function                                    |
//+-------------------------------------------------------------------+
int OnInit(){
   LastBar = -1;
   today = -1;
   tick=0;
   bars = BarArray(Bid);
   pendingOrders = PendingOrders();
   return(INIT_SUCCEEDED);
}
//+-------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+-------------------------------------------------------------------+
void OnDeinit(const int reason){
}

//+-------------------------------------------------------------------+
//| Expert tick function                                              |
//+-------------------------------------------------------------------+
void OnTick(){
   if(today != TimeDay(TimeCurrent())){
      today = TimeDay(TimeCurrent());
      bars = BarArray(Bid);//Clearing the bar array
   }  
   bars.changeUnfinishBar(Bid);   
   if(LastBar != Time[0]){
      LastBar = Time[0];
      bars.add(bars.getUnfinishBar());   
      OnBar();
   }   
   //@StartOperating() method evocation
   if(TimeHour(TimeCurrent()) == STARTING_TRADING_HOUR)
      startOperating();
   //---
   //@OrdersHandler() method evocation
   pendingOrders.onTick();
   ordersHandler();
   //--- 
}
//+-------------------------------------------------------------------+
//| Expert bar function                                               |
//| This method runs when a new bar is closed                         |
//+-------------------------------------------------------------------+
void OnBar(){
   Pattern pattern;
   if(pattern.thereIsEntry() && isTimeToEnter()){
      orderRegist(pattern.getOrder());
   }
}


//Check if it's time to enter the market
//Return true if it's time to enter and false if it's not
bool isTimeToEnter(){
   return Month()!=8 && TimeHour(TimeCurrent()) >= STARTING_TRADING_HOUR && TimeHour(TimeCurrent()) < ENDING_TRADING_HOUR;
}
 

//Handle all opearations needed to do to open order or peding orders
void ordersHandler(){
   int ordersNumber = OrdersTotal();
   for(int i = 0; i < ordersNumber; i++)
      closeTradeDuringTheNight(i);
   ordersNumber = OrdersTotal();
   for(int i = 0; i < ordersNumber; i++){
      OrderSelect(i,SELECT_BY_POS);
      if(OrderType() == OP_BUYLIMIT||OrderType() == OP_SELLLIMIT)
         closePendingOrdersAfterTP(i);
   }  
}   

//Close all open trades and pending orders during the night
void closeTradeDuringTheNight(int OrderPos){
   pendingOrders.clear();
   if(!isTimeToEnter()){
      OrderSelect(OrderPos,SELECT_BY_POS);
      if(OrderType() == OP_BUY||OrderType() == OP_SELL)
         OrderClose(OrderTicket(),OrderLots(),OrderType() == OP_BUY ? Ask : Bid,SLIPPAGE);
      else
         OrderDelete(OrderTicket());
   }
}

//Cancel pending orders when the price passes the tp times 1.5
void closePendingOrdersAfterTP(int OrderPos){
   OrderSelect(OrderPos,SELECT_BY_POS);
   double tp = OrderTakeProfit();
   double entry = OrderOpenPrice();
   double maxPrice = entry + (tp - entry)*1.5;
   if(OrderType() == OP_BUYLIMIT && Ask > maxPrice)
      OrderDelete(OrderTicket());
   if(OrderType() == OP_SELLLIMIT && Bid < maxPrice)
      OrderDelete(OrderTicket());
}      

//When the starting operating time opens runs all the pending orders
void startOperating(){
   for(int i = 0; i < pendingOrders.getSize(); i++){
      orderRegist(pendingOrders.getOrder(i));
   }
   pendingOrders.clear();
}

//Regist an order
void orderRegist(Order &order){
   if(isTimeToEnter() && !isRepeatedOrder(order)){
      OrderSend(_Symbol,order.getType(),order.getLotSize(),order.getEntry(),SLIPPAGE,order.getSl(),order.getTp());
      //Alert("Type ",order.getType()==OP_BUYLIMIT?"Call ":"Sell "," Ask" ,Ask," Entry ",order.getEntry()," SL ",order.getSl());
   }   
   if(isTimeToEnter() && !pendingOrders.exists(order))
      pendingOrders.add(order);
}

//Check if there is any repeated in the orders
bool isRepeatedOrder(Order &order){
   int ordersNumber = OrdersTotal();
   bool repeated = false;
   for(int i = 0; i < ordersNumber && !repeated; i++){
      if(areOrdersEqual(order,i))
         repeated = true;
   }
   if(!repeated && pendingOrders.exists(order))
      repeated = true;
   return repeated;
}   

bool areOrdersEqual(Order &order1, int pos){
   OrderSelect(pos,SELECT_BY_POS);
   Order order = Order(OrderType(),OrderOpenPrice(),OrderStopLoss(),OrderTakeProfit());
   return order1.isEqual(order);
}

double now(){
   double minutes = TimeMinute(TimeCurrent());
   double secunds = TimeSeconds(TimeCurrent());
   return minutes + secunds / 60;
}
//+------------------------------------------------------------------+
//|                                                OrdersHandler.mqh |
//|                                                       Diogo Rolo |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Diogo Rolo"
#property link      "https://www.mql5.com"
#property strict

#include "PendingOrders.mqh"
#include "Report.mqh"
#include "Library.mqh"

#include <Enum/MODE_DIRECTION.mqh>
#include <Struct/Order.mqh>

const int BREAKEVEN_SPREAD_SIZE = 2;//When the EA try to put breakeven will put it this times of spreads above or bellow the open price
const int POINTS_WITH_ONLY_1_TRADE = 20;//The EA will only open 1 trade if the entry differ these number of points

class OrdersHandler{
private:
   datetime LastBar; //variable to allow the method @OnBar() excecute properly;
   PendingOrders pendingOrders;
   Report report;
   double STARTING_BE;
   double STARTING_TRALLING_STOP;
   double TRALLING_STOP_FACTOR;
   double CANCEL_PENDING_ORDER_AT_RISK_REWARD;
   bool CLOSE_PENDING_ORDERS_DURING_NIGHT;
   bool CLOSE_TRADES_DURING_NIGHT;
   double STARTING_TRADING_HOUR_1;
   double ENDING_TRADING_HOUR_1;
   double STARTING_TRADING_HOUR_2;
   double ENDING_TRADING_HOUR_2;
   int SLIPPAGE;
   double RISK_PER_TRADE;
   int EXPERT_ID;
   int orderRegist(PendingOrder &pendingOrder);
   void closeTradeDuringTheNight();
   void cancelInvalidPendingOrders();
   void breakeven();
   bool isThisOrderInBreakeven(int pos);
   void trallingStop();
   double getSLSize(double lotSize);
public:
   OrdersHandler();
   OrdersHandler(double STARTING_BE, double STARTING_TRALLING_STOP , double TRALLING_STOP_FACTOR , 
                  double CANCEL_PENDING_ORDER_AT_RISK_REWARD , bool CLOSE_PENDING_ORDERS_DURING_NIGHT, 
                  bool CLOSE_TRADES_DURING_NIGHT, double STARTING_TRADING_HOUR_1, double ENDING_TRADING_HOUR_1, 
                  double STARTING_TRADING_HOUR_2, double ENDING_TRADING_HOUR_2, int SLIPPAGE, double RISK_PER_TRADE, int EXPERT_ID, Report &report);
   void Handle();
   bool isRepeatedOrder(double entry, double sl,int magicNumber);
};

OrdersHandler::OrdersHandler(void){}

OrdersHandler::OrdersHandler(double starting_be, double starting_tralling_stop , double tralling_stop_factor , 
                  double cancel_pending_order_at_risk_reward , bool close_pending_orders_during_night, 
                  bool close_trades_during_night, double starting_trading_hour_1, double ending_trading_hour_1, 
                  double starting_trading_hour_2, double ending_trading_hour_2, int slippage, double risk_per_trade, int expertId, Report &reportLocal){
   STARTING_BE = starting_be;
   STARTING_TRALLING_STOP = starting_tralling_stop;
   TRALLING_STOP_FACTOR = tralling_stop_factor;
   CANCEL_PENDING_ORDER_AT_RISK_REWARD = cancel_pending_order_at_risk_reward;
   CLOSE_PENDING_ORDERS_DURING_NIGHT = close_pending_orders_during_night;
   CLOSE_TRADES_DURING_NIGHT = close_trades_during_night;
   STARTING_TRADING_HOUR_1 = starting_trading_hour_1;
   ENDING_TRADING_HOUR_1 = ending_trading_hour_1;
   STARTING_TRADING_HOUR_2 = starting_trading_hour_2;
   ENDING_TRADING_HOUR_2 = ending_trading_hour_2;
   SLIPPAGE = slippage;
   RISK_PER_TRADE = risk_per_trade;
   EXPERT_ID = expertId;
   report = reportLocal;
   if(!CLOSE_PENDING_ORDERS_DURING_NIGHT)
      pendingOrders = PendingOrders();
}   

int OrdersHandler::orderRegist(PendingOrder &pendingOrder){
   int ticket = -1;
   if(pendingOrder.valid){
      int type  = -1;
      if(pendingOrder.order.direction == BUY)
         type = OP_BUYLIMIT;
      else if(pendingOrder.order.direction == SELL)
         type = OP_SELLLIMIT;
      bool isOrderValid = (type == OP_BUYLIMIT)? Ask > pendingOrder.order.entry: Bid < pendingOrder.order.entry;
      if(isOrderValid && !isRepeatedOrder(pendingOrder.order.entry,pendingOrder.order.sl,(int) MathFloor(pendingOrder.order.strategyID)/10)){
         ticket = OrderSend(_Symbol,type,pendingOrder.lotSize,pendingOrder.order.entry,SLIPPAGE,pendingOrder.order.sl,pendingOrder.order.tp,NULL,pendingOrder.order.strategyID);
         report.addPendingOrder(ticket);
      }
      
   }
   return ticket;
}


void OrdersHandler::Handle(){
   if(!CLOSE_PENDING_ORDERS_DURING_NIGHT)
      pendingOrders.OnTick();
    while(pendingOrders.getSize() > 0 && !CLOSE_PENDING_ORDERS_DURING_NIGHT){
      orderRegist(pendingOrders.pop());
   }
   bool isTimeToEnter = isTimeToEnter(STARTING_TRADING_HOUR_1,ENDING_TRADING_HOUR_1) || isTimeToEnter(STARTING_TRADING_HOUR_2,ENDING_TRADING_HOUR_2);
   if(!isTimeToEnter)
      closeTradeDuringTheNight();
   if(CANCEL_PENDING_ORDER_AT_RISK_REWARD > 0)
      cancelInvalidPendingOrders();
   if(STARTING_BE > 0)
      breakeven();
   if(TRALLING_STOP_FACTOR > 0)
      trallingStop();
}

//Close all open trades and pending orders during the night
void OrdersHandler::closeTradeDuringTheNight(){
   int ordersNumber = OrdersTotal();
   for(int i = ordersNumber-1; i >= 0; i--){
      bool selected = OrderSelect(i,SELECT_BY_POS);
      int id = (int) MathFloor(OrderMagicNumber()/10);
      if(!selected)
         Alert("Ticket not Found");
      else if (id == EXPERT_ID){
         if((OrderType() == OP_BUY||OrderType() == OP_SELL) && CLOSE_TRADES_DURING_NIGHT){
            bool closed = OrderClose(OrderTicket(),OrderLots(),OrderType() == OP_BUY ? Ask : Bid,SLIPPAGE);
            if(!closed)
               Alert("Order not closed");
         }
         else if(!(OrderType() == OP_BUY||OrderType() == OP_SELL)){
            if(!CLOSE_PENDING_ORDERS_DURING_NIGHT){
               Order order;
               order.entry = OrderOpenPrice();
               order.sl = OrderStopLoss();
               order.tp = OrderTakeProfit();
               order.strategyID = OrderMagicNumber();
               order.direction = OrderType() == OP_BUYLIMIT ? BUY:SELL;
               pendingOrders.add(order,OrderLots());
            }
            bool deleted = OrderDelete(OrderTicket());
            if(!deleted)
               Alert("Order not deleted");
         }
      }
   }
}

void OrdersHandler::cancelInvalidPendingOrders(){
   int ordersNumber = OrdersTotal();
   for(int i = ordersNumber-1; i >= 0; i--){
      bool selected = OrderSelect(i,SELECT_BY_POS);
      int id = (int) MathFloor(OrderMagicNumber()/10);
      if(!selected)
         Alert("Ticket not Found");
      else if (id == EXPERT_ID){
         if(OrderType() == OP_BUYLIMIT||OrderType() == OP_SELLLIMIT){
            double slSize = getSLSize(OrderLots());
            double entry = OrderOpenPrice();
            double maxPrice;
            if(OrderType() == OP_BUYLIMIT){
               maxPrice = entry + slSize * CANCEL_PENDING_ORDER_AT_RISK_REWARD;
               if(Ask > maxPrice){
                  bool deleted = OrderDelete(OrderTicket());
                  if(!deleted)
                     Alert("Order not deleted");
               }
            }
            if(OrderType() == OP_SELLLIMIT){
               maxPrice = entry - slSize * CANCEL_PENDING_ORDER_AT_RISK_REWARD;
               if(Bid < maxPrice){
                  bool deleted = OrderDelete(OrderTicket());
                  if(!deleted)
                     Alert("Order not deleted");
               }
            }
         }
      }
   }
}

void OrdersHandler::breakeven(){
   int total = OrdersTotal();
   for (int i = 0; i < total; i++){
      if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES) == true){
         int id = (int) MathFloor(OrderMagicNumber()/10);
         double slSize = getSLSize(OrderLots());
         double sl = -1;
         if (!isThisOrderInBreakeven(i) && OrderType() == OP_BUY && Bid > OrderOpenPrice() + STARTING_BE * slSize)
            sl = MathMax(OrderStopLoss(),NormalizeDouble(OrderOpenPrice() +  BREAKEVEN_SPREAD_SIZE * (Ask-Bid),Digits()));
         else if(!isThisOrderInBreakeven(i) && OrderType() == OP_SELL && Ask < OrderOpenPrice() - STARTING_BE * slSize)
            sl = MathMin(OrderStopLoss(),NormalizeDouble(OrderOpenPrice() - BREAKEVEN_SPREAD_SIZE * (Ask-Bid),Digits()));
         if(sl != -1 && sl != OrderStopLoss() && id == EXPERT_ID){
            bool modified = OrderModify(OrderTicket(), OrderOpenPrice(), sl, OrderTakeProfit(), 0, clrNONE);
            if(!modified)
               Alert("Order not Modified");
         }
      }
   }
}

bool OrdersHandler::isThisOrderInBreakeven(int pos){
   if (OrderSelect(pos, SELECT_BY_POS, MODE_TRADES) == true){
      if((OrderStopLoss() - OrderOpenPrice())* (OrderType() == OP_BUY ? 1 : -1) > 0)
         return true;
   }
   return false;
}

void OrdersHandler::trallingStop(){
   int total = OrdersTotal();
   for (int i = 0; i < total; i++){
      if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES) == true){
         int id = (int) MathFloor(OrderMagicNumber()/10);
         double slSize = getSLSize(OrderLots());
         double sl = -1;
         if(OrderType() == OP_BUY && Bid > OrderOpenPrice() + STARTING_TRALLING_STOP * slSize){
            sl = NormalizeDouble(MathMax(OrderStopLoss(),Bid - TRALLING_STOP_FACTOR * slSize),Digits());
         }
         else if(OrderType() == OP_SELL && Ask < OrderOpenPrice() - STARTING_TRALLING_STOP * slSize){
            sl = NormalizeDouble(MathMin(OrderStopLoss(),Ask + TRALLING_STOP_FACTOR * slSize),Digits());
         }
         if(sl != -1 && sl != OrderStopLoss() && id == EXPERT_ID){
            bool modified = OrderModify(OrderTicket(), OrderOpenPrice(), sl, OrderTakeProfit(), 0, clrNONE);
            if(!modified)
               Alert("Order not Modified");
            }
      }
   }
}


double OrdersHandler::getSLSize(double lotSize){
   double tickValue = MarketInfo(_Symbol, MODE_TICKVALUE);
   return AccountBalance() * RISK_PER_TRADE / lotSize*Point / tickValue;
}

//Check if there is any repeated in the orders
bool OrdersHandler::isRepeatedOrder(double entry, double sl,int magicNumber){
   int ordersNumber = OrdersTotal();
   bool repeated = false;
   for(int i = 0; i < ordersNumber && !repeated; i++){
      bool selected = OrderSelect(i,SELECT_BY_POS);
      if(!selected){
         Alert("Ticket not Found");
         return true;
      }
      int strategyId = (int)MathMod(OrderMagicNumber(),10);
      if(magicNumber == strategyId && ((sl >= OrderStopLoss() - Point && sl <= OrderStopLoss() + Point) || 
            (OrderOpenPrice() - Point * POINTS_WITH_ONLY_1_TRADE <= entry && 
             OrderOpenPrice() + Point * POINTS_WITH_ONLY_1_TRADE >= entry)))
         repeated = true;
   }
   return repeated;
}
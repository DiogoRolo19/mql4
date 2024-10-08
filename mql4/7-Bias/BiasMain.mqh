//+------------------------------------------------------------------+
//|                                                         Bias.mq4 |
//|                                                       Diogo Rolo |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Diogo Rolo"
#property link      ""
#property version   "1.00"
#property strict

#include <F1rstMillion/Indicators/Bias.mqh>
#include <F1rstMillion/Library.mqh>
#include <F1rstMillion/PendingOrders.mqh>
#include <F1rstMillion/Enum/MODE_DIRECTION.mqh>
#include <F1rstMillion/Lists/IntArray.mqh>

struct Inputs{
   ENUM_TIMEFRAMES TIMEFRAME;
   double STARTING_TRADING_HOUR;
   double ENDING_TRADING_HOUR;
   double STARTING_PENDING_HOUR;
   double ENDING_PENDING_HOUR;
   int MAX_SL;
   int MIN_SL;
   double ENTRY_FIBONACCI;
   int LENGHT;
   int LENGHT_LOWER;
   int LEGS;
   double RISK_RATIO;
   double RISK_PER_TRADE;
   bool TYPE_1A;
   bool TYPE_1B;
   bool TYPE_2A;
   bool TYPE_2B;
   bool TYPE_3A;
   bool TYPE_4A;
   bool TYPE_4B;
   double STARTING_BE;
   double STARTING_TRALLING_STOP;
   double TRALLING_STOP_FACTOR;
   double CANCEL_PENDING_ORDER_AT_RISK_REWARD;
   bool CLOSE_PENDING_ORDERS_DURING_NIGHT;
   bool CLOSE_TRADES_DURING_NIGHT;
   int SLIPPAGE;
   int MAX_TRADES_SAME_SL;
};

class BiasMain{
private:
   Bias bias;
   int expertID;
   string Name;
   bool LOGGING;
   datetime LastBar; //variable to allow the method @OnBar() excecute properly
   double BREAKEVEN_SPREAD_SIZE;//When the EA try to put breakeven will put it this times of spreads above or bellow the open price
   Inputs inputs;
   
   void initialize();
   IntArray OnBar(PendingOrders &pendingOrders);
   int orderRegist(PendingOrders &pendingOrders, Order &order);
   int orderRegist(PendingOrders &pendingOrders,double entry, double sl, double tp,int strategyID, MODE_DIRECTION direction);
   void ordersHandler(PendingOrders &pendingOrders);
   void closeTradeDuringTheNight(PendingOrders &pendingOrders);
   void cancelInvalidPendingOrders();
   void breakeven();
   bool isThisOrderInBreakeven(int pos);
   void trallingStop();
   void createID();
   void createStringID();
public:
   BiasMain();
   BiasMain(Inputs &pInputs, bool logging);
   void end();
   IntArray OnTick();
   IntArray OnTick(PendingOrders &pendingOrders);
   string getName();
};

BiasMain::BiasMain(void){}
BiasMain::BiasMain(Inputs &pInputs, bool logging){
   inputs = pInputs;
   LOGGING = logging;
   initialize();
   if(LOGGING)
      Print("Initializing " + Name);
}
void BiasMain::initialize(){
   expertID = 0;
   createID();
   BREAKEVEN_SPREAD_SIZE = 0.5;
   
   LastBar = iTime(_Symbol,inputs.TIMEFRAME,0);
   
   createStringID();
   bias = Bias(inputs.LENGHT,inputs.LENGHT_LOWER,inputs.LEGS,inputs.ENTRY_FIBONACCI,inputs.RISK_RATIO,inputs.TIMEFRAME,expertID, Name);
}

void BiasMain::end(){
   bias.end();
}

IntArray BiasMain::OnTick(){
   return OnTick(PendingOrders());
}
IntArray BiasMain::OnTick(PendingOrders &pendingOrders){
   bias.OnTick();
   IntArray ticketArray = IntArray();
   if(!inputs.CLOSE_PENDING_ORDERS_DURING_NIGHT)
      pendingOrders.OnTick();
   if(LastBar != iTime(_Symbol,inputs.TIMEFRAME,0)){
      LastBar = iTime(_Symbol,inputs.TIMEFRAME,0); 
      ticketArray = OnBar(pendingOrders);
   }
   ordersHandler(pendingOrders);
   return ticketArray;
}

IntArray BiasMain::OnBar(PendingOrders &pendingOrders){
   IntArray ticketArray = IntArray();
   bool isTimeToEnter = isTimeToEnter(inputs.STARTING_TRADING_HOUR,inputs.ENDING_TRADING_HOUR);
   bool isTimeToPending = isTimeToEnter(inputs.STARTING_PENDING_HOUR,inputs.ENDING_PENDING_HOUR);
   Order order;
   if(isTimeToEnter || isTimeToPending){
      order.strategyID = -1;
      if(inputs.TYPE_1A && order.strategyID == -1)
         order = bias.enterType1a();
      if(inputs.TYPE_1B && order.strategyID == -1)
         order = bias.enterType1b();
      if(inputs.TYPE_2A && order.strategyID == -1)
         order = bias.enterType2a();
      if(inputs.TYPE_2B && order.strategyID == -1)
         order = bias.enterType2b();
      if(inputs.TYPE_3A && order.strategyID == -1)
         order = bias.enterType3a();
      if(inputs.TYPE_4A && order.strategyID == -1)
         order = bias.enterType4a();
      if(inputs.TYPE_4B && order.strategyID == -1)
         order = bias.enterType4b();
      if(order.strategyID != -1){
         int ticket = orderRegist(pendingOrders,order);
         if(ticket != -1){
            if(LOGGING)
               Print(IntegerToString(ticket) + " was open by " + Name);
            ticketArray.addLast(ticket);
            
         }
      }
   }
   return ticketArray;
}

int BiasMain::orderRegist(PendingOrders &pendingOrders,Order &order){
   int ticket = -1;
   bool isTimeToEnter = isTimeToEnter(inputs.STARTING_TRADING_HOUR,inputs.ENDING_TRADING_HOUR);
   bool isTimeToPending = isTimeToEnter(inputs.STARTING_PENDING_HOUR,inputs.ENDING_PENDING_HOUR);
   if(isTimeToEnter && AccountFreeMargin() > 0){
      ticket = orderRegist(order.entry, order.sl, order.tp, order.direction, inputs.RISK_PER_TRADE, inputs.MIN_SL, inputs.MAX_SL,inputs.SLIPPAGE,expertID, inputs.MAX_TRADES_SAME_SL);
   }
   else if(isTimeToPending){
      double slSize = MathAbs(order.entry-order.sl);
      if(slSize>= inputs.MIN_SL*Point && slSize<= inputs.MAX_SL*Point){
         pendingOrders.add(order,getLotSize(inputs.RISK_PER_TRADE,slSize),Name);
      }
   }
   return ticket;
}

//Regist an order
int BiasMain::orderRegist(PendingOrders &pendingOrders, double entry, double sl, double tp,int strategyID, MODE_DIRECTION direction){
   Order order;
   order.entry = entry;
   order.sl = sl;
   order.tp = tp;
   order.strategyID = strategyID;
   order.direction = direction;
   order.expertID = expertID;
   return orderRegist(pendingOrders,order);
}


void BiasMain::ordersHandler(PendingOrders &pendingOrders){
   bool isTimeToEnter = isTimeToEnter(inputs.STARTING_TRADING_HOUR,inputs.ENDING_TRADING_HOUR);
   if(!isTimeToEnter)
      closeTradeDuringTheNight(pendingOrders);
   if(inputs.CANCEL_PENDING_ORDER_AT_RISK_REWARD > 0)
      cancelInvalidPendingOrders();
   if(inputs.STARTING_BE > 0)
      breakeven();
   if(inputs.TRALLING_STOP_FACTOR > 0)
      trallingStop();
}   

//Close all open trades and pending orders during the night
void BiasMain::closeTradeDuringTheNight(PendingOrders &pendingOrders){
   int ordersNumber = OrdersTotal();
   for(int i = ordersNumber-1; i >= 0; i--){
      bool selected = OrderSelect(i,SELECT_BY_POS);
      if(!selected)
         Alert("Ticket not Found (during night)");
      else{
         int id = OrderMagicNumber();
         if (id == expertID && Symbol() == OrderSymbol()){
            
            if((OrderType() == OP_BUY||OrderType() == OP_SELL) && inputs.CLOSE_TRADES_DURING_NIGHT){
               bool closed = OrderClose(OrderTicket(),OrderLots(),OrderType() == OP_BUY ? Ask : Bid,inputs.SLIPPAGE);
               if(!closed)
                  Alert("Order not closed (during night)");
            }
            else if(!(OrderType() == OP_BUY||OrderType() == OP_SELL)){
               if(!inputs.CLOSE_PENDING_ORDERS_DURING_NIGHT){
                  Order order;
                  order.entry = OrderOpenPrice();
                  order.sl = OrderStopLoss();
                  order.tp = OrderTakeProfit();
                  order.strategyID = OrderMagicNumber();
                  order.direction = OrderType() == OP_BUYLIMIT ? BUY:SELL;
                  pendingOrders.add(order,OrderLots(),Name);
               }
               bool deleted = OrderDelete(OrderTicket());
               if(!deleted)
                  Alert("Order not deleted (during night)");
            }
         }
      }
   }
}

void BiasMain::cancelInvalidPendingOrders(){
   int ordersNumber = OrdersTotal();
   for(int i = ordersNumber-1; i >= 0; i--){
      bool selected = OrderSelect(i,SELECT_BY_POS);
      int id = OrderMagicNumber();
      if(!selected)
         Alert("Ticket not Found (after risk reward)");
      else if (id == expertID && Symbol() == OrderSymbol()){
         if(OrderType() == OP_BUYLIMIT||OrderType() == OP_SELLLIMIT){
            double slSize = getSLSize(OrderLots(),inputs.RISK_PER_TRADE);
            double entry = OrderOpenPrice();
            double maxPrice;
            if(OrderType() == OP_BUYLIMIT){
               maxPrice = entry + slSize * inputs.CANCEL_PENDING_ORDER_AT_RISK_REWARD;
               if(Ask > maxPrice){
                  bool deleted = OrderDelete(OrderTicket());
                  if(!deleted)
                     Alert("Order not deleted (after risk reward)");
               }
            }
            if(OrderType() == OP_SELLLIMIT){
               maxPrice = entry - slSize * inputs.CANCEL_PENDING_ORDER_AT_RISK_REWARD;
               if(Bid < maxPrice){
                  bool deleted = OrderDelete(OrderTicket());
                  if(!deleted)
                     Alert("Order not deleted (after risk reward)");
               }
            }
         }
      }
   }
}


void BiasMain::breakeven(){
   int ordersNumber = OrdersTotal();
   for(int i = ordersNumber-1; i >= 0; i--){
      if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES) == true){
         double slSize = getSLSize(OrderLots(), inputs.RISK_PER_TRADE);
         double sl = -1;
         int id = OrderMagicNumber();
         if (!isThisOrderInBreakeven(i) && OrderType() == OP_BUY && Bid > OrderOpenPrice() + inputs.STARTING_BE * slSize)
            sl = MathMax(OrderStopLoss(),NormalizeDouble(OrderOpenPrice() +  BREAKEVEN_SPREAD_SIZE * (Ask-Bid),Digits()));
         else if(!isThisOrderInBreakeven(i) && OrderType() == OP_SELL && Ask < OrderOpenPrice() - inputs.STARTING_BE * slSize)
            sl = MathMin(OrderStopLoss(),NormalizeDouble(OrderOpenPrice() - BREAKEVEN_SPREAD_SIZE * (Ask-Bid),Digits()));
         if(sl != -1 && sl != OrderStopLoss() && id == expertID && Symbol() == OrderSymbol()){
            bool modified = OrderModify(OrderTicket(), OrderOpenPrice(), sl, OrderTakeProfit(), 0, clrNONE);
            if(!modified)
               Alert("Order not Modified (breakeven)");
         }
      }
   }
}

bool BiasMain::isThisOrderInBreakeven(int pos){
   if (OrderSelect(pos, SELECT_BY_POS, MODE_TRADES) == true){
      if((OrderStopLoss() - OrderOpenPrice())* (OrderType() == OP_BUY ? 1 : -1) > 0)
         return true;
   }
   return false;
}


void BiasMain::trallingStop(){
   int ordersNumber = OrdersTotal();
   for(int i = ordersNumber-1; i >= 0; i--){
      if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES) == true){
         int id = OrderMagicNumber();
         double slSize = getSLSize(OrderLots(), inputs.RISK_PER_TRADE);
         double sl = -1;
         if(OrderType() == OP_BUY && Bid > OrderOpenPrice() + inputs.STARTING_TRALLING_STOP * slSize){
            sl = NormalizeDouble(MathMax(OrderStopLoss(),Bid - inputs.TRALLING_STOP_FACTOR * slSize),Digits());
         }
         else if(OrderType() == OP_SELL && Ask < OrderOpenPrice() - inputs.STARTING_TRALLING_STOP * slSize){
            sl = NormalizeDouble(MathMin(OrderStopLoss(),Ask + inputs.TRALLING_STOP_FACTOR * slSize),Digits());
         }
         if(sl != -1 && sl != OrderStopLoss() && id == expertID && Symbol() == OrderSymbol()){
            bool modified = OrderModify(OrderTicket(), OrderOpenPrice(), sl, OrderTakeProfit(), 0, clrNONE);
            if(!modified)
               Alert("Order not Modified (traling stop)");
            }
      }
   }
}

void BiasMain::createID(){
   string str= "bias";
   int iStr = getIntFromStringLowerCase(str);
   int bool0 = getIntFromBool(inputs.TYPE_1A);
   int bool1 = getIntFromBool(inputs.TYPE_1B);
   int bool2 = getIntFromBool(inputs.TYPE_2A);
   int bool3 = getIntFromBool(inputs.TYPE_2B);
   int bool4 = getIntFromBool(inputs.TYPE_3A);
   int bool5 = getIntFromBool(inputs.TYPE_4A);
   int bool6 = getIntFromBool(inputs.TYPE_4B);
   int period = getTimeframeID(inputs.TIMEFRAME);
   int lenght = inputs.LENGHT;
   int lowerLenght = inputs.LENGHT_LOWER;
   // Use operações de bit para criar o ID
   expertID = (int)(bool0 * MathPow(2,0) + bool1 * MathPow(2,1) + bool2 * MathPow(2,2) + bool3 * MathPow(2,3) + bool4 * MathPow(2,4) + bool5 * MathPow(2,5) + bool6 * MathPow(2,6));
   expertID = expertID * 6 + period;
   expertID = (int)(MathPow(26,3)) * expertID + iStr;
   expertID = 50 * expertID + inputs.LENGHT;
   expertID = 50 * expertID + inputs.LENGHT_LOWER;
   expertID = 5 * expertID + inputs.LEGS;
}



void BiasMain::createStringID(){
   Name = StringSubstr(WindowExpertName(),0,3);
   Name += "_S-" + _Symbol;
   Name += "_TF-" + timeframeToStr((ENUM_TIMEFRAMES) inputs.TIMEFRAME);
   Name += "_L-" + IntegerToString(inputs.LENGHT);
   if(inputs.TYPE_2A)
      Name += "_LL-" + IntegerToString(inputs.LENGHT_LOWER);
   Name += "_LE-" + IntegerToString(inputs.LEGS);
   Name += "_T-";
   if(inputs.TYPE_1A && inputs.TYPE_1B)
      Name += "1";
   else if(inputs.TYPE_1A)
      Name += "1A";
   else if(inputs.TYPE_1B)
      Name += "1B";

   if(inputs.TYPE_2A && inputs.TYPE_2B)
      Name += "2";
   else if(inputs.TYPE_2A)
      Name += "2A";
   else if(inputs.TYPE_2B)
      Name += "2B";
   
   if(inputs.TYPE_3A)
      Name += "3";
   
   if(inputs.TYPE_4A && inputs.TYPE_4B)
      Name += "4";
   else if(inputs.TYPE_4A)
      Name += "4A";
   else if(inputs.TYPE_4B)
      Name += "4B";
   Name += "_F-" + DoubleToStr(inputs.ENTRY_FIBONACCI,2);
   Name += "_RR-" + DoubleToStr(inputs.RISK_RATIO,1);
   Name += "_BE-" + DoubleToStr(inputs.STARTING_BE,1);
   Name += "_STS-" + DoubleToStr(inputs.STARTING_TRALLING_STOP,1);
   Name += "_TSF-" + DoubleToStr(inputs.TRALLING_STOP_FACTOR,1);
}

string BiasMain::getName(void){
   return Name;
}
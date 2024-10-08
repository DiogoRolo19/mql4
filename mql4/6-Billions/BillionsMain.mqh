//+------------------------------------------------------------------+
//|                                                 BillionsMain.mq4 |
//|                                                       Diogo Rolo |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Diogo Rolo"
#property link      ""
#property version   "1.00"
#property strict

#include <F1rstMillion/Indicators/Billions.mqh>
#include <F1rstMillion/Library.mqh>
#include <F1rstMillion/PendingOrders.mqh>
#include <F1rstMillion/Enum/MODE_DIRECTION.mqh>
#include <F1rstMillion/Lists/IntArray.mqh>

struct Inputs{
   ENUM_TIMEFRAMES TIMEFRAME;
   ENUM_TIMEFRAMES HIGHER_TIMEFRAME;
   int HIGHER_TIMEFRAME_LENGHT;
   double STARTING_TRADING_HOUR;
   double ENDING_TRADING_HOUR;
   double STARTING_PENDING_HOUR;
   double ENDING_PENDING_HOUR;
   int MAX_SL;
   int MIN_SL;
   string LENGHT;
   string LENGHT_HIGHER;
   double RISK_RATIO;
   double RISK_PER_TRADE;
   bool TYPE_1;
   double STARTING_BE;
   double STARTING_TRALLING_STOP;
   double TRALLING_STOP_FACTOR;
   double CANCEL_PENDING_ORDER_AT_RISK_REWARD;
   bool CLOSE_PENDING_ORDERS_DURING_NIGHT;
   bool CLOSE_TRADES_DURING_NIGHT;
   int SLIPPAGE;
};

class BillionsMain{
private:
   Billions billions;
   ZigZag zigZagHTF;
   int pointsFile;
   int pointsFile2;
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
   MODE_DIRECTION HigherDirection();
   string higherTimeframePoints();
   string format(Points &point);
   string formatData();
   
public:
   BillionsMain();
   BillionsMain(Inputs &pInputs, bool logging, bool restricted);
   void end();
   IntArray OnTick();
   IntArray OnTick(PendingOrders &pendingOrders);
   string getName();
};

BillionsMain::BillionsMain(void){}
BillionsMain::BillionsMain(Inputs &pInputs, bool logging, bool restricted = false){
   inputs = pInputs;
   LOGGING = logging;
   expertID = 0;
   createID();
   BREAKEVEN_SPREAD_SIZE = 0.5;
   
   LastBar = iTime(_Symbol,inputs.TIMEFRAME,0);
   
   createStringID();
   
   zigZagHTF = ZigZag(inputs.HIGHER_TIMEFRAME_LENGHT,2,inputs.HIGHER_TIMEFRAME);
   
   billions = Billions(inputs.LENGHT,inputs.LENGHT_HIGHER,inputs.RISK_RATIO,inputs.TIMEFRAME,expertID,restricted);
   if(LOGGING){
      string name = "Backtesting_" +WindowExpertName()+ "\\Points.csv";
      FileDelete(name);
      pointsFile = FileOpen(name,FILE_WRITE|FILE_CSV);
      FileWrite(pointsFile,"Date", "Time","Lenghts","1H","1L","HH1","2L","2H","HL0","3H","3L","HH0");
      string name2 = "Backtesting_" +WindowExpertName()+ "\\Points2.csv";
      FileDelete(name2);
      pointsFile2 = FileOpen(name2,FILE_WRITE|FILE_CSV);
      FileWrite(pointsFile2,"Date", "Time","Lenghts","1","2","3","4");
   }
   
   if(LOGGING)
      Print("Initializing " + Name);
}
void BillionsMain::initialize(){
   
}

void BillionsMain::end(){
   billions.end();
   if(LOGGING){
      FileClose(pointsFile);
      FileClose(pointsFile2);
   }
}

IntArray BillionsMain::OnTick(){
   return OnTick(PendingOrders());
}
IntArray BillionsMain::OnTick(PendingOrders &pendingOrders){
   zigZagHTF.OnTick();
   billions.OnTick();
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

IntArray BillionsMain::OnBar(PendingOrders &pendingOrders){
   IntArray ticketArray = IntArray();
   bool isTimeToEnter = isTimeToEnter(inputs.STARTING_TRADING_HOUR,inputs.ENDING_TRADING_HOUR);
   bool isTimeToPending = isTimeToEnter(inputs.STARTING_PENDING_HOUR,inputs.ENDING_PENDING_HOUR);
   Order order;
   if(isTimeToEnter || isTimeToPending){
      order.strategyID = -1;
      if(inputs.TYPE_1 && order.strategyID == -1)
         order = billions.enterType1();
      if(order.strategyID != -1 && order.direction == HigherDirection()){
         int ticket = orderRegist(pendingOrders,order);
         if(ticket != -1){
            if(LOGGING){
               //Print(IntegerToString(ticket) + " was open by " + Name);
               Print(IntegerToString(ticket) + " => " + order.description);
               string description = order.description;
               StringReplace(description,"-","");
               FileWrite(pointsFile,description);
               FileWrite(pointsFile2,higherTimeframePoints());
            }
            ticketArray.addLast(ticket);
            
         }
      }
   }
   return ticketArray;
}

string BillionsMain::higherTimeframePoints(){
   string data = formatData() + ";" + 
         IntegerToString(inputs.HIGHER_TIMEFRAME_LENGHT) + "_" + 
         IntegerToString(inputs.HIGHER_TIMEFRAME_LENGHT) + "_" +
         IntegerToString(inputs.HIGHER_TIMEFRAME_LENGHT) + "_" + 
         IntegerToString(inputs.HIGHER_TIMEFRAME_LENGHT) + ";";
   
      if(zigZagHTF.isLastPointHigh()){
         data += format(zigZagHTF.getLow(1)) + ";";
         data += format(zigZagHTF.getHigh(1)) + ";";
         data += format(zigZagHTF.getLow(0)) + ";";
         data += format(zigZagHTF.getHigh(0));
      }
      else{
         data += format(zigZagHTF.getHigh(1)) + ";";
         data += format(zigZagHTF.getLow(1)) + ";";
         data += format(zigZagHTF.getHigh(0)) + ";";
         data += format(zigZagHTF.getLow(0));
      }
   return data;
}

string BillionsMain::format(Points &point){
   return "(" + IntegerToString(point.candle) + "," + DoubleToStr(point.value,Digits()) + ")";
}

string BillionsMain::formatData(){
   datetime time = iTime(_Symbol,(int)inputs.HIGHER_TIMEFRAME,0);
   return TimeToStr(time,TIME_DATE) + ";" + TimeToStr(time,TIME_MINUTES);
}

MODE_DIRECTION BillionsMain::HigherDirection(){
   Points null;
   null.candle = -1;
   null.value = -1;
   if(zigZagHTF.indexOfHigh(null) == -1 && zigZagHTF.indexOfLow(null) == -1){
      int shift = zigZagHTF.isLastPointHigh()?0:1;
      if(zigZagHTF.getHigh(0).value > zigZagHTF.getHigh(1).value && Ask < fibonacci(zigZagHTF.getLow(shift).value,zigZagHTF.getHigh(0).value,0.5) && Ask > zigZagHTF.getLow(shift).value)
         return BUY;
      if(zigZagHTF.getLow(0).value < zigZagHTF.getLow(1).value && Bid > fibonacci(zigZagHTF.getHigh(1-shift).value,zigZagHTF.getLow(0).value,0.5) && Bid < zigZagHTF.getHigh(1-shift).value)
         return SELL;
   }
   return NO_DIRECTION;
}

int BillionsMain::orderRegist(PendingOrders &pendingOrders,Order &order){
   int ticket = -1;
   bool isTimeToEnter = isTimeToEnter(inputs.STARTING_TRADING_HOUR,inputs.ENDING_TRADING_HOUR);
   bool isTimeToPending = isTimeToEnter(inputs.STARTING_PENDING_HOUR,inputs.ENDING_PENDING_HOUR);
   if(isTimeToEnter && AccountFreeMargin() > 0){
      ticket = orderRegist(order.entry, order.sl, order.tp, order.direction, inputs.RISK_PER_TRADE, 
         inputs.MIN_SL, inputs.MAX_SL,inputs.SLIPPAGE,expertID);
   }
   else if(isTimeToPending && (order.entry != Ask || order.direction != BUY) && 
      (order.entry != Bid || order.direction != SELL)){
      double slSize = MathAbs(order.entry-order.sl);
      if(slSize>= inputs.MIN_SL*Point && slSize<= inputs.MAX_SL*Point){
         pendingOrders.add(order,getLotSize(inputs.RISK_PER_TRADE,slSize),Name);
      }
   }
   return ticket;
}

//Regist an order
int BillionsMain::orderRegist(PendingOrders &pendingOrders, double entry, double sl, double tp,
                              int strategyID, MODE_DIRECTION direction){
   Order order;
   order.entry = entry;
   order.sl = sl;
   order.tp = tp;
   order.strategyID = strategyID;
   order.direction = direction;
   order.expertID = expertID;
   return orderRegist(pendingOrders,order);
}


void BillionsMain::ordersHandler(PendingOrders &pendingOrders){
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
void BillionsMain::closeTradeDuringTheNight(PendingOrders &pendingOrders){
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

void BillionsMain::cancelInvalidPendingOrders(){
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


void BillionsMain::breakeven(){
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

bool BillionsMain::isThisOrderInBreakeven(int pos){
   if (OrderSelect(pos, SELECT_BY_POS, MODE_TRADES) == true){
      if((OrderStopLoss() - OrderOpenPrice())* (OrderType() == OP_BUY ? 1 : -1) > 0)
         return true;
   }
   return false;
}


void BillionsMain::trallingStop(){
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

void BillionsMain::createID(){
   string str= "bil";
   int iStr = getIntFromStringLowerCase(str);
   int bool0 = getIntFromBool(inputs.TYPE_1);
   int period = getTimeframeID(inputs.TIMEFRAME);
   string lenght[];
   string higherLenght[];
   StringSplit(inputs.LENGHT,',',lenght);
   StringSplit(inputs.LENGHT_HIGHER,',',higherLenght);
   // Use operações de bit para criar o ID
   expertID = (int)(bool0 * MathPow(2,0));
   expertID = expertID * 6 + period;
   expertID = (int)(MathPow(26,3)) * expertID + iStr;
   expertID = 50 * expertID + (int)inputs.LENGHT[0];
   expertID = 50 * expertID + (int)inputs.LENGHT_HIGHER[0];
}



void BillionsMain::createStringID(){
   Name = StringSubstr(WindowExpertName(),0,3);
   Name += "_S-" + _Symbol;
   Name += "_TF-" + timeframeToStr((ENUM_TIMEFRAMES) inputs.TIMEFRAME);
   Name += "_L-" + inputs.LENGHT;
   Name += "_L-" + inputs.LENGHT_HIGHER;
   Name += "_T-";
   if(inputs.TYPE_1)
      Name += "1";
   Name += "_RR-" + DoubleToStr(inputs.RISK_RATIO,1);
   Name += "_BE-" + DoubleToStr(inputs.STARTING_BE,1);
   Name += "_STS-" + DoubleToStr(inputs.STARTING_TRALLING_STOP,1);
   Name += "_TSF-" + DoubleToStr(inputs.TRALLING_STOP_FACTOR,1);
}

string BillionsMain::getName(void){
   return Name;
}
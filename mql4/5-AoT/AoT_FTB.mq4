//+------------------------------------------------------------------+
//|                                              RSIStrategy_AoT.mq4 |
//|                                                       Diogo Rolo |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Diogo Rolo"
#property link      ""
#property version   "1.00"
#property strict

#include <F1rstMillion/RetailPatterns.mqh>
#include <F1rstMillion/Library.mqh>
#include <F1rstMillion/Report.mqh>

Report report;

datetime LastBar; //variable to allow the method @OnBar() excecute properly
const int BREAKEVEN_SPREAD_SIZE = 2;//When the EA try to put breakeven will put it this times of spreads above or bellow the open price
const int SLIPPAGE = 10; 

input const bool LOGGING = false;

input const double STARTING_TRADING_HOUR = 9;
input const double ENDING_TRADING_HOUR = 21;

input const MODE_DIRECTION DIRECTION = BOTH_DIRECTIONS;

input const int RSI_LENGHT = 2;
input const int RSI_UPPER_VALUE = 80;
input const int RSI_LOWER_VALUE = 20;

input const double FIBO_PATTERN_LEVEL = 0.333;

input const int SL_SIZE = 20;

input const double RISK_RATIO = 3;
input const double STARTING_BE = 1;
input const double STARTING_TRALLING_STOP = 0;
input const double TRALLING_STOP_FACTOR = 5;
input const double CANCEL_PENDING_ORDER_AT_RISK_REWARD = 20;
input const bool CLOSE_TRADES_DURING_NIGHT = false;

input const double RISK_PER_TRADE = 0.01;

int expertID;
string Name;

int OnInit(){
   createIntID();
   createStringID();
   report = Report(Name,true,LOGGING);
   return(INIT_SUCCEEDED);
}


void OnDeinit(const int reason){
   report.printReport();
}

void OnTick(){  
   if(LastBar != Time[0]){
      LastBar = Time[0]; 
      OnBar();
   }
   report.onTick();
}

void OnBar(){
   bool isTimeToEnter = isTimeToEnter(STARTING_TRADING_HOUR,ENDING_TRADING_HOUR);
   ordersHandler();
   if(isTimeToEnter(STARTING_TRADING_HOUR,ENDING_TRADING_HOUR)){
      double rsi1 = iRSI(_Symbol,Period(),RSI_LENGHT,PRICE_CLOSE,1);
      double rsi2 = iRSI(_Symbol,Period(),RSI_LENGHT,PRICE_CLOSE,2);
      
      if((rsi1 <= RSI_LOWER_VALUE || rsi2 <= RSI_LOWER_VALUE) && isHammer(1,FIBO_PATTERN_LEVEL,(ENUM_TIMEFRAMES)Period()) && (DIRECTION == BOTH_DIRECTIONS || DIRECTION == BUY) && AccountFreeMargin() > 0){
         double sl = Low[1] - SL_SIZE * Point;
         double slSize = Bid - sl;
         double tp = Bid + (slSize * RISK_RATIO);
         if(!isRepeatedOrder(Ask, sl, expertID)){
            double tickValue = MarketInfo(_Symbol, MODE_TICKVALUE);
            double lotSize = MathFloor(AccountEquity() * RISK_PER_TRADE / slSize*Point / tickValue*100)/100;
            int ticket = OrderSend(_Symbol,OP_BUY,lotSize,Ask,SLIPPAGE,sl,tp,NULL,expertID);
            if(ticket != -1){
               report.addOpenOrder(ticket);
               Print(IntegerToString(ticket) + " was open by " + Name);
            }
         }
      }
      else if((rsi1 >= RSI_UPPER_VALUE || rsi2 >= RSI_UPPER_VALUE) && isStar(1,FIBO_PATTERN_LEVEL,(ENUM_TIMEFRAMES)Period()) && (DIRECTION == BOTH_DIRECTIONS || DIRECTION == SELL) && AccountFreeMargin() > 0){
         double spread = Ask - Bid;
         double sl = High[1] + SL_SIZE * Point + spread;
         double slSize = sl - Bid;
         if(!isRepeatedOrder(Bid, sl, expertID)){
            double tickValue = MarketInfo(_Symbol, MODE_TICKVALUE);
            double lotSize = MathFloor(AccountEquity() * RISK_PER_TRADE / slSize*Point / tickValue*100)/100;
            double tp = Bid - (slSize * RISK_RATIO) - spread;
            int ticket = OrderSend(_Symbol,OP_SELL,lotSize,Bid,SLIPPAGE,sl,tp,NULL,expertID);
            if(ticket != -1){
               report.addOpenOrder(ticket);
               Print(IntegerToString(ticket) + " was open by " + Name);
            }
         }
      }
   }
}

void createIntID(){
   string str= "ftb";
   int iStr = getIntFromStringLowerCase(str);
   int period = Period();
   int ticker = getIntFromStringUpperCase(idFromTicker());
   Print(idFromTicker());
   // Use operações de bit para criar o ID
   expertID = expertID * 4 + period;
   expertID = (int)(MathPow(26,3)) * expertID + iStr;
   expertID = (int)(MathPow(26,2)) * expertID + ticker;
   expertID = 100 * expertID + (int)(FIBO_PATTERN_LEVEL*100);
   expertID = 20 * expertID + RSI_LENGHT;
   expertID = 100 * expertID + RSI_UPPER_VALUE;
   expertID = 100 * expertID + RSI_LOWER_VALUE;
   expertID = 30 * expertID + SL_SIZE;
}


void ordersHandler(){
   bool isTimeToEnter = isTimeToEnter(STARTING_TRADING_HOUR,ENDING_TRADING_HOUR);
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
void closeTradeDuringTheNight(){
   int ordersNumber = OrdersTotal();
   int id = (int) MathFloor(OrderMagicNumber()/10);
   for(int i = ordersNumber-1; i >= 0; i--){
      bool selected = OrderSelect(i,SELECT_BY_POS);
      if(!selected)
         Alert("Ticket not Found");
      else if (id == expertID){
         if((OrderType() == OP_BUY||OrderType() == OP_SELL) && CLOSE_TRADES_DURING_NIGHT){
            bool closed = OrderClose(OrderTicket(),OrderLots(),OrderType() == OP_BUY ? Ask : Bid,SLIPPAGE);
            if(!closed)
               Alert("Order not closed");
         }
         else if(!(OrderType() == OP_BUY||OrderType() == OP_SELL)){
            bool deleted = OrderDelete(OrderTicket());
            if(!deleted)
               Alert("Order not deleted");
         }
      }
   }
}

void cancelInvalidPendingOrders(){
   int ordersNumber = OrdersTotal();
   for(int i = ordersNumber-1; i >= 0; i--){
      bool selected = OrderSelect(i,SELECT_BY_POS);
      int id = (int) MathFloor(OrderMagicNumber()/10);
      if(!selected)
         Alert("Ticket not Found");
      else if (id == expertID){
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


void breakeven(){
   int total = OrdersTotal();
   for (int i = 0; i < total; i++){
      if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES) == true){
         double slSize = getSLSize(OrderLots());
         double sl = -1;
         int id = (int) MathFloor(OrderMagicNumber()/10);
         if (!isThisOrderInBreakeven(i) && OrderType() == OP_BUY && Bid > OrderOpenPrice() + STARTING_BE * slSize)
            sl = MathMax(OrderStopLoss(),NormalizeDouble(OrderOpenPrice() +  BREAKEVEN_SPREAD_SIZE * (Ask-Bid),Digits()));
         else if(!isThisOrderInBreakeven(i) && OrderType() == OP_SELL && Ask < OrderOpenPrice() - STARTING_BE * slSize)
            sl = MathMin(OrderStopLoss(),NormalizeDouble(OrderOpenPrice() - BREAKEVEN_SPREAD_SIZE * (Ask-Bid),Digits()));
         if(sl != -1 && sl != OrderStopLoss() && id == expertID){
            bool modified = OrderModify(OrderTicket(), OrderOpenPrice(), sl, OrderTakeProfit(), 0, clrNONE);
            if(!modified)
               Alert("Order not Modified");
         }
      }
   }
}

bool isThisOrderInBreakeven(int pos){
   if (OrderSelect(pos, SELECT_BY_POS, MODE_TRADES) == true){
      if((OrderStopLoss() - OrderOpenPrice())* (OrderType() == OP_BUY ? 1 : -1) > 0)
         return true;
   }
   return false;
}


void trallingStop(){
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
         if(sl != -1 && sl != OrderStopLoss() && id == expertID){
            bool modified = OrderModify(OrderTicket(), OrderOpenPrice(), sl, OrderTakeProfit(), 0, clrNONE);
            if(!modified)
               Alert("Order not Modified");
            }
      }
   }
}

double getSLSize(double lotSize){
   double tickValue = MarketInfo(_Symbol, MODE_TICKVALUE);
   return AccountBalance() * RISK_PER_TRADE / lotSize*Point / tickValue;
}

void createStringID(){
   Name = "FTB";
   Name += "_" + idFromTicker();
   Name += "_TF-" + timeframeToStr((ENUM_TIMEFRAMES) Period());
   Name += "_F-" + DoubleToStr(FIBO_PATTERN_LEVEL,2);
   Name += "_L-" + IntegerToString(RSI_LENGHT);
   Name += "_RSIU-" + IntegerToString(RSI_UPPER_VALUE);
   Name += "_RSIL-" + IntegerToString(RSI_LOWER_VALUE);
   Name += "_SL-" + IntegerToString(SL_SIZE);
   Name += "_RR-" + DoubleToStr(RISK_RATIO,1);
   Name += "_BE-" + DoubleToStr(STARTING_BE,1);
   Name += "_STS-" + DoubleToStr(STARTING_TRALLING_STOP,1);
   Name += "_TSF-" + DoubleToStr(TRALLING_STOP_FACTOR,1);
}

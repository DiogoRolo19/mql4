//+------------------------------------------------------------------+
//|                                                      Library.mqh |
//|                                                       Diogo Rolo |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Diogo Rolo"
#property link      "https://www.mql5.com"
#property strict

#include <F1rstMillion/Enum/MODE_DIRECTION.mqh>
#include <F1rstMillion/Struct/Order.mqh>

const int POINTS_WITH_ONLY_1_TRADE = 20;//The EA will only open 1 trade if the entry differ these number of points
const ENUM_TIMEFRAMES TIMEFRAMES[] = {PERIOD_M1,PERIOD_M5,PERIOD_M15,PERIOD_M30,PERIOD_H1,PERIOD_H4,PERIOD_D1};
bool isTimeToEnter(double startingTH, double endingTH){
   return getTime() >= startingTH && getTime() < endingTH;
}

double getSLSize(double lotSize, double riskPerTrade){
   double tickValue = MarketInfo(_Symbol, MODE_TICKVALUE);
   return AccountBalance() * riskPerTrade / lotSize*Point / tickValue;
}

double getTime(){
   return TimeHour(TimeCurrent()) + TimeMinute(TimeCurrent())/60.0;
}

//Regist an order
int orderRegist(double entry, double sl, double tp, MODE_DIRECTION direction,double riskPerTrade, int min_sl, int max_sl, int slippage, int expertId, int maxTradesSameSL=0){
   int ticket = -1;
   double slSize = (direction == BUY)?(entry - sl):(sl-entry);
   if(slSize > min_sl * Point && slSize <= max_sl * Point && !isRepeatedOrder(entry,sl,expertId,maxTradesSameSL)){
      double lotSize = getLotSize(riskPerTrade, slSize);
      double maxLots = MarketInfo(_Symbol,MODE_MAXLOT);
      
      if((direction == BUY && Ask > entry)|| (direction == SELL && Bid < entry)){
         int type  = -1;
         if(direction == BUY)
            type = OP_BUYLIMIT;
         else if(direction == SELL)
            type = OP_SELLLIMIT;
         
         while(lotSize>0){
            
            ticket = OrderSend(_Symbol,type,MathMin(lotSize,maxLots),entry,slippage,sl,tp,NULL,expertId);
            
            lotSize-=maxLots;
         }
      }
      else if((direction == BUY && Ask == entry)|| (direction == SELL && Bid == entry)){
         int type  = -1;
         if(direction == BUY)
            type = OP_BUY;
         else if(direction == SELL)
            type = OP_SELL;
         while(lotSize>0){
            ticket = OrderSend(_Symbol,type,MathMin(lotSize,maxLots),entry,slippage,sl,tp,NULL,expertId);
            
            lotSize-=maxLots;
         }
      }
   }
   return ticket;
}

double getLotSize(double riskPerTrade, double slSize){
   double tickValue = MarketInfo(_Symbol, MODE_TICKVALUE);
   double maxLotsPerMargin = AccountBalance()/MarketInfo(_Symbol, MODE_MARGINREQUIRED);
   return MathFloor(MathMin(AccountEquity() * riskPerTrade / slSize*Point / tickValue,maxLotsPerMargin)*100)/100;
}

//Check if there is any repeated in the orders or if there is more than the max trades with the same sl
bool isRepeatedOrder(double entry, double sl,int magicNumber,int maxTradesSameSL=1){
   int ordersNumber = OrdersTotal();
   int counter = 0;
   bool repeated = false;
   for(int i = 0; i < ordersNumber && !repeated; i++){
      bool selected = OrderSelect(i,SELECT_BY_POS);
      if(!selected){
         Alert("Ticket not Found (order repeated)");
      }
      if(Symbol() == OrderSymbol()){
         if(magicNumber == OrderMagicNumber() && (isSameValue(sl,OrderStopLoss()) || isSameValue(entry,OrderOpenPrice())))
            repeated = true;
         else if(isSameValue(sl,OrderStopLoss()) && isSameValue(entry,OrderOpenPrice()))
            repeated = true;
         if(maxTradesSameSL != 0 && isSameValue(sl,OrderStopLoss()))
            counter++;
      }
   }
   if(!repeated && maxTradesSameSL != 0 && counter >= maxTradesSameSL)
      repeated = true;
   return repeated;
}

bool isSameValue(double value1, double value2){
   return value1 >= value2 - Point * POINTS_WITH_ONLY_1_TRADE && value1 <= value2 + Point * POINTS_WITH_ONLY_1_TRADE;
}

string timeframeToStr(ENUM_TIMEFRAMES timeframe){
   string str;
   switch(timeframe){
      case PERIOD_M1:
         str="M1";
         break;
      case PERIOD_M5:
         str="M5";
         break;
      case PERIOD_M15:
         str="M15";
         break;
      case PERIOD_M30:
         str="M30";
         break;
      case PERIOD_H1:
         str="H1";
         break;
      case PERIOD_H4:
         str="H4";
         break;
      case PERIOD_D1:
         str="D1";
         break;
      case PERIOD_MN1:
         str="MN1";
         break;
      case PERIOD_W1:
         str="W1";
         break;
   }
   return str;
}

ENUM_TIMEFRAMES StrToTimeframe(string str){
   ENUM_TIMEFRAMES tf = PERIOD_CURRENT;
   if(str == "M1")
      tf = PERIOD_M1;
   else if(str == "M5")
      tf = PERIOD_M5;
   else if(str == "M15")
      tf = PERIOD_M15;
   else if(str == "M30")
      tf = PERIOD_M30;
   else if(str == "H1")
      tf = PERIOD_H1;
   else if(str == "H4")
      tf = PERIOD_H4;
   else if(str == "D1")
      tf = PERIOD_D1;
   else if(str == "MN1")
      tf = PERIOD_MN1;
   else if(str == "W1")
      tf = PERIOD_W1;
   return tf;
}

int getIntFromBool(bool boolean){
   return boolean ? 1 : 0;
}
int getIntFromStringLowerCase(string str){
   return (str[0] - 'a') * 26 * 26 + (str[1] - 'a') * 26 + (str[2] - 'a');
}

int getIntFromStringUpperCase(string str){
   return (str[0] - 'A') * 26 + (str[1] - 'A');
}
string idFromTicker(){
   string symbol = Symbol();
   if (StringSubstr(symbol,0,3) == "XAU" || StringSubstr(symbol,0,3) == "XAG")
      return StringSubstr(symbol,0,3);
   else if (StringLen(symbol) == 6)
      return StringSubstr(symbol, 0,1) + StringSubstr(symbol, 3, 1);
   else
      return symbol;
}

ENUM_TIMEFRAMES getHigherTimeframe(ENUM_TIMEFRAMES timeframe, int increment){
   
   int pos = -1;
   for(int i = 0; i < 7 && pos == -1;i++){
      if(TIMEFRAMES[i] == timeframe){
         pos = i;
      }
   }
   if(pos + increment < 7)
      return TIMEFRAMES[pos+increment];
   else
      return -1;
}

int getTimeframeID(ENUM_TIMEFRAMES timeframe){
   int pos = -1;
   for(int i = 0; i < 7 && pos == -1;i++){
      if(TIMEFRAMES[i] == timeframe)
         pos = i;
   }
   return pos;
}
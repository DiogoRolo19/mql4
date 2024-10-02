//+-------------------------------------------------------------------+
//|                                                   PriceAction.mq4 |
//|                                                        Diogo Rolo |
//|                                                                   |
//+-------------------------------------------------------------------+
#property strict

//+-------------------------------------------------------------------+
//| Structures                                                        |
//+-------------------------------------------------------------------+

//+-------------------------------------------------------------------+
//| Expert inputs                                                     |
//+-------------------------------------------------------------------+

input const double RISK_PER_TRADE = 0.005;
input const int STARTING_TRADING_HOUR = 15;//10/15;
input const int ENDING_TRADING_HOUR = 20;
input const int SLIPPAGE = 100;
input const double SL = 20;
input const double MIN_LOTS = 0.10;


//+-------------------------------------------------------------------+
//| Expert global variables                                           |
//+-------------------------------------------------------------------+

datetime LastBar; //variable to allow the method @OnBar() excecute properly
int tick;//To allow fast runing;
bool Direction;
const int BIAS_DEEP = 5; //Have to be the same as the value above
bool HighDirection[][5];//BIAS_DEEP
datetime lastTrade;
bool isTimeToEnter;

//+-------------------------------------------------------------------+
//| Expert constants                                                  |
//+-------------------------------------------------------------------+

const bool BUY = true;
const bool SELL = false;
const int HIGH_DIRECTION_TIMEFRAMES[] = { 
                              PERIOD_D1,
                              PERIOD_H4,
                              PERIOD_H1
                              };

//+-------------------------------------------------------------------+
//| Expert initialization function                                    |
//+-------------------------------------------------------------------+
int OnInit(){
   tick=0;
   Direction = Mama(PERIOD_M5) > Fama(PERIOD_M5) ? BUY:SELL;
   bool weekly = Mama(PERIOD_W1) > Fama(PERIOD_W1) ? BUY:SELL;
   ArrayResize(HighDirection,ArraySize(HIGH_DIRECTION_TIMEFRAMES));
   InitializateHighDirection();
   lastTrade = Time[0];
   isTimeToEnter = isTimeToEnter();
   
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
   tick++;
   if(tick == 10000)
      tick = 0;
   if(MathMod(tick,20)== 0)
      UpdateHighDirection();
   if(isTimeToEnter != isTimeToEnter()){
      isTimeToEnter = isTimeToEnter();
      //@OrdersHandler() method evocation
      OrdersHandler();
      //--- 
   }
   if(Mama(PERIOD_M5) > Fama(PERIOD_M5)){
      if(Direction == SELL){
         Direction = BUY;
         CloseAll(SELL);
         if(isTimeToEnter && isConfluencialDirection(BUY) && lastTrade != Time[0])
            RegistOrder(BUY);
      } 
   }
   else{
      if(Direction == BUY){
         Direction = SELL;
         CloseAll(BUY);
         if(isTimeToEnter && isConfluencialDirection(SELL) && lastTrade != Time[0])
            RegistOrder(SELL);
      }
   }
   
   Comment(" D1: ", stringType(HighDirection[0][0]), " H4: ", stringType(HighDirection[1][0]),
           " H1: ", stringType(HighDirection[2][0]), " M5: ", stringType(Direction));
}

void InitializateHighDirection(){
   for(int i = 0; i<ArraySize(HIGH_DIRECTION_TIMEFRAMES);i++){
      int direction = Mama(HIGH_DIRECTION_TIMEFRAMES[i]) > Fama(HIGH_DIRECTION_TIMEFRAMES[i]) ? BUY:SELL;
      for(int j = 0; j < BIAS_DEEP;j++){
         HighDirection[i][j] = direction;
      }
   }
}

void UpdateHighDirection(){
   for(int i = 0; i<ArraySize(HIGH_DIRECTION_TIMEFRAMES);i++){
      for(int j = BIAS_DEEP-1; j > 0;j--){
         HighDirection[i][j] = HighDirection[i][j-1];
      }
      HighDirection[i][0] = Mama(HIGH_DIRECTION_TIMEFRAMES[i]) > Fama(HIGH_DIRECTION_TIMEFRAMES[i]) ? BUY:SELL;
   }
}

bool isConfluencialDirection(bool type){
   bool isConfluencialDirection = true;
   for(int i = 0; i<ArraySize(HIGH_DIRECTION_TIMEFRAMES) && isConfluencialDirection;i++){
      bool duringTrend = true;
      bool trendDirection = HighDirection[i][0];
      for(int j = 1; j < BIAS_DEEP && duringTrend;j++){
         if(trendDirection != HighDirection[i][j])
            duringTrend = false;
      }
      if(duringTrend && trendDirection != type)
         isConfluencialDirection = false;
   }
   return isConfluencialDirection;
}

double Mama(int timeFrame){
   return iCustom(_Symbol,timeFrame,"Mama/Mama",0.35,0.35,0,0);
}

double Fama(int timeFrame){
   return iCustom(_Symbol,timeFrame,"Mama/Mama",0.35,0.35,1,0);
}

void RegistOrder(bool type){
   lastTrade = Time[0];
   double maxLots = MarketInfo(_Symbol,MODE_MAXLOT);
   double lotSize = LotSize(SL);
   do{
      
      if(type == BUY){
         bool isOrderSended = OrderSend(_Symbol,OP_BUY,MathMin(lotSize,maxLots),Bid,SLIPPAGE,Bid-SL,0);
         if(!isOrderSended){
            alertOrderNotSended(OP_BUY,Bid,Bid-SL,MathMin(lotSize,maxLots));
         }
      }
      else{
         bool isOrderSended = OrderSend(_Symbol,OP_SELL,MathMin(lotSize,maxLots),Ask,SLIPPAGE,Ask+SL,0);
         if(!isOrderSended){
            alertOrderNotSended(OP_SELL,Ask,Ask+SL,MathMin(lotSize,maxLots));
         }
      } 
   lotSize-= maxLots;
   }
   while(lotSize > 0);   
}   

void CloseAll(bool type){
   int size = OrdersTotal();
   for(int i=size-1;i>=0;i--){
      bool doesOrderExist = OrderSelect(i,SELECT_BY_POS);
      if(!doesOrderExist)
         alertOrderDoesntExists();
      else if(TypeOfOrder(OrderOpenPrice(),OrderStopLoss()) == type){
         closeOrder(i,false);
      }
   }
}

//Verify is ther order is buy or put
bool TypeOfOrder(double entry, double sl){
   return entry > sl ? BUY : SELL;
}

//Calculate the lot size based on the risk management with @riskPerTrade
//If this changes the trailingstopo have to change too
double LotSize(double slSize){
   double tickValue = MarketInfo(_Symbol, MODE_TICKVALUE);
   return NormalizeDouble(AccountEquity() * RISK_PER_TRADE / slSize*Point / tickValue,2);
}

//Check if it's time to enter the market
//Return true if it's time to enter and false if it's not
bool isTimeToEnter(){
   return Month()!=8 && TimeHour(TimeCurrent()) >= STARTING_TRADING_HOUR && TimeHour(TimeCurrent()) < ENDING_TRADING_HOUR;
}

//Handle all opearations needed to do to over orders
void OrdersHandler(){
   int ordersNumber = OrdersTotal();
   if(ordersNumber > 0){
      for(int i = ordersNumber - 1; i >= 0; i--){
            bool doesOrderExist = OrderSelect(i,SELECT_BY_POS);
            if(!doesOrderExist)
               alertOrderDoesntExists();
            else{
               closeOrder(i,true);
            }
      }   
   }
}

void closeOrder(int position, bool closeAll){
   bool doesOrderExist = OrderSelect(position,SELECT_BY_POS);
   if(!doesOrderExist)
      alertOrderDoesntExists();
   else{
      bool shouldCloseAll = OrderLots()/2 < MIN_LOTS  || OrderProfit() < 0 || closeAll;
      double lots = shouldCloseAll ? OrderLots() : NormalizeDouble(OrderLots()/2,2);  // If the value is smaller then MIN_LOTS or the profit is negative 
                                                                                      // close the trade, if not close half
      int ticket = OrderTicket();
      if(!shouldCloseAll){
         //breakeven(ticket);
      }
      bool orderClosed = OrderClose(ticket,lots,OrderType() == OP_BUY ? Ask : Bid,SLIPPAGE);
      if(!orderClosed)
         alertOrderNotClosed(OrderType(),OrderOpenPrice(),OrderStopLoss(),lots);
   }
}

void breakeven(int ticket){
   bool doesOrderExist = OrderSelect(ticket,SELECT_BY_TICKET);
   if(!doesOrderExist)
      alertOrderDoesntExists();
   else{
      double spread = Ask - Bid;
      double newSL = OrderType() == OP_BUY ?   
                     OrderOpenPrice() + 2 * spread < Ask && OrderOpenPrice() + 2 * spread > OrderStopLoss() ? OrderOpenPrice() + 2 * spread : OrderOpenPrice():
                     OrderOpenPrice() - 2 * spread > Bid && OrderOpenPrice() - 2 * spread < OrderStopLoss() ? OrderOpenPrice() - 2 * spread : OrderOpenPrice();
      bool orderModified = OrderModify(ticket,OrderOpenPrice(),newSL,0,0);
      if(!orderModified){
         alertOrderNotModified(OrderType(),OrderOpenPrice(),newSL,OrderLots());
      }
   }
}

void alertOrderNotSended(int type, double entry, double sl, double lotSize){
   Alert("Not Sended a ",type == OP_BUY? "Buy":"Sell" , " Order with: Entry: ",entry, ", SL: ", sl, " and Lot Size: ", lotSize,".");
}

void alertOrderNotClosed(int type, double entry, double sl, double lotSize){
   Alert("Not Closed a ",type == OP_BUY? "Buy":"Sell" , " Order with: Entry: ",entry, ", SL: ", sl, " and Lot Size: ", lotSize,".");
}

void alertOrderNotModified(int type, double entry, double sl, double lotSize){
   Alert("Not Modified a ",type == OP_BUY? "Buy":"Sell" , " Order with: Entry: ",entry, ", SL: ", sl, " and Lot Size: ", lotSize,".");
}

void alertOrderDoesntExists(){
   Alert("The order you trying to acess doesn't exists");
}

string stringType(bool type){
   return type == BUY?"Buy":"Sell";
}
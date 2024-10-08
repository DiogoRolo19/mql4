//+------------------------------------------------------------------+
//|                                                         Tuga.mq4 |
//|                                                       Diogo Rolo |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Diogo Rolo"
#property version   "1.00"
#property strict
#include <F1rstMillion/Report.mqh>
#include <F1rstMillion/Enum/MODE_DIRECTION.mqh>

datetime lastBar; //variable to allow the method @OnBar() excecute properly

Report report;

input const string INPUT_FILE = "Inputs";
input const double STARTING_TRADING_HOUR = 8;
input const double ENDING_TRADING_HOUR = 20;
input const int SLIPPAGE = 10; 

input const double RISK_RATIO = 3;
input const double RISK_PER_TRADE = 0.01;
input const double STARTING_BE = 0;
input const double STARTING_TRALLING_STOP = 0;
input const double TRALLING_STOP_FACTOR = 2;
input const bool STOP_IN_BODIES = true;



input const int MAX_SL_POINTS_SIZE = 150;
input const int MIN_SL_POINTS_SIZE = 150;
input const int SL_SHIFT = 0;
input const double CANCEL_PENDING_ORDER_AT_RISK_REWARD = 4;

input const int FRACTALS_NUMBER = 5;
input const int LAST_FRACTAL_NUMBER = 2;

input const int MAX_CANDELS_PER_SETUP = 12;

input const bool STRUCTURE_IN_BODIES = true;
input const bool USE_IMBALANCES = true;
input const bool USE_DIVERGENCES = true;
input const double CONFIRMATION_FIBONACCI = 0.5;
input const double ENTRY_FIBONACCI = 0.5;

input const bool PREVIUS_DAY_BIAS = true;
input const bool ASIAN_BIAS = true;
input const bool EUROPEAN_BIAS = true;
input const bool AMERICAN_BIAS = true;

input const MODE_DIRECTION STRATEGY_0 = BOTH_DIRECTIONS;
input const MODE_DIRECTION STRATEGY_1 = BOTH_DIRECTIONS;
input const MODE_DIRECTION STRATEGY_2 = BOTH_DIRECTIONS;
input const MODE_DIRECTION STRATEGY_3 = BOTH_DIRECTIONS;
input const MODE_DIRECTION STRATEGY_4 = BOTH_DIRECTIONS;
input const MODE_DIRECTION STRATEGY_5 = BOTH_DIRECTIONS;
input const MODE_DIRECTION STRATEGY_6 = BOTH_DIRECTIONS;
input const MODE_DIRECTION STRATEGY_7 = BOTH_DIRECTIONS;



const int BREAKEVEN_SPREAD_SIZE = 2;//When the EA try to put breakeven will put it this times of spreads above or bellow the open price
const int POINTS_WITH_ONLY_1_TRADE = 20;//The EA will only open 1 trade if the entry differ these number of points



class Range{
private:
   double upBoundary;
   double downBoundary;
public:
   Range();
   Range(double upValue, double downValue);
   bool isInsideRange(double value);
};

Range::Range(){
   upBoundary=-1;
   downBoundary=-1;
}

Range::Range(double upValue, double downValue){
   upBoundary=upValue;
   downBoundary=downValue;
}

bool Range::isInsideRange(double value){
   bool isInsideRange = false;
   if(value<upBoundary && value>downBoundary)
      isInsideRange = true;
   return isInsideRange;
}

struct Order{
   double entry;
   double tp;
   double sl;
   MODE_DIRECTION direction;
   Range validityRange;
}; 

class PendingOrders{
private:
   Order orders[20];
   int size;
   int strategyID;
   void registAll(MODE_DIRECTION direction);
   void remove(int pos);
public:
   PendingOrders();
   PendingOrders(int strategyId);
   void newOrder(Order &order);
   void onBar();
   bool orderExist(Order &order);
};

PendingOrders::PendingOrders(void){
   size = 0;
   strategyID = -1;
}

PendingOrders::PendingOrders(int strategyId){
   size = 0;
   strategyID=strategyId;
}

void PendingOrders::newOrder(Order &order){
   orders[size++] = order;
}

void PendingOrders::onBar(void){
   bool print = false;
   if(size >0 && (strategyInputs[strategyID][BUY].tradingTime.isTimeToEnter() || strategyInputs[strategyID][SELL].tradingTime.isTimeToEnter()))
      print = true;
   if(print)
      Print("Starting Pending Orders Bar Size:", size);
   for(int i = size-1; i>=0;i--){
      if(!orders[i].validityRange.isInsideRange(High[1]) || !orders[i].validityRange.isInsideRange(Low[1]))
         remove(i);
   }
   if(strategyInputs[strategyID][BUY].tradingTime.isTimeToEnter())
      registAll(BUY);
   if(print)
      Print("Size after buys:", size);
   if(strategyInputs[strategyID][SELL].tradingTime.isTimeToEnter())
      registAll(SELL);
   if(print)
      Print("Size after sells:", size);
}

void PendingOrders::registAll(MODE_DIRECTION direction){
   for(int i = size-1; i >= 0; i--){
      if(orders[i].direction == direction){
         orderRegist(orders[i],strategyID);
         remove(i);
      }
   }
}

void PendingOrders::remove(int pos){
   for(int i = pos; i<size-1;i++){
      orders[i] = orders[i+1];
   }
   size--;
}

bool PendingOrders::orderExist(Order &order){
   bool orderExist = false;
   for(int i = 0; i< size; i++){
      if(areOrdersEquals(orders[i].entry,orders[i].sl,strategyID,order.entry,order.sl,strategyID))
         orderExist = true;
   }
   return orderExist;
}

class TradingTime{
private:
   double startingTradingHour[200];
   double endingTradingHour[200];
   int size;
public:
   TradingTime();
   TradingTime(string tRange);
   bool isTimeToEnter();
};

TradingTime::TradingTime(){
   size=1;
   startingTradingHour[0] = STARTING_TRADING_HOUR;
   endingTradingHour[0] = ENDING_TRADING_HOUR;
}

TradingTime::TradingTime(string tRange){
   string temp[200];
   StringSplit(tRange, ',',temp);
   size = ArraySize(temp);
   for(int i=0;i<size;i++){
      string temp2[2];
      StringSplit(temp[i],'-',temp2);
      startingTradingHour[i] = StringToDouble(temp2[0]);
      endingTradingHour[i] = StringToDouble(temp2[1]);
   }
   string str = "";
   for(int i = 0; i<size;i++){
      if(i>0)
         str+=",";
      str+= (startingTradingHour[i] + "-" + endingTradingHour[i]);
   }
   Print(str);
   Print(isTimeToEnter());
}

bool TradingTime::isTimeToEnter(){
   bool isTimeToEnter = false;
   for(int i = 0; i<size && !isTimeToEnter;i++){
      if((startingTradingHour[i]<endingTradingHour[i] && timeToDouble(TimeCurrent()) >= startingTradingHour[i] && timeToDouble(TimeCurrent()) < endingTradingHour[i]) ||
         (startingTradingHour[i]>endingTradingHour[i] && (timeToDouble(TimeCurrent()) >= startingTradingHour[i] || timeToDouble(TimeCurrent()) < endingTradingHour[i])))
         isTimeToEnter = true;
   }
   return isTimeToEnter;
}




struct Setup{ 
   int point[9]; // PASS THE NUMBER OF POINTS
   MODE_DIRECTION type;
   int fractalNumber;
   int lastFractalNumber;
}; 

struct SetupArray{
   Setup setup[18]; // NUMBER OF DIFFER COMBINATIONS OF FRACTAL AND LAST_FRACTAL (<STRATEGIES*2)
   int size;
};

struct Movement{
   int high;
   int low;
   ENUM_TIMEFRAMES timeframe;
};

struct GlobalBias{
   bool dailyBias;
   bool asianBias;
   bool europeanBias;
   bool americanBias;
};

struct Inputs{
   bool run;
   TradingTime tradingTime;
   double riskRatio;
   double riskPerTrade;
   double startingBE;
   double startingTralingStop;
   double tralingStopFactor;
   bool stopInBodies;
   int maxSlPointsSize;
   int minSlPointsSize;
   int slShift;
   double cancelPendingOrderAtRiskReward;
   int fractalNumber;
   int lastFractalNumber;
   int maxCandelsPerStetup;
   bool structureInBodies;
   bool useImbalances;
   bool useDivergences;
   double confirmationFibonacci;
   double entryFibonacci;
   bool previusDayBias;
   bool asianBias;
   bool europeanBias;
   bool americanBias;
};


Inputs strategyInputs[8][2];
SetupArray setups;
PendingOrders pendingOrders[8];

const string SESSIONS[][2] =  {  
                                 {"20:00", "05:00"},
                                 {"05:00", "14:00"},
                                 {"11:00", "19:00"}
                              };


int OnInit(){
   lastBar = -1;
   Print("StopLevel = ", (int)MarketInfo(Symbol(), MODE_STOPLEVEL));
   for(int i=0;i<8;i++)
      pendingOrders[i] = PendingOrders(i);
   inputsHandler();
   
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason){
   report.printReport();
}

void OnTick(){
   report.onTick();
   ordersHandler();
   if(lastBar != Time[0]){
      lastBar = Time[0]; 
      OnBar();
   }
}

void OnBar(){
   for(int i = 0; i<8; i++){
      pendingOrders[i].onBar();
   }
   Setup s;
   for(int i = 0;i < setups.size;i++){//do entries for each fractals setup
      setups.setup[i] = getPoints(ArraySize(s.point),setups.setup[i].fractalNumber,setups.setup[i].lastFractalNumber); //Fill lastLow,lastHigh,firstLow,firstHigh,divergencePeak and type.
      doEntries(i);
   }
}

void doEntries(int pos){
   GlobalBias bias = directionBias();
   if(strategyInputs[0][SELL].run)
      strategySell0(pos,bias);
   if(strategyInputs[1][SELL].run)
      strategySell1(pos,bias);
   if(strategyInputs[2][SELL].run)
      strategySell2(pos,bias);
   if(strategyInputs[3][SELL].run)
      strategySell3(pos,bias);
   if(strategyInputs[4][SELL].run)
      strategySell4(pos,bias);
   if(strategyInputs[5][SELL].run)
      strategySell5(pos,bias);
   if(strategyInputs[6][SELL].run)
      strategySell6(pos,bias);
   if(strategyInputs[7][SELL].run)
      strategySell7(pos,bias);
   if(strategyInputs[0][BUY].run)
      strategyBuy0(pos,bias);
   if(strategyInputs[1][BUY].run)
      strategyBuy1(pos,bias);
   if(strategyInputs[2][BUY].run)
      strategyBuy2(pos,bias);
   if(strategyInputs[3][BUY].run)
      strategyBuy3(pos,bias);
   if(strategyInputs[4][BUY].run)
      strategyBuy4(pos,bias);
   if(strategyInputs[5][BUY].run)
      strategyBuy5(pos,bias);
   if(strategyInputs[6][BUY].run)
      strategyBuy6(pos,bias);
   if(strategyInputs[7][BUY].run)
      strategyBuy7(pos,bias);
}

bool strategySell0(int pos, GlobalBias &bias){
   const int strategyID = 0;
   MODE_DIRECTION direction = SELL;
   int maxCandelsPerStetup= strategyInputs[strategyID][direction].maxCandelsPerStetup;
   bool stopInBodies = strategyInputs[strategyID][direction].stopInBodies;
   bool useDivergences = strategyInputs[strategyID][direction].useDivergences;
   bool useImbalances = strategyInputs[strategyID][direction].useImbalances;
   double entryFibonacci = strategyInputs[strategyID][direction].entryFibonacci;
   double confirmationFibonacci = strategyInputs[strategyID][direction].confirmationFibonacci;
   int slShift= strategyInputs[strategyID][direction].slShift;
   int fractalNumber = strategyInputs[strategyID][direction].fractalNumber;
   int lastFractalNumber = strategyInputs[strategyID][direction].lastFractalNumber;
   bool isOrderResgisted = false;
   Setup s = setups.setup[pos];
   if(s.type == direction && s.point[7]<7*maxCandelsPerStetup && s.point[7] > 0 && isConfluent(bias,strategyID,direction) &&
         s.fractalNumber == fractalNumber && s.lastFractalNumber == lastFractalNumber &&
         isLowerLow(s.point[2],s.point[0],true,strategyID,direction) && 
         checkFibonacci(s.point[3],s.point[2],s.point[1],confirmationFibonacci,strategyID,direction) &&
         isLowerLow(s.point[4],s.point[2],true,strategyID,direction) &&
         isLowerHigh(s.point[3],s.point[1],false,strategyID,direction) && isHigherHigh(s.point[5],s.point[3],false,strategyID,direction)&&  //3 is the higher high
         isHigherHigh(s.point[7],s.point[3],false,strategyID,direction) && //3 is the higher high
         (existDivergence(s.point[5],s.point[3],strategyID,direction) || existDivergence(s.point[7],s.point[3],strategyID,direction) || !useDivergences) &&
         isHigherLow(s.point[6],s.point[4],true,strategyID,direction) &&
         (existImbalance(s.point[1],s.point[0],fibonacci(High[s.point[1]],Low[s.point[0]],0.5),direction)|| !useImbalances)){
      double spread = NormalizeDouble(Ask - Bid,Digits());
      double entry = fibonacci(High[s.point[1]],Low[s.point[0]],entryFibonacci);
      double sl = ((stopInBodies)? MathMax(Close[s.point[1]],Close[s.point[1]]): High[s.point[1]]) + MathPow(10,-Digits()) * slShift + spread;
      double tp = calculateTP(entry,sl,strategyID,direction);
      if(Bid<entry){
         orderRegist(entry,sl,tp,strategyID,direction);
         isOrderResgisted = true;
      }
   }
   return isOrderResgisted;
}

bool strategyBuy0(int pos, GlobalBias &bias){
   const int strategyID = 0;
   MODE_DIRECTION direction = BUY;
   int maxCandelsPerStetup= strategyInputs[strategyID][direction].maxCandelsPerStetup;
   bool stopInBodies = strategyInputs[strategyID][direction].stopInBodies;
   bool useDivergences = strategyInputs[strategyID][direction].useDivergences;
   bool useImbalances = strategyInputs[strategyID][direction].useImbalances;
   double entryFibonacci = strategyInputs[strategyID][direction].entryFibonacci;
   double confirmationFibonacci = strategyInputs[strategyID][direction].confirmationFibonacci;
   int slShift= strategyInputs[strategyID][direction].slShift;
   int fractalNumber = strategyInputs[strategyID][direction].fractalNumber;
   int lastFractalNumber = strategyInputs[strategyID][direction].lastFractalNumber;
   bool isOrderResgisted = false;
   Setup s = setups.setup[pos];
   if(s.type == direction && s.point[7]<7*maxCandelsPerStetup && s.point[7] > 0 && isConfluent(bias,strategyID,direction) &&
         s.fractalNumber == fractalNumber && s.lastFractalNumber == lastFractalNumber &&
         isHigherHigh(s.point[2],s.point[0],true,strategyID,direction) &&
         checkFibonacci(s.point[3],s.point[2],s.point[1],confirmationFibonacci,strategyID,direction) &&
         isHigherHigh(s.point[4],s.point[2],true,strategyID,direction) &&
         isHigherLow(s.point[3],s.point[1],false,strategyID,direction) && isLowerLow(s.point[5],s.point[3],false,strategyID,direction) //3 is the lower low
         && isLowerLow(s.point[7],s.point[3],false,strategyID,direction) &&//3 is the lower low
         (existDivergence(s.point[5],s.point[3],strategyID,direction) || existDivergence(s.point[7],s.point[3],strategyID,direction) || !useDivergences) &&
         isLowerHigh(s.point[6],s.point[4],true,strategyID,direction) &&
         (existImbalance(s.point[1],s.point[0],fibonacci(Low[s.point[1]],High[s.point[0]],0.5),direction)|| !useImbalances)){
      double spread = NormalizeDouble(Ask - Bid,Digits());
      double entry = fibonacci(Low[s.point[1]],High[s.point[0]],entryFibonacci) + spread;
      double sl = ((stopInBodies)? MathMin(Close[s.point[1]],Close[s.point[1]]): Low[s.point[1]]) - MathPow(10,-Digits()) * slShift;
      double tp = calculateTP(entry,sl,strategyID,direction);
      if(Ask>entry){
         orderRegist(entry,sl,tp,strategyID,direction);
         isOrderResgisted = true;
      }
   }
   return isOrderResgisted;
}

bool strategySell1(int pos, GlobalBias &bias){
   const int strategyID = 1;
   MODE_DIRECTION direction = SELL;
   int maxCandelsPerStetup= strategyInputs[strategyID][direction].maxCandelsPerStetup;
   bool stopInBodies = strategyInputs[strategyID][direction].stopInBodies;
   bool useDivergences = strategyInputs[strategyID][direction].useDivergences;
   bool useImbalances = strategyInputs[strategyID][direction].useImbalances;
   double entryFibonacci = strategyInputs[strategyID][direction].entryFibonacci;
   int slShift= strategyInputs[strategyID][direction].slShift;
   int fractalNumber = strategyInputs[strategyID][direction].fractalNumber;
   int lastFractalNumber = strategyInputs[strategyID][direction].lastFractalNumber;
   bool isOrderResgisted = false;
   Setup s = setups.setup[pos];
   if(s.type == direction && s.point[5]<5*maxCandelsPerStetup && s.point[5] > 0 && isConfluent(bias,strategyID,direction) &&
         s.fractalNumber == fractalNumber && s.lastFractalNumber == lastFractalNumber &&
         isLowerLow(s.point[2],s.point[0],true,strategyID,direction) &&
         isHigherHigh(s.point[3],s.point[1],false,strategyID,direction) && isHigherHigh(s.point[5],s.point[1],false,strategyID,direction) && // 1 is higherhigh
         (existDivergence(s.point[3],s.point[1],strategyID,direction) || existDivergence(s.point[5],s.point[1],strategyID,direction) || !useDivergences) &&
         isHigherLow(s.point[4],s.point[2],true,strategyID,direction) &&
         (existImbalance(s.point[1],s.point[0],fibonacci(High[s.point[1]],Low[s.point[0]],0.5),direction)|| !useImbalances)){
      double spread = NormalizeDouble(Ask - Bid,Digits());
      double entry = fibonacci(High[s.point[1]],Low[s.point[0]],entryFibonacci);
      double sl = ((stopInBodies)? MathMax(Close[s.point[1]],Close[s.point[1]]): High[s.point[1]]) + MathPow(10,-Digits()) * slShift + spread;
      double tp = calculateTP(entry,sl,strategyID,direction);
      if(Bid<entry){
         orderRegist(entry,sl,tp,strategyID,direction);
         isOrderResgisted = true;
      }
   }
   return isOrderResgisted;
}

bool strategyBuy1(int pos, GlobalBias &bias){
   const int strategyID = 1;
   const MODE_DIRECTION direction = BUY;
   int maxCandelsPerStetup= strategyInputs[strategyID][direction].maxCandelsPerStetup;
   bool stopInBodies = strategyInputs[strategyID][direction].stopInBodies;
   bool useDivergences = strategyInputs[strategyID][direction].useDivergences;
   bool useImbalances = strategyInputs[strategyID][direction].useImbalances;
   double entryFibonacci = strategyInputs[strategyID][direction].entryFibonacci;
   int slShift= strategyInputs[strategyID][direction].slShift;
   int fractalNumber = strategyInputs[strategyID][direction].fractalNumber;
   int lastFractalNumber = strategyInputs[strategyID][direction].lastFractalNumber;
   bool isOrderResgisted = false;
   Setup s = setups.setup[pos];
   if(s.type == direction && s.point[5]<5*maxCandelsPerStetup && s.point[5] > 0 && isConfluent(bias,strategyID,direction) &&
         s.fractalNumber == fractalNumber && s.lastFractalNumber == lastFractalNumber &&
         isHigherHigh(s.point[2],s.point[0],true,strategyID,direction) &&
         isLowerLow(s.point[3],s.point[1],false,strategyID,direction) && isLowerLow(s.point[5],s.point[1],false,strategyID,direction) &&//1 is lower low
         (existDivergence(s.point[3],s.point[1],strategyID,direction) || existDivergence(s.point[5],s.point[1],strategyID,direction) || !useDivergences) &&
         isLowerHigh(s.point[4],s.point[2],true,strategyID,direction) &&
         (existImbalance(s.point[1],s.point[0],fibonacci(Low[s.point[1]],High[s.point[0]],0.5),direction)|| !useImbalances)){
      double spread = NormalizeDouble(Ask - Bid,Digits());
      double entry = fibonacci(Low[s.point[1]],High[s.point[0]],entryFibonacci) + spread;
      double sl = ((stopInBodies)? MathMin(Close[s.point[1]],Close[s.point[1]]): Low[s.point[1]]) - MathPow(10,-Digits()) * slShift;
      double tp = calculateTP(entry,sl,strategyID,direction);
      if(Ask>entry){
         orderRegist(entry,sl,tp,strategyID,direction);
         isOrderResgisted = true;
      }
   }
   return isOrderResgisted;
}

bool strategySell2(int pos, GlobalBias &bias){
   const int strategyID = 2;
   MODE_DIRECTION direction = SELL;
   int maxCandelsPerStetup= strategyInputs[strategyID][direction].maxCandelsPerStetup;
   bool stopInBodies = strategyInputs[strategyID][direction].stopInBodies;
   bool useDivergences = strategyInputs[strategyID][direction].useDivergences;
   bool useImbalances = strategyInputs[strategyID][direction].useImbalances;
   int slShift= strategyInputs[strategyID][direction].slShift;
   int fractalNumber = strategyInputs[strategyID][direction].fractalNumber;
   int lastFractalNumber = strategyInputs[strategyID][direction].lastFractalNumber;
   bool isOrderResgisted = false;
   Setup s = setups.setup[pos];
   if(s.type == direction && s.point[7]<7*maxCandelsPerStetup && s.point[7] > 0 && isConfluent(bias,strategyID,direction) &&
         s.fractalNumber == fractalNumber && s.lastFractalNumber == lastFractalNumber &&
         isLowerLow(s.point[2],s.point[0],true,strategyID,direction) &&
         isHigherHigh(s.point[3],s.point[1],false,strategyID,direction) && isHigherHigh(s.point[5],s.point[1],false,strategyID,direction) // 1 is higherhigh
         && isHigherHigh(s.point[7],s.point[1],false,strategyID,direction) &&// 1 is higherhigh
         (existDivergence(s.point[3],s.point[1],strategyID,direction) || existDivergence(s.point[5],s.point[1],strategyID,direction) || 
         existDivergence(s.point[7],s.point[1],strategyID,direction) || !useDivergences) &&
         isHigherLow(s.point[4],s.point[2],true,strategyID,direction) &&
         isHigherLow(s.point[6],s.point[4],true,strategyID,direction)){
      double spread = NormalizeDouble(Ask - Bid,Digits());
      double entry = MathMin(Open[s.point[2]],Close[s.point[2]]);
      double sl = ((stopInBodies)? MathMax(Close[s.point[1]],Close[s.point[1]]): High[s.point[1]]) + MathPow(10,-Digits()) * slShift + spread;
      double tp = calculateTP(entry,sl,strategyID,direction);
      if(Bid<entry){
         orderRegist(entry,sl,tp,strategyID,direction);
         isOrderResgisted = true;
      }
   }
   return isOrderResgisted;
}

bool strategyBuy2(int pos, GlobalBias &bias){
   const int strategyID = 2;
   MODE_DIRECTION direction = BUY;
   int maxCandelsPerStetup= strategyInputs[strategyID][direction].maxCandelsPerStetup;
   bool stopInBodies = strategyInputs[strategyID][direction].stopInBodies;
   bool useDivergences = strategyInputs[strategyID][direction].useDivergences;
   bool useImbalances = strategyInputs[strategyID][direction].useImbalances;
   int slShift= strategyInputs[strategyID][direction].slShift;
   int fractalNumber = strategyInputs[strategyID][direction].fractalNumber;
   int lastFractalNumber = strategyInputs[strategyID][direction].lastFractalNumber;
   bool isOrderResgisted = false;
   Setup s = setups.setup[pos];
   if(s.type == direction && s.point[7]<7*maxCandelsPerStetup && s.point[7] > 0 && isConfluent(bias,strategyID,direction) &&
         s.fractalNumber == fractalNumber && s.lastFractalNumber == lastFractalNumber &&
         isHigherHigh(s.point[2],s.point[0],true,strategyID,direction) &&
         isLowerLow(s.point[3],s.point[1],false,strategyID,direction) && isLowerLow(s.point[5],s.point[1],false,strategyID,direction) && //1 is lower low 
         isLowerLow(s.point[7],s.point[1],false,strategyID,direction) &&//1 is lower low
         (existDivergence(s.point[3],s.point[1],strategyID,direction) || existDivergence(s.point[5],s.point[1],strategyID,direction) || 
         existDivergence(s.point[7],s.point[1],strategyID,direction) || !useDivergences) &&
         isLowerHigh(s.point[4],s.point[2],true,strategyID,direction) &&
         isLowerHigh(s.point[6],s.point[4],true,strategyID,direction)){
      double spread = NormalizeDouble(Ask - Bid,Digits());
      double entry = MathMax(Open[s.point[2]],Close[s.point[2]]) - + spread;
      double sl = ((stopInBodies)? MathMin(Close[s.point[1]],Close[s.point[1]]): Low[s.point[1]]) - MathPow(10,-Digits()) * slShift;
      double tp = calculateTP(entry,sl,strategyID,direction);
      if(Ask>entry){
         orderRegist(entry,sl,tp,strategyID,direction);
         isOrderResgisted = true;
      }
   }
   return isOrderResgisted;
}

bool strategySell3(int pos, GlobalBias &bias){
   const int strategyID = 3;
   MODE_DIRECTION direction = SELL;
   int maxCandelsPerStetup= strategyInputs[strategyID][direction].maxCandelsPerStetup;
   bool stopInBodies = strategyInputs[strategyID][direction].stopInBodies;
   bool useDivergences = strategyInputs[strategyID][direction].useDivergences;
   bool useImbalances = strategyInputs[strategyID][direction].useImbalances;
   double entryFibonacci = strategyInputs[strategyID][direction].entryFibonacci;
   double confirmationFibonacci = strategyInputs[strategyID][direction].confirmationFibonacci;
   int slShift= strategyInputs[strategyID][direction].slShift;
   int fractalNumber = strategyInputs[strategyID][direction].fractalNumber;
   int lastFractalNumber = strategyInputs[strategyID][direction].lastFractalNumber;
   bool isOrderResgisted = false;
   Setup s = setups.setup[pos];
   if(s.type == direction && s.point[7]<7*maxCandelsPerStetup && s.point[7] > 0 && isConfluent(bias,strategyID,direction) &&
         s.fractalNumber == fractalNumber && s.lastFractalNumber == lastFractalNumber &&
         isLowerLow(s.point[2],s.point[0],true,strategyID,direction) && 
         checkFibonacci(s.point[3],s.point[2],s.point[1],confirmationFibonacci,strategyID,direction) &&
         isLowerLow(s.point[4],s.point[2],true,strategyID,direction) &&
         isLowerHigh(s.point[3],s.point[1],false,strategyID,direction) && isHigherHigh(s.point[5],s.point[3],false,strategyID,direction) //3 is the higher high
         && isHigherHigh(s.point[7],s.point[3],false,strategyID,direction) && //3 is the higher high
         (existDivergence(s.point[5],s.point[3],strategyID,direction) || existDivergence(s.point[7],s.point[3],strategyID,direction) || !useDivergences) &&
         isHigherLow(s.point[6],s.point[4],true,strategyID,direction)){
      double spread = NormalizeDouble(Ask - Bid,Digits());
      double entry = fibonacci(High[s.point[1]],Low[s.point[0]],entryFibonacci);
      double sl = ((stopInBodies)? MathMax(Close[s.point[1]],Close[s.point[1]]): High[s.point[1]]) + MathPow(10,-Digits()) * slShift + spread;
      double tp = calculateTP(entry,sl,strategyID,direction);
      if(Bid<entry){
         orderRegist(entry,sl,tp,strategyID,direction);
         isOrderResgisted = true;
      }
   }
   return isOrderResgisted;
}

bool strategyBuy3(int pos, GlobalBias &bias){
   const int strategyID = 3;
   MODE_DIRECTION direction = BUY;
   int maxCandelsPerStetup= strategyInputs[strategyID][direction].maxCandelsPerStetup;
   bool stopInBodies = strategyInputs[strategyID][direction].stopInBodies;
   bool useDivergences = strategyInputs[strategyID][direction].useDivergences;
   bool useImbalances = strategyInputs[strategyID][direction].useImbalances;
   double entryFibonacci = strategyInputs[strategyID][direction].entryFibonacci;
   double confirmationFibonacci = strategyInputs[strategyID][direction].confirmationFibonacci;
   int slShift= strategyInputs[strategyID][direction].slShift;
   int fractalNumber = strategyInputs[strategyID][direction].fractalNumber;
   int lastFractalNumber = strategyInputs[strategyID][direction].lastFractalNumber;
   bool isOrderResgisted = false;
   Setup s = setups.setup[pos];
   if(s.type == direction && s.point[7]<7*maxCandelsPerStetup && s.point[7] > 0 && isConfluent(bias,strategyID,direction) &&
         s.fractalNumber == fractalNumber && s.lastFractalNumber == lastFractalNumber &&
         isHigherHigh(s.point[2],s.point[0],true,strategyID,direction) &&
         checkFibonacci(s.point[3],s.point[2],s.point[1],confirmationFibonacci,strategyID,direction) &&
         isHigherHigh(s.point[4],s.point[2],true,strategyID,direction) &&
         isHigherLow(s.point[3],s.point[1],false,strategyID,direction) && isLowerLow(s.point[5],s.point[3],false,strategyID,direction) //3 is lower low
         && isLowerLow(s.point[7],s.point[3],false,strategyID,direction) &&//3 is lower low
         (existDivergence(s.point[5],s.point[3],strategyID,direction) || existDivergence(s.point[7],s.point[3],strategyID,direction) || !useDivergences) &&
         isLowerHigh(s.point[6],s.point[4],true,strategyID,direction)){
      double spread = NormalizeDouble(Ask - Bid,Digits());
      double entry = fibonacci(Low[s.point[1]],High[s.point[0]],entryFibonacci) + spread;
      double sl = ((stopInBodies)? MathMin(Close[s.point[1]],Close[s.point[1]]): Low[s.point[1]]) - MathPow(10,-Digits()) * slShift;
      double tp = calculateTP(entry,sl,strategyID,direction);
      if(Ask>entry){
         orderRegist(entry,sl,tp,strategyID,direction);
         isOrderResgisted = true;
      }
   }
   return isOrderResgisted;
}

bool strategySell4(int pos, GlobalBias &bias){
   const int strategyID = 4;
   MODE_DIRECTION direction = SELL;
   int maxCandelsPerStetup= strategyInputs[strategyID][direction].maxCandelsPerStetup;
   bool stopInBodies = strategyInputs[strategyID][direction].stopInBodies;
   bool useDivergences = strategyInputs[strategyID][direction].useDivergences;
   bool useImbalances = strategyInputs[strategyID][direction].useImbalances;
   double confirmationFibonacci = strategyInputs[strategyID][direction].confirmationFibonacci;
   int slShift= strategyInputs[strategyID][direction].slShift;
   int fractalNumber = strategyInputs[strategyID][direction].fractalNumber;
   int lastFractalNumber = strategyInputs[strategyID][direction].lastFractalNumber;
   bool isOrderResgisted = false;
   Setup s = setups.setup[pos];
   if(s.type == direction && s.point[7]<7*maxCandelsPerStetup && s.point[7] > 0 && isConfluent(bias,strategyID,direction) &&
         s.fractalNumber == fractalNumber && s.lastFractalNumber == lastFractalNumber &&
         isHigherLow(s.point[2],s.point[0],true,strategyID,direction) && 
         checkFibonacci(s.point[3],s.point[2],s.point[1],confirmationFibonacci,strategyID,direction) &&
         isLowerLow(s.point[4],s.point[2],true,strategyID,direction) &&
         isLowerHigh(s.point[3],s.point[1],false,strategyID,direction) && isHigherHigh(s.point[5],s.point[3],false,strategyID,direction) //3 is the higher high
         && isHigherHigh(s.point[7],s.point[3],false,strategyID,direction) && //3 is the higher high
         isHigherLow(s.point[6],s.point[4],true,strategyID,direction) &&
         (existDivergence(s.point[5],s.point[3],strategyID,direction) || existDivergence(s.point[7],s.point[3],strategyID,direction)|| !useDivergences) &&
         (existImbalance(s.point[3],s.point[1],0,direction)|| !useImbalances)){
      double spread = NormalizeDouble(Ask - Bid,Digits());
      double entry = High[s.point[1]];
      double sl = ((stopInBodies)? MathMax(Close[s.point[3]],Close[s.point[3]]): High[s.point[3]]) + MathPow(10,-Digits()) * slShift + spread;
      double tp = calculateTP(entry,sl,strategyID,direction);
      if(Bid<entry){
         orderRegist(entry,sl,tp,strategyID,direction);
         isOrderResgisted = true;
      }
   }
   return isOrderResgisted;
}

bool strategyBuy4(int pos, GlobalBias &bias){
   const int strategyID = 4;
   MODE_DIRECTION direction = BUY;
   int maxCandelsPerStetup= strategyInputs[strategyID][direction].maxCandelsPerStetup;
   bool stopInBodies = strategyInputs[strategyID][direction].stopInBodies;
   bool useDivergences = strategyInputs[strategyID][direction].useDivergences;
   bool useImbalances = strategyInputs[strategyID][direction].useImbalances;
   double confirmationFibonacci = strategyInputs[strategyID][direction].confirmationFibonacci;
   int slShift= strategyInputs[strategyID][direction].slShift;
   int fractalNumber = strategyInputs[strategyID][direction].fractalNumber;
   int lastFractalNumber = strategyInputs[strategyID][direction].lastFractalNumber;
   bool isOrderResgisted = false;
   Setup s = setups.setup[pos];
   if(s.type == direction && s.point[7]<7*maxCandelsPerStetup && s.point[7] > 0 && isConfluent(bias,strategyID,direction) &&
         s.fractalNumber == fractalNumber && s.lastFractalNumber == lastFractalNumber &&
         isLowerHigh(s.point[2],s.point[0],true,strategyID,direction) &&
         checkFibonacci(s.point[3],s.point[2],s.point[1],confirmationFibonacci,strategyID,direction) &&
         isHigherHigh(s.point[4],s.point[2],true,strategyID,direction) &&
         isHigherLow(s.point[3],s.point[1],false,strategyID,direction) && isLowerLow(s.point[5],s.point[3],false,strategyID,direction) && //3 is lower low
         isLowerLow(s.point[7],s.point[3],false,strategyID,direction) &&//3 is lower low
         isLowerHigh(s.point[6],s.point[4],true,strategyID,direction) &&
         (existDivergence(s.point[5],s.point[3],strategyID,direction) || existDivergence(s.point[7],s.point[3],strategyID,direction) || !useDivergences) &&
         (existImbalance(s.point[3],s.point[1],0,direction) || !useImbalances)){
      double spread = NormalizeDouble(Ask - Bid,Digits());
      double entry = Low[s.point[1]] + spread;
      double sl = ((stopInBodies)? MathMin(Close[s.point[3]],Close[s.point[3]]): Low[s.point[3]]) - MathPow(10,-Digits()) * slShift;
      double tp = calculateTP(entry,sl,strategyID,direction);
      if(Ask>entry){
         orderRegist(entry,sl,tp,strategyID,direction);
         isOrderResgisted = true;
      }
   }
   return isOrderResgisted;
}

bool strategySell5(int pos, GlobalBias &bias){
   const int strategyID = 5;
   MODE_DIRECTION direction = SELL;
   int maxCandelsPerStetup= strategyInputs[strategyID][direction].maxCandelsPerStetup;
   bool stopInBodies = strategyInputs[strategyID][direction].stopInBodies;
   bool useDivergences = strategyInputs[strategyID][direction].useDivergences;
   bool useImbalances = strategyInputs[strategyID][direction].useImbalances;
   double entryFibonacci = strategyInputs[strategyID][direction].entryFibonacci;
   int slShift= strategyInputs[strategyID][direction].slShift;
   int fractalNumber = strategyInputs[strategyID][direction].fractalNumber;
   int lastFractalNumber = strategyInputs[strategyID][direction].lastFractalNumber;
   bool isOrderResgisted = false;
   Setup s = setups.setup[pos];
   if(s.type == direction && s.point[7]<7*maxCandelsPerStetup && s.point[7] > 0 && isConfluent(bias,strategyID,direction) &&
         s.fractalNumber == fractalNumber && s.lastFractalNumber == lastFractalNumber &&
         isLowerLow(s.point[2],s.point[0],true,strategyID,direction) && 
         isHigherLow(s.point[4],s.point[2],true,strategyID,direction) &&
         isLowerHigh(s.point[3],s.point[1],false,strategyID,direction) && isHigherHigh(s.point[5],s.point[3],false,strategyID,direction) && //3 is the higher high
         isHigherHigh(s.point[7],s.point[3],false,strategyID,direction) && //3 is the higher high
         (existDivergence(s.point[5],s.point[3],strategyID,direction) || existDivergence(s.point[7],s.point[3],strategyID,direction) || !useDivergences) &&
         isHigherLow(s.point[6],s.point[4],true,strategyID,direction) &&
         (existImbalance(s.point[1],s.point[0],fibonacci(High[s.point[1]],Low[s.point[0]],0.5),direction)|| !useImbalances)){
      double spread = NormalizeDouble(Ask - Bid,Digits());
      double entry = fibonacci(High[s.point[1]],Low[s.point[0]],entryFibonacci);
      double sl = ((stopInBodies)? MathMax(Close[s.point[1]],Close[s.point[1]]): High[s.point[1]]) + MathPow(10,-Digits()) * slShift + spread;
      double tp = calculateTP(entry,sl,strategyID,direction);
      if(Bid<entry){
         orderRegist(entry,sl,tp,strategyID,direction);
         isOrderResgisted = true;
      }
   }
   return isOrderResgisted;
}

bool strategyBuy5(int pos, GlobalBias &bias){
   const int strategyID = 5;
   MODE_DIRECTION direction = BUY;
   int maxCandelsPerStetup= strategyInputs[strategyID][direction].maxCandelsPerStetup;
   bool stopInBodies = strategyInputs[strategyID][direction].stopInBodies;
   bool useDivergences = strategyInputs[strategyID][direction].useDivergences;
   bool useImbalances = strategyInputs[strategyID][direction].useImbalances;
   double entryFibonacci = strategyInputs[strategyID][direction].entryFibonacci;
   int slShift= strategyInputs[strategyID][direction].slShift;
   int fractalNumber = strategyInputs[strategyID][direction].fractalNumber;
   int lastFractalNumber = strategyInputs[strategyID][direction].lastFractalNumber;
   bool isOrderResgisted = false;
   Setup s = setups.setup[pos];
   if(s.type == direction && s.point[7]<7*maxCandelsPerStetup && s.point[7] > 0 && isConfluent(bias,strategyID,direction) &&
         s.fractalNumber == fractalNumber && s.lastFractalNumber == lastFractalNumber &&
         isHigherHigh(s.point[2],s.point[0],true,strategyID,direction) &&
         isLowerHigh(s.point[4],s.point[2],true,strategyID,direction) &&
         isHigherLow(s.point[3],s.point[1],false,strategyID,direction) && isLowerLow(s.point[5],s.point[3],false,strategyID,direction) && //3 is the lower low
         isLowerLow(s.point[7],s.point[3],false,strategyID,direction) &&//3 is the lower low
         (existDivergence(s.point[5],s.point[3],strategyID,direction) || existDivergence(s.point[7],s.point[3],strategyID,direction) || !useDivergences) &&
         isLowerHigh(s.point[6],s.point[4],true,strategyID,direction) &&
         (existImbalance(s.point[1],s.point[0],fibonacci(Low[s.point[1]],High[s.point[0]],0.5),direction)|| !useImbalances)){
      double spread = NormalizeDouble(Ask - Bid,Digits());
      double entry = fibonacci(Low[s.point[1]],High[s.point[0]],entryFibonacci) + spread;
      double sl = ((stopInBodies)? MathMin(Close[s.point[1]],Close[s.point[1]]): Low[s.point[1]]) - MathPow(10,-Digits()) * slShift;
      double tp = calculateTP(entry,sl,strategyID,direction);
      if(Ask>entry){
         orderRegist(entry,sl,tp,strategyID,direction);
         isOrderResgisted = true;
      }
   }
   return isOrderResgisted;
}

bool strategySell6(int pos, GlobalBias &bias){
   const int strategyID = 6;
   MODE_DIRECTION direction = SELL;
   int maxCandelsPerStetup= strategyInputs[strategyID][direction].maxCandelsPerStetup;
   bool stopInBodies = strategyInputs[strategyID][direction].stopInBodies;
   bool useDivergences = strategyInputs[strategyID][direction].useDivergences;
   bool useImbalances = strategyInputs[strategyID][direction].useImbalances;
   double entryFibonacci = strategyInputs[strategyID][direction].entryFibonacci;
   int slShift= strategyInputs[strategyID][direction].slShift;
   int fractalNumber = strategyInputs[strategyID][direction].fractalNumber;
   int lastFractalNumber = strategyInputs[strategyID][direction].lastFractalNumber;
   bool isOrderResgisted = false;
   Setup s = setups.setup[pos];
   if(s.type == direction && s.point[7]<7*maxCandelsPerStetup && s.point[7] > 0 && isConfluent(bias,strategyID,direction) &&
         s.fractalNumber == fractalNumber && s.lastFractalNumber == lastFractalNumber &&
         isLowerLow(s.point[2],s.point[0],true,strategyID,direction) && 
         isHigherLow(s.point[4],s.point[2],true,strategyID,direction) &&
         isLowerHigh(s.point[5],s.point[3],false,strategyID,direction) && isLowerHigh(s.point[5],s.point[1],false,strategyID,direction) && //5 is the higher high
         isHigherHigh(s.point[7],s.point[5],false,strategyID,direction) && //5 is the higher high
         (existDivergence(s.point[7],s.point[5],strategyID,direction) || existDivergence(s.point[5],s.point[3],strategyID,direction)|| 
         existDivergence(s.point[5],s.point[1],strategyID,direction) || !useDivergences) &&
         isHigherLow(s.point[6],s.point[4],true,strategyID,direction) &&
         (existImbalance(s.point[1],s.point[0],fibonacci(High[s.point[1]],Low[s.point[0]],0.5),direction)|| !useImbalances)){
      double spread = NormalizeDouble(Ask - Bid,Digits());
      double entry = fibonacci(High[s.point[1]],Low[s.point[0]],entryFibonacci);
      double sl = ((stopInBodies)? MathMax(Close[s.point[1]],Close[s.point[1]]): High[s.point[1]]) + MathPow(10,-Digits()) * slShift + spread;
      double tp = calculateTP(entry,sl,strategyID,direction);
      if(Bid<entry){
         orderRegist(entry,sl,tp,strategyID,direction);
         isOrderResgisted = true;
      }
   }
   return isOrderResgisted;
}

bool strategyBuy6(int pos, GlobalBias &bias){
   const int strategyID = 6;
   MODE_DIRECTION direction = BUY;
   int maxCandelsPerStetup= strategyInputs[strategyID][direction].maxCandelsPerStetup;
   bool stopInBodies = strategyInputs[strategyID][direction].stopInBodies;
   bool useDivergences = strategyInputs[strategyID][direction].useDivergences;
   bool useImbalances = strategyInputs[strategyID][direction].useImbalances;
   double entryFibonacci = strategyInputs[strategyID][direction].entryFibonacci;
   int slShift= strategyInputs[strategyID][direction].slShift;
   int fractalNumber = strategyInputs[strategyID][direction].fractalNumber;
   int lastFractalNumber = strategyInputs[strategyID][direction].lastFractalNumber;
   bool isOrderResgisted = false;
   Setup s = setups.setup[pos];
   if(s.type == direction && s.point[7]<7*maxCandelsPerStetup && s.point[7] > 0 && isConfluent(bias,strategyID,direction) &&
         s.fractalNumber == fractalNumber && s.lastFractalNumber == lastFractalNumber &&
         isHigherHigh(s.point[2],s.point[0],true,strategyID,direction) &&
         isLowerHigh(s.point[4],s.point[2],true,strategyID,direction) &&
         isHigherLow(s.point[5],s.point[3],false,strategyID,direction) && isHigherLow(s.point[5],s.point[1],false,strategyID,direction) && //5 is the lower low
         isLowerLow(s.point[7],s.point[5],false,strategyID,direction) && //5 is the lower low
         (existDivergence(s.point[7],s.point[5],strategyID,direction) || existDivergence(s.point[5],s.point[3],strategyID,direction) ||
         existDivergence(s.point[5],s.point[1],strategyID,direction) || !useDivergences) &&
         isLowerHigh(s.point[6],s.point[4],true,strategyID,direction) &&
         (existImbalance(s.point[1],s.point[0],fibonacci(Low[s.point[1]],High[s.point[0]],0.5),direction)|| !useImbalances)){
      double spread = NormalizeDouble(Ask - Bid,Digits());
      double entry = fibonacci(Low[s.point[1]],High[s.point[0]],entryFibonacci) + spread;
      double sl = ((stopInBodies)? MathMin(Close[s.point[1]],Close[s.point[1]]): Low[s.point[1]]) - MathPow(10,-Digits()) * slShift;
      double tp = calculateTP(entry,sl,strategyID,direction);
      if(Ask>entry){
         orderRegist(entry,sl,tp,strategyID,direction);
         isOrderResgisted = true;
      }
   }
   return isOrderResgisted;
}

bool strategySell7(int pos, GlobalBias &bias){
   const int strategyID = 7;
   MODE_DIRECTION direction = SELL;
   int maxCandelsPerStetup= strategyInputs[strategyID][direction].maxCandelsPerStetup;
   bool stopInBodies = strategyInputs[strategyID][direction].stopInBodies;
   bool useDivergences = strategyInputs[strategyID][direction].useDivergences;
   bool useImbalances = strategyInputs[strategyID][direction].useImbalances;
   double entryFibonacci = strategyInputs[strategyID][direction].entryFibonacci;
   int slShift= strategyInputs[strategyID][direction].slShift;
   int fractalNumber = strategyInputs[strategyID][direction].fractalNumber;
   int lastFractalNumber = strategyInputs[strategyID][direction].lastFractalNumber;
   bool isOrderResgisted = false;
   Setup s = setups.setup[pos];
   if(s.type == direction && s.point[5]<5*maxCandelsPerStetup && s.point[5] > 0 && isConfluent(bias,strategyID,direction) &&
         s.fractalNumber == fractalNumber && s.lastFractalNumber == lastFractalNumber &&
         isHigherLow(s.point[2],s.point[0],true,strategyID,direction) && 
         isHigherLow(s.point[4],s.point[2],true,strategyID,direction) &&
         isHigherHigh(s.point[5],s.point[3],false,strategyID,direction) && isLowerHigh(s.point[3],s.point[1],false,strategyID,direction) && //3 is the higher high
         (existDivergence(s.point[5],s.point[3],strategyID,direction) || existDivergence(s.point[3],s.point[1],strategyID,direction) || !useDivergences) &&
         (existImbalance(s.point[1],s.point[0],fibonacci(High[s.point[1]],Low[s.point[0]],0.5),direction)|| !useImbalances)){
      double spread = NormalizeDouble(Ask - Bid,Digits());
      double entry = fibonacci(High[s.point[1]],Low[s.point[0]],entryFibonacci);
      double sl = ((stopInBodies)? MathMax(Close[s.point[1]],Close[s.point[1]]): High[s.point[1]]) + MathPow(10,-Digits()) * slShift + spread;
      double tp = calculateTP(entry,sl,strategyID,direction);
      if(Bid<entry){
         orderRegist(entry,sl,tp,strategyID,direction);
         isOrderResgisted = true;
      }
   }
   return isOrderResgisted;
}

bool strategyBuy7(int pos, GlobalBias &bias){
   const int strategyID = 7;
   MODE_DIRECTION direction = BUY;
   int maxCandelsPerStetup= strategyInputs[strategyID][direction].maxCandelsPerStetup;
   bool stopInBodies = strategyInputs[strategyID][direction].stopInBodies;
   bool useDivergences = strategyInputs[strategyID][direction].useDivergences;
   bool useImbalances = strategyInputs[strategyID][direction].useImbalances;
   double entryFibonacci = strategyInputs[strategyID][direction].entryFibonacci;
   int slShift= strategyInputs[strategyID][direction].slShift;
   int fractalNumber = strategyInputs[strategyID][direction].fractalNumber;
   int lastFractalNumber = strategyInputs[strategyID][direction].lastFractalNumber;
   bool isOrderResgisted = false;
   Setup s = setups.setup[pos];
   if(s.type == direction && s.point[5]<5*maxCandelsPerStetup && s.point[5] > 0 && isConfluent(bias,strategyID,direction) &&
         s.fractalNumber == fractalNumber && s.lastFractalNumber == lastFractalNumber &&
         isLowerHigh(s.point[2],s.point[0],true,strategyID,direction) &&
         isLowerHigh(s.point[4],s.point[2],true,strategyID,direction) &&
         isLowerLow(s.point[5],s.point[3],false,strategyID,direction) && isHigherLow(s.point[3],s.point[1],false,strategyID,direction)  && //3 is the lower low
         (existDivergence(s.point[5],s.point[3],strategyID,direction) || existDivergence(s.point[3],s.point[1],strategyID,direction) || !useDivergences) &&
         (existImbalance(s.point[1],s.point[0],fibonacci(Low[s.point[1]],High[s.point[0]],0.5),direction)|| !useImbalances)){
      double spread = NormalizeDouble(Ask - Bid,Digits());
      double entry = fibonacci(Low[s.point[1]],High[s.point[0]],entryFibonacci) + spread;
      double sl = ((stopInBodies)? MathMin(Close[s.point[1]],Close[s.point[1]]): Low[s.point[1]]) - MathPow(10,-Digits()) * slShift;
      double tp = calculateTP(entry,sl,strategyID,direction);
      if(Ask>entry){
         orderRegist(entry,sl,tp,strategyID,direction);
         isOrderResgisted = true;
      }
   }
   return isOrderResgisted;
}

GlobalBias directionBias(){
   GlobalBias bias;   
   bias.dailyBias = previusDayHighAndLowFib();
   bias.asianBias = sessionHighAndLowFib(0);
   bias.europeanBias = sessionHighAndLowFib(1);
   bias.americanBias = sessionHighAndLowFib(2);
   return bias;
}

bool isConfluent(GlobalBias &bias,int strategyID, MODE_DIRECTION direction){
   bool confluent = false;
   if((strategyInputs[strategyID][direction].previusDayBias && bias.dailyBias == direction) ||
         (strategyInputs[strategyID][direction].asianBias && bias.asianBias == direction) ||
         (strategyInputs[strategyID][direction].europeanBias && bias.europeanBias == direction) ||
         (strategyInputs[strategyID][direction].americanBias && bias.americanBias == direction))
      confluent = true;
   return confluent;
}

MODE_DIRECTION previusDayHighAndLowFib(){
   Movement m = getPreviusDayHighAndLow();
   return getDirectionBias(m.low,m.high,m.timeframe);
}

Movement getPreviusDayHighAndLow(){
   Movement m;
   m.timeframe = PERIOD_H1;
   m.high = high(m.timeframe,24);
   m.low = low(m.timeframe,24);
   return m;
}

MODE_DIRECTION sessionHighAndLowFib(int sessionPos){
   Movement m = getSessionHighAndLow(sessionPos);
   if(MathAbs(m.low - m.high)>2)
      return getDirectionBias(m.low,m.high,m.timeframe);
   else
      return NO_DIRECTION;
}

Movement getSessionHighAndLow(int sessionPos){
   Movement m;
   m.low = -1;
   m.high = -1;
   m.timeframe = PERIOD_M30;
   double startTime = timeToDouble(SESSIONS[sessionPos][0]);
   double finishTime = timeToDouble(SESSIONS[sessionPos][1]);
   bool finished = false;
   bool started = false;
   for(int i = 0;i<=100 && !finished; i++){
      double actualTime = timeToDouble(TimeHour(iTime(_Symbol,m.timeframe,i)),TimeMinute(iTime(_Symbol,m.timeframe,i)));
      if(isInsindeTimeRange(startTime,finishTime,actualTime) && !started){
         started = true;
         m.low = i;
         m.high = i;
      }
      else if(isInsindeTimeRange(startTime,finishTime,actualTime) && started){
         if(iLow(_Symbol,m.timeframe,i) < iLow(_Symbol,m.timeframe,m.low)){
            m.low = i;
         }
         if(iHigh(_Symbol,m.timeframe,i) > iHigh(_Symbol,m.timeframe,m.high)){
            m.high = i;
         }
      }
      else if(!isInsindeTimeRange(startTime,finishTime,actualTime) && started){
         finished = true;
      }
   }
   return m;
}



MODE_DIRECTION getDirectionBias(int lowCandel, int highCandel, ENUM_TIMEFRAMES timeframe){
   MODE_DIRECTION bias = NO_DIRECTION;
   if(lowCandel>highCandel){//The low appears first
      double upFibRange = fibonacci(iLow(_Symbol,timeframe,lowCandel),iHigh(_Symbol,timeframe,highCandel),0.50);
      double downFibRange = fibonacci(iLow(_Symbol,timeframe,lowCandel),iHigh(_Symbol,timeframe,highCandel),0.95);
      double entryValue = fibonacci(iLow(_Symbol,timeframe,lowCandel),iHigh(_Symbol,timeframe,highCandel),0.70);
      if(Bid>downFibRange && Bid<upFibRange && touchXbetweenYandZ(entryValue,upFibRange,downFibRange,BUY)){
         bias = BUY;
      }
   }
   
   else if(highCandel>lowCandel){//The high appears first
      double upFibRange = fibonacci(iHigh(_Symbol,timeframe,highCandel),iLow(_Symbol,timeframe,lowCandel),0.95);
      double downFibRange = fibonacci(iHigh(_Symbol,timeframe,highCandel),iLow(_Symbol,timeframe,lowCandel),0.50);
      double entryValue = fibonacci(iHigh(_Symbol,timeframe,highCandel),iLow(_Symbol,timeframe,lowCandel),0.70);
      if(Bid>downFibRange && Bid<upFibRange && touchXbetweenYandZ(entryValue,upFibRange,downFibRange,SELL)){
         bias = SELL;
      }
   }
   return bias;
}

bool touchXbetweenYandZ(double x,double y,double z, MODE_DIRECTION direction){
   bool touched = false;
   bool outOfRange = false;
   double upRange = MathMax(y,z);
   double downRange = MathMin(y,z);
   for(int i = 0; i<=100 && !touched && !outOfRange;i++){
      if((direction == BUY && Low[i] < x) || (direction == SELL && High[i] > x)){
         touched = true;
      }
      if(High[i]>upRange || Low[i]<downRange){
         outOfRange = true;
      }
   }
   return touched && !outOfRange;
}

bool isInsindeTimeRange(double startTime, double finishTime, double checkTime){
   bool isInside = false;
   if((startTime <= finishTime && checkTime >= startTime && checkTime <= finishTime) ||
         (startTime > finishTime && (checkTime >= startTime || checkTime <= finishTime)))
      isInside = true;
   return isInside;
}

int low(ENUM_TIMEFRAMES timeframe, int candels){
   int low = 0;
   for(int i = 1; i<=candels;i++){
      if(iLow(_Symbol,timeframe,i) < iLow(_Symbol,timeframe,low)){
         low = i;
      }
   }
   return low;
}

int high(ENUM_TIMEFRAMES timeframe, int candels){
   int high = 0;
   for(int i = 1; i<=candels;i++){
      if(iHigh(_Symbol,timeframe,i) > iHigh(_Symbol,timeframe,high)){
         high = i;
      }
   }
   return high;
}

bool isHigherHigh(int point1, int point2, bool structure,int strategyID, MODE_DIRECTION direction){
   bool bodyHigh = MathMax(Close[point1],Open[point1]) < MathMax(Close[point2],Open[point2]);
   bool wickHigh = High[point1]<High[point2];
   bool structureInBodies = strategyInputs[strategyID][direction].structureInBodies;
   if(structure && structureInBodies)
      return bodyHigh;
   else
      return wickHigh;
}

bool isHigherLow(int point1,int point2, bool structure,int strategyID, MODE_DIRECTION direction){
   bool bodyLow = MathMin(Close[point1],Open[point1]) < MathMin(Close[point2],Open[point2]);
   bool wickLow = Low[point1]<Low[point2];
   bool structureInBodies = strategyInputs[strategyID][direction].structureInBodies;
   if(structure && structureInBodies)
      return bodyLow;
   else
      return wickLow;
}

bool isLowerHigh(int point1, int point2, bool structure,int strategyID, MODE_DIRECTION direction){
   bool bodyHigh = MathMax(Close[point1],Open[point1]) > MathMax(Close[point2],Open[point2]);
   bool wickHigh = High[point1]>High[point2];
   bool structureInBodies = strategyInputs[strategyID][direction].structureInBodies;
   if(structure && structureInBodies)
      return bodyHigh;
   else
      return wickHigh;
}

bool isLowerLow(int point1,int point2, bool structure,int strategyID, MODE_DIRECTION direction){
   bool bodyLow = MathMin(Close[point1],Open[point1]) > MathMin(Close[point2],Open[point2]);
   bool wickLow = Low[point1]>Low[point2];
   bool structureInBodies = strategyInputs[strategyID][direction].structureInBodies;
   if(structure && structureInBodies)
      return bodyLow;
   else
      return wickLow;
}

//check if point3 is in the range above the level of fibonacci between 1 and 2
bool checkFibonacci(int point1,int point2,int point3,double level,int strategyID, MODE_DIRECTION direction){
   if((direction==BUY && fibonacci(Low[point1],High[point2],level) > Low[point3] && isHigherLow(point1,point3,false,strategyID,direction)) ||
         (direction==SELL && fibonacci(High[point1],Low[point2],level) < High[point3] && isLowerHigh(point1,point3,false,strategyID,direction)))
      return true;
   else
      return false;
}

double fibonacci(double value1,double value2,double level){
   return NormalizeDouble(value2-((value2-value1)*level),Digits());
}

bool existDivergence(int point1, int point2, int strategyID, MODE_DIRECTION direction){
   bool exist = false;
   if(direction == SELL && 
         ((isHigherHigh(point1,point2,false,strategyID,direction) && peakVolume(point1,SELL) > peakVolume(point2,SELL))||
         (isLowerHigh(point1,point2,false,strategyID,direction) && peakVolume(point1,SELL) < peakVolume(point2,SELL))))
      exist = true;
   else if(direction == BUY && 
         ((isLowerLow(point1,point2,false,strategyID,direction) && peakVolume(point1,BUY) > peakVolume(point2,BUY))||
         (isHigherLow(point1,point2,false,strategyID,direction) && peakVolume(point1,BUY) < peakVolume(point2,BUY))))
      exist = true;
   return exist;
}

bool isBUY(int i){
   return Close[i]>Open[i];
}

long peakVolume(int i, int type){
   long volume = -1;
   if(type == BUY){
      if(!isBUY(i))
         volume = Volume[i];
      else if(!isBUY(i+1))
         volume = Volume[i+1];
      else
         volume = Volume[i];
   }
   else if(type == SELL){
      if(isBUY(i))
         volume = Volume[i];
      else if(isBUY(i+1))
         volume = Volume[i+1];
      else
         volume = Volume[i];
   }
   return volume;
}

bool existImbalance(int firstPoint,int secundPoint,double startingValue, int type){
   bool thereIsImbalance = false;
   if(startingValue == 0){
      if(type == BUY)
         startingValue = Low[secundPoint];
      else if(type == SELL)
         startingValue = High[secundPoint];
   }
   for(int i = secundPoint + 1;i<=firstPoint && !thereIsImbalance;i++){
      if(type == BUY){
         if(Low[i]<startingValue){
            if(MathMin(Open[i],Close[i])>=startingValue || High[i+1]>=startingValue)
               startingValue = Low[i];
            else
               thereIsImbalance = true;
         }
      }else if(type == SELL){
         if(High[i]>startingValue){
            if(MathMax(Open[i],Close[i])<=startingValue || Low[i+1]<=startingValue)
               startingValue = High[i];
            else
               thereIsImbalance = true;
         }
      }
   }
   return thereIsImbalance;
}

double calculateTP(double entry,double sl, int strategy, MODE_DIRECTION direction){
   double tp = 0;
   double riskRatio = strategyInputs[strategy][direction].riskRatio;
   if(riskRatio > 0){
      tp = NormalizeDouble(entry + (entry - sl) * RISK_RATIO,Digits());
   }
   else if(riskRatio == 0){
      tp = longestTP(entry,sl);
   }
   return tp;
}

double longestTP(double entry,double sl){
   if(entry>sl){
      return highestHighForTP();
   }
   else{
      return lowestLowForTP();
   }
}

double highestHighForTP(){
   Movement m = getPreviusDayHighAndLow();
   double high = iHigh(_Symbol,m.timeframe,m.high);
   for(int i = 0; i < ArraySize(SESSIONS)/2;i++){
      m = getSessionHighAndLow(i);
      high = MathMax(high,iHigh(_Symbol,m.timeframe,m.high));
   }
   return high;
}

double lowestLowForTP(){
   Movement m = getPreviusDayHighAndLow();
   double low = iLow(_Symbol,m.timeframe,m.low);
   for(int i = 0; i < ArraySize(SESSIONS)/2;i++){
      m = getSessionHighAndLow(i);
      low = MathMin(low,iLow(_Symbol,m.timeframe,m.low));
   }
   return low;
}

//Regist an order
void orderRegist(double entry, double sl, double tp,int strategyID, MODE_DIRECTION direction){
   double slSize = ((direction == BUY)?(entry - sl):(sl-entry)) * MathPow(10,Digits());
   int maxSlPointsSize = strategyInputs[strategyID][direction].maxSlPointsSize;
   int minSlPointsSize = strategyInputs[strategyID][direction].minSlPointsSize;
   double cancelPendingOrderAtRiskReward = strategyInputs[strategyID][direction].cancelPendingOrderAtRiskReward;
   bool isOrderValid = (direction == BUY && Bid < entry + slSize / MathPow(10,Digits()) * cancelPendingOrderAtRiskReward && Ask > entry)||
                           (direction == SELL && Ask > entry - slSize / MathPow(10,Digits()) * cancelPendingOrderAtRiskReward && Bid < entry);
   if(!isRepeatedOrder(entry,sl,strategyID) && slSize < maxSlPointsSize && slSize > minSlPointsSize && isOrderValid){
      Order order;
      order.entry = entry;
      order.sl = sl;
      order.tp = tp;
      order.direction = direction;
      Print(strategyInputs[strategyID][direction].tradingTime.isTimeToEnter());
      if(strategyInputs[strategyID][direction].tradingTime.isTimeToEnter())
         orderRegist(order,strategyID);
      else{
         double tpBoundory;
         if(cancelPendingOrderAtRiskReward>0)
            tpBoundory = direction==BUY ? 
                  entry + slSize / MathPow(10,Digits()) * cancelPendingOrderAtRiskReward: 
                  entry - slSize / MathPow(10,Digits()) * cancelPendingOrderAtRiskReward;
         else
            tpBoundory = direction==BUY ? 100000 : 0;
         order.validityRange = Range(MathMax(tpBoundory,sl),MathMin(tpBoundory,sl));
         if(!pendingOrders[strategyID].orderExist(order))
            pendingOrders[strategyID].newOrder(order);
      }
   }
}

void orderRegist(Order &order,int strategyID){
   Print("Order Regist");
   int type  = -1;
   if(order.direction == BUY)
      type = OP_BUYLIMIT;
   else if(order.direction == SELL)
      type = OP_SELLLIMIT;
   double slSize = ((order.direction == BUY)?(order.entry - order.sl):(order.sl-order.entry)) * MathPow(10,Digits());
   double tickValue = MarketInfo(_Symbol, MODE_TICKVALUE);
   double maxLotsPerMargin = ACCOUNT_BALANCE/MarketInfo(_Symbol, MODE_MARGINREQUIRED)*AccountLeverage();
   double riskPerTrade = strategyInputs[strategyID][order.direction].riskPerTrade;
   double lotSize = MathFloor(MathMin(AccountEquity() * riskPerTrade / (slSize / MathPow(10,Digits())) *Point / tickValue,maxLotsPerMargin)*100)/100;
   double maxLots = MarketInfo(_Symbol,MODE_MAXLOT);
   Print("SLSize:" + slSize);
   Print("LotSize:" + lotSize);
   Print("SL:" + order.sl);
   Print("Entry:" + order.entry);
   Print("TP:" + order.tp);
   do{
      int ticket = OrderSend(_Symbol,type,MathMin(lotSize,maxLots),order.entry,SLIPPAGE,order.sl,order.tp,NULL,strategyID);
      lotSize-=maxLots;
      report.addPendingOrder(ticket);
   }while(lotSize>=0);
}

//Check if there is any repeated in the orders
bool isRepeatedOrder(double entry, double sl,int magicNumber){
   int ordersNumber = OrdersTotal();
   bool repeated = false;
   for(int i = 0; i < ordersNumber && !repeated; i++){
      OrderSelect(i,SELECT_BY_POS);
      if(areOrdersEquals(entry,sl,magicNumber,OrderOpenPrice(),OrderStopLoss(),OrderMagicNumber()))
         repeated = true;
   }
   return repeated;
}

bool areOrdersEquals(double entry1,double sl1,int magicNumber1, double entry2,double sl2,int magicNumber2){
   bool areOrdersEquals = false;
   if(magicNumber1 == magicNumber2 && ((entry2 - Point * POINTS_WITH_ONLY_1_TRADE <= entry1 && entry2 + Point * POINTS_WITH_ONLY_1_TRADE >= entry1) || sl1 == sl2))
      areOrdersEquals = true;
   return areOrdersEquals;
}

Setup getPoints(int size,int fractalsNumber, int lastFractalNumber){
   Setup s;
   s.fractalNumber = fractalsNumber;
   s.lastFractalNumber = lastFractalNumber;
   int actualPoint = 0;
   for(int i=0;i<ArraySize(s.point);i++){
      s.point[i] = -1;
   }
   s.type = NO_DIRECTION;
   for(int i=lastFractalNumber+1;i<=100 - fractalsNumber && actualPoint<size;i++){
      if(actualPoint==0){
      	if(isLow(i,fractalsNumber,lastFractalNumber) || isHigh(i,fractalsNumber,lastFractalNumber)){
            s.point[actualPoint++] = i;
      	}
      	if(isLow(i,fractalsNumber,lastFractalNumber))
      		s.type = SELL;
      	else if(isHigh(i,fractalsNumber,lastFractalNumber))
      		s.type = BUY;
      }
      else if(MathMod(actualPoint,2)==1){
      	if(s.type==SELL){
      		if(isLow(i,fractalsNumber,fractalsNumber)){
      		   if(Low[s.point[actualPoint - 1]]>Low[i])
      		      s.point[actualPoint - 1] = i;
      		}
      	else if(isHigh(i,fractalsNumber,fractalsNumber)){
      		   s.point[actualPoint++] = i;
      		}
      	}
      	else if(s.type == BUY){
      		if(isHigh(i,fractalsNumber,fractalsNumber)){
      		   if(High[s.point[actualPoint - 1]]<High[i])
      		      s.point[actualPoint - 1] = i;
      		}
      		else if(isLow(i,fractalsNumber,fractalsNumber)){
      		   s.point[actualPoint++] = i;
      		}
   	   }
      } 
      else if(actualPoint !=0 && MathMod(actualPoint,2) == 0){
   	   if(s.type==SELL){
      		if(isHigh(i,fractalsNumber,fractalsNumber)){
      		   if(High[s.point[actualPoint - 1]]<High[i])
      		      s.point[actualPoint - 1] = i;
      		}
      		else if(isLow(i,fractalsNumber,fractalsNumber)){
      		   s.point[actualPoint++] = i;
      		}
   	   }
   	   else if(s.type == BUY){
      		if(isLow(i,fractalsNumber,fractalsNumber)){
      		   if(Low[s.point[actualPoint - 1]]>Low[i])
      		      s.point[actualPoint - 1] = i;
      		}
      		else if(isHigh(i,fractalsNumber,fractalsNumber)){
      		   s.point[actualPoint++] = i;
      	   }
         }
      }
   }
   return s;
}

bool isLow(int pos,int leftNumber,int rightNumber){
   bool isLow = true;
   if(pos-rightNumber<0)
      rightNumber = pos;
   
   for(int i = pos-rightNumber;i<=pos+leftNumber;i++){
      if(Low[pos]>Low[i])
         isLow = false;
   }
   return isLow;
}
bool isHigh(int pos,int leftNumber,int rightNumber){
   bool isHigh = true;
   if(pos-rightNumber<0)
      rightNumber = pos;
   for(int i = pos-rightNumber;i<=pos+leftNumber;i++){
      if(High[pos]<High[i])
         isHigh = false;
   }
   return isHigh;
}


void ordersHandler(){
   closeTradeDuringTheNight();
   cancelInvalidPendingOrders();
   breakeven();
   trallingStop();
}

//Close all open trades and pending orders during the night
void closeTradeDuringTheNight(){
   int ordersNumber = OrdersTotal();
   for(int i = 0; i < ordersNumber; i++){
      OrderSelect(i,SELECT_BY_POS);
      const int strategyID = OrderMagicNumber();
      const MODE_DIRECTION direction = (OrderType() == OP_BUY || OrderType() == OP_BUYLIMIT) ? BUY:SELL;
      if(!strategyInputs[strategyID][direction].tradingTime.isTimeToEnter()){
         if(!(OrderType() == OP_BUY||OrderType() == OP_SELL)){
            double entry = OrderOpenPrice();
            double sl = OrderStopLoss();
            double tp = OrderTakeProfit();
            bool deleted = OrderDelete(OrderTicket());
            if(deleted)
               orderRegist(entry,sl,tp,strategyID,direction);
         }
      }
   }
}
 
void cancelInvalidPendingOrders(){
   int ordersNumber = OrdersTotal();
   for(int i = 0; i < ordersNumber; i++){
      OrderSelect(i,SELECT_BY_POS);
      int strategyID = OrderMagicNumber();
      MODE_DIRECTION direction = OrderType() == OP_BUY? BUY:SELL;
      double cancelPendingOrderAtRiskReward = strategyInputs[strategyID][direction].cancelPendingOrderAtRiskReward;
      if(cancelPendingOrderAtRiskReward > 0){
         if(OrderType() == OP_BUYLIMIT||OrderType() == OP_SELLLIMIT){
            double slSize = getSLSize(OrderLots());
            double entry = OrderOpenPrice();
            double maxPrice;
            if(OrderType() == OP_BUYLIMIT){
               maxPrice = entry + slSize * cancelPendingOrderAtRiskReward;
               if(Ask > maxPrice)
                  OrderDelete(OrderTicket());
            }
            if(OrderType() == OP_SELLLIMIT){
               maxPrice = entry - slSize * cancelPendingOrderAtRiskReward;
               if(Bid < maxPrice)
                  OrderDelete(OrderTicket());
            }
         }
      }
   }
}

void breakeven(){
   int total = OrdersTotal();
   for (int i = 0; i < total; i++){
      if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES) == true){
         int strategyID = OrderMagicNumber();
         MODE_DIRECTION direction = OrderType() == OP_BUY? BUY:SELL;
         double startingBE = strategyInputs[strategyID][direction].startingBE;
         if(startingBE > 0){
            double slSize = getSLSize(OrderLots());
            double sl = -1;
            
            if (!isThisOrderInBreakeven(i) && OrderType() == OP_BUY && Bid > OrderOpenPrice() + startingBE * slSize)
               sl = MathMax(OrderStopLoss(),NormalizeDouble(OrderOpenPrice() +  BREAKEVEN_SPREAD_SIZE * (Ask-Bid),Digits()));
            else if(!isThisOrderInBreakeven(i) && OrderType() == OP_SELL && Ask < OrderOpenPrice() - startingBE * slSize)
               sl = MathMin(OrderStopLoss(),NormalizeDouble(OrderOpenPrice() - BREAKEVEN_SPREAD_SIZE * (Ask-Bid),Digits()));
            if(sl != -1 && sl != OrderStopLoss())
               OrderModify(OrderTicket(), OrderOpenPrice(), sl, OrderTakeProfit(), 0, clrNONE);
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
         int strategyID = OrderMagicNumber();
         MODE_DIRECTION direction = OrderType() == OP_BUY? BUY:SELL;
         double startingTralingStop = strategyInputs[strategyID][direction].startingTralingStop;
         double tralingStopFactor = strategyInputs[strategyID][direction].tralingStopFactor;
         if(tralingStopFactor > 0){
            double slSize = getSLSize(OrderLots());
            double sl = -1;
            if(OrderType() == OP_BUY && Bid > OrderOpenPrice() + startingTralingStop * slSize){
               sl = NormalizeDouble(MathMax(OrderStopLoss(),Bid - tralingStopFactor * slSize),Digits());
            }
            else if(OrderType() == OP_SELL && Ask < OrderOpenPrice() - startingTralingStop * slSize){
               sl = NormalizeDouble(MathMin(OrderStopLoss(),Ask + tralingStopFactor * slSize),Digits());
            }
            if(sl != -1 && sl != OrderStopLoss())
               OrderModify(OrderTicket(), OrderOpenPrice(), sl, OrderTakeProfit(), 0, clrNONE);
         }
      }
   }
}

double getSLSize(double lotSize){
   double tickValue = MarketInfo(_Symbol, MODE_TICKVALUE);
   return AccountBalance() * RISK_PER_TRADE / lotSize*Point / tickValue;
}

double timeToDouble(string time){
   return StrToDouble(StringSubstr(time,0,2)) + StrToDouble(StringSubstr(time,3,2))/60;
}

double timeToDouble(int hour,int minute){
   return hour + minute/60.0;
}

double timeToDouble(datetime time){
   return timeToDouble(TimeHour(time),TimeMinute(time));
}

void inputsHandler(){
   if(INPUT_FILE == ""){
      Inputs defaultSet;
      defaultSet.run = false;
      defaultSet.tradingTime = TradingTime(DoubleToString(STARTING_TRADING_HOUR) + "-" + DoubleToString(ENDING_TRADING_HOUR));
      defaultSet.riskRatio = RISK_RATIO;
      defaultSet.riskPerTrade = RISK_PER_TRADE;
      defaultSet.startingBE = STARTING_BE;
      defaultSet.startingTralingStop = STARTING_TRALLING_STOP;
      defaultSet.tralingStopFactor = TRALLING_STOP_FACTOR;
      defaultSet.stopInBodies = STOP_IN_BODIES;
      defaultSet.maxSlPointsSize = MAX_SL_POINTS_SIZE;
      defaultSet.minSlPointsSize = MIN_SL_POINTS_SIZE;
      defaultSet.slShift = SL_SHIFT;
      defaultSet.cancelPendingOrderAtRiskReward = CANCEL_PENDING_ORDER_AT_RISK_REWARD;
      defaultSet.fractalNumber = FRACTALS_NUMBER;
      defaultSet.lastFractalNumber = LAST_FRACTAL_NUMBER;
      defaultSet.maxCandelsPerStetup = MAX_CANDELS_PER_SETUP;
      defaultSet.structureInBodies = STRUCTURE_IN_BODIES;
      defaultSet.useImbalances = USE_IMBALANCES;
      defaultSet.useDivergences = USE_DIVERGENCES;
      defaultSet.confirmationFibonacci = CONFIRMATION_FIBONACCI;
      defaultSet.entryFibonacci = ENTRY_FIBONACCI;
      defaultSet.previusDayBias = PREVIUS_DAY_BIAS;
      defaultSet.asianBias = ASIAN_BIAS;
      defaultSet.europeanBias = EUROPEAN_BIAS;
      defaultSet.americanBias = AMERICAN_BIAS;
      MODE_DIRECTION strategies[8];
      strategies[0] = STRATEGY_0; strategies[1] = STRATEGY_1; strategies[2] = STRATEGY_2; strategies[3] = STRATEGY_3; strategies[4] = STRATEGY_4; strategies[5] = STRATEGY_5; strategies[6] = STRATEGY_6; strategies[7] = STRATEGY_7;
      for(int i = 0;i < ArraySize(strategyInputs)/2;i++){
         for(int j = 0; j < 2;j++){
            if(strategies[i]==BOTH_DIRECTIONS || j == strategies[i])
               defaultSet.run = true;
            else
               defaultSet.run = false;
            
            strategyInputs[i][j] = defaultSet;
         }
      }
      setups.size = 1;
      setups.setup[0].fractalNumber = FRACTALS_NUMBER;
      setups.setup[0].lastFractalNumber = LAST_FRACTAL_NUMBER;
   }
   else{
      int file = FileOpen(INPUT_FILE + ".txt",FILE_READ);
      if(file == -1)
         Alert("ERROR: File Does Not Exist!");
      else{
         for(int i = 0;i < ArraySize(strategyInputs)/2;i++){
            for(int j = 0; j < 2;j++){
               Inputs actualSet;
               string fileContent = FileReadString(file); // ignoring first line
               actualSet.run = subString(FileReadString(file)) == "true";
               if(actualSet.run){
                  actualSet.tradingTime = TradingTime(subString(FileReadString(file)));
                  actualSet.riskRatio = StringToDouble(subString(FileReadString(file)));
                  actualSet.riskPerTrade = StringToDouble(subString(FileReadString(file)));
                  actualSet.startingBE = StringToDouble(subString(FileReadString(file)));
                  actualSet.startingTralingStop = StringToDouble(subString(FileReadString(file)));
                  actualSet.tralingStopFactor = StringToDouble(subString(FileReadString(file)));
                  actualSet.stopInBodies = subString(FileReadString(file)) == "true";
                  actualSet.maxSlPointsSize = (int)StringToInteger(subString(FileReadString(file)));
                  actualSet.minSlPointsSize = (int)StringToInteger(subString(FileReadString(file)));
                  actualSet.slShift = (int)StringToInteger(subString(FileReadString(file)));
                  actualSet.cancelPendingOrderAtRiskReward = StringToDouble(subString(FileReadString(file)));
                  actualSet.fractalNumber = (int)StringToInteger(subString(FileReadString(file)));
                  actualSet.lastFractalNumber = (int)StringToInteger(subString(FileReadString(file)));
                  actualSet.maxCandelsPerStetup = (int)StringToInteger(subString(FileReadString(file)));
                  actualSet.structureInBodies = subString(FileReadString(file)) == "true";
                  actualSet.useImbalances = subString(FileReadString(file)) == "true";
                  actualSet.useDivergences = subString(FileReadString(file)) == "true";
                  actualSet.confirmationFibonacci = StringToDouble(subString(FileReadString(file)));
                  actualSet.entryFibonacci = StringToDouble(subString(FileReadString(file)));
                  actualSet.previusDayBias = subString(FileReadString(file)) == "true";
                  actualSet.asianBias = subString(FileReadString(file)) == "true";
                  actualSet.europeanBias = subString(FileReadString(file)) == "true";
                  actualSet.americanBias = subString(FileReadString(file)) == "true";
                  strategyInputs[i][j] = actualSet;
                  handleFractalsInputs(i,j);
               }
               else{
                  strategyInputs[i][j] = actualSet;
               }
            }
         }
      }
      FileClose(file);
   }
   for(int k =0; k < setups.size; k++){
   }
}

string subString(string data){
   string subStrings[2];
   StringSplit(data,':',subStrings);
   if(ArraySize(subStrings)!=2)
      Alert("ERROR: Wrong Input Parameter (" + data + ")!");
   return subStrings[1];
}

void handleFractalsInputs(int i,int j){
   bool repeated = false;
   for(int k =0; k < setups.size; k++){
      if(setups.setup[k].fractalNumber == strategyInputs[i][j].fractalNumber && 
            setups.setup[k].lastFractalNumber == strategyInputs[i][j].lastFractalNumber)
         repeated = true;
   }
   if(!repeated){
      setups.setup[setups.size].fractalNumber = strategyInputs[i][j].fractalNumber;
      setups.setup[setups.size].lastFractalNumber = strategyInputs[i][j].lastFractalNumber;
      setups.size++;
   }
}

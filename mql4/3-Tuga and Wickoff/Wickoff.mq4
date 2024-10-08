//+------------------------------------------------------------------+
//|                                                      Wickoff.mq4 |
//|                                                       Diogo Rolo |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Diogo Rolo"
#property version   "1.00"
#property strict
#include <F1rstMillion/Report.mqh>
#include <F1rstMillion/Lists/CircularList.mqh>
#include <F1rstMillion/Enum/MODE_DIRECTION.mqh>

datetime LastBar; //variable to allow the method @OnBar() excecute properly

Report report;

CircularList extraCandelsM1;
CircularList extraCandelsBias[];
const int BIAS_SIZE = 6;
const ENUM_TIMEFRAMES BIAS_TIMEFRAMES[] = {PERIOD_M5,PERIOD_M15,PERIOD_M30,PERIOD_H1,PERIOD_H4,PERIOD_D1};

enum MODE_BIAS {
   NO_BIAS = 0,
   AVERAGE = 1,
   MOVEMENT = 2,
   BOTH_BIAS = 3
}; 

enum MODE_RSI {
   NO_RSI = 0,
   PS = 1,
   SC = 2,
   ST_SOW = 3
};


const int MAX_CANDELS = 100; //Max candels that will be checked (max is 100)
const int BREAKEVEN_SPREAD_SIZE = 2;//When the EA try to put breakeven will put it this times of spreads above or bellow the open price
const int POINTS_WITH_ONLY_1_TRADE = 20;//The EA will only open 1 trade if the entry differ these number of points


input const double STARTING_TRADING_HOUR_1 = 9.5;
input const double ENDING_TRADING_HOUR_1 = 13;
input const double STARTING_TRADING_HOUR_2 = 14.5;
input const double ENDING_TRADING_HOUR_2 = 20;
const int SLIPPAGE = 10; 

input const double RISK_RATIO = 50;
const double RISK_PER_TRADE = 0.01;
input const double ENTRY_FIBONACCI_1 = 0.7;
input const double ENTRY_FIBONACCI_2 = 0.7;
input const double ENTRY_FIBONACCI_3 = 0.5;
input const double STARTING_BE = 1;
input const double STARTING_TRALLING_STOP = 0;
input const double TRALLING_STOP_FACTOR = 5;
input const double CANCEL_PENDING_ORDER_AT_RISK_REWARD = 20;
const bool CLOSE_TRADES_DURING_NIGHT = false;
input const bool USE_VOL = false;
input const int VOL_LENGHT = 100;
input const double VOL_TRIGGER = 2.5;
input const int EXTRA_CANDELS = 50;
input const int EXTRA_CANDELS_BIAS = 50;

input const MODE_RSI RSI = NO_RSI;
input const bool VOL_INSTEAD_RSI = false;

input const bool USE_BIAS = false;
input const int ATR_LENGHT = 7;
input const double ATR_MULTIPLIER = 1;
input const int POINT_ALLOWANCE = 1;
input const bool BIG_SPRING = false;

input const bool ACC1 = true;
input const bool ACC2 = true;
input const bool RACC1 = true;
input const bool DIS1 = true;
input const bool DIS2 = true;
input const bool RDIS1 = true;

input const double AR_FIBO_1 = 0.5;
input const double AR_FIBO_2 = 0.8;
input const double ST_FIBO_1 = 0.5;
input const double ST_FIBO_2 = 1.1;
input const double UA_FIBO_1 = 0.7;
input const double UA_FIBO_2 = 0.95;
input const double STSOW_FIBO_1_1 = 0.9;
input const double STSOW_FIBO_1_2 = 1.2;
input const double STSOW_FIBO_2_1 = 1;
input const double STSOW_FIBO_2_2 = 1.2;
input const double STUA_FIBO_1_1 = 0.5;
input const double STUA_FIBO_1_2 = 0.9;
input const double STUA_FIBO_2_1 = 1;
input const double STUA_FIBO_2_2 = 1.5;
input const double SPRING_FIBO_1 = 1;
input const double SPRING_FIBO_2 = 2;
input const double LPS_FIBO_1 = 0.5;
input const double LPS_FIBO_2 = 0;


const string points[] = {"sos","spring","stua","stsow","ua","st","ar","sc","b","ps","a"};

int pointsFile;
const string FOLDER_BIAS_NAME = "biasPrint";

struct Spring{
   double spring;
   int pos;
};

class SpringsArray{
private:
   Spring springs[100];
   int counter;
   void remove();
   void removeElement(int pos);
public:
   SpringsArray();
   void add(double spring, int pos);
   void increment();
   bool existSpring(double spring);
};

SpringsArray::SpringsArray(void){
   counter = 0;
   for(int i=0;i<100;i++){
      Spring spring;
      spring.spring = -1;
      spring.pos = -1;
      springs[i] = spring;
   }
}
void SpringsArray::add(double spring,int pos){
   Spring temp;
   temp.spring = spring;
   temp.pos = pos;
   springs[counter++] = temp;
}
void SpringsArray::increment(void){
   for(int i = 0; i<counter; i++)
      springs[i].pos++;
}
void SpringsArray::remove(void){
   for(int i = counter-1;i>=0;i--){
      if(springs[i].pos >= MAX_CANDELS){
         removeElement(i);
      }
   }
}
void SpringsArray::removeElement(int pos){
   for(int i = pos; i<counter-1; i++){
      springs[i] = springs[i+1];
   }
   counter--;
}
bool SpringsArray::existSpring(double spring){
   bool exists = false;
   for(int i = 0; i<counter; i++){
      if(springs[i].spring == spring)
         exists = true;
   }
   return exists;
}

SpringsArray springsArray;

int biasFile;

int OnInit(){
   LastBar = -1;
   extraCandelsM1 = CircularList(EXTRA_CANDELS+1);
   ArrayResize(extraCandelsBias,BIAS_SIZE);
   for(int i = 0; i < BIAS_SIZE; i++)
      extraCandelsBias[i] = CircularList(EXTRA_CANDELS_BIAS+1);
   FileDelete("Backtesting_" +WindowExpertName()+ "\\Points.csv");
   pointsFile = FileOpen("Backtesting_" +WindowExpertName()+ "\\Points.csv",FILE_WRITE|FILE_CSV);
   FileWrite(pointsFile,"Ticket","a","ps","b","sc","ar","st","ua","stsow","stua","spring","sos");
   FolderClean("Backtesting_" +WindowExpertName()+"\\"+FOLDER_BIAS_NAME);
   Print("StopLevel = ", (int)MarketInfo(Symbol(), MODE_STOPLEVEL));
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason){
   FileClose(biasFile);
   FileClose(pointsFile);
   report.printReport();
}

int createFile(string name){
   int counter = 0;
   string fileName = "Backtesting_" +WindowExpertName()+ "\\"+ name + ".csv";
   if(FileIsExist(fileName)){
      do{
         counter++;
         fileName = "Backtesting_" +WindowExpertName()+ "\\"+ name + "(" + IntegerToString(counter) + ")" + ".csv";
      }
      while (FileIsExist(fileName));
   }
   Print("The report will be saved in ",TerminalInfoString(TERMINAL_DATA_PATH),"\\",fileName);
   return FileOpen(fileName,FILE_WRITE|FILE_CSV);
}

void OnTick(){
   report.onTick();
   ordersHandler();
   if(LastBar != Time[0]){
      LastBar = Time[0]; 
      OnBar();
   }
}

void OnBar(){
   Candel lastCandel = Candel(High[100],Low[100],Open[100],Close[100],Volume[100]);
   extraCandelsM1.addLast(lastCandel);
   if(!USE_BIAS || isConfluent(BUY)){
      if(ACC1)
         accumulation1();
      if(ACC2)
         accumulation2();
      if(RACC1)
         reaccumulation1();
   }
   if(!USE_BIAS || isConfluent(SELL)){
      if(DIS1)
         distribution1();
      if(DIS2)
         distribution2();
      if(RDIS1)
         redistribution1();
   }
   springsArray.increment();
}

bool isConfluent(MODE_DIRECTION direction){
   double springValueApp = direction==BUY ? MathMin(iLow (_Symbol,PERIOD_H1,0), iLow (_Symbol,PERIOD_H1,1)):
                                            MathMax(iHigh(_Symbol,PERIOD_H1,0), iHigh(_Symbol,PERIOD_H1,1));
   for(int t = 0; t < 6; t++){
      ENUM_TIMEFRAMES timeframe = BIAS_TIMEFRAMES[t];
      for(int i = 0; i < MAX_CANDELS - ATR_LENGHT-1; i++){
         double open = iOpen(_Symbol,timeframe,i);
         double high = iHigh(_Symbol,timeframe,i);
         double low = iOpen(_Symbol,timeframe,i);
         double close = iClose(_Symbol,timeframe,i);
         if(direction == BUY){
            if(open <= low + POINT_ALLOWANCE * MathPow(10,-Digits()) && close > open && 
               close - open > atr(ATR_LENGHT,timeframe,i) * ATR_MULTIPLIER && low < Close[0] && high > springValueApp)
               return true;
            else if(high < springValueApp)
               break;
         }
         else if(direction == SELL){
            if(open >= high - POINT_ALLOWANCE * MathPow(10,-Digits()) && close < open && 
               open - close > atr(ATR_LENGHT,timeframe,i) * ATR_MULTIPLIER && high > Close[0] && low < springValueApp)
               return true;
            else if(low > springValueApp)
               break;
         }
      }
   }
   return false;
}

double atr(int lenght,  ENUM_TIMEFRAMES timeframe, int pos){
   double atr = 0;
   for(int i = pos +1; i <= pos + lenght; i++){
      atr += MathAbs(iClose(_Symbol,timeframe,pos) - iOpen(_Symbol,timeframe,pos));
   }
   atr/=lenght;
   return atr;
}

void accumulation1(){
   const int strategyID = 0;
   const MODE_DIRECTION direction = BUY;
   int size = MAX_CANDELS /*+ extraCandelsM1.getSize()-1*/;
   double smallerValue = Bid;
   for(int sos = 1; sos <=  size -12;sos++){ //Looking for the sign of strength(sos)
      smallerValue = MathMin(smallerValue,low(sos));
      if(isReallyHigh(sos,0)){
         for(int spring = sos + 1; spring <= size -11;spring++){//Looking for the spring
            if(high(spring)>= high(sos))//If there is any value that spring can take that is higher than the sos this sos is not valid
               spring = MAX_CANDELS + 1;//no more springs for this sos
            else if(isReallyLow(spring,sos) && fibonacci(low(spring),high(sos),ENTRY_FIBONACCI_1)<Bid && !springsArray.existSpring(low(spring)) && low(spring) < smallerValue && isBigSpring(spring, direction)){
               for(int stua = spring + 1; stua <= size -10;stua++){//Looking for the stua
                  if(low(stua)<=low(spring)){//If there is any value that stua can take that is lower than the spring this spring is not valid
                     stua = MAX_CANDELS + 1;//no more stuas for this spring
                  }
                  else if(isReallyHigh(stua,spring) && high(stua) < high(sos)){
                     for(int stsow = stua + 1; stsow <= size -9;stsow++){//Looking for the stsow
                        if(high(stsow) >= high(stua)){//If there is any value that stsow can take that is higher than the stua this stua is not valid
                           stsow = MAX_CANDELS + 1;//no more stsows for this stua
                        }
                        else if(isReallyLow(stsow,stua) && low(stsow) > low(spring) && (RSI!=ST_SOW || rsiDivergence(spring,stsow,direction))){
                           for(int ua = stsow + 1; ua <= size -8;ua++){//Looking for the ua
                              if(low(ua) <= low(stsow)){//If there is any value that ua can take that is lower than the stsow this stsow is not valid
                                 ua = MAX_CANDELS + 1;//no more uas for this stsow
                              }
                              else if(isReallyHigh(ua,stsow) && fibonacci(high(ua),low(stsow),STUA_FIBO_1_1)<=high(stua) && fibonacci(high(ua),low(stsow),STUA_FIBO_1_2)>=high(stua) 
                                                             && fibonacci(low(stsow),high(ua),SPRING_FIBO_1) > low(spring) && fibonacci(low(stsow),high(ua),SPRING_FIBO_2) < low(spring)){
                                 for(int st = ua + 1; st <= size -7;st++){//Looking for the st
                                    if(high(st) >= high(ua)){//If there is any value that st can take that is higher than the ua this ua is not valid
                                       st = MAX_CANDELS + 1;//no more sts for this ua
                                    }
                                    else if(isReallyLow(st,ua)){
                                       for(int ar = st + 1; ar <= size -6;ar++){//Looking for the ar
                                          if(low(ar) <= low(st)){//If there is any value that ar can take that is lower than the st this st is not valid
                                             ar = MAX_CANDELS + 1;//no more ars for this st
                                          }
                                          else if(isReallyHigh(ar,st) && high(ar)<high(ua)){
                                             for(int sc = ar + 1; sc <= size -5;sc++){//Looking for the sc
                                                if(high(sc) >= high(ar)){//If there is any value that sc can take that is higher than the ar this ar is not valid
                                                   sc = MAX_CANDELS + 1;//no more scs for this ar
                                                }
                                                else if(isReallyLow(sc,ar) && fibonacci(low(sc),high(ar),ST_FIBO_1)>=low(st) && fibonacci(low(sc),high(ar),ST_FIBO_2)<=low(st) && (RSI!=SC || rsiDivergence(spring,sc,direction))){
                                                   for(int b = sc + 1; b <= size -4;b++){//Looking for the b
                                                      if(low(b) <= low(sc)){//If there is any value that b can take that is lower than the sc this sc is not valid
                                                         b = MAX_CANDELS + 1;//no more bs for this sc
                                                      }
                                                      else if(isReallyHigh(b,sc) && fibonacci(low(sc),high(b),STSOW_FIBO_1_1)>=low(stsow) && fibonacci(low(sc),high(b),STSOW_FIBO_1_2)<=low(stsow) &&
                                                              fibonacci(high(b),low(sc),AR_FIBO_1)<=high(ar) && fibonacci(high(b),low(sc),AR_FIBO_2)>=high(ar) &&
                                                              fibonacci(high(b),low(sc),UA_FIBO_1)<=high(ua) && fibonacci(high(b),low(sc),UA_FIBO_2)>=high(ua)){
                                                         for(int ps = b + 1; ps <= size -3;ps++){//Looking for the ps
                                                            if(high(ps) >= high(b)){//If there is any value that ps can take that is higher than the b this b is not valid
                                                               ps = MAX_CANDELS + 1;//no more pss for this b
                                                            }
                                                            else if(isReallyLow(ps,b) && (!USE_VOL || relativeVolume(VOL_LENGHT,VOL_TRIGGER,ps)) && low(ps)>low(sc) && (RSI!=PS || rsiDivergence(spring,ps,direction))){//Max Volume
                                                               for(int a = ps + 1; a <= size -2;a++){//Looking for the a
                                                                  if(low(a) <= low(ps)){//If there is any value that a can take that is lower than the ps this ps is not valid
                                                                     a = MAX_CANDELS + 1;//no more as for this ps
                                                                  }
                                                                  else if(isReallyHigh(a,ps) && fibonacci(high(a),low(ps),0.382)<=high(b) && high(b)<high(a) && high(a)>high(a+1) && high(a)>high(a+2)){
                                                                     double spread = NormalizeDouble(Ask - Bid,Digits());
                                                                     double entry = fibonacci(low(spring),high(stua),ENTRY_FIBONACCI_1) + spread;
                                                                     double sl = low(spring);
                                                                     double tp = NormalizeDouble(entry + (entry - sl) * RISK_RATIO,Digits());;
                                                                     if(Ask>entry){
                                                                        int ticket = orderRegist(entry,sl,tp,strategyID,direction);
                                                                        if(ticket !=-1){
                                                                           int totalSize = MAX_CANDELS + extraCandelsM1.getSize();
                                                                           FileWrite(pointsFile,ticket,totalSize-a,totalSize-ps,totalSize-b,totalSize-sc,totalSize-ar,totalSize-st,totalSize-ua,totalSize-stsow,totalSize-stua,totalSize-spring,totalSize-sos);
                                                                        }
                                                                     }
                                                                  }
                                                               }
                                                            }
                                                         }
                                                      }
                                                   }
                                                }
                                             }
                                          }
                                       }
                                    }
                                 }
                              }
                           }
                        }
                     }
                  }
               }
            }
         }
      }
   }
}

void accumulation2(){
   const int strategyID = 1;
   const MODE_DIRECTION direction = BUY;
   int size = MAX_CANDELS /*+ extraCandelsM1.getSize()-1*/;
   double smallerValue = Bid;
   for(int sos = 1; sos <=  size -12;sos++){ //Looking for the sign of strength(sos)
      smallerValue = MathMin(smallerValue,low(sos));
      if(isReallyHigh(sos,0)){
         for(int spring = sos + 1; spring <= size -11;spring++){//Looking for the spring
            if(high(spring)>= high(sos))//If there is any value that spring can take that is higher than the sos this sos is not valid
               spring = MAX_CANDELS + 1;//no more springs for this sos
            else if(isReallyLow(spring,sos) && !springsArray.existSpring(low(spring)) && low(spring) < smallerValue && isBigSpring(spring, direction)){
               for(int stua = spring + 1; stua <= size -10;stua++){//Looking for the stua
                  if(low(stua)<=low(spring)){//If there is any value that stua can take that is lower than the spring this spring is not valid
                     stua = MAX_CANDELS + 1;//no more stuas for this spring
                  }
                  else if(isReallyHigh(stua,spring) && high(stua) < high(sos)){
                     for(int stsow = stua + 1; stsow <= size -9;stsow++){//Looking for the stsow
                        if(high(stsow) >= high(stua)){//If there is any value that stsow can take that is higher than the stua this stua is not valid
                           stsow = MAX_CANDELS + 1;//no more stsows for this stua
                        }
                        else if(isReallyLow(stsow,stua) && low(stsow) < low(spring)){
                           for(int ua = stsow + 1; ua <= size -8;ua++){//Looking for the ua
                              if(low(ua) <= low(stsow)){//If there is any value that ua can take that is lower than the stsow this stsow is not valid
                                 ua = MAX_CANDELS + 1;//no more uas for this stsow
                              }
                              else if(isReallyHigh(ua,stsow) && fibonacci(high(ua),low(stsow),STUA_FIBO_2_1)<=high(stua) && fibonacci(high(ua),low(stsow),STUA_FIBO_2_2)>=high(stua) 
                                                             && fibonacci(high(ua),low(stsow),LPS_FIBO_1) > low(spring) && fibonacci(high(ua),low(stsow),LPS_FIBO_2) < low(spring)){Print("HI");
                                 for(int st = ua + 1; st <= size -7;st++){//Looking for the st
                                    if(high(st) >= high(ua)){//If there is any value that st can take that is higher than the ua this ua is not valid
                                       st = MAX_CANDELS + 1;//no more sts for this ua
                                    }
                                    else if(isReallyLow(st,ua)){
                                       for(int ar = st + 1; ar <= size -6;ar++){//Looking for the ar
                                          if(low(ar) <= low(st)){//If there is any value that ar can take that is lower than the st this st is not valid
                                             ar = MAX_CANDELS + 1;//no more ars for this st
                                          }
                                          else if(isReallyHigh(ar,st) && high(ar)<high(ua)){
                                             for(int sc = ar + 1; sc <= size -5;sc++){//Looking for the sc
                                                if(high(sc) >= high(ar)){//If there is any value that sc can take that is higher than the ar this ar is not valid
                                                   sc = MAX_CANDELS + 1;//no more scs for this ar
                                                }
                                                else if(isReallyLow(sc,ar) && fibonacci(low(sc),high(ar),ST_FIBO_1)>=low(st) && fibonacci(low(sc),high(ar),ST_FIBO_2)<=low(st) && (RSI!=SC || rsiDivergence(stsow,sc,direction))){
                                                   for(int b = sc + 1; b <= size -4;b++){//Looking for the b
                                                      if(low(b) <= low(sc)){//If there is any value that b can take that is lower than the sc this sc is not valid
                                                         b = MAX_CANDELS + 1;//no more bs for this sc
                                                      }
                                                      else if(isReallyHigh(b,sc) && fibonacci(low(sc),high(b),STSOW_FIBO_2_1)>=low(stsow) && fibonacci(low(sc),high(b),STSOW_FIBO_2_2)<=low(stsow) &&
                                                              fibonacci(high(b),low(sc),AR_FIBO_1)<=high(ar) && fibonacci(high(b),low(sc),AR_FIBO_2)>=high(ar) &&
                                                              fibonacci(high(b),low(sc),UA_FIBO_1)<=high(ua) && fibonacci(high(b),low(sc),UA_FIBO_2)>=high(ua)){
                                                         for(int ps = b + 1; ps <= size -3;ps++){//Looking for the ps
                                                            if(high(ps) >= high(b)){//If there is any value that ps can take that is higher than the b this b is not valid
                                                               ps = MAX_CANDELS + 1;//no more pss for this b
                                                            }
                                                            else if(isReallyLow(ps,b) && (!USE_VOL || relativeVolume(VOL_LENGHT,VOL_TRIGGER, ps)) && low(ps)>low(sc) && (RSI!=PS || rsiDivergence(stsow,ps,direction))){//Max Volume
                                                               for(int a = ps + 1; a <= size -2;a++){//Looking for the a
                                                                  if(low(a) <= low(ps)){//If there is any value that a can take that is lower than the ps this ps is not valid
                                                                     a = MAX_CANDELS + 1;//no more as for this ps
                                                                  }
                                                                  else if(isReallyHigh(a,ps) && fibonacci(high(a),low(ps),0.382)<=high(b) && high(b)<high(a) && high(a)>high(a+1) && high(a)>high(a+2)){
                                                                     double spread = NormalizeDouble(Ask - Bid,Digits());
                                                                     double entry = fibonacci(low(stsow),high(ua),ENTRY_FIBONACCI_2) + spread;
                                                                     double sl = low(stsow);
                                                                     double tp = NormalizeDouble(entry + (entry - sl) * RISK_RATIO,Digits());;
                                                                     if(Ask>entry){
                                                                        int ticket = orderRegist(entry,sl,tp,strategyID,direction);
                                                                        if(ticket !=-1){
                                                                           int totalSize = MAX_CANDELS + extraCandelsM1.getSize();
                                                                           FileWrite(pointsFile,ticket,totalSize-a,totalSize-ps,totalSize-b,totalSize-sc,totalSize-ar,totalSize-st,totalSize-ua,totalSize-stsow,totalSize-stua,totalSize-spring,totalSize-sos);
                                                                        }
                                                                     }
                                                                  }
                                                               }
                                                            }
                                                         }
                                                      }
                                                   }
                                                }
                                             }
                                          }
                                       }
                                    }
                                 }
                              }
                           }
                        }
                     }
                  }
               }
            }
         }
      }
   }
}

void reaccumulation1(){
   const int strategyID = 2;
   const MODE_DIRECTION direction = BUY;
   int size = MAX_CANDELS /*+ extraCandelsM1.getSize()-1*/;
   double smallerValue = Bid;
   for(int choch = 1; choch <= size -14;choch++){
      if(isReallyLow(choch,0)){
         for(int sos = choch + 1; sos <=  size -13;sos++){ //Looking for the sign of strength(sos)
            smallerValue = MathMin(smallerValue,low(sos));
            if(low(sos)<=low(choch)){
               sos = MAX_CANDELS + 1;
            }
            else if(isReallyHigh(sos,0) && !springsArray.existSpring(high(sos))){
               for(int spring = sos + 1; spring <= size -12;spring++){//Looking for the spring
                  if(high(spring)>= high(sos))//If there is any value that spring can take that is higher than the sos this sos is not valid
                     spring = MAX_CANDELS + 1;//no more springs for this sos
                  else if(isReallyLow(spring,sos) && low(spring) > low(choch) && isBigSpring(spring, direction)){
                     for(int stua = spring + 1; stua <= size -11;stua++){//Looking for the stua
                        if(low(stua)<=low(spring)){//If there is any value that stua can take that is lower than the spring this spring is not valid
                           stua = MAX_CANDELS + 1;//no more stuas for this spring
                        }
                        else if(isReallyHigh(stua,spring) && high(stua) < high(sos)){
                           for(int stsow = stua + 1; stsow <= size -12;stsow++){//Looking for the stsow
                              if(high(stsow) >= high(stua)){//If there is any value that stsow can take that is higher than the stua this stua is not valid
                                 stsow = MAX_CANDELS + 1;//no more stsows for this stua
                              }
                              else if(isReallyLow(stsow,stua) && low(stsow) > low(spring) && (RSI!=ST_SOW || rsiDivergence(spring,stsow,direction))){
                                 for(int ua = stsow + 1; ua <= size -9;ua++){//Looking for the ua
                                    if(low(ua) <= low(stsow)){//If there is any value that ua can take that is lower than the stsow this stsow is not valid
                                       ua = MAX_CANDELS + 1;//no more uas for this stsow
                                    }
                                    else if(isReallyHigh(ua,stsow) && fibonacci(high(ua),low(stsow),STUA_FIBO_1_1)<=high(stua) && fibonacci(high(ua),low(stsow),STUA_FIBO_1_2)>=high(stua) 
                                                                   && fibonacci(low(stsow),high(ua),SPRING_FIBO_1) > low(spring) && fibonacci(low(stsow),high(ua),SPRING_FIBO_2) < low(spring)){
                                       for(int st = ua + 1; st <= size -8;st++){//Looking for the st
                                          if(high(st) >= high(ua)){//If there is any value that st can take that is higher than the ua this ua is not valid
                                             st = MAX_CANDELS + 1;//no more sts for this ua
                                          }
                                          else if(isReallyLow(st,ua)){
                                             for(int ar = st + 1; ar <= size -7;ar++){//Looking for the ar
                                                if(low(ar) <= low(st)){//If there is any value that ar can take that is lower than the st this st is not valid
                                                   ar = MAX_CANDELS + 1;//no more ars for this st
                                                }
                                                else if(isReallyHigh(ar,st) && high(ar)<high(ua)){
                                                   for(int sc = ar + 1; sc <= size -6;sc++){//Looking for the sc
                                                      if(high(sc) >= high(ar)){//If there is any value that sc can take that is higher than the ar this ar is not valid
                                                         sc = MAX_CANDELS + 1;//no more scs for this ar
                                                      }
                                                      else if(isReallyLow(sc,ar) && fibonacci(low(sc),high(ar),ST_FIBO_1)>=low(st) && fibonacci(low(sc),high(ar),ST_FIBO_2)<=low(st) && (RSI!=SC || rsiDivergence(spring,sc,direction))){
                                                         for(int b = sc + 1; b <= size -5;b++){//Looking for the b
                                                            if(low(b) <= low(sc)){//If there is any value that b can take that is lower than the sc this sc is not valid
                                                               b = MAX_CANDELS + 1;//no more bs for this sc
                                                            }
                                                            else if(isReallyHigh(b,sc) && fibonacci(low(sc),high(b),STSOW_FIBO_1_1)>=low(stsow) && fibonacci(low(sc),high(b),STSOW_FIBO_1_2)<=low(stsow) &&
                                                                    fibonacci(high(b),low(sc),AR_FIBO_1)<=high(ar) && fibonacci(high(b),low(sc),AR_FIBO_2)>=high(ar) &&
                                                                    fibonacci(high(b),low(sc),UA_FIBO_1)<=high(ua) && fibonacci(high(b),low(sc),UA_FIBO_2)>=high(ua)){
                                                               for(int ps = b + 1; ps <= size -4;ps++){//Looking for the ps
                                                                  if(high(ps) >= high(b)){//If there is any value that ps can take that is higher than the b this b is not valid
                                                                     ps = MAX_CANDELS + 1;//no more pss for this b
                                                                  }
                                                                  else if(isReallyLow(ps,b) && (!USE_VOL || relativeVolume(VOL_LENGHT,VOL_TRIGGER, ps)) && low(ps)>low(sc) && (RSI!=PS || rsiDivergence(spring,ps,direction))){//Max Volume
                                                                     for(int a = ps + 1; a <= size -3;a++){//Looking for the a
                                                                        if(low(a) <= low(ps)){//If there is any value that a can take that is lower than the ps this ps is not valid
                                                                           a = MAX_CANDELS + 1;//no more as for this ps
                                                                        }
                                                                        else if(isReallyHigh(a,ps) && fibonacci(high(a),low(ps),0.382)<=high(b) && high(b)<high(a) && high(a)>high(a+1) && high(a)>high(a+2)){
                                                                           double spread = NormalizeDouble(Ask - Bid,Digits());
                                                                           double entry = fibonacci(low(spring),high(stua),ENTRY_FIBONACCI_1) + spread;
                                                                           double sl = low(spring);
                                                                           double tp = NormalizeDouble(entry + (entry - sl) * RISK_RATIO,Digits());;
                                                                           if(Ask>entry){
                                                                              int ticket = orderRegist(entry,sl,tp,strategyID,direction);
                                                                              if(ticket !=-1){
                                                                                 int totalSize = MAX_CANDELS + extraCandelsM1.getSize();
                                                                                 FileWrite(pointsFile,ticket,totalSize-a,totalSize-ps,totalSize-b,totalSize-sc,totalSize-ar,totalSize-st,totalSize-ua,totalSize-stsow,totalSize-stua,totalSize-spring,totalSize-sos);
                                                                              }
                                                                           }
                                                                        }
                                                                     }
                                                                  }
                                                               }
                                                            }
                                                         }
                                                      }
                                                   }
                                                }
                                             }
                                          }
                                       }
                                    }
                                 }
                              }
                           }
                        }
                     }
                  }
               }
            }
         }
      }
   }
}


void distribution1(){
   const int strategyID = 0;
   const MODE_DIRECTION direction = SELL;
   int size = MAX_CANDELS /*+ extraCandelsM1.getSize()-1*/;
   double biggerValue = Bid;
   for(int sos = 1; sos <=  size -12;sos++){ //Looking for the sign of strength(sos)
      biggerValue = MathMax(biggerValue,high(sos));
      if(isReallyLow(sos,0)){
         for(int spring = sos + 1; spring <= size -11;spring++){//Looking for the spring
            if(low(spring)<= low(sos))//If there is any value that spring can take that is lower than the sos this sos is not valid
               spring = MAX_CANDELS + 1;//no more springs for this sos
            else if(isReallyHigh(spring,sos) && fibonacci(high(spring),low(sos),ENTRY_FIBONACCI_1)>Bid && !springsArray.existSpring(high(spring)) && high(spring) > biggerValue && isBigSpring(spring, direction)){
               for(int stua = spring + 1; stua <= size -10;stua++){//Looking for the stua
                  if(high(stua)>=high(spring)){//If there is any value that stua can take that is higher than the spring this spring is not valid
                     stua = MAX_CANDELS + 1;//no more stuas for this spring
                  }
                  else if(isReallyLow(stua,spring) && low(stua) > low(sos)){
                     for(int stsow = stua + 1; stsow <= size -9;stsow++){//Looking for the stsow
                        if(low(stsow) <= low(stua)){//If there is any value that stsow can take that is lower than the stua this stua is not valid
                           stsow = MAX_CANDELS + 1;//no more stsows for this stua
                        }
                        else if(isReallyHigh(stsow,stua) && high(stsow) < high(spring) && (RSI!=ST_SOW || rsiDivergence(spring,stsow,direction))){
                           for(int ua = stsow + 1; ua <= size -8;ua++){//Looking for the ua
                              if(high(ua) >= high(stsow)){//If there is any value that ua can take that is higher than the stsow this stsow is not valid
                                 ua = MAX_CANDELS + 1;//no more uas for this stsow
                              }
                              else if(isReallyLow(ua,stsow) && fibonacci(low(ua),high(stsow),STUA_FIBO_1_1)>=low(stua) && fibonacci(low(ua),high(stsow),STUA_FIBO_1_2)<=low(stua) 
                                                             && fibonacci(high(stsow),low(ua),SPRING_FIBO_1) < high(spring) && fibonacci(high(stsow),low(ua),SPRING_FIBO_2) > high(spring)){
                                 for(int st = ua + 1; st <= size -7;st++){//Looking for the st
                                    if(low(st) <= low(ua)){//If there is any value that st can take that is lower than the ua this ua is not valid
                                       st = MAX_CANDELS + 1;//no more sts for this ua
                                    }
                                    else if(isReallyHigh(st,ua)){
                                       for(int ar = st + 1; ar <= size -6;ar++){//Looking for the ar
                                          if(high(ar) >= high(st)){//If there is any value that ar can take that is higher than the st this st is not valid
                                             ar = MAX_CANDELS + 1;//no more ars for this st
                                          }
                                          else if(isReallyLow(ar,st) && low(ar)>low(ua)){
                                             for(int sc = ar + 1; sc <= size -5;sc++){//Looking for the sc
                                                if(low(sc) <= low(ar)){//If there is any value that sc can take that is lower than the ar this ar is not valid
                                                   sc = MAX_CANDELS + 1;//no more scs for this ar
                                                }
                                                else if(isReallyHigh(sc,ar) && fibonacci(high(sc),low(ar),ST_FIBO_1)<=high(st) && fibonacci(high(sc),low(ar),ST_FIBO_2)>=high(st) && (RSI!=SC || rsiDivergence(spring,sc,direction))){
                                                   for(int b = sc + 1; b <= size -4;b++){//Looking for the b
                                                      if(high(b) >= high(sc)){//If there is any value that b can take that is higher than the sc this sc is not valid
                                                         b = MAX_CANDELS + 1;//no more bs for this sc
                                                      }
                                                      else if(isReallyLow(b,sc) && fibonacci(high(sc),low(b),STSOW_FIBO_1_1)<=high(stsow) && fibonacci(high(sc),low(b),STSOW_FIBO_1_2)>=high(stsow) &&
                                                              fibonacci(low(b),high(sc),AR_FIBO_1)>=low(ar) && fibonacci(low(b),high(sc),AR_FIBO_2)<=low(ar) &&
                                                              fibonacci(low(b),high(sc),UA_FIBO_1)>=low(ua) && fibonacci(low(b),high(sc),UA_FIBO_2)<=low(ua)){
                                                         for(int ps = b + 1; ps <= size -3;ps++){//Looking for the ps
                                                            if(low(ps) <= low(b)){//If there is any value that ps can take that is lower than the b this b is not valid
                                                               ps = MAX_CANDELS + 1;//no more pss for this b
                                                            }
                                                            else if(isReallyHigh(ps,b) && (!USE_VOL || relativeVolume(VOL_LENGHT,VOL_TRIGGER,ps)) && high(ps)<high(sc) && (RSI!=PS || rsiDivergence(spring,ps,direction))){//Max Volume
                                                               for(int a = ps + 1; a <= size -2;a++){//Looking for the a
                                                                  if(high(a) >= high(ps)){//If there is any value that a can take that is higher than the ps this ps is not valid
                                                                     a = MAX_CANDELS + 1;//no more as for this ps
                                                                  }
                                                                  else if(isReallyLow(a,ps) && fibonacci(low(a),high(ps),0.382)>=low(b) && low(b)>low(a) && low(a)<low(a+1) && low(a)<low(a+2)){
                                                                     double spread = NormalizeDouble(Ask - Bid,Digits());
                                                                     double entry = fibonacci(high(spring),low(stua),ENTRY_FIBONACCI_1);
                                                                     double sl = high(spring)+ spread;
                                                                     double tp = NormalizeDouble(entry + (entry - sl) * RISK_RATIO,Digits())- spread;
                                                                     if(Ask<entry){
                                                                        int ticket = orderRegist(entry,sl,tp,strategyID,direction);
                                                                        if(ticket !=-1){
                                                                           int totalSize = MAX_CANDELS + extraCandelsM1.getSize();
                                                                           FileWrite(pointsFile,ticket,totalSize-a,totalSize-ps,totalSize-b,totalSize-sc,totalSize-ar,totalSize-st,totalSize-ua,totalSize-stsow,totalSize-stua,totalSize-spring,totalSize-sos);
                                                                        }
                                                                     }
                                                                  }
                                                               }
                                                            }
                                                         }
                                                      }
                                                   }
                                                }
                                             }
                                          }
                                       }
                                    }
                                 }
                              }
                           }
                        }
                     }
                  }
               }
            }
         }
      }
   }
}

void distribution2(){
   const int strategyID = 1;
   const MODE_DIRECTION direction = SELL;
   int size = MAX_CANDELS /*+ extraCandelsM1.getSize()-1*/;
   double biggerValue = Bid;
   for(int sos = 1; sos <=  size -12;sos++){ //Looking for the sign of strength(sos)
      biggerValue = MathMax(biggerValue,high(sos));
      if(isReallyLow(sos,0)){
         for(int spring = sos + 1; spring <= size -11;spring++){//Looking for the spring
            if(low(spring)<= low(sos))//If there is any value that spring can take that is lower than the sos this sos is not valid
               spring = MAX_CANDELS + 1;//no more springs for this sos
            else if(isReallyHigh(spring,sos) && !springsArray.existSpring(high(spring)) && high(spring) > biggerValue && isBigSpring(spring, direction)){
               for(int stua = spring + 1; stua <= size -10;stua++){//Looking for the stua
                  if(high(stua)>=high(spring)){//If there is any value that stua can take that is higher than the spring this spring is not valid
                     stua = MAX_CANDELS + 1;//no more stuas for this spring
                  }
                  else if(isReallyLow(stua,spring) && low(stua) > low(sos)){
                     for(int stsow = stua + 1; stsow <= size -9;stsow++){//Looking for the stsow
                        if(low(stsow) <= low(stua)){//If there is any value that stsow can take that is lower than the stua this stua is not valid
                           stsow = MAX_CANDELS + 1;//no more stsows for this stua
                        }
                        else if(isReallyHigh(stsow,stua) && high(stsow) > high(spring)){
                           for(int ua = stsow + 1; ua <= size -8;ua++){//Looking for the ua
                              if(high(ua) >= high(stsow)){//If there is any value that ua can take that is higher than the stsow this stsow is not valid
                                 ua = MAX_CANDELS + 1;//no more uas for this stsow
                              }
                              else if(isReallyLow(ua,stsow) && fibonacci(low(ua),high(stsow),STUA_FIBO_2_1)>=low(stua) && fibonacci(low(ua),high(stsow),STUA_FIBO_2_2)<=low(stua) 
                                                             && fibonacci(low(ua),high(stsow),LPS_FIBO_1) < high(spring) && fibonacci(low(ua),high(stsow),LPS_FIBO_2) > high(spring)){Print("HI");
                                 for(int st = ua + 1; st <= size -7;st++){//Looking for the st
                                    if(low(st) <= low(ua)){//If there is any value that st can take that is lower than the ua this ua is not valid
                                       st = MAX_CANDELS + 1;//no more sts for this ua
                                    }
                                    else if(isReallyHigh(st,ua)){
                                       for(int ar = st + 1; ar <= size -6;ar++){//Looking for the ar
                                          if(high(ar) >= high(st)){//If there is any value that ar can take that is higher than the st this st is not valid
                                             ar = MAX_CANDELS + 1;//no more ars for this st
                                          }
                                          else if(isReallyLow(ar,st) && low(ar)>low(ua)){
                                             for(int sc = ar + 1; sc <= size -5;sc++){//Looking for the sc
                                                if(low(sc) <= low(ar)){//If there is any value that sc can take that is lower than the ar this ar is not valid
                                                   sc = MAX_CANDELS + 1;//no more scs for this ar
                                                }
                                                else if(isReallyHigh(sc,ar) && fibonacci(high(sc),low(ar),ST_FIBO_1)<=high(st) && fibonacci(high(sc),low(ar),ST_FIBO_2)>=high(st) && (RSI!=SC || rsiDivergence(stsow,sc,direction))){
                                                   for(int b = sc + 1; b <= size -4;b++){//Looking for the b
                                                      if(high(b) >= high(sc)){//If there is any value that b can take that is higher than the sc this sc is not valid
                                                         b = MAX_CANDELS + 1;//no more bs for this sc
                                                      }
                                                      else if(isReallyLow(b,sc) && fibonacci(high(sc),low(b),STSOW_FIBO_2_1)<=high(stsow) && fibonacci(high(sc),low(b),STSOW_FIBO_2_2)>=high(stsow) &&
                                                              fibonacci(low(b),high(sc),AR_FIBO_1)>=low(ar) && fibonacci(low(b),high(sc),AR_FIBO_2)<=low(ar) &&
                                                              fibonacci(low(b),high(sc),UA_FIBO_1)>=low(ua) && fibonacci(low(b),high(sc),UA_FIBO_2)<=low(ua)){
                                                         for(int ps = b + 1; ps <= size -3;ps++){//Looking for the ps
                                                            if(low(ps) <= low(b)){//If there is any value that ps can take that is lower than the b this b is not valid
                                                               ps = MAX_CANDELS + 1;//no more pss for this b
                                                            }
                                                            else if(isReallyHigh(ps,b) && (!USE_VOL || relativeVolume(VOL_LENGHT,VOL_TRIGGER,ps)) && high(ps)<high(sc) && (RSI!=PS || rsiDivergence(stsow,ps,direction))){//Max Volume
                                                               for(int a = ps + 1; a <= size -2;a++){//Looking for the a
                                                                  if(high(a) >= high(ps)){//If there is any value that a can take that is higher than the ps this ps is not valid
                                                                     a = MAX_CANDELS + 1;//no more as for this ps
                                                                  }
                                                                  else if(isReallyLow(a,ps) && fibonacci(low(a),high(ps),0.382)>=low(b) && low(b)>low(a) && low(a)<low(a+1) && low(a)<low(a+2)){
                                                                     double spread = NormalizeDouble(Ask - Bid,Digits());
                                                                     double entry = fibonacci(high(stsow),low(ua),ENTRY_FIBONACCI_2);
                                                                     double sl = high(stsow)+ spread;
                                                                     double tp = NormalizeDouble(entry + (entry - sl) * RISK_RATIO,Digits()) - spread;
                                                                     if(Ask<entry){
                                                                        int ticket = orderRegist(entry,sl,tp,strategyID,direction);
                                                                        if(ticket !=-1){
                                                                           int totalSize = MAX_CANDELS + extraCandelsM1.getSize();
                                                                           FileWrite(pointsFile,ticket,totalSize-a,totalSize-ps,totalSize-b,totalSize-sc,totalSize-ar,totalSize-st,totalSize-ua,totalSize-stsow,totalSize-stua,totalSize-spring,totalSize-sos);
                                                                        }
                                                                     }
                                                                  }
                                                               }
                                                            }
                                                         }
                                                      }
                                                   }
                                                }
                                             }
                                          }
                                       }
                                    }
                                 }
                              }
                           }
                        }
                     }
                  }
               }
            }
         }
      }
   }
}

void redistribution1(){
   const int strategyID = 2;
   const MODE_DIRECTION direction = SELL;
   int size = MAX_CANDELS /*+ extraCandelsM1.getSize()-1*/;
   for(int choch = 1; choch <= size -14;choch++){
      if(isReallyLow(choch,0)){
         for(int sos = choch + 1; sos <=  size -13;sos++){ //Looking for the sign of strength(sos)
            if(low(sos)<=low(choch)){
               sos = MAX_CANDELS + 1;
            }
            else if(isReallyHigh(sos,0) && !springsArray.existSpring(high(sos))){
               for(int spring = sos + 1; spring <= size -12;spring++){//Looking for the spring
                  if(high(spring)>= high(sos))//If there is any value that spring can take that is higher than the sos this sos is not valid
                     spring = MAX_CANDELS + 1;//no more springs for this sos
                  else if(isReallyLow(spring,sos) && low(spring) > low(choch) && isBigSpring(spring, direction)){
                     for(int stua = spring + 1; stua <= size -11;stua++){//Looking for the stua
                        if(low(stua)<=low(spring)){//If there is any value that stua can take that is lower than the spring this spring is not valid
                           stua = MAX_CANDELS + 1;//no more stuas for this spring
                        }
                        else if(isReallyHigh(stua,spring) && high(stua) < high(sos)){
                           for(int stsow = stua + 1; stsow <= size -12;stsow++){//Looking for the stsow
                              if(high(stsow) >= high(stua)){//If there is any value that stsow can take that is higher than the stua this stua is not valid
                                 stsow = MAX_CANDELS + 1;//no more stsows for this stua
                              }
                              else if(isReallyLow(stsow,stua) && low(stsow) > low(spring) && (RSI!=ST_SOW || rsiDivergence(spring,stsow,direction))){
                                 for(int ua = stsow + 1; ua <= size -9;ua++){//Looking for the ua
                                    if(low(ua) <= low(stsow)){//If there is any value that ua can take that is lower than the stsow this stsow is not valid
                                       ua = MAX_CANDELS + 1;//no more uas for this stsow
                                    }
                                    else if(isReallyHigh(ua,stsow) && fibonacci(high(ua),low(stsow),STUA_FIBO_1_1)<=high(stua) && fibonacci(high(ua),low(stsow),STUA_FIBO_1_2)>=high(stua) 
                                                                   && fibonacci(low(stsow),high(ua),SPRING_FIBO_1) > low(spring) && fibonacci(low(stsow),high(ua),SPRING_FIBO_2) < low(spring)){
                                       for(int st = ua + 1; st <= size -8;st++){//Looking for the st
                                          if(high(st) >= high(ua)){//If there is any value that st can take that is higher than the ua this ua is not valid
                                             st = MAX_CANDELS + 1;//no more sts for this ua
                                          }
                                          else if(isReallyLow(st,ua)){
                                             for(int ar = st + 1; ar <= size -7;ar++){//Looking for the ar
                                                if(low(ar) <= low(st)){//If there is any value that ar can take that is lower than the st this st is not valid
                                                   ar = MAX_CANDELS + 1;//no more ars for this st
                                                }
                                                else if(isReallyHigh(ar,st) && high(ar)<high(ua)){
                                                   for(int sc = ar + 1; sc <= size -6;sc++){//Looking for the sc
                                                      if(high(sc) >= high(ar)){//If there is any value that sc can take that is higher than the ar this ar is not valid
                                                         sc = MAX_CANDELS + 1;//no more scs for this ar
                                                      }
                                                      else if(isReallyLow(sc,ar) && fibonacci(low(sc),high(ar),ST_FIBO_1)>=low(st) && fibonacci(low(sc),high(ar),ST_FIBO_2)<=low(st) && (RSI!=SC || rsiDivergence(spring,sc,direction))){
                                                         for(int b = sc + 1; b <= size -5;b++){//Looking for the b
                                                            if(low(b) <= low(sc)){//If there is any value that b can take that is lower than the sc this sc is not valid
                                                               b = MAX_CANDELS + 1;//no more bs for this sc
                                                            }
                                                            else if(isReallyHigh(b,sc) && fibonacci(low(sc),high(b),STSOW_FIBO_1_1)>=low(stsow) && fibonacci(low(sc),high(b),STSOW_FIBO_1_2)<=low(stsow) &&
                                                                    fibonacci(high(b),low(sc),AR_FIBO_1)<=high(ar) && fibonacci(high(b),low(sc),AR_FIBO_2)>=high(ar) &&
                                                                    fibonacci(high(b),low(sc),UA_FIBO_1)<=high(ua) && fibonacci(high(b),low(sc),UA_FIBO_2)>=high(ua)){
                                                               for(int ps = b + 1; ps <= size -4;ps++){//Looking for the ps
                                                                  if(high(ps) >= high(b)){//If there is any value that ps can take that is higher than the b this b is not valid
                                                                     ps = MAX_CANDELS + 1;//no more pss for this b
                                                                  }
                                                                  else if(isReallyLow(ps,b) && (!USE_VOL || relativeVolume(VOL_LENGHT,VOL_TRIGGER,ps)) && low(ps)>low(sc) && (RSI!=PS || rsiDivergence(spring,ps,direction))){//Max Volume
                                                                     for(int a = ps + 1; a <= size -3;a++){//Looking for the a
                                                                        if(low(a) <= low(ps)){//If there is any value that a can take that is lower than the ps this ps is not valid
                                                                           a = MAX_CANDELS + 1;//no more as for this ps
                                                                        }
                                                                        else if(isReallyHigh(a,ps) && fibonacci(high(a),low(ps),0.382)<=high(b) && high(b)<high(a) && high(a)>high(a+1) && high(a)>high(a+2)){
                                                                           double spread = NormalizeDouble(Ask - Bid,Digits());
                                                                           double entry = fibonacci(high(sos),low(spring),ENTRY_FIBONACCI_1) + spread;
                                                                           double sl = high(sos);
                                                                           double tp = NormalizeDouble(entry + (entry - sl) * RISK_RATIO,Digits());;
                                                                           if(Ask>entry){
                                                                              int ticket = orderRegist(entry,sl,tp,strategyID,direction);
                                                                              if(ticket !=-1){
                                                                                 int totalSize = MAX_CANDELS + extraCandelsM1.getSize();
                                                                                 FileWrite(pointsFile,ticket,totalSize-a,totalSize-ps,totalSize-b,totalSize-sc,totalSize-ar,totalSize-st,totalSize-ua,totalSize-stsow,totalSize-stua,totalSize-spring,totalSize-sos);
                                                                              }
                                                                           }
                                                                        }
                                                                     }
                                                                  }
                                                               }
                                                            }
                                                         }
                                                      }
                                                   }
                                                }
                                             }
                                          }
                                       }
                                    }
                                 }
                              }
                           }
                        }
                     }
                  }
               }
            }
         }
      }
   }
}

bool isBigSpring(int pSpring, MODE_DIRECTION direction){
   if(!BIG_SPRING)
      return true;
   int spring;
   if(candelDirection(Open[pSpring],Close[pSpring]) == direction)
      spring = pSpring;
   else{
      spring = pSpring - 1;
   }
   if((MathAbs( Close[spring]  -  Open[spring])  >  atr(ATR_LENGHT,PERIOD_CURRENT,spring)  * ATR_MULTIPLIER) ||
      ((MathAbs(Close[spring-1] - Open[spring-1]) > atr(ATR_LENGHT,PERIOD_CURRENT,spring-1) * ATR_MULTIPLIER) && candelDirection(Open[spring-1],Close[spring-1]) == direction))
      return true;
   return false;
}


double high(int pos){
   int size = 5-1;
   if(pos >= 0 && pos <= MAX_CANDELS)
      return High[pos];
   else if(pos > MAX_CANDELS && pos <= MAX_CANDELS + size)
      return 5;
   else
      return -1;
}

double low(int pos){
   int size = 5-1;
   if(pos >= 0 && pos <= MAX_CANDELS)
      return Low[pos];
   else if(pos > MAX_CANDELS && pos <= MAX_CANDELS + size)
      return 5;
   else
      return -1;
}

long volume(int pos){
   int size = 5-1;
   if(pos >= 0 && pos <= MAX_CANDELS)
      return Volume[pos];
   else if(pos > MAX_CANDELS && pos <= MAX_CANDELS + size)
      return 5;
   else
      return -1;
}

double open(int pos){
   int size = 5-1;
   if(pos >= 0 && pos <= MAX_CANDELS)
      return Open[pos];
   else if(pos > MAX_CANDELS && pos <= MAX_CANDELS + size)
      return 5;
   else
      return -1;
}

double close(int pos){
   int size = 5-1;
   if(pos >= 0 && pos <= MAX_CANDELS)
      return Close[pos];
   else if(pos > MAX_CANDELS && pos <= MAX_CANDELS + size)
      return 5;
   else
      return -1;
}

bool rsiDivergence(int spring, int divergencePoint,MODE_DIRECTION direction){
   if(!VOL_INSTEAD_RSI)
      return (direction == BUY && iRSI(_Symbol,PERIOD_CURRENT,14,PRICE_CLOSE,spring) > iRSI(_Symbol,PERIOD_CURRENT,14,PRICE_CLOSE,divergencePoint)) ||
             (direction == SELL && iRSI(_Symbol,PERIOD_CURRENT,14,PRICE_CLOSE,spring) < iRSI(_Symbol,PERIOD_CURRENT,14,PRICE_CLOSE,divergencePoint));
   else
      return (direction == BUY && Volume[spring] > Volume[divergencePoint]) ||
          (direction == SELL && Volume[spring] < Volume[divergencePoint]);          
}

MODE_DIRECTION candelDirection(double open,double close){
   MODE_DIRECTION direction;
   if(close > open)
      direction = BUY;
   else if(close < open)
      direction = SELL;
   else
      direction = NO_DIRECTION;
   return direction;
}

MODE_DIRECTION inverseDirection(MODE_DIRECTION direction){
   MODE_DIRECTION inverseDirection = NO_DIRECTION;
   if(direction == BUY)
      inverseDirection = SELL;
   else if(direction == SELL)
      inverseDirection = BUY;
   return inverseDirection;
}

bool isReallyLow(int low, int range){
   bool isLow = true;
   for(int i = low-1; i >= range; i--){
      if(low(i) < low(low))
         isLow = false;
   }
   return isLow;
}

bool isReallyHigh(int high, int range){
   bool isHigh = true;
   for(int i = high-1; i >= range; i--){
      if(high(i) > high(high))
         isHigh = false;
   }
   return isHigh;
}

double fibonacci(double value1,double value2,double level){
   return NormalizeDouble(value2-((value2-value1)*level),Digits());
}


bool relativeVolume(int lenght, double volTrigger, int pos){
   double smaVol = 0;
   for(int i = 0; i < lenght; i++)
      smaVol+= (double)Volume[i];
   smaVol/=lenght;
   return Volume[pos]/smaVol >= volTrigger;
}

//Check if there is any repeated in the orders
bool isRepeatedOrder(double entry, double sl,int magicNumber){
   int ordersNumber = OrdersTotal();
   bool repeated = false;
   for(int i = 0; i < ordersNumber && !repeated; i++){
      bool selected = OrderSelect(i,SELECT_BY_POS);
      if(!selected){
         Alert("Ticket not Found");
         return true;
      }
      if(magicNumber == OrderMagicNumber() && ((OrderOpenPrice() - Point * POINTS_WITH_ONLY_1_TRADE <= entry && OrderOpenPrice() + Point * POINTS_WITH_ONLY_1_TRADE >= entry) || sl == OrderStopLoss()))
         repeated = true;
   }
   return repeated;
}

//Regist an order
int orderRegist(double entry, double sl, double tp,int strategyID, MODE_DIRECTION direction){
   int ticket = -1;
   int type  = -1;
   if(direction == BUY)
      type = OP_BUYLIMIT;
   else if(direction == SELL)
      type = OP_SELLLIMIT;
   double slSize = (type == OP_BUYLIMIT)?(entry - sl):(sl-entry);
   double riskPerTrade = RISK_PER_TRADE;
   bool isOrderValid = (type == OP_BUYLIMIT && Ask > entry)||
                           (type == OP_SELLLIMIT && Bid < entry);
   if(!isRepeatedOrder(entry,sl,strategyID) && slSize > 0 && isTimeToEnter() && isOrderValid){
      double tickValue = MarketInfo(_Symbol, MODE_TICKVALUE);
      double maxLotsPerMargin = ACCOUNT_BALANCE/MarketInfo(_Symbol, MODE_MARGINREQUIRED)*AccountLeverage();
      double lotSize = MathFloor(MathMin(AccountEquity() * riskPerTrade / slSize*Point / tickValue,maxLotsPerMargin)*100)/100;
      double maxLots = MarketInfo(_Symbol,MODE_MAXLOT);
      do{
         ticket = OrderSend(_Symbol,type,MathMin(lotSize,maxLots),entry,SLIPPAGE,sl,tp,NULL,strategyID);
         if(ticket != -1){
            biasCandelsCreator(ticket,"M1",PERIOD_M1);
            biasCandelsCreator(ticket,"M5",PERIOD_M5);
            biasCandelsCreator(ticket,"M15",PERIOD_M15);
            biasCandelsCreator(ticket,"M30",PERIOD_M30);
            biasCandelsCreator(ticket,"H1",PERIOD_H1);
            biasCandelsCreator(ticket,"H4",PERIOD_H4);
            biasCandelsCreator(ticket,"D1",PERIOD_D1);
         }
         lotSize-=maxLots;
         report.addPendingOrder(ticket);
      }while(lotSize>=0);
   }
   return ticket;
}

void biasCandelsCreator(int ticket,string timeframeName,ENUM_TIMEFRAMES timeframe){
   const int candelsNumber = 100;
   int file = createFile(FOLDER_BIAS_NAME + "\\" + timeframeName + "\\biasCandels" + IntegerToString(ticket));
   int counter = 1;
   FileWrite(file,"Numbers","Volume","Open","High","Low","Close");
   
   if(timeframe == Period()){
      for(int i = 0; i < extraCandelsM1.getSize()-1; i++){
         Candel candel = extraCandelsM1.getPos(i);
         FileWrite(file,counter++,candel.volume,candel.open,candel.high,candel.low,candel.close);
      }
   }
   for(int i = candelsNumber; i > 0;i--)
      FileWrite(file,counter++,iVolume(_Symbol,timeframe,i),iOpen(_Symbol,timeframe,i),iHigh(_Symbol,timeframe,i),iLow(_Symbol,timeframe,i),iClose(_Symbol,timeframe,i));
   
   FileClose(file);
}

void ordersHandler(){
   if(!isTimeToEnter())
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
   for(int i = ordersNumber-1; i >= 0; i--){
      bool selected = OrderSelect(i,SELECT_BY_POS);
      if(!selected)
         Alert("Ticket not Found");
      else{
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

bool isTimeToEnter(){
   return (getTime() >= STARTING_TRADING_HOUR_1 && getTime() < ENDING_TRADING_HOUR_1) ||
          (getTime() >= STARTING_TRADING_HOUR_2 && getTime() < ENDING_TRADING_HOUR_2);
}

void cancelInvalidPendingOrders(){
   int ordersNumber = OrdersTotal();
   for(int i = ordersNumber-1; i >= 0; i--){
      bool selected = OrderSelect(i,SELECT_BY_POS);
      if(!selected)
         Alert("Ticket not Found");
      else{
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
         if (!isThisOrderInBreakeven(i) && OrderType() == OP_BUY && Bid > OrderOpenPrice() + STARTING_BE * slSize)
            sl = MathMax(OrderStopLoss(),NormalizeDouble(OrderOpenPrice() +  BREAKEVEN_SPREAD_SIZE * (Ask-Bid),Digits()));
         else if(!isThisOrderInBreakeven(i) && OrderType() == OP_SELL && Ask < OrderOpenPrice() - STARTING_BE * slSize)
            sl = MathMin(OrderStopLoss(),NormalizeDouble(OrderOpenPrice() - BREAKEVEN_SPREAD_SIZE * (Ask-Bid),Digits()));
         if(sl != -1 && sl != OrderStopLoss()){
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
         double slSize = getSLSize(OrderLots());
         double sl = -1;
         if(OrderType() == OP_BUY && Bid > OrderOpenPrice() + STARTING_TRALLING_STOP * slSize){
            sl = NormalizeDouble(MathMax(OrderStopLoss(),Bid - TRALLING_STOP_FACTOR * slSize),Digits());
         }
         else if(OrderType() == OP_SELL && Ask < OrderOpenPrice() - STARTING_TRALLING_STOP * slSize){
            sl = NormalizeDouble(MathMin(OrderStopLoss(),Ask + TRALLING_STOP_FACTOR * slSize),Digits());
         }
         if(sl != -1 && sl != OrderStopLoss()){
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

int timeframeConvertor(ENUM_TIMEFRAMES timeframe){
   switch(timeframe){
      case PERIOD_M5:
        return 0;
      case PERIOD_M15:
        return 1;
      case PERIOD_M30:
        return 2;
      case PERIOD_H1:
        return 3;
      case PERIOD_H4:
        return 4;
      case PERIOD_D1:
        return 5;
      default:
        return -1;
   }
}

double getTime(){
   return TimeHour(TimeCurrent()) + TimeMinute(TimeCurrent())/60;
}
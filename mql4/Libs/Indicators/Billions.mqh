//+------------------------------------------------------------------+
//|                                                     Billions.mqh |
//|                                                       Diogo Rolo |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Diogo Rolo"
#property link      "https://www.mql5.com"
#property strict

#include <F1rstMillion/Enum/MODE_DIRECTION.mqh>
#include <F1rstMillion/Struct/Order.mqh>
#include <F1rstMillion/Struct/Points.mqh>
#include <F1rstMillion/Indicators/ZigZag.mqh>
#include <F1rstMillion/Library.mqh>

struct ZZ{
   ZigZag zigzag;
   int lenght;
   int size;
};

class Billions{
private:
   ZZ zigzag[];
   ZZ zigzagHigher[];
   int zigzagSize;
   int zigzagHigherSize;
   double RISK_RATIO;
   ENUM_TIMEFRAMES TIMEFRAME;
   int EXPERT_ID;
   bool RESTRICTED;
   void OnBar();
   void initialize(string lenght,string lenghtHigher, double riskRatio, ENUM_TIMEFRAMES timeframe, int expertID);
   Order type1(ZZ &zz[],ZZ &zzHigher[],MODE_DIRECTION direction);
   Order fillOrder(double firstPoint, double secundPoint, MODE_DIRECTION direction,int strategyID, string description);
   string format(Points &point);
   string formatData();
   datetime time(int shift);
   double open(int shift);
   double high(int shift);
   double low(int shift);
   double close(int shift);
   long volume(int shift);

public:
   Billions();
   Billions(string lenght,string lenghtHigher, double riskRatio, ENUM_TIMEFRAMES timeframe, int expertID, bool restricted);
   void end();
   void OnTick();
   Order enterType1();
};

Billions::Billions(void){}


Billions::Billions(string localLenght,string localLenghtHigher, double riskRatio, ENUM_TIMEFRAMES timeframe, int expertID, bool restricted = false){
   string l[];
   StringSplit(localLenght,',',l);
   zigzagSize = ArraySize(l);
   ArrayResize(zigzag,zigzagSize);
   for(int i = 0; i < zigzagSize; i++){
      ZZ zz;
      zz.lenght = StrToInteger(l[i]);
      zz.size = 15;
      zz.zigzag = ZigZag(zz.lenght, zz.size, timeframe);
      zigzag[i] = zz;
   }
   string lh[];
   StringSplit(localLenghtHigher,',',lh);
   zigzagHigherSize = ArraySize(lh);
   ArrayResize(zigzagHigher,zigzagHigherSize);
   for(int i = 0; i < zigzagHigherSize; i++){
      ZZ zz;
      zz.lenght = StrToInteger(lh[i]);
      zz.size = 2;
      zz.zigzag = ZigZag(zz.lenght, zz.size, timeframe);
      zigzagHigher[i] = zz;
   }
   RISK_RATIO = riskRatio;
   TIMEFRAME = timeframe;
   EXPERT_ID = expertID;
   RESTRICTED = restricted;
}

void Billions::end(void){
}

void Billions::OnTick(void){
   for(int i = 0; i < zigzagSize; i++)
      zigzag[i].zigzag.OnTick();
   for(int i = 0; i < zigzagHigherSize; i++)
      zigzagHigher[i].zigzag.OnTick();
}

Order Billions::enterType1(){
   Order order = type1(zigzag,zigzagHigher,SELL);
   if(order.strategyID == -1){
      ZZ zz[];
      ZZ zzHigher[];
      ArrayResize(zz,zigzagSize);
      ArrayResize(zzHigher,zigzagHigherSize);
      for(int i = 0; i < zigzagHigherSize; i++){
         zzHigher[i] = zigzagHigher[i];
         zzHigher[i].zigzag = zigzagHigher[i].zigzag.invert();
      }
      for(int i = 0; i < zigzagSize; i++){
         zz[i] = zigzag[i];
         zz[i].zigzag = zigzag[i].zigzag.invert();
      }
      order = type1(zz,zzHigher,BUY);
   }
   return order;
}

Order Billions::type1(ZZ &zz[],ZZ &zzHigher[],MODE_DIRECTION direction){
   Order order;
   order.strategyID = -1;
   
   Points null;
   null.candle = -1;
   null.value = -1;
   
   for(int i = 0; i < zigzagHigherSize && order.strategyID == -1; i++){
      if((zzHigher[i].zigzag.indexOfHigh(null) > 1 || zzHigher[i].zigzag.indexOfHigh(null) == -1) &&
         (zzHigher[i].zigzag.indexOfLow(null) > 1 || zzHigher[i].zigzag.indexOfLow(null) == -1)){

         if(zzHigher[i].zigzag.getHigh(0).candle == 1 && zzHigher[i].zigzag.isLastPointHigh()){
            Points higherHigh1 = zzHigher[i].zigzag.getHigh(1);
            Points higherLow0 = zzHigher[i].zigzag.getLow(0);
            Points higherHigh0 = zzHigher[i].zigzag.getHigh(0);
            if(higherHigh1.value > higherHigh0.value && higherHigh0.value > fibonacci(higherHigh1.value,higherLow0.value,0.5)){
               for(int j = 0; j < zigzagSize && order.strategyID == -1; j++){
               
                  if(zzHigher[i].lenght > zz[j].lenght && zz[j].zigzag.isLastPointHigh()){
                  
                     int indexHigherHigh1Phase1 = zz[j].zigzag.indexOfHigh(zzHigher[i].zigzag.getHigh(1));
                     int indexOfNull = zz[j].zigzag.indexOfHigh(null);
                     if(indexHigherHigh1Phase1 != -1 && (indexOfNull > indexHigherHigh1Phase1 + 1 || 
                        (indexOfNull == -1 && zz[j].size > indexHigherHigh1Phase1 + 2))){
                        //we can find the value in the higher timeframe and there is still more 1 value at left of it
   
                        Points phase1High = zz[j].zigzag.getHigh(indexHigherHigh1Phase1+1);
                        Points phase1Low = zz[j].zigzag.getLow(indexHigherHigh1Phase1);
                        
                        if(phase1High.value < higherHigh1.value && phase1Low.value > higherLow0.value){
                           for(int k = 0; k < zigzagSize && order.strategyID == -1; k++){
                              if(zz[k].zigzag.isLastPointHigh()){
                                 int indexHigherHigh1Phase2 = zz[k].zigzag.indexOfHigh(zzHigher[i].zigzag.getHigh(1));
                                 int indexHigherLow0Phase2 = zz[k].zigzag.indexOfLow(zzHigher[i].zigzag.getLow(0));
                                 
                                 if(indexHigherHigh1Phase2 != -1 && indexHigherLow0Phase2 != -1 && 
                                       indexHigherHigh1Phase2 - indexHigherLow0Phase2 > 1){
                                    
                                    int initX = indexHigherHigh1Phase2-1;
                                    for(int x = initX; x > indexHigherLow0Phase2 && order.strategyID == -1 && (!RESTRICTED || x==initX) ; x--){
                                    // The (!RESTRICTED || x==initX) is to in case of the RESTRICTED mode is active the for only run 1 time
                                    
                                       Points phase2Low = zz[k].zigzag.getLow(x);
                                       Points phase2High = zz[k].zigzag.getHigh(x);
                                       
                                       if(phase2High.value > phase1Low.value && phase2High.value < fibonacci(higherHigh1.value,phase2Low.value,0.7) && 
                                          phase2High.value >= fibonacci(higherHigh1.value,phase2Low.value,0.45) && 
                                          phase2Low.value < phase1Low.value && phase2High.value < higherHigh0.value){
                                          for(int l = 0; l < zigzagSize && order.strategyID == -1; l++){
                                          
                                             if(zz[l].zigzag.isLastPointHigh()){
                                                int indexHigherLow0Phase3 = zz[l].zigzag.indexOfLow(zzHigher[i].zigzag.getLow(0));
                                                int indexHigherHigh0Phase3 = zz[l].zigzag.indexOfHigh(zzHigher[i].zigzag.getHigh(0));
                                                
                                                if(indexHigherLow0Phase3 != -1 && indexHigherHigh0Phase3 != -1 && 
                                                      indexHigherLow0Phase3 - indexHigherHigh0Phase3 > 0){
                                                   int initY = indexHigherLow0Phase3;
                                                   for(int y = initY; y>indexHigherHigh0Phase3 && order.strategyID==-1 && (!RESTRICTED||y==initY); y--){
                                                   // The (!RESTRICTED || y==initY) is to in case of the RESTRICTED mode is active the for only run 1 time
                                                      Points phase3High = zz[l].zigzag.getHigh(y);
                                                      Points phase3Low = zz[l].zigzag.getLow(y-1);
                                                      
                                                      if(phase3High.value < phase2High.value && phase3High.value > phase2Low.value && 
                                                         phase3High.value > fibonacci(phase2High.value,higherLow0.value,0.5)){
                                                         if(phase1High.candle >= phase1Low.candle && 
                                                            phase2Low.candle >= phase2High.candle && 
                                                            phase3High.candle >= phase3Low.candle){
                                                            //This restrition is suposelly irrelevant beacuse the zigzag should handle
                                                            //this but the zigzag should have an error
                                                            
                                                            string description = formatData() + ";" + 
                                                                  IntegerToString(zzHigher[i].lenght) + "_" + 
                                                                  IntegerToString(zz[j].lenght) + "_" +
                                                                  IntegerToString(zz[k].lenght) + "_" + 
                                                                  IntegerToString(zz[l].lenght) + ";";
                                                            description += format(phase1High) + ";";
                                                            description += format(phase1Low) + ";";
                                                            description += format(higherHigh1) + ";";
                                                            description += format(phase2Low) + ";";
                                                            description += format(phase2High) + ";";
                                                            description += format(higherLow0) + ";";
                                                            description += format(phase3High) + ";";
                                                            description += format(phase3Low) + ";";
                                                            description += format(higherHigh0);
                                                            if(direction==SELL)
                                                               order = fillOrder(phase2High.value,higherHigh1.value,direction,0,description);
                                                            else
                                                               order = fillOrder(-phase2High.value,-higherHigh1.value,direction,0,description);
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
   
   
   
   return order;
}

string Billions::format(Points &point){
   return "("+IntegerToString(point.candle) + "," + DoubleToStr(point.value,Digits()) + ")";
}

string Billions::formatData(){
   datetime time = time(0);
   return TimeToStr(time,TIME_DATE) + ";" + TimeToStr(time,TIME_MINUTES);
}

Order Billions::fillOrder(double pEntry, double pSl, MODE_DIRECTION direction,int strategyID, string description = ""){
   double spread = NormalizeDouble(Ask - Bid,Digits());
   double entry = pEntry + (direction == BUY ? spread :0);
   if(Ask < pEntry && direction == BUY)
      entry = Ask;
   else if(Bid > pEntry && direction == SELL)
      entry = Bid;
   double sl = pSl + (direction == BUY ? 0 : spread);
   double tp = NormalizeDouble(entry + (entry - sl) * RISK_RATIO,Digits());
   Order order;
   order.strategyID = -1;

   if(direction == BUY ? Ask>=entry : Bid<=entry){
      order.sl = sl;
      order.entry = entry;
      order.tp = tp;
      order.strategyID = strategyID;
      order.expertID = EXPERT_ID;
      order.direction = direction;
      order.description = description;
   }
   return order;
}

datetime Billions::time(int shift){return iTime(_Symbol,TIMEFRAME,shift);}
double Billions::open(int shift){return iOpen(_Symbol,TIMEFRAME,shift);}
double Billions::high(int shift){return iHigh(_Symbol,TIMEFRAME,shift);}
double Billions::low(int shift){return iLow(_Symbol,TIMEFRAME,shift);}
double Billions::close(int shift){return iClose(_Symbol,TIMEFRAME,shift);}
long Billions::volume(int shift){return iVolume(_Symbol,TIMEFRAME,shift);}
//+------------------------------------------------------------------+
//|                                                         Bias.mqh |
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


class Bias{
private:
   ZigZag zigzag;
   ZigZag zigzagLower;
   int SIZE;
   int pointsFile;
   int LEGS;
   double ENTRY_FIBO;
   double RISK_RATIO;
   ENUM_TIMEFRAMES TIMEFRAME;
   int EXPERT_ID;
   void OnBar();
   Order fillOrder(Points &firstPoint, Points &secundPoint, MODE_DIRECTION direction,int strategyID);
   void writePoints(MODE_DIRECTION direction,int size);
   void writePointsType2(MODE_DIRECTION direction,int size);
   string writeData(MODE_DIRECTION direction,int size, ZigZag &zigzagLocal);
   datetime time(int shift);
   double open(int shift);
   double high(int shift);
   double low(int shift);
   double close(int shift);
   long volume(int shift);

public:
   Bias();
   Bias(int lenght,int lenghtLower, int legs, double entryFibo, double riskRatio, ENUM_TIMEFRAMES timeframe, int expertID, string fileName);
   void end();
   void OnTick();
   Order enterType1a();
   Order enterType1b();
   Order enterType2a();
   Order enterType2b();
   Order enterType3a();
   Order enterType4a();
   Order enterType4b();
};

Bias::Bias(void){}

Bias::Bias(int localLenght,int localLenghtLower, int legs, double entryFibo, double riskRatio, ENUM_TIMEFRAMES timeframe, int expertID, string fileName = ""){
   LEGS = legs;
   SIZE = LEGS+4;
   zigzag = ZigZag(localLenght, SIZE, timeframe);
   zigzagLower = ZigZag(localLenghtLower, SIZE, timeframe);
   ENTRY_FIBO = entryFibo;
   RISK_RATIO = riskRatio;
   TIMEFRAME = timeframe;
   EXPERT_ID = expertID;
   if(fileName != ""){
      FileDelete("Backtesting_" +WindowExpertName()+ "\\Points_"+fileName+".csv");
      pointsFile = FileOpen("Backtesting_" +WindowExpertName()+ "\\Points_" + fileName + ".csv",FILE_WRITE|FILE_CSV);
   }
}
void Bias::end(void){
   FileClose(pointsFile);
}

void Bias::OnTick(void){
   zigzag.OnTick();
   zigzagLower.OnTick();
}

Order Bias::enterType1a(){
   Order order;
   order.strategyID = -1;
   Points null;
   null.candle = -1;
   null.value = -1;
   if((zigzag.indexOfHigh(null) > LEGS || zigzag.indexOfHigh(null) == -1 ) && 
         (zigzag.indexOfLow(null) > LEGS || zigzag.indexOfLow(null) == -1)){
      if(zigzag.getHigh(0).candle == 1 && zigzag.isLastPointHigh()){
         if(zigzag.getHigh(0).value > zigzag.getHigh(1).value){
            bool isValid = true;
            for (int i = 1; i < LEGS && isValid;i++){
               isValid = zigzag.getHigh(i).value < zigzag.getHigh(i+1).value && zigzag.getLow(i-1).value < zigzag.getLow(i).value;
            }
            if(isValid){
               order = fillOrder(zigzag.getLow(0),zigzag.getHigh(0),BUY,0);
               if(order.strategyID != -1)
                  writePoints(BUY,LEGS);
            }
         }
      }
      if(zigzag.getLow(0).candle == 1 && !zigzag.isLastPointHigh()){
         if(zigzag.getLow(0).value < zigzag.getLow(1).value){
            bool isValid = true;
            for (int i = 1; i < LEGS && isValid;i++){
               isValid = zigzag.getLow(i).value > zigzag.getLow(i+1).value && zigzag.getHigh(i-1).value > zigzag.getHigh(i).value;
            }
            if(isValid){
               order = fillOrder(zigzag.getHigh(0),zigzag.getLow(0),SELL,0);
               if(order.strategyID != -1)
                  writePoints(SELL,LEGS);
            }
         }
      }
   }
   return order;
}

Order Bias::enterType1b(){
   Order order;
   order.strategyID = -1;
   Points null;
   null.candle = -1;
   null.value = -1;
   if((zigzag.indexOfHigh(null) > LEGS + 1 || zigzag.indexOfHigh(null) == -1 ) && 
         (zigzag.indexOfLow(null) > LEGS + 1 || zigzag.indexOfLow(null) == -1)){
      if(zigzag.getHigh(0).candle == 1 && zigzag.isLastPointHigh()){
         if(zigzag.getHigh(0).value > zigzag.getHigh(2).value && zigzag.getHigh(1).value < zigzag.getHigh(2).value &&
               zigzag.getLow(0).value > zigzag.getLow(1).value ){
            bool isValid = true;
            for (int i = 1; i < LEGS && isValid;i++){
               isValid = zigzag.getHigh(i+1).value < zigzag.getHigh(i+2).value && zigzag.getLow(i).value < zigzag.getLow(i+1).value;
            }
            if(isValid){
               order = fillOrder(zigzag.getLow(1),zigzag.getHigh(0),BUY,1);
               if(order.strategyID != -1)
                  writePoints(BUY,LEGS+1);
            }
         }
      }
      if(zigzag.getLow(0).candle == 1 && !zigzag.isLastPointHigh()){
         if(zigzag.getLow(0).value < zigzag.getLow(2).value && zigzag.getLow(1).value > zigzag.getLow(2).value &&
               zigzag.getHigh(0).value < zigzag.getHigh(1).value){
            bool isValid = true;
            for (int i = 1; i < LEGS && isValid;i++){
               isValid = zigzag.getLow(i+1).value > zigzag.getLow(i+2).value && zigzag.getHigh(i).value > zigzag.getHigh(i+1).value;
            }
            if(isValid){
               order = fillOrder(zigzag.getHigh(1),zigzag.getLow(0),SELL,1);
               if(order.strategyID != -1)
                  writePoints(SELL,LEGS+1);
            }
         }
      }
   }
   return order;
}

Order Bias::enterType2a(){
   Order order;
   order.strategyID = -1;
   Points null;
   null.candle = -1;
   null.value = -1;
   if((zigzag.indexOfHigh(null) > LEGS + 2 || zigzag.indexOfHigh(null) == -1 ) && 
         (zigzag.indexOfLow(null) > LEGS + 2 || zigzag.indexOfLow(null) == -1) &&
         (zigzagLower.indexOfHigh(null) > 1 || zigzagLower.indexOfHigh(null) == -1 ) &&
         (zigzagLower.indexOfLow(null) > 1 || zigzagLower.indexOfLow(null) == -1)){
      if(zigzagLower.getHigh(0).candle == 1 && zigzagLower.isLastPointHigh() && zigzagLower.indexOfLow(zigzag.getLow(0)) == 1){
         int shift = zigzag.getHigh(0).candle < zigzag.getLow(0).candle ? 1 : 0;
         if(zigzagLower.getHigh(0).value > zigzagLower.getHigh(1).value && zigzagLower.getLow(0).value > zigzagLower.getLow(1).value){
            bool isValid = true;
            for (int i = 1; i < LEGS && isValid;i++){
               isValid = zigzag.getHigh(i-1 + shift).value < zigzag.getHigh(i + shift).value && zigzag.getLow(i-1).value < zigzag.getLow(i).value;
            }
            if(isValid){
               order = fillOrder(zigzag.getLow(0),zigzagLower.getHigh(0),BUY,2);
               if(order.strategyID != -1)
                  writePointsType2(BUY,LEGS + 2);
            }
         } 
      }
      if(zigzagLower.getLow(0).candle == 1 && !zigzagLower.isLastPointHigh() && zigzagLower.indexOfHigh(zigzag.getHigh(0)) == 1){
         int shift = zigzag.getLow(0).candle < zigzag.getHigh(0).candle? 1 : 0;
         if(zigzagLower.getLow(0).value < zigzagLower.getLow(1).value && zigzagLower.getHigh(0).value < zigzagLower.getHigh(1).value){
            bool isValid = true;
            for (int i = 1; i < LEGS && isValid;i++){
               isValid = zigzag.getLow(i-1 + shift).value > zigzag.getLow(i + shift).value && zigzag.getHigh(i-1).value > zigzag.getHigh(i).value;
            }
            if(isValid){
               order = fillOrder(zigzag.getHigh(0),zigzagLower.getLow(0),SELL,2);
               if(order.strategyID != -1)
                  writePointsType2(SELL,LEGS + 2);
            }
         }
      }
   }
   return order;
}

Order Bias::enterType2b(){
   Order order;
   order.strategyID = -1;
   Points null;
   null.candle = -1;
   null.value = -1;
   if((zigzag.indexOfHigh(null) > LEGS + 1 || zigzag.indexOfHigh(null) == -1 ) && 
         (zigzag.indexOfLow(null) > LEGS + 1 || zigzag.indexOfLow(null) == -1)){
      if(zigzag.getHigh(0).candle == 1 && zigzag.isLastPointHigh()){
         if(zigzag.getHigh(0).value > zigzag.getHigh(1).value && zigzag.getHigh(1).value < zigzag.getHigh(2).value &&
               zigzag.getLow(0).value > zigzag.getLow(1).value){
            bool isValid = true;
            for (int i = 1; i < LEGS && isValid;i++){
               isValid = zigzag.getHigh(i+1).value < zigzag.getHigh(i+2).value && zigzag.getLow(i).value < zigzag.getLow(i+1).value;
            }
            if(isValid){
               order = fillOrder(zigzag.getLow(1),zigzag.getHigh(0),BUY,3);
               if(order.strategyID != -1)
                  writePoints(BUY,LEGS + 1);
            }
         }
      }
      if(zigzag.getLow(0).candle == 1 && !zigzag.isLastPointHigh()){
         if(zigzag.getLow(0).value < zigzag.getLow(1).value && zigzag.getLow(1).value > zigzag.getLow(2).value &&
               zigzag.getHigh(0).value < zigzag.getHigh(1).value){
            bool isValid = true;
            for (int i = 1; i < LEGS && isValid;i++){
               isValid = zigzag.getLow(i+1).value > zigzag.getLow(i+2).value && zigzag.getHigh(i).value > zigzag.getHigh(i+1).value;
            }
            if(isValid){
               order = fillOrder(zigzag.getHigh(1),zigzag.getLow(0),SELL,3);
               if(order.strategyID != -1)
                  writePoints(SELL,LEGS + 1);
            }
         }
      }
   }
   return order;
}

Order Bias::enterType3a(){
   Order order;
   order.strategyID = -1;
   Points null;
   null.candle = -1;
   null.value = -1;
   if((zigzag.indexOfHigh(null) > 3 || zigzag.indexOfHigh(null) == -1 ) && 
         (zigzag.indexOfLow(null) > 3 || zigzag.indexOfLow(null) == -1)){
      if(zigzag.getHigh(0).candle == 1 && zigzag.isLastPointHigh()){
         if(zigzag.getHigh(0).value > zigzag.getHigh(1).value && zigzag.getHigh(1).value > zigzag.getHigh(2).value &&
               zigzag.getHigh(2).value < zigzag.getHigh(3).value && zigzag.getLow(0).value < zigzag.getLow(1).value &&
               zigzag.getLow(1).value < zigzag.getLow(2).value){
            order = fillOrder(zigzag.getLow(0),zigzag.getHigh(0),BUY,4);
            if(order.strategyID != -1)
               writePoints(BUY,4);
         }
      }
      if(zigzag.getLow(0).candle == 1 && !zigzag.isLastPointHigh()){
         if(zigzag.getLow(0).value < zigzag.getLow(1).value && zigzag.getLow(1).value < zigzag.getLow(2).value &&
               zigzag.getLow(2).value > zigzag.getLow(3).value && zigzag.getHigh(0).value > zigzag.getHigh(1).value &&
               zigzag.getHigh(1).value > zigzag.getHigh(2).value){
            order = fillOrder(zigzag.getHigh(0),zigzag.getLow(0),SELL,4);
            if(order.strategyID != -1)
               writePoints(SELL,4);
         }
      }
   }
   return order;
}

Order Bias::enterType4a(){
   Order order;
   order.strategyID = -1;
   Points null;
   null.candle = -1;
   null.value = -1;
   if((zigzag.indexOfHigh(null) > LEGS + 2 || zigzag.indexOfHigh(null) == -1 ) && 
         (zigzag.indexOfLow(null) > LEGS + 2 || zigzag.indexOfLow(null) == -1)){
      if(zigzag.getHigh(0).candle == 1 && zigzag.isLastPointHigh()){
         if(zigzag.getHigh(0).value > zigzag.getHigh(3).value && zigzag.getHigh(1).value < zigzag.getHigh(2).value &&
               zigzag.getHigh(2).value < zigzag.getHigh(3).value && zigzag.getLow(0).value < zigzag.getLow(2).value && 
               zigzag.getLow(1).value > zigzag.getLow(2).value){
            bool isValid = true;
            for (int i = 1; i < LEGS && isValid;i++){
               isValid = zigzag.getHigh(i+2).value < zigzag.getHigh(i+3).value && zigzag.getLow(i+1).value < zigzag.getLow(i+2).value;
            }
            if(isValid){
               order = fillOrder(zigzag.getLow(0),zigzag.getHigh(0),BUY,5);
               if(order.strategyID != -1)
                  writePoints(BUY,LEGS + 2);
            }
         }
      }
      if(zigzag.getLow(0).candle == 1 && !zigzag.isLastPointHigh()){
         if(zigzag.getLow(0).value < zigzag.getLow(3).value && zigzag.getLow(1).value > zigzag.getLow(2).value &&
               zigzag.getLow(2).value > zigzag.getLow(3).value && zigzag.getHigh(0).value > zigzag.getHigh(2).value && 
               zigzag.getHigh(1).value < zigzag.getHigh(2).value){
            bool isValid = true;
            for (int i = 1; i < LEGS && isValid;i++){
               isValid = zigzag.getLow(i+2).value > zigzag.getLow(i+3).value && zigzag.getHigh(i+1).value > zigzag.getHigh(i+2).value;
            }
            if(isValid){
               order = fillOrder(zigzag.getHigh(0),zigzag.getLow(0),SELL,5);
               if(order.strategyID != -1)
                  writePoints(SELL,LEGS + 2);
            }
         }
      }
   }
   return order;
}

Order Bias::enterType4b(){
   Order order;
   order.strategyID = -1;
   Points null;
   null.candle = -1;
   null.value = -1;
   if((zigzag.indexOfHigh(null) > LEGS + 2 || zigzag.indexOfHigh(null) == -1 ) && 
         (zigzag.indexOfLow(null) > LEGS + 2 || zigzag.indexOfLow(null) == -1)){
      if(zigzag.getHigh(0).candle == 1 && zigzag.isLastPointHigh()){
         if(zigzag.getHigh(0).value > zigzag.getHigh(1).value && zigzag.getHigh(1).value > zigzag.getHigh(2).value &&
               zigzag.getHigh(2).value < zigzag.getHigh(3).value && zigzag.getLow(0).value < zigzag.getLow(2).value && 
               zigzag.getLow(1).value > zigzag.getLow(2).value){
            bool isValid = true;
            for (int i = 1; i < LEGS && isValid;i++){
               isValid = zigzag.getHigh(i+2).value < zigzag.getHigh(i+3).value && zigzag.getLow(i+1).value < zigzag.getLow(i+2).value;
            }
            if(isValid){
               order = fillOrder(zigzag.getLow(0),zigzag.getHigh(0),BUY,6);
               if(order.strategyID != -1)
                  writePoints(BUY,LEGS + 2);
            }
         }
      }
      if(zigzag.getLow(0).candle == 1 && !zigzag.isLastPointHigh()){
         if(zigzag.getLow(0).value < zigzag.getLow(1).value && zigzag.getLow(1).value < zigzag.getLow(2).value &&
               zigzag.getLow(2).value > zigzag.getLow(3).value && zigzag.getHigh(0).value > zigzag.getHigh(2).value && 
               zigzag.getHigh(1).value < zigzag.getHigh(2).value){
            bool isValid = true;
            for (int i = 1; i < LEGS && isValid;i++){
               isValid = zigzag.getLow(i+2).value > zigzag.getLow(i+3).value && zigzag.getHigh(i+1).value > zigzag.getHigh(i+2).value;
            }
            if(isValid){
               order = fillOrder(zigzag.getHigh(0),zigzag.getLow(0),SELL,6);
               if(order.strategyID != -1)
                  writePoints(SELL,LEGS + 2);
            }
         }
      }
   }
   return order;
}

Order Bias::fillOrder(Points &firstPoint, Points &secundPoint, MODE_DIRECTION direction,int strategyID){
   double spread = NormalizeDouble(Ask - Bid,Digits());
   double entry = fibonacci(firstPoint.value,secundPoint.value,ENTRY_FIBO) + (direction == BUY ? spread :0);
   double sl = firstPoint.value + (direction == BUY ? 0 : spread);
   double tp = NormalizeDouble(entry + (entry - sl) * RISK_RATIO,Digits());
   Order order;
   order.strategyID = -1;
   if(direction == BUY ? Ask>entry : Bid<entry){
      order.sl = sl;
      order.entry = entry;
      order.tp = tp;
      order.strategyID = strategyID;
      order.expertID = EXPERT_ID;
      order.direction = direction;
   }
   return order;
}


void Bias::writePoints(MODE_DIRECTION direction,int size){
   datetime time = time(0);
   string data = TimeToStr(time,TIME_DATE) + ";" + TimeToStr(time,TIME_MINUTES);
   data += writeData(direction,size,zigzag);
   FileWrite(pointsFile,data);
}

void Bias::writePointsType2(MODE_DIRECTION direction,int size){
   datetime time = time(0);
   string data = TimeToStr(time,TIME_DATE) + ";" + TimeToStr(time,TIME_MINUTES);
   data += writeData(direction,2,zigzagLower);
   data += writeData(direction,size-1,zigzag);
   FileWrite(pointsFile,data);
}

string Bias::writeData(MODE_DIRECTION direction,int size,ZigZag &zigzagLocal){
   string data = "";
   for(int i = 0; i < size; i++){
      if(direction == BUY){
         data += ";" + "("+IntegerToString(zigzagLocal.getHigh(i).candle) + "," + DoubleToString(zigzagLocal.getHigh(i).value,Digits()) + ")";
         data += ";" + "("+IntegerToString(zigzagLocal.getLow(i).candle) + "," + DoubleToString(zigzagLocal.getLow(i).value,Digits()) + ")";
      }
      if(direction == SELL){
         data += ";" + "("+IntegerToString(zigzagLocal.getLow(i).candle) + "," + DoubleToString(zigzagLocal.getLow(i).value,Digits()) + ")";
         data += ";" + "("+IntegerToString(zigzagLocal.getHigh(i).candle) + "," + DoubleToString(zigzagLocal.getHigh(i).value,Digits()) + ")";
      }
   }
   return data;
}


datetime Bias::time(int shift){return iTime(_Symbol,TIMEFRAME,shift);}
double Bias::open(int shift){return iOpen(_Symbol,TIMEFRAME,shift);}
double Bias::high(int shift){return iHigh(_Symbol,TIMEFRAME,shift);}
double Bias::low(int shift){return iLow(_Symbol,TIMEFRAME,shift);}
double Bias::close(int shift){return iClose(_Symbol,TIMEFRAME,shift);}
long Bias::volume(int shift){return iVolume(_Symbol,TIMEFRAME,shift);}
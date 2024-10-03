//+------------------------------------------------------------------+
//|                                                       ZigZag.mqh |
//|                                                       Diogo Rolo |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Diogo Rolo"
#property link      "https://www.mql5.com"
#property strict

#include <F1rstMillion/Lists/PointsArray.mqh>
#include <F1rstMillion/RetailPatterns.mqh>

class ZigZag{
protected:
   PointsArray highs;
   PointsArray lows;
   Points lastSavedHigh_points;
   Points lastSavedLow_points;
   bool IsLastPointHigh;
   int LENGHT;
   int SIZE;
   ENUM_TIMEFRAMES TIMEFRAME;
private:
   ZigZag(int lenght, int size, ENUM_TIMEFRAMES timeframe, PointsArray &highs, PointsArray &lows,Points &lastSavedHigh_points,Points &lastSavedLow_points);
   datetime LastBar; //variable to allow the method @OnBar() excecute properly
   int pointsFile;
   void initialize(int lenght, int size, ENUM_TIMEFRAMES timeframe);
   void OnBar();
   void updateHighsAndLows();
   void OnCalculation(int shift);
   double taHigh(int candel);
   double taLow(int candel);
   datetime time(int shift);
   double open(int shift);
   double high(int shift);
   double low(int shift);
   double close(int shift);
   long volume(int shift);
public:
   ZigZag();
   ZigZag(int lenght, int size, ENUM_TIMEFRAMES timeframe,string fileName);
   ZigZag(ZigZag &zigzag);
   ZigZag invert();
   void OnTick();
   void end();
   bool isLastPointHigh();
   Points getLow(int shift);
   Points getHigh(int shift);
   int indexOfHigh(Points &point);
   int indexOfLow(Points &point);
   string print(int size);
};

ZigZag::ZigZag(void){}

ZigZag::ZigZag(int lenghtP, int sizeP, ENUM_TIMEFRAMES timeframe,string fileName=""){
   initialize(lenghtP, sizeP, timeframe);
   if(fileName != ""){
      string name = "Backtesting_" +WindowExpertName()+ "\\PointsZigZag_" + fileName + ".csv";
      FileDelete(name);
      pointsFile = FileOpen(name,FILE_WRITE|FILE_CSV);
      FileWrite(pointsFile,"Time", "Direction","Value");
      //FileWrite(pointsFile,"Date", "Time","Lenghts","1H","1L","HH1","2L","2H","HL0","3H","3L","HH0"); usar isto para o formato do filipe
   }
}

ZigZag::ZigZag(int lenght,int size,ENUM_TIMEFRAMES timeframe,PointsArray &pHighs,PointsArray &pLows,Points &pLastSavedHigh_points,Points &pLastSavedLow_points){
   LENGHT = lenght;
   SIZE = size;
   TIMEFRAME = timeframe;
   highs = pHighs;
   lows = pLows;
   lastSavedHigh_points = pLastSavedHigh_points;
   lastSavedLow_points = pLastSavedLow_points;
}

ZigZag::ZigZag(ZigZag &zz){
   highs = zz.highs;
   lows = zz.lows;
   lastSavedHigh_points = zz.lastSavedHigh_points;
   lastSavedLow_points = zz.lastSavedLow_points;
   LENGHT = zz.LENGHT;
   SIZE = zz.SIZE;
   TIMEFRAME = zz.TIMEFRAME;
}


void ZigZag::initialize(int lenghtP, int sizeP, ENUM_TIMEFRAMES timeframe){
   LENGHT = lenghtP;
   SIZE = sizeP;
   TIMEFRAME = timeframe;
   highs = PointsArray(SIZE,-1);
   lows = PointsArray(SIZE,-1);
   for(int i = 100 - LENGHT; i > 0; i--)
      OnCalculation(i);
}

ZigZag ZigZag::invert(void){
   PointsArray h;
   PointsArray l;
   Points lsh;
   Points lsl;
   h=highs;
   l=lows;
   lsh=lastSavedHigh_points;
   lsl=lastSavedLow_points;
   
   Points temp;
   for(int i=0;i<SIZE;i++){
      temp = highs.get(i);
      if(temp.value != -1)
         temp.value = -temp.value;
      h.set(i,temp);
      temp = lows.get(i);
      if(temp.value != -1)
         temp.value = -temp.value;
      l.set(i,temp);
   }
   lsh.value = -lsh.value;
   lsl.value = -lsl.value;
   
   return ZigZag(LENGHT,SIZE,TIMEFRAME,l,h,lsl,lsh);
}

void ZigZag::OnTick(void){
   if(LastBar != time(0)){
      LastBar = time(0); 
      OnBar();
   }
}

void ZigZag::end(void){
   FileClose(pointsFile);
}

void ZigZag::OnBar(void){
   highs.addToAll(1);
   lows.addToAll(1);
   
   lastSavedHigh_points.candle++;
   lastSavedLow_points.candle++;
   
   updateHighsAndLows();
}

Points ZigZag::getHigh(int shift){
   return highs.get(shift);
}

Points ZigZag::getLow(int shift){
   return lows.get(shift);
}

int ZigZag::indexOfHigh(Points &point){
   return highs.indexOf(point);
}

int ZigZag::indexOfLow(Points &point){
   return lows.indexOf(point);
}

bool ZigZag::isLastPointHigh(void){
   return lows.get(0).candle == -1 || (highs.get(0).candle != -1 && (highs.get(0).candle < lows.get(0).candle || (highs.get(0).candle == lows.get(0).candle && IsLastPointHigh)));
}

void ZigZag::updateHighsAndLows(){
   OnCalculation(1);
}

void ZigZag::OnCalculation(int shift){
   double tahigh = taHigh(shift);
   double talow = taLow(shift);
   Points previusHigh_points = highs.get(0);
   Points previusLow_points = lows.get(0);
   if(high(shift) == tahigh &&  low(shift) != talow){
      Points point;
      point.candle = shift;
      point.value = high(shift);
      
      if(highs.get(0).candle == -1 || lows.get(0).candle == -1){
         highs.removeLast();
         highs.addFirst(point);
      }
      else if(isLastPointHigh()){
         if (highs.get(0).value <= high(shift))
            highs.set(0,point);
      }
      else{
         highs.removeLast();
         highs.addFirst(point);
      }
   }
   else if(low(shift) == talow && high(shift) != tahigh){
      Points point;
      point.candle = shift;
      point.value = low(shift);
      
      if(lows.get(0).candle == -1 && highs.get(0).candle == -1){
         lows.removeLast();
         lows.addFirst(point);
      }
      else if(!isLastPointHigh()){
         if (lows.get(0).value >= low(shift))
            lows.set(0,point);
      }
      else{
         lows.removeLast();
         lows.addFirst(point);
      }
   }
   else if (high(shift) == tahigh &&  low(shift) == talow){
      Points pointHigh;
      pointHigh.candle = shift;
      pointHigh.value = high(shift);
      Points pointLow;
      pointLow.candle = shift;
      pointLow.value = low(shift);
      
      if(highs.get(0).candle == -1){
         highs.removeLast();
         highs.addFirst(pointHigh);
         IsLastPointHigh = true;
      }
      
      else if(lows.get(0).candle == -1){
         lows.removeLast();
         lows.addFirst(pointLow);
         IsLastPointHigh = false;
      }
      
      else if(isLastPointHigh()){
         if (highs.get(0).value < high(shift)){
            highs.set(0,pointHigh);
            lows.removeLast();
            lows.addFirst(pointLow);
            IsLastPointHigh = false;
         }
         else{
            lows.removeLast();
            lows.addFirst(pointLow);
            IsLastPointHigh = false;
            if(close(shift) > open(shift)){
               highs.removeLast();
               highs.addFirst(pointHigh);
               IsLastPointHigh = true;
            }
         }
      }
      
      else{
         if (lows.get(0).value > low(shift)){
            lows.set(0,pointLow);
            highs.removeLast();
            highs.addFirst(pointHigh);
            IsLastPointHigh = true;
         }
         else{
            highs.removeLast();
            highs.addFirst(pointHigh);
            IsLastPointHigh = true;
            if(close(shift) < open(shift)){
               lows.removeLast();
               lows.addFirst(pointLow);
               IsLastPointHigh = false;
            }
         }
      }
      
   }
   Points null;
   null.candle = -1;
   null.value = -1;
   if(previusHigh_points.candle != highs.get(0).candle && previusLow_points.candle != lows.get(0).candle){
      if(isLastPointHigh() && lastSavedHigh_points.candle != highs.get(1).candle && lastSavedLow_points.candle != lows.get(0).candle && 
         (highs.indexOf(null) > 1 || highs.indexOf(null) == -1) && (lows.indexOf(null) > 0 || lows.indexOf(null) == -1)){
         FileWrite(pointsFile,time(highs.get(1).candle),"High",DoubleToStr(highs.get(1).value), IntegerToString(highs.get(1).candle));
         lastSavedHigh_points = highs.get(1);
         FileWrite(pointsFile,time(lows.get(0).candle),"Low",DoubleToStr(lows.get(0).value), IntegerToString(lows.get(0).candle));
         lastSavedLow_points = lows.get(0);
      }
      else if (!isLastPointHigh() && lastSavedHigh_points.candle != highs.get(0).candle && lastSavedLow_points.candle != lows.get(1).candle && 
         (highs.indexOf(null) > 0 || highs.indexOf(null) == -1) && (lows.indexOf(null) > 1 || lows.indexOf(null) == -1)){
         FileWrite(pointsFile,time(lows.get(1).candle),"Low",DoubleToStr(lows.get(1).value), IntegerToString(lows.get(1).candle));
         lastSavedLow_points = lows.get(1);
         FileWrite(pointsFile,time(highs.get(0).candle),"High",DoubleToStr(highs.get(0).value), IntegerToString(highs.get(0).candle));
         lastSavedHigh_points = highs.get(0);
      }
   }
   else if(previusHigh_points.candle != highs.get(0).candle && lastSavedLow_points.candle != lows.get(0).candle){
      FileWrite(pointsFile,time(lows.get(0).candle),"Low",DoubleToStr(lows.get(0).value), IntegerToString(lows.get(0).candle));
      lastSavedLow_points = lows.get(0);
   }
   else if(previusLow_points.candle != lows.get(0).candle && lastSavedHigh_points.candle != highs.get(0).candle){
      FileWrite(pointsFile,time(highs.get(0).candle),"High",DoubleToStr(highs.get(0).value), IntegerToString(highs.get(0).candle));
      lastSavedHigh_points = highs.get(0);
   }
   
   /*
   Teste para imprimir os points no formato do filipe para encontrar erros
   
   if(SIZE > 5 && ((isLastPointHigh() && highs.get(2).candle > lows.get(2).candle) || (!isLastPointHigh() && highs.get(2).candle < lows.get(2).candle)) && highs.get(5).candle != -1){
      string s[9];
      if(isLastPointHigh()){
         for(int i = 0; i < 4; i++){
            s[i*2] = highs.get(i).candle + "(" + highs.get(i).value + ")";
            s[i*2 + 1] = lows.get(i).candle + "(" + lows.get(i).value + ")";
         }
         s[8] = highs.get(4).candle + "(" + highs.get(4).value + ")";
      }
      else{
         for(int i = 0; i < 4; i++){
            s[i*2] = lows.get(i).candle + "(" + lows.get(i).value + ")";
            s[i*2 + 1] = highs.get(i).candle + "(" + highs.get(i).value + ")";
         }
         s[8] = lows.get(4).candle + "(" + lows.get(4).value + ")";
      }
      string text = "";
      for(int i = 8; i >= 0; i--){
         text += s[i] + (i==0?"":";");
      }
      FileWrite(pointsFile,TimeToStr(time(1),TIME_DATE),TimeToStr(time(1),TIME_MINUTES),option,text);
   }
   */
}

string ZigZag::print(int sizeP){
   string str = "";
   bool isLastPointHigh = isLastPointHigh();
   for(int i = 0; i < sizeP; i++){
      if(isLastPointHigh){
         str+= DoubleToStr(getHigh(i).value) + ";";
         str+= DoubleToStr(getLow(i).value) + ";";
      }
      else{
         str+= DoubleToStr(getLow(i).value) + ";";
         str+= DoubleToStr(getHigh(i).value) + ";";
      }
   }
   return str;
}

double ZigZag::taHigh(int candel){
   return taHigh(candel, LENGHT, TIMEFRAME);
}

double ZigZag::taLow(int candel){
   return taLow(candel, LENGHT, TIMEFRAME);
}

datetime ZigZag::time(int shift){return iTime(_Symbol,TIMEFRAME,shift);}
double ZigZag::open(int shift){return iOpen(_Symbol,TIMEFRAME,shift);}
double ZigZag::high(int shift){return iHigh(_Symbol,TIMEFRAME,shift);}
double ZigZag::low(int shift){return iLow(_Symbol,TIMEFRAME,shift);}
double ZigZag::close(int shift){return iClose(_Symbol,TIMEFRAME,shift);}
long ZigZag::volume(int shift){return iVolume(_Symbol,TIMEFRAME,shift);}
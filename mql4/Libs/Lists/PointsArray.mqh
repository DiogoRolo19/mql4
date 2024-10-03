//+------------------------------------------------------------------+
//|                                                  DoubleArray.mqh |
//|                                                       Diogo Rolo |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Diogo Rolo"
#property link      ""
#property strict

#include <F1rstMillion/Struct/Points.mqh>

class PointsArray{
   public:
      Points array[];
      int size;
      PointsArray();
      PointsArray(int pSize);
      PointsArray(const PointsArray &pArray);
      PointsArray(int pSize,Points &pArray[]);
      PointsArray(int pSize, int value);
      Points get(int pos);
      void remove(int pos);
      void removeLast();
      void add(int pos, Points &point);
      void addFirst(Points &point);
      void set(int pos, Points &point);
      void addToAll(int value);
      int indexOf(Points &point);
      int getSize();
      string print();
};

PointsArray::PointsArray(void){size=10;ArrayResize(array,size);}
PointsArray::PointsArray(int pSize){size = pSize; ArrayResize(array,size);}
PointsArray::PointsArray(int pSize,Points &pArray[]){
   size = pSize;
   ArrayResize(array,size);
   for(int i = 0; i < pSize; i++)
      array[i] = pArray[i];
}
PointsArray::PointsArray(const PointsArray &pArray){
   size = pArray.size;
   ArrayResize(array,size);
   for(int i = 0; i < size; i++)
      array[i] = pArray.array[i];
}
PointsArray::PointsArray(int pSize,int value){
   size = pSize;
   ArrayResize(array,size);
   Points point;
   point.value = value;
   point.candle = value;
   for(int i = 0; i < size; i++){
      array[i] = point;
   }
}
Points PointsArray::get(int pos){
   return array[pos];
}
void PointsArray::remove(int pos){
   for(int i = 0; i < size-1;i++)
      array[i] = array[i+1];
   size--;
}
void PointsArray::removeLast(){
   size--;
}
void PointsArray::add(int pos,Points &point){
   for(int i = size; i > pos;i--)
      array[i] = array[i-1];
   array[pos] = point;
   size++;
}
void PointsArray::addFirst(Points &point){
   add(0,point);
}
void PointsArray::set(int pos,Points &point){
   array[pos] = point;
}
void PointsArray::addToAll(int value){
   for(int i = 0; i < size;i++){
      if(array[i].candle != -1)
         array[i].candle = array[i].candle + value;
   }
}
int PointsArray::indexOf(Points &point){
   int returnValue = -1;
   for(int i = 0; i < size && returnValue == -1;i++){
      if(array[i].value == point.value && array[i].candle == point.candle){
         returnValue = i;
      }
   }
   return returnValue;
}

int PointsArray::getSize(void){
   return size;
}

string PointsArray::print(){
   string r = "";
   for(int i = 0; i < size;i++)
      r += DoubleToString(array[i].value) + "/" + IntegerToString(array[i].candle) + (i!=size-1?",":".");
   return r;
}
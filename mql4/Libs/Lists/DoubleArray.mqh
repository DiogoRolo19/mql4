//+------------------------------------------------------------------+
//|                                                  DoubleArray.mqh |
//|                                                       Diogo Rolo |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Diogo Rolo"
#property link      ""
#property strict

class DoubleArray{
   public:
      double array[];
      int size;
      DoubleArray();
      DoubleArray(int pSize);
      DoubleArray(const DoubleArray &doubleArray);
      DoubleArray(int pSize, double value);
      double get(int pos);
      void remove(int pos);
      void removeLast();
      void add(int pos, double value);
      void addFirst(double value);
      void set(int pos, double value);
      int indexOf(double value);
      int getSize();
      string print();
};

DoubleArray::DoubleArray(void){}
DoubleArray::DoubleArray(int pSize){size = pSize; ArrayResize(array,size);}
DoubleArray::DoubleArray(int pSize,double value){
   size = pSize;
   ArrayResize(array,size);
   for(int i = 0; i < pSize; i++)
      array[i] = value;
}
DoubleArray::DoubleArray(const DoubleArray &doubleArray){
   size = doubleArray.size;
   ArrayResize(array,size);
   for(int i = 0; i < size; i++)
      array[i] = doubleArray.array[i];
}

double DoubleArray::get(int pos){
   return array[pos];
}
void DoubleArray::remove(int pos){
   for(int i = 0; i < size-1;i++)
      array[i] = array[i+1];
   size--;
}
void DoubleArray::removeLast(){
   size--;
}
void DoubleArray::add(int pos,double value){
   for(int i = size; i > pos;i--)
      array[i] = array[i-1];
   array[pos] = value;
   size++;
}
void DoubleArray::addFirst(double value){
   add(0,value);
}
void DoubleArray::set(int pos,double value){
   array[pos] = value;
}
int DoubleArray::indexOf(double value){
   int returnValue = -1;
   bool found = false;
   for(int i = 0; i < size && !found;i++){
      if(array[i] == value){
         found = true;
         returnValue = i;
      }
   }
   return returnValue;
}


int DoubleArray::getSize(void){
   return size;
}

string DoubleArray::print(){
   string r = "";
   for(int i = 0; i < size;i++)
      r += DoubleToStr(array[i],2)+ (i!=size-1?",":".");
   return r;
}
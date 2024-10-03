//+------------------------------------------------------------------+
//|                                                  DoubleArray.mqh |
//|                                                       Diogo Rolo |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Diogo Rolo"
#property link      ""
#property strict

class IntArray{
   private:
      void resize();
   public:
      int array[];
      int size;
      int maxSize;
      IntArray();
      IntArray(int pSize);
      IntArray(const IntArray &intArray);
      IntArray(int pSize, int &pArray[]);
      IntArray(int pSize, int value);
      void clear();
      int get(int pos);
      void remove(int pos);
      void removeLast();
      void add(int pos, int value);
      void addFirst(int value);
      void addLast(int value);
      void addLast(IntArray &intArray);
      void set(int pos, int value);
      int getSize();
      bool exist(int value);
      string print();
};

IntArray::IntArray(void){maxSize=10;ArrayResize(array,maxSize);size = 0;}
IntArray::IntArray(int pSize){maxSize = pSize; ArrayResize(array,maxSize);size = 0;}
IntArray::IntArray(int pSize,int &pArray[]){
   maxSize = pSize;
   size = maxSize;
   ArrayResize(array,maxSize);
   for(int i = 0; i < pSize; i++)
      array[i] = pArray[i];
}
IntArray::IntArray(const IntArray &intArray){
   size = intArray.size;
   maxSize = intArray.maxSize;
   ArrayResize(array,maxSize);
   for(int i = 0; i < size; i++)
      array[i] = intArray.array[i];
}
IntArray::IntArray(int pSize,int value){
   size = pSize;
   maxSize = size;
   ArrayResize(array,maxSize);
   for(int i = 0; i < size; i++){
      array[i] = value;
   }
}
int IntArray::get(int pos){
   return array[pos];
}
void IntArray::remove(int pos){
   for(int i = pos; i < size-1;i++)
      array[i] = array[i+1];
   size--;
}

void IntArray::clear(void){
   size = 0;
}

void IntArray::removeLast(){
   size--;
}

void IntArray::add(int pos,int value){
   resize();
   for(int i = size; i > pos;i--)
      array[i] = array[i-1];
   array[pos] = value;
   size++;
}
void IntArray::addFirst(int value){
   add(0,value);
}
void IntArray::addLast(int value){
   resize();
   array[size] = value;
   size++;
}
void IntArray::addLast(IntArray &intArray){
   for(int i = 0; i < intArray.getSize(); i++){
      addLast(intArray.get(i));
   }
}
void IntArray::resize(){
   if(size == maxSize){
      maxSize *= 2;
      ArrayResize(array,maxSize);
   }
}
void IntArray::set(int pos,int value){
   array[pos] = value;
}

int IntArray::getSize(void){
   return size;
}

bool IntArray::exist(int value){
   bool found = false;
   for(int i = 0; i < size && !found;i++){
      if(array[i] == value)
         found = true;
   }
   return found;
}

string IntArray::print(){
   string r = "";
   for(int i = 0; i < size;i++)
      r += IntegerToString(array[i])+ (i!=size-1?",":".");
   return r;
}
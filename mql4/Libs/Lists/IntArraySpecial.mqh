//+------------------------------------------------------------------+
//|                                                  DoubleArray.mqh |
//|                                                       Diogo Rolo |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Diogo Rolo"
#property link      ""
#property strict

class IntArraySpecial{
   private:
      void resize();
   public:
      int array[];
      int size;
      IntArraySpecial();
      IntArraySpecial(int pSize);
      IntArraySpecial(const IntArraySpecial &intArray);
      IntArraySpecial(int pSize, int &pArray[]);
      IntArraySpecial(int pSize, int value);
      int get(int pos);
      void remove(int pos);
      void removeLast();
      void add(int pos, int value);
      void addFirst(int value);
      void addLast(int value);
      void set(int pos, int value);
      void addToAll(int value);
      int indexOf(int value);
      void removeAbove(int value);
      int getSize();
      bool exist(int value);
      string print();
};

IntArraySpecial::IntArraySpecial(void){size=10;ArrayResize(array,size);}
IntArraySpecial::IntArraySpecial(int pSize){size = pSize; ArrayResize(array,size);}
IntArraySpecial::IntArraySpecial(int pSize,int &pArray[]){
   size = pSize;
   ArrayResize(array,size);
   for(int i = 0; i < pSize; i++)
      array[i] = pArray[i];
}
IntArraySpecial::IntArraySpecial(const IntArraySpecial &intArray){
   size = intArray.size;
   ArrayResize(array,size);
   for(int i = 0; i < size; i++)
      array[i] = intArray.array[i];
}
IntArraySpecial::IntArraySpecial(int pSize,int value){
   size = pSize;
   ArrayResize(array,size);
   for(int i = 0; i < size; i++){
      array[i] = value;
   }
}
int IntArraySpecial::get(int pos){
   return array[pos];
}
void IntArraySpecial::remove(int pos){
   for(int i = 0; i < size-1;i++)
      array[i] = array[i+1];
   size--;
}
void IntArraySpecial::removeLast(){
   size--;
}
void IntArraySpecial::add(int pos,int value){
   for(int i = size; i > pos;i--)
      array[i] = array[i-1];
   array[pos] = value;
   size++;
}
void IntArraySpecial::addFirst(int value){
   add(0,value);
}
void IntArraySpecial::addLast(int value){
   add(size-1,value);
}
void IntArraySpecial::set(int pos,int value){
   array[pos] = value;
}
void IntArraySpecial::addToAll(int value){
   for(int i = 0; i < size;i++){
      if(array[i] != -1)
         array[i] = array[i] + value;
   }
}
int IntArraySpecial::indexOf(int value){
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

void IntArraySpecial::removeAbove(int value){
   for(int i = 0; i < size;i++){
      if(array[i] > value)
        array[i] = -1;
   }
}

int IntArraySpecial::getSize(void){
   return size;
}

bool IntArraySpecial::exist(int value){
   bool found = false;
   for(int i = 0; i < size && !found;i++){
      if(array[i] == value)
         found = true;
   }
   return found;
}

void IntArraySpecial::resize(){
   if(size == maxSize){
      maxSize *= 2;
      ArrayResize(array,maxSize);
   }
}

string IntArraySpecial::print(){
   string r = "";
   for(int i = 0; i < size;i++)
      r += IntegerToString(array[i])+ (i!=size-1?",":".");
   return r;
}
//+------------------------------------------------------------------+
//|                                                 CircularList.mqh |
//|                                                       Diogo Rolo |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Diogo Rolo"
#property link      ""
#property strict

#include <F1rstMillion/Candel.mqh>

class CircularList{
   private:
      Candel array[];
      int maxSize;
      int size;
      int last;
      void initArray(void);
      int previusPos(int pos);
      int nextPos(int pos);
   public:
      CircularList(int pSize);
      CircularList(void);
      Candel getPos(int pos);
      void addLast(Candel &candel);
      void test();
      int getSize();
};

CircularList::CircularList(int pSize){
   maxSize = pSize;
   initArray();
}

CircularList::CircularList(void){
   maxSize = 50;
   initArray();
}

void CircularList::initArray(void){
   ArrayResize(array,maxSize);
   last = -1;
   size = 0;
   for(int i=0;i<maxSize;i++){
      array[i] = Candel();
   }
}

void CircularList::addLast(Candel &candel){
   last = nextPos(last);
   array[last] = candel;
   size = MathMin(size+1,maxSize);
}

Candel CircularList::getPos(int pos){
   if(pos>=size)
      return Candel();
   else{
      int realPos;
      if(size<maxSize)
         realPos = pos;
      else if(pos<maxSize - (last+1))
         realPos = last+pos+1;
      else
         realPos = pos - (maxSize - (last+1));
      return array[realPos];
   }
}

int CircularList::nextPos(int pos){
   pos++;
   if(pos>=maxSize)
      pos = 0;
   return pos;
}

int CircularList::previusPos(int pos){
   pos--;
   if(pos<0)
      pos = maxSize-1;
   return pos;
}

int CircularList::getSize(void){
   return size;
}

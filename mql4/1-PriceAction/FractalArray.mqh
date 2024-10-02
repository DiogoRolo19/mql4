//+------------------------------------------------------------------+
//|                                                      Pattern.mqh |
//|                                                       Diogo Rolo |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Diogo Rolo"
#property link      ""
#property version   "1.00"
#property strict

const int DEFAULT_SIZE = 4;

class FractalArray{
private:
   double fractals[];
   int positions[];
   int size;
   int maxSize;
public:
   FractalArray();
   FractalArray(int fractalsSize);
   void add(double value, int position);
   double getFractal(int pos);
   int getFractalPosition(int pos);
   bool isFull();
   int getSize();
   int find(double value);
   void reestructure();
};

FractalArray::FractalArray(){
   FractalArray(DEFAULT_SIZE);
}
FractalArray::FractalArray(int fractalsSize){
   ArrayResize(fractals,fractalsSize);
   ArrayResize(positions,fractalsSize);
   size = 0;
   maxSize = fractalsSize;
}
void FractalArray::add(double value, int position){
   if(size<maxSize){
      size++;
      fractals[size-1] = value;
      positions[size-1] = position;
   }
}
double FractalArray::getFractal(int pos){
   return fractals[pos];
}
int FractalArray::getFractalPosition(int pos){
   if(pos<size)
      return positions[pos];
   else
      return -1;
}
bool FractalArray::isFull(){
   return size >= maxSize;
}
int FractalArray::getSize(){
   return size;
}
int FractalArray::find(double value){
   bool founded = false;
   int pos = -1;
   for(int i = 0;i<size && !founded;i++){
      if(getFractal(i) == value){
         founded = true;
         pos = i;
      }
   }
   return pos;
}
void FractalArray::reestructure(){ 
   int startSize = size;
   for(int i = startSize -1;i>0;i--){
      if(getFractalPosition(i) == getFractalPosition(i-1)){
         if(getFractalPosition(i) == 1){
            fractals[i-1] = MathMax(getFractal(i),getFractal(i-1));
            size--;
         }
         else if(getFractalPosition(i) == -1){
            fractals[i-1] = MathMin(getFractal(i),getFractal(i-1));
            size--;
         }
         for(int j = i; j < size; j++){
            fractals[j]= fractals[j+1];
            positions[j] = positions[j+1];
         }
      }
   }
}
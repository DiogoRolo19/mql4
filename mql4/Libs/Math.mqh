//+------------------------------------------------------------------+
//|                                                         Math.mqh |
//|                                                       Diogo Rolo |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Diogo Rolo"
#property link      ""
#property strict

const double NEPER = 2.7182818285;

double Random(){
   return MathRand()*1.0/SHORT_MAX;
}

int IntRandom(int range){
   int random;
   do{
      random = (int)MathFloor(Random()*(range));
   } while(random == range);
   return random;
}

void UniqueRandom(int &randoms[],int numbers, int range){
   int array[];
   ArrayResize(array,range);
   for(int i = 0; i < range; i++)
      array[i]=i;
   
   ArrayResize(randoms,numbers);
   for(int i = 0; i < numbers; i++){
      int pos = IntRandom(range-i);
      randoms[i] = array[pos];
      array[pos] = array[range-1-i];
      //Print("---");;
      //for(int j = 0; j < range; j++)
         //Print(array[j]);
   }
}


double fibonacci(double value1,double value2,double level){
   return NormalizeDouble(value2-((value2-value1)*level),Digits());
}
//+-------------------------------------------------------------------+
//|                                                   PriceAction.mq4 |
//|                                                        Diogo Rolo |
//|                                                                   |
//+-------------------------------------------------------------------+
#property strict

class Bar{
private:
   double open;
   double close;
   double high;
   double low;
public:
   Bar(Bar &bar);
   Bar(double newValue);
   Bar(double barOpen, double initialClose, double initialHigh, double initialLow);
   bool isBuy();
   void changeBar(double newValue);
   void changeBar(double newClose, double newHigh,double newLow);
   bool IsCall();
   double getOpen();
   double getClose();
   double getHigh();
   double getLow();
   datetime getTime();
};
Bar::Bar(Bar &bar){
   open = bar.getOpen();
   close = bar.getClose();
   high = bar.getHigh();
   low = bar.getLow();
}
Bar::Bar(double newValue){
   open = newValue;
   close = newValue;
   high = newValue;
   low = newValue;
}
Bar::Bar(double barOpen, double initialClose, double initialHigh, double initialLow){
   open = barOpen;
   close = initialClose;
   high = initialHigh;
   low = initialHigh;
}

void Bar::changeBar(double newValue){
   close = newValue;
   if(newValue > high)
      high = newValue;
   if(newValue < low)
      low = newValue;
}

void Bar::changeBar(double newClose, double newHigh,double newLow){
   close = newClose;
   if(newHigh > high)
      high = newHigh;
   if(newLow < low)
      low = newLow;
}

bool Bar::isBuy(){
   return (close-open) > 0;
}
double Bar::getOpen(){
   return open;
}
double Bar::getClose(){
   return close;
}
double Bar::getHigh(){
   return high;
}
double Bar::getLow(){
   return low;
}
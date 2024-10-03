//+------------------------------------------------------------------+
//|                                                       Candel.mqh |
//|                                                       Diogo Rolo |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Diogo Rolo"
#property link      ""
#property strict

class Candel{
   public:
      double high;
      double low;
      double open;
      double close;
      long volume;
      Candel(double high, double low, double open, double close, long volume);
      Candel(void);
      Candel(const Candel &candel);
};

Candel::Candel(double pHigh,double pLow,double pOpen,double pClose,long pVolume){
   high = pHigh;
   low = pLow;
   open = pOpen;
   close = pClose;
   volume = pVolume;

}
Candel::Candel(void){
   high = -1;
   low = -1;
   open = -1;
   close = -1;
   volume = -1;
}
Candel::Candel(const Candel &candel){
   high = candel.high;
   low = candel.low;
   open = candel.open;
   close = candel.close;
   volume = candel.volume;
}
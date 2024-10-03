//+------------------------------------------------------------------+
//|                                                       Report.mqh |
//|                                                       Diogo Rolo |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Diogo Rolo"
#property link      ""
#property strict

struct Trade{
   int ticket;
   bool firstBaseline;
   bool secundBaseline;
   bool thirdBaseline;
   double maxProfit;
};

class TradesArray{
   private:
      void resize();
      Trade array[];
      int size;
      int maxSize;
      int getPos(int ticket);
   public:
      TradesArray();
      Trade get(int pos);
      void add(int ticket);
      void set(int pos, Trade &trade);
      int getSize();
      bool exist(int ticket);
      void remove(int ticket);
};

TradesArray::TradesArray(void){maxSize=10;ArrayResize(array,maxSize);size = 0;}

Trade TradesArray::get(int pos){
   return array[pos];
}

void TradesArray::add(int ticket){
   resize();
   Trade trade;
   trade.ticket = ticket;
   trade.firstBaseline = false;
   trade.secundBaseline = false;
   trade.thirdBaseline = false;
   trade.maxProfit = -1;
   array[size++] = trade;
}

void TradesArray::set(int pos,Trade &trade){
   array[pos] = trade;
}

void TradesArray::resize(){
   if(size == maxSize){
      maxSize *= 2;
      ArrayResize(array,maxSize);
   }
}

int TradesArray::getSize(void){
   return size;
}

int TradesArray::getPos(int ticket){
   int pos = -1;
   for(int i = 0; i < size && pos == -1;i++){
      if(array[i].ticket == ticket)
         pos = i;
   }
   return pos;
}

bool TradesArray::exist(int ticket){
   return getPos(ticket) != -1;
}

void TradesArray::remove(int ticket){
   int pos = getPos(ticket);
   for(int i = pos; i < size - 1; i++)
      array[i] = array[i+1];
   if(pos!=-1)
      size--;
}

class FMTS{
private:
   TradesArray tradesArray;
   double Fibo;
public:
   FMTS();
   FMTS(double fibo);
   void OnTick();
};

FMTS::FMTS(void){
   tradesArray = TradesArray();
   Fibo = 0.5;
}

FMTS::FMTS(double fibo){
   tradesArray = TradesArray();
   Fibo = fibo;
}

void FMTS::OnTick(void){
   int ordersNumber = OrdersTotal();
   for(int i = ordersNumber-1; i >= 0; i--){
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES)){
         int ticket = OrderTicket();
         if(!tradesArray.exist(ticket))
            tradesArray.add(ticket);
      }
   }
   int size = tradesArray.getSize();
   for(int i = size - 1; i >= 0; i--){
      Trade trade = tradesArray.get(i);
      if(!OrderSelect(trade.ticket,SELECT_BY_TICKET,MODE_TRADES) || OrderCloseTime() != 0)
         tradesArray.remove(trade.ticket);
      else{
         trade.maxProfit = MathMax(OrderProfit(),trade.maxProfit);
         if(!trade.firstBaseline){
            if(OrderProfit() > 0){
               trade.firstBaseline = true;
               double sl = NormalizeDouble(OrderOpenPrice() + (OrderStopLoss() - OrderOpenPrice())*3/4 , (int)MarketInfo(OrderSymbol(),MODE_DIGITS));
               bool modify = OrderModify(OrderTicket(),OrderOpenPrice(),sl,OrderTakeProfit(),0);
               if(!modify)
                  Alert("Order not Modified (Phase1 FMTS)");
            }
         }
         if(trade.firstBaseline && !trade.secundBaseline){
            if(OrderProfit() > 300){
               trade.secundBaseline = true;
               double sl = NormalizeDouble(OrderOpenPrice() + (OrderStopLoss() - OrderOpenPrice())/4 , (int)MarketInfo(OrderSymbol(),MODE_DIGITS));
               bool modify = OrderModify(OrderTicket(),OrderOpenPrice(),sl,OrderTakeProfit(),0);
               if(!modify)
                  Alert("Order not Modified (Phase2 FMTS)");
            }
            else{
               if(OrderProfit() <= -495){
                  double price = OrderType()== OP_BUY ? MarketInfo(OrderSymbol(),MODE_BID) : MarketInfo(OrderSymbol(),MODE_ASK);
                  bool closed = OrderClose(OrderTicket(),OrderLots(),price,100);
                  if(!closed)
                     Alert("Order not Closed (Phase1 FMTS)");
               }
            }
         }
         if(trade.secundBaseline && !trade.thirdBaseline){
            if(OrderProfit() > 1000){
               trade.thirdBaseline = true;
               bool modify = OrderModify(OrderTicket(),OrderOpenPrice(),OrderOpenPrice(),OrderTakeProfit(),0);
               if(!modify)
                  Alert("Order not Modified (Phase3 FMTS)");
            }
            else{
               if(OrderProfit() <= trade.maxProfit * Fibo + 5){
                  double price = OrderType()== OP_BUY ? MarketInfo(OrderSymbol(),MODE_BID) : MarketInfo(OrderSymbol(),MODE_ASK);
                  bool closed = OrderClose(OrderTicket(),OrderLots(),price,100);
                  if(!closed)
                     Alert("Order not Closed (Phase2 FMTS)");
               }
            }
         }
         if(trade.thirdBaseline){
            if(OrderProfit() <= trade.maxProfit - 1000*(1-Fibo)){
               double price = OrderType()== OP_BUY ? MarketInfo(OrderSymbol(),MODE_BID) : MarketInfo(OrderSymbol(),MODE_ASK);
               bool closed = OrderClose(OrderTicket(),OrderLots(),price,100);
               if(!closed)
                  Alert("Order not Closed (Phase3 FMTS)");
            }
         }
         tradesArray.set(i,trade);
      }
   }
}
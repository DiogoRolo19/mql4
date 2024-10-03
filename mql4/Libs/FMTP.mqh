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
   bool changed;
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
   trade.changed = false;
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

class FMTP{
private:
   TradesArray tradesArray;
   double TP;
public:
   FMTP();
   FMTP(double tp);
   void OnTick();
};

FMTP::FMTP(void){
   tradesArray = TradesArray();
   TP = 3;
}

FMTP::FMTP(double tp){
   tradesArray = TradesArray();
   TP = tp;
}

void FMTP::OnTick(void){
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
         if(!trade.changed){
            double spread = (OrderType() == OP_SELL || OrderType() == OP_SELLLIMIT) ? - NormalizeDouble(MarketInfo(OrderSymbol(),MODE_ASK) - MarketInfo(OrderSymbol(),MODE_BID),(int)MarketInfo(OrderSymbol(),MODE_DIGITS)) : 0;
            double tp = NormalizeDouble(OrderOpenPrice() + (OrderOpenPrice() - OrderStopLoss()) * TP,(int)MarketInfo(OrderSymbol(),MODE_DIGITS)) + spread;
            bool modified = OrderModify(OrderTicket(), OrderOpenPrice(), OrderStopLoss(), tp, 0, clrNONE);
            if(!modified)
               Alert("Order not Modified (FMTP)");
            else
               trade.changed = true;
         }
         tradesArray.set(i,trade);
      }
   }
}
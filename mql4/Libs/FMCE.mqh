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
   int level;
   int candles;
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
   trade.level = 0;
   trade.candles = 0;
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

class FMCE{
private:
   TradesArray tradesArray;
   int Levels;
   int Minutes;
   datetime LastBar;
   double LEVELS[];
public:
   FMCE();
   FMCE(int levels, int minutes, double decay);
   void OnTick();
};

FMCE::FMCE(void){
   tradesArray = TradesArray();
   Levels = 2;
   LastBar = iTime(_Symbol,PERIOD_M1,0);
   Minutes = 5;
   ArrayResize(LEVELS,Levels);
   double percentual = 1;
   for(int i = Levels-1; i>=0; i--){
      percentual -= 0.05;
      LEVELS[i] = percentual;
   }
}

FMCE::FMCE(int levels, int minutes, double decay){
   tradesArray = TradesArray();
   Levels = levels;
   LastBar = iTime(_Symbol,PERIOD_M1,0);
   Minutes = minutes;
   ArrayResize(LEVELS,Levels);
   double percentual = 1;
   for(int i = Levels-1; i>=0; i--){
      percentual -= decay;
      LEVELS[i] = percentual;
   }
}

void FMCE::OnTick(void){
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
      else if(OrderType() == OP_BUY || OrderType() == OP_SELL){
         if(LastBar != iTime(_Symbol,PERIOD_M1,0)){
            LastBar = iTime(_Symbol,PERIOD_M1,0); 
            trade.candles++;
         }
         double price = OrderType()== OP_BUY ? MarketInfo(OrderSymbol(),MODE_BID) : MarketInfo(OrderSymbol(),MODE_ASK);
         double percentual = (price - OrderOpenPrice())/(OrderTakeProfit()-OrderOpenPrice());
         if(trade.level < Levels && percentual >= LEVELS[trade.level]){
            trade.level++;
            trade.candles = 0;
         }
         if(trade.candles > Minutes){
            bool closed = OrderClose(OrderTicket(),OrderLots(),price,100);
            if(!closed)
               Alert("Order not Closed (FMCE - " + (string)(trade.level==0?0:LEVELS[trade.level-1]) + ")");
         }
         tradesArray.set(i,trade);
      }
   }
}
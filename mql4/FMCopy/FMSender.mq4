//+------------------------------------------------------------------+
//|                                                     FMSender.mq4 |
//|                                                       Diogo Rolo |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+

#property copyright "Diogo Rolo"
#property version   "1.00"
#property strict

#include <F1rstMillion/Lists/IntArray.mqh>

struct Trade{
   int ticket;
   double openPrice;
   double sl;
   double tp;
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
      Trade get(int ticket);
      Trade getByPos(int pos);
      void add(Trade &trade);
      void set(int ticket, Trade &trade);
      int getSize();
      bool exist(int ticket);
      void remove(int pos);
};

TradesArray::TradesArray(void){maxSize=10;ArrayResize(array,maxSize);size = 0;}

Trade TradesArray::get(int ticket){
   int pos = getPos(ticket);
   if(pos != -1)
      return array[pos];
   else{
      Trade trade;
      trade.ticket = -1;
      return trade;
   }
}

Trade TradesArray::getByPos(int pos){
   return array[pos];
}

void TradesArray::add(Trade &trade){
   resize();
   array[size++] = trade;
}

void TradesArray::set(int ticket,Trade &trade){
   array[getPos(ticket)] = trade;
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

void TradesArray::remove(int pos){
   for(int i = pos; i < size - 1; i++)
      array[i] = array[i+1];
   size--;
}


TradesArray trades;
int counter;

input const int copiersNumber = 1;

int OnInit(){
   trades = TradesArray();
   counter = 0;
   return(INIT_SUCCEEDED);
}


void OnDeinit(const int reason){
   
}


void OnTick(){
   IntArray newTrades;
   IntArray changedTrades;
   IntArray oldTrades;
   for(int i = 0; i < OrdersTotal();i++){
      if(OrderSelect(i,SELECT_BY_POS)){
         Trade trade = trades.get(OrderTicket());
         if(trade.ticket == -1){
            newTrades.addLast(OrderTicket());
            trade.ticket = OrderTicket();
            trade.openPrice = OrderOpenPrice();
            trade.sl = OrderStopLoss();
            trade.tp = OrderTakeProfit();
            trades.add(trade);
         }
         else if (OrderOpenPrice() != trade.openPrice || OrderStopLoss() != trade.sl || OrderTakeProfit() != trade.tp){
            changedTrades.addLast(OrderTicket());
            trade.openPrice = OrderOpenPrice();
            trade.sl = OrderStopLoss();
            trade.tp = OrderTakeProfit();
            trades.set(trade.ticket,trade);
         }
      }
   }
   for(int i = trades.getSize() - 1; i >= 0 ;i--){
      Trade trade = trades.getByPos(i);
      if(!OrderSelect(trade.ticket,SELECT_BY_TICKET) || OrderCloseTime() != 0){
         oldTrades.addLast(trade.ticket);
         trades.remove(i);
      }
   }
   
   if(newTrades.getSize() != 0 || changedTrades.getSize() != 0 || oldTrades.getSize() != 0){
      int totalSize = newTrades.getSize() + changedTrades.getSize() + oldTrades.getSize();
      string fileData[];
      ArrayResize(fileData, totalSize);
      int fileDataCounter = 0;
      for(int i = 0; i < newTrades.getSize(); i++){
         if(OrderSelect(newTrades.get(i),SELECT_BY_TICKET)){
            double lots = NormalizeDouble(OrderLots() * 100000.0 / AccountBalance(),2);
            fileData[fileDataCounter++] = (string)OrderTicket() + ";" + (string)OrderType() + ";" + (string)lots + ";" + 
                           (string)OrderOpenPrice() + ";" + (string)OrderStopLoss() + ";" + (string)OrderTakeProfit() + ";" + (string)OrderSymbol();
         }
      }
      for(int i = 0; i < changedTrades.getSize(); i++){
         if(OrderSelect(changedTrades.get(i),SELECT_BY_TICKET))
            fileData[fileDataCounter++] = (string)OrderTicket() + ";" + (string)OrderOpenPrice() + ";" + 
                                          (string)OrderStopLoss() + ";" + (string)OrderTakeProfit();
      }
      for(int i = 0; i < oldTrades.getSize(); i++){
         fileData[fileDataCounter++] = (string)oldTrades.get(i);
      }
      
      counter = counter == 50 ? 0 : counter + 1;
      write(fileData,totalSize);
   }
}

void write(string &fileData[], int totalSize){
   for(int i=0; i<copiersNumber; i++){
      string fileName = "FMCopy" + (string) i + "\\" + (string) counter + ".txt";
      int file = FileOpen(fileName,FILE_WRITE|FILE_TXT);
      for(int k = 0; k < totalSize; k++)
         FileWrite(file,fileData[k]);
      FileClose(file);
   }
}
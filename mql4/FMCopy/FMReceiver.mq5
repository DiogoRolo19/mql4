//+------------------------------------------------------------------+
//|                                                   FMReceiver.mq5 |
//|                                                       Diogo Rolo |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+

#property copyright "Diogo Rolo"
#property version   "1.00"
#property strict

#include <trade/trade.mqh>
CTrade trade;

enum CMD{
   OP_BUY = 0,
   OP_SELL = 1,
   OP_BUYLIMIT = 2,
   OP_SELLLIMIT = 3,
   OP_BUYSTOP = 4,
   OP_SELLSTOP = 5
};

struct pair{
   ulong ticket1;
   ulong ticket2;
};

class TicketsDict{
   private:
      pair array[];
      int size;
      int maxSize;
      void resize();
   public:
      TicketsDict();
      void add(ulong ticket1,ulong ticket2);
      ulong convert(ulong ticket);
      void remove(ulong ticket);
};

TicketsDict::TicketsDict(void){
   size = 0;
   maxSize = 10;
   ArrayResize(array,maxSize);
}

void TicketsDict::resize(void){
   if(size == maxSize){
      maxSize *= 2;
      ArrayResize(array, maxSize);
   }
}

void TicketsDict::add(ulong ticket1,ulong ticket2){
   resize();
   pair p;
   p.ticket1 = ticket1;
   p.ticket2 = ticket2;
   array[size++] = p;
}

ulong TicketsDict::convert(ulong ticket){
   ulong ret = -1;
   for(int i = 0; i < size && ret == -1; i++){
      if(array[i].ticket1 == ticket)
         ret = array[i].ticket2;
   }
   return ret;
}

void TicketsDict::remove(ulong ticket){
   int pos = -1;
   for(int i = 0; i < size && pos == -1;i++){
      if(array[i].ticket1 == ticket)
         pos = i;
   }
   if(pos !=-1){
      for(int i = pos; i < size-1;i++)
         array[i] = array[i+1];
      size--;
   }
}

TicketsDict ticketsConverter;

input const double RISK_PROPORTION = 1;

int OnInit(){
   ticketsConverter = TicketsDict();
   trade.SetExpertMagicNumber(123);
   return(INIT_SUCCEEDED);
}


void OnDeinit(const int reason){
   
}


void OnTick(){
   int counter = 0;
   string fileName = "FMCopy\\" + (string) counter + ".txt";
   if(FileIsExist(fileName)){
      fileName = "FMCopy\\" + (string) 50 + ".txt";
      if(FileIsExist(fileName)){
         counter = 51;
         while(FileIsExist(fileName)){
            counter--;
            fileName = "FMCopy\\" + (string) counter + ".txt";
         }
         if(!FileIsExist(fileName))
            fileName = "FMCopy\\" + (string) (counter+1) + ".txt";
      }
      else
         fileName = "FMCopy\\" + (string) counter + ".txt";
   }
   else{
      while(!FileIsExist(fileName) && counter <= 50){
         counter++;
         fileName = "FMCopy\\" + (string) counter + ".txt";
      }
   }
   if(counter != 51){
      int file = FileOpen(fileName,FILE_READ|FILE_TXT|FILE_ANSI);
      while(!FileIsEnding(file)){
         int size=FileReadInteger(file,INT_VALUE);
         string str = FileReadString(file,size);
         string arrLine[];
         int nArgs = StringSplit(str,';',arrLine);
         if(nArgs ==1){
            ulong originalTicket = ticketsConverter.convert((int)arrLine[0]);
            bool deleted = trade.OrderDelete(originalTicket);
            if(!deleted){
               trade.PositionClose(originalTicket);
            }
            ticketsConverter.remove(originalTicket);
            Print("Closing order: " + (string)originalTicket);
         }
         else if(nArgs==4){
            ulong originalTicket = ticketsConverter.convert((int)arrLine[0]);
            bool modifed = trade.OrderModify(originalTicket,(double)arrLine[1],(double)arrLine[2],(double)arrLine[3],ORDER_TIME_GTC,0);
            Print("Modifing order: " + (string)originalTicket);
         }
         else{
            double lots = NormalizeDouble((double)arrLine[2] / 100000.0 * AccountInfoDouble(ACCOUNT_EQUITY) * RISK_PROPORTION,2);
            double bid = SymbolInfoDouble(arrLine[6],SYMBOL_BID);
            double ask = SymbolInfoDouble(arrLine[6],SYMBOL_ASK);
            double price = -1;
            bool tradeOpen = false;
            switch((int)arrLine[1]){
               case OP_BUY:
                  tradeOpen = trade.Buy(lots,arrLine[6],ask,(double)arrLine[4],(double)arrLine[5]);
                  break;
               case OP_SELL:
                  tradeOpen = trade.Sell(lots,arrLine[6],bid,(double)arrLine[4],(double)arrLine[5]);
                  break;
               case OP_BUYLIMIT:
                  tradeOpen = trade.BuyLimit(lots,(double)arrLine[3],arrLine[6],(double)arrLine[4],(double)arrLine[5]);
                  break;
               case OP_SELLLIMIT:
                  tradeOpen = trade.SellLimit(lots,(double)arrLine[3],arrLine[6],(double)arrLine[4],(double)arrLine[5]);
                  break;
               case OP_BUYSTOP:
                  tradeOpen = trade.BuyStop(lots,(double)arrLine[3],arrLine[6],(double)arrLine[4],(double)arrLine[5]);
                  break;
               case OP_SELLSTOP:
                  tradeOpen = trade.SellStop(lots,(double)arrLine[3],arrLine[6],(double)arrLine[4],(double)arrLine[5]);
                  break;
            }
            
            ulong ticket = trade.ResultOrder();
            
            if(ticket>0){
               ticketsConverter.add((int)arrLine[0],ticket);
               Print("New order: " + (string)ticket);
            }
         }
      }
      FileClose(file);
      FileDelete(fileName);
   }
}
//+------------------------------------------------------------------+
//|                                                   FMReceiver.mq4 |
//|                                                       Diogo Rolo |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+

//TODO
//Upgrade the dictonary

#property copyright "Diogo Rolo"
#property version   "1.00"
#property strict

struct pair{
   int ticket1;
   int ticket2;
};

class TicketsDict{
   private:
      pair array[];
      int size;
      int maxSize;
      void resize();
   public:
      TicketsDict();
      void add(int ticket1,int ticket2);
      int convert(int ticket);
      void remove(int ticket);
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

void TicketsDict::add(int ticket1,int ticket2){
   resize();
   pair p;
   p.ticket1 = ticket1;
   p.ticket2 = ticket2;
   array[size++] = p;
}

int TicketsDict::convert(int ticket){
   int ret = -1;
   for(int i = 0; i < size && ret == -1; i++){
      if(array[i].ticket1 == ticket)
         ret = array[i].ticket2;
   }
   return ret;
}

void TicketsDict::remove(int ticket){
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
      int file = FileOpen(fileName,FILE_READ|FILE_TXT);
      int size = (int)FileSize(file);
      while(!FileIsEnding(file)){
         string str = FileReadString(file,size);
         string arrLine[];
         int nArgs = StringSplit(str,';',arrLine);
         if(nArgs ==1){
            int originalTicket = ticketsConverter.convert((int)arrLine[0]);
            bool deleted = OrderDelete(originalTicket);
            if(!deleted){
               if(OrderSelect(originalTicket,SELECT_BY_TICKET)){
                  double price = OrderType()==OP_BUY?MarketInfo(OrderSymbol(),MODE_BID):MarketInfo(OrderSymbol(),MODE_ASK);
                  bool closed = OrderClose(originalTicket,OrderLots(),price,100);
               }
            }
            ticketsConverter.remove(originalTicket);
            Print("Closing order: " + (string)originalTicket);
         }
         else if(nArgs==4){
            int originalTicket = ticketsConverter.convert((int)arrLine[0]);
            bool modifed = OrderModify(originalTicket,(double)arrLine[1],(double)arrLine[2],(double)arrLine[3],0);
            Print("Modifing order: " + (string)originalTicket);
         }
         else{
            double lots = NormalizeDouble((double)arrLine[2] / 100000.0 * AccountBalance() * RISK_PROPORTION,2);
            double bid = MarketInfo(arrLine[6],MODE_BID);
            double ask = MarketInfo(arrLine[6],MODE_ASK);
            int ticket = OrderSend(arrLine[6],(int)arrLine[1],lots,((int)arrLine[1] == OP_BUY ? ask : ((int)arrLine[1] == OP_SELL ? bid : (double)arrLine[3])),100,(double)arrLine[4],(double)arrLine[5]);
            ticketsConverter.add((int)arrLine[0],ticket);
            Print("New order: " + (string)ticket);
         }
      }
      FileClose(file);
      FileDelete(fileName);
   }
}
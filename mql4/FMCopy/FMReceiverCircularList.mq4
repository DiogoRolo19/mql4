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
      int firstElement;
      int lastElement;
      int getRealPos(int pos);
      int find(int ticket);
      void print();
   public:
      TicketsDict();
      void add(int ticket1,int ticket2);
      int convert(int ticket);
      void remove(int ticket);
      void resize();
};

TicketsDict::TicketsDict(void){
   size = 0;
   maxSize = 10;
   firstElement = 0;
   lastElement = -1;
   ArrayResize(array,maxSize);
}

void TicketsDict::resize(void){
   if(size == maxSize){
      pair temp[];
      int tempMaxSize = maxSize*2;
      ArrayResize(temp, tempMaxSize);
      ArrayResize(array, tempMaxSize);
      for(int i = 0; i < size; i++){
         int pos = getRealPos(i);
         temp[i] = array[pos];
      }
      ArrayCopy(array,temp);
      maxSize = tempMaxSize;
      firstElement = 0;
      lastElement = size-1;
      print();
   }
}

void TicketsDict::add(int ticket1,int ticket2){
   pair p;
   p.ticket1 = ticket1;
   p.ticket2 = ticket2;
   int posToAdd = lastElement + 1 < maxSize ? lastElement + 1 : 0;
   array[posToAdd] = p;
   lastElement = posToAdd;
   size++;
   print();
}

int TicketsDict::convert(int ticket){
   int pos = getRealPos(find(ticket));
   return array[pos].ticket2;
}

void TicketsDict::remove(int ticket){
   int pos = find(ticket);
   if(pos !=-1){
      for(int i = pos; i > 0;i--)
         array[getRealPos(i)] = array[getRealPos(i-1)];
      size--;
      firstElement = firstElement != maxSize-1 ? firstElement + 1 : 0;
      print();
   }
}

int TicketsDict::getRealPos(int pos){
   return firstElement + pos < maxSize ? firstElement + pos : lastElement - (size - 1 - pos);
}

int TicketsDict::find(int ticket){
   int ret = -1;
   for(int i = 0; i < size && ret == -1; i++){
      int pos = getRealPos(i);
      if(array[pos].ticket1 == ticket)
         ret = i;
   }
   return ret;
}

void TicketsDict::print(void){
   Print("Size: " + (string) size);
   Print("Max Size: " + (string) maxSize);
   Print("First Element: " + (string) firstElement);
   Print("Last Element: " + (string) lastElement);
   for(int i = 0; i < maxSize;i++){
      Print((string) i + ": " + (string) array[i].ticket2);
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
         if(nArgs == 1){
            int originalTicket = ticketsConverter.convert((int)arrLine[0]);
            bool deleted = OrderDelete(originalTicket);
            if(!deleted){
               if(OrderSelect(originalTicket,SELECT_BY_TICKET)){
                  double price = OrderType()==OP_BUY?MarketInfo(OrderSymbol(),MODE_BID):MarketInfo(OrderSymbol(),MODE_ASK);
                  bool closed = OrderClose(originalTicket,OrderLots(),price,100);
               }
            }
            ticketsConverter.remove((int)arrLine[0]);
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
   ticketsConverter.resize();
}
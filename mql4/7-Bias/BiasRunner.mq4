//+------------------------------------------------------------------+
//|                                                   BiasRunner.mq4 |
//|                                                       Diogo Rolo |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Diogo Rolo"
#property link      ""
#property version   "1.00"
#property strict

#include "BiasMain.mqh"
#include <F1rstMillion/Lists/IntArray.mqh>
#include <F1rstMillion/Report.mqh>
#include <F1rstMillion/FMTS.mqh>

BiasMain BiasArray[];
PendingOrders PendingOrdersArray;
Report report;
FMTS fmts;
int Size;
datetime LastBar; //variable to allow the method @OnBar() excecute properly

input const string FILE = "";

input const bool LOGGING = false;

const int MAX_TRADES_SAME_SL = 3;

input const double FMTS_FIBO = 0;

const double STARTING_TRADING_HOUR = 9;
const double ENDING_TRADING_HOUR = 21;
const double STARTING_PENDING_HOUR = 0;
const double ENDING_PENDING_HOUR = 24;

const int MAX_SL = 500;
input const int MIN_SL = 40;


input const double ENTRY_FIBONACCI = 0.5;

input const int LENGHT = 10;
input const int LENGHT_LOWER = 8;
input const int LEGS = 3;

input const double RISK_RATIO = 50;
input const double RISK_PER_TRADE = 0.01;

input const bool TYPE_1A = true;
input const bool TYPE_1B = true;
input const bool TYPE_2A = true;
input const bool TYPE_2B = true;
input const bool TYPE_3A = true;
input const bool TYPE_4A = true;
input const bool TYPE_4B = true;

input const double STARTING_BE = 0;
const double STARTING_TRALLING_STOP = 0;
const double TRALLING_STOP_FACTOR = 0;
const double CANCEL_PENDING_ORDER_AT_RISK_REWARD = 20;
const bool CLOSE_PENDING_ORDERS_DURING_NIGHT = true;
const bool CLOSE_TRADES_DURING_NIGHT = false;
const int SLIPPAGE = 10;

//The next section is only for encrypt the script
string secret_key = "F1rstMillion";
bool isLogged = false;
string adminKey = "RplvBwV97jPVR&YAC7LitckED";
int currentMonth = -1;
int counterMaxTries = 40;
//end section

int OnInit(){
   if(FMTS_FIBO != 0)
      fmts = FMTS(FMTS_FIBO);
   LastBar = iTime(_Symbol,PERIOD_M1,0);
   currentMonth = Month();
   hashHandle();
   if(!CLOSE_PENDING_ORDERS_DURING_NIGHT)
      PendingOrdersArray = PendingOrders();
   string expertName = startBias();
   report = Report(expertName,false,LOGGING);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason){
   for(int i = 0; i < Size; i++){
      BiasArray[i].end();
   }
   report.printReport();
}

void OnTick(){
   if(currentMonth != Month() && !IsTesting()){
      hashHandle();
      currentMonth = Month();
   }
   if(isSecure()){
      for(int i = 0; i < Size; i++){
         IntArray ticketArray = BiasArray[i].OnTick(PendingOrdersArray);
         int size = ticketArray.getSize();
         if(size > 0){
            for(int j = 0; j < size; j++){
               int ticket = ticketArray.get(j);
               string name = BiasArray[i].getName();
               report.addPendingOrder(ticket,name);
            }
         }
      }
   }
   if(LastBar != iTime(_Symbol,PERIOD_M1,0)){
      LastBar = iTime(_Symbol,PERIOD_M1,0); 
      OnBar();
   }
   if(FMTS_FIBO != 0)
      fmts.OnTick();
   report.onTick();
}

void OnBar(){
   bool isTimeToEnter = isTimeToEnter(STARTING_TRADING_HOUR,ENDING_TRADING_HOUR);
   while(!CLOSE_PENDING_ORDERS_DURING_NIGHT && isTimeToEnter && PendingOrdersArray.getSize() > 0){
      PendingOrder po = PendingOrdersArray.pop();
      orderRegist(po);
   }
}

bool isSecure(){
   return IsTesting() || isLogged;
}

// Custom "hash" function (not cryptographic, just an example)
uint hash(string _input) {
    uint hash = 0;
    int length = StringLen(_input);
    
    for (int i = 0; i < length; i++) {
        hash += (uint)StringGetCharacter(_input, i);
        hash = (hash ^ (hash << 7)) + (hash >> 25);
    }
    
    return hash;
}

void hashHandle(){
   string current_month = IntegerToString(Month());
   string current_year =  StringSubstr(IntegerToString(Year()), 2,2);
   string data_to_encrypt = current_month + current_year + secret_key;
   uint currentHash = hash(data_to_encrypt);
   
   int contains = fileContains(IntegerToString(currentHash));
   
   isLogged = contains != -1;
   
   if(contains == 1){
      string next_month = IntegerToString(Month() != 12 ? Month() + 1 : 1);
      string next_year =  StringSubstr(IntegerToString( Month() != 12 ? Year() : Year() + 1), 2,2);
      data_to_encrypt = next_month + next_year + secret_key;
      uint nextHash = hash(data_to_encrypt);
      if(LOGGING){
         Print("Mode Admin");
         Print("Current hash: " + IntegerToString(currentHash));
         Print("Next hash: " + IntegerToString(nextHash));
      }
   }
   if(LOGGING)
      Print(isLogged ? "Mode trades On" : "Mode trades Off");
}

int orderRegist(PendingOrder &pendingOrder){
   int ticket = -1;
   if(pendingOrder.valid){
      int type  = -1;
      if(pendingOrder.order.direction == BUY)
         type = OP_BUYLIMIT;
      else if(pendingOrder.order.direction == SELL)
         type = OP_SELLLIMIT;
      bool isOrderValid = (type == OP_BUYLIMIT)? Ask > pendingOrder.order.entry: Bid < pendingOrder.order.entry;
      if(isOrderValid && !isRepeatedOrder(pendingOrder.order.entry,pendingOrder.order.sl,pendingOrder.order.expertID,MAX_TRADES_SAME_SL) && AccountFreeMargin() > 0 && pendingOrder.lotSize > 0){
         ticket = OrderSend(_Symbol,type,pendingOrder.lotSize,pendingOrder.order.entry,SLIPPAGE,pendingOrder.order.sl,pendingOrder.order.tp,NULL,pendingOrder.order.strategyID);
         if(ticket!=-1){
            report.addPendingOrder(ticket,pendingOrder.name);
            if(LOGGING)
               Print(IntegerToString(ticket) + " was open by " + pendingOrder.name);
         }
      }
   }
   return ticket;
}

int fileContains(string monthlyPass){
   int file = FileOpen("Passwords.txt",FILE_READ);
   int found = -1;
   if(file == -1){
      if(counterMaxTries >= 100)
         Alert("ERROR: File Does Not Exist!");
   }
   else if(counterMaxTries < 100){
      string pass = FileReadString(file);
      int counter = 0;
      while(pass != "" && found != 1 && counter < 100){
         if(monthlyPass == pass)
            found = 0;
         if(adminKey == pass)
            found = 1;
         pass = FileReadString(file);
         counter++;
      }
   }
   counterMaxTries++;
   FileClose(file);
   return found;
}

string startBias(){
   string name;
   if(FILE == ""){
      Size = 1;
      ArrayResize(BiasArray,Size);
      Inputs inputs = defaultInputs();
      BiasArray[0] = BiasMain(inputs,LOGGING);
      name = BiasArray[0].getName();
   }
   else{
      int file = FileOpen(FILE+".txt",FILE_READ|FILE_BIN);
      if(file>=0){
         name = "Master" + "_" + _Symbol;
         int size = (int)FileSize(file);
         string str = FileReadString(file,size);
         string arrFile[];
         StringSplit(str,'\n',arrFile);
         Size = ArraySize(arrFile);
         ArrayResize(BiasArray,Size);
         for(int i = 0; i < Size; i++){
            StringReplace(arrFile[i],".csv","");
            Inputs inputs = getInputs(arrFile[i]);
            BiasArray[i] = BiasMain(inputs,LOGGING);
         }
      }
      else
         Alert(FILE + " doesnt exist!");
      FileClose(file);
   }
   return name;
}

Inputs defaultInputs(){
   Inputs defInputs;
   defInputs.TIMEFRAME = (ENUM_TIMEFRAMES) Period();
   defInputs.STARTING_TRADING_HOUR = STARTING_TRADING_HOUR;
   defInputs.ENDING_TRADING_HOUR = ENDING_TRADING_HOUR;
   defInputs.STARTING_PENDING_HOUR = STARTING_PENDING_HOUR;
   defInputs.ENDING_PENDING_HOUR = STARTING_PENDING_HOUR;
   defInputs.MAX_SL = MAX_SL;
   defInputs.MIN_SL = MIN_SL;
   defInputs.ENTRY_FIBONACCI = ENTRY_FIBONACCI;
   defInputs.LENGHT = LENGHT;
   defInputs.LENGHT_LOWER = LENGHT_LOWER;
   defInputs.LEGS = LEGS;
   defInputs.RISK_RATIO = RISK_RATIO;
   defInputs.RISK_PER_TRADE = RISK_PER_TRADE;
   defInputs.TYPE_1A = TYPE_1A;
   defInputs.TYPE_1B = TYPE_1B;
   defInputs.TYPE_2A = TYPE_2A;
   defInputs.TYPE_2B = TYPE_2B;
   defInputs.TYPE_3A = TYPE_3A;
   defInputs.TYPE_4A = TYPE_4A;
   defInputs.TYPE_4B = TYPE_4B;
   defInputs.STARTING_BE = STARTING_BE;
   defInputs.STARTING_TRALLING_STOP = STARTING_TRALLING_STOP;
   defInputs.TRALLING_STOP_FACTOR = TRALLING_STOP_FACTOR;
   defInputs.CANCEL_PENDING_ORDER_AT_RISK_REWARD = CANCEL_PENDING_ORDER_AT_RISK_REWARD;
   defInputs.CLOSE_PENDING_ORDERS_DURING_NIGHT = CLOSE_PENDING_ORDERS_DURING_NIGHT;
   defInputs.CLOSE_TRADES_DURING_NIGHT = CLOSE_TRADES_DURING_NIGHT;
   defInputs.SLIPPAGE = SLIPPAGE;
   defInputs.MAX_TRADES_SAME_SL = MAX_TRADES_SAME_SL;
   return defInputs;
}

Inputs getInputs(string name){
   Inputs inputs = defaultInputs();
   string array[];
   StringSplit(name,'_',array);
   int size = ArraySize(array);
   for(int i = 1; i < size; i++){
      string value[];
      StringSplit(array[i],'-',value);
      if(value[0] == "TF")
         inputs.TIMEFRAME = StrToTimeframe((value[1]));
      else if(value[0] == "L")
         inputs.LENGHT = (int)StringToInteger(value[1]);
      else if(value[0] == "LL")
         inputs.LENGHT_LOWER = (int)StringToInteger(value[1]);
      else if(value[0] == "LE")
         inputs.LEGS = (int)StringToInteger(value[1]);
      else if(value[0] == "T"){
         string type = getType(value[1]);
         char charArray[];
         StringToCharArray(type,charArray);
         inputs.TYPE_1A = CharToString(charArray[0]) == "1";
         inputs.TYPE_1B = CharToString(charArray[1]) == "1";
         inputs.TYPE_2A = CharToString(charArray[2]) == "1";
         inputs.TYPE_2B = CharToString(charArray[3]) == "1";
         inputs.TYPE_3A = CharToString(charArray[4]) == "1";
         inputs.TYPE_4A = CharToString(charArray[5]) == "1";
         inputs.TYPE_4B = CharToString(charArray[6]) == "1";
      }
      else if(value[0] == "F")
         inputs.ENTRY_FIBONACCI = StringToDouble(value[1]);
      else if(value[0] == "RR")
         inputs.RISK_RATIO = StringToDouble(value[1]);
      else if(value[0] == "RT")
         inputs.RISK_PER_TRADE = StringToDouble(value[1]);
      else if(value[0] == "BE")
         inputs.STARTING_BE = StringToDouble(value[1]);
      else if(value[0] == "STS")
         inputs.STARTING_TRALLING_STOP = StringToDouble(value[1]);
      else if(value[0] == "TSF")
         inputs.TRALLING_STOP_FACTOR = StringToDouble(value[1]);
      else if(value[0] == "STH")
         inputs.STARTING_TRADING_HOUR = StringToDouble(value[1]);
      else if(value[0] == "ETH")
         inputs.ENDING_TRADING_HOUR = StringToDouble(value[1]);
      else if(value[0] == "SPH")
         inputs.STARTING_PENDING_HOUR = StringToDouble(value[1]);
      else if(value[0] == "EPH")
         inputs.ENDING_PENDING_HOUR = StringToDouble(value[1]);
      else if(value[0] == "MAX")
         inputs.MAX_SL = (int)StringToInteger(value[1]);
      else if(value[0] == "MIN")
         inputs.MIN_SL = (int)StringToInteger(value[1]);
      else if(value[0] == "CPO")
         inputs.CANCEL_PENDING_ORDER_AT_RISK_REWARD = StringToDouble(value[1]);
      else if(value[0] == "CPN")
         inputs.CLOSE_PENDING_ORDERS_DURING_NIGHT = StringToInteger(value[1]) == 1;
      else if(value[0] == "CN")
         inputs.CLOSE_TRADES_DURING_NIGHT = StringToInteger(value[1]) == 1;
   }
   if(!inputs.TYPE_2A)
      inputs.LENGHT_LOWER = 0;
   return inputs;
}

string getType(string value){
   int size = StringLen(value);
   char charArray[];
   StringToCharArray(value,charArray);
   string array[];
   ArrayResize(array,size);
   for(int i = 0; i < size; i++)
      array[i] = CharToString(charArray[i]);
   
   string result = "";
   int counter = 0;
   int lastNumber = 0;
   while(counter < size){
      if(array[counter] == "1" || array[counter] == "2" || array[counter] == "4"){
         if(lastNumber != StringToInteger(array[counter]) - 1){
            if(array[counter] == "2")
               result += "00";
            if(array[counter] == "4")
               result += lastNumber == 0? "00000": lastNumber == 1?"000":"0";
         }
         lastNumber = (int)StringToInteger(array[counter]);
         if(size == counter+1 || (array[counter+1] != "A" && array[counter+1] != "B")){
            result += "11";
            counter++;
         }
         else{
            if(array[counter+1] =="A")
                 result += "10";
            else if(array[counter+1] =="B")
               result += "01";
            counter += 2;
         }
      }
      else if(array[counter] == "3"){
         
         if(lastNumber == 0)
            result += "00001";
         else if(lastNumber == 1)
            result += "001";
         else if(lastNumber == 2)
            result += "1"; 
         counter++;
         lastNumber = 3;
      }
   }
   result += lastNumber == 0 ? "0000000" : lastNumber == 1 ? "00000" : lastNumber == 2 ? "000" : lastNumber == 3 ? "00" : "";
   return result;
}
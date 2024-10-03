//+------------------------------------------------------------------+
//|                                                       Report.mqh |
//|                                                       Diogo Rolo |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Diogo Rolo"
#property link      ""
#property strict

#include <F1rstMillion/GUI.mqh>

const bool TYPE_BUY = true;
const bool TYPE_SELL = false;

struct ReportOrder{
   int ticket;
   string strategy;
   bool type;
   double entry;
   double initialSl;
   double sl;
   double tp;
   double profit;
   double initialBalance;
   double finalBalance;
   double maxProfitPercentual;
   double maxDrawdownPercentual;
   double maxLossPercentual;
   double distanceToOpen;
   int strategyID;
   datetime pendingTime;
   datetime openTime;
   datetime closeTime;
};

struct ReportOrdersArray{
   ReportOrder order[];
   int counter;
};

class Report{
private:
   GUI gui;
   ReportOrdersArray activePendingOrders;
   ReportOrdersArray closedPendingOrders;
   ReportOrdersArray activeOrders;
   ReportOrdersArray closedOrders;
   bool MODE_OPEN_ORDERS;
   bool MODE_STRATEGIES_NAMES;
   string ID;
   double INITIAL_BALANCE;
   bool LOGGING;
   int sellsAmount;
   int buysAmount;
   double averageRiskReward;
   double profit;
   double loss;
   int sellWinsAmount;
   int buyWinsAmount;
   int sellBesAmount;
   int buyBesAmount;
   int sellLossesAmount;
   int buyLossesAmount;
   double maxDrawdownPercentual;
   double maxBalance;
   int maxConsecutiveWins;
   int actualConsecutiveWins;
   int maxSequenceWithoutLosses;
   int actualSequenceWithoutLosses;
   int maxConsecutiveLosses;
   int actualConsecutiveLosses;
   int maxSequenceWithoutWins;
   int actualSequenceWithoutWins;
   void initialization();
   void closePendingOrder(int pos);
   void openOrder(int pos);
   void closeOrder(int pos);
   void updateReport(ReportOrder &order);
   void updatePendingOrder(int pos);
   void updateActiveOrder(int pos);
   int createFile();
   void removeElement(ReportOrdersArray &array,int pos);
public:
   Report();
   Report(bool guiInit, string id, bool modeOpenOrders, bool logging);
   Report(string id, bool modeOpenOrders, bool logging);
   void addWarning(string warning);
   void addPendingOrder(int ticket, string strategy);
   void addOpenOrder(int ticket, string strategy);
   void onTick();
   void printReport();
   void newModeTradesAllowedGUI(bool modeTradesAllowed);
};

Report::Report(){
   MODE_OPEN_ORDERS = false;
   LOGGING = true;
   initialization();
   ID = WindowExpertName();
}


Report::Report(bool modeTradesAllowed, string id, bool modeOpenOrders, bool logging){
   gui = GUI(id, guiModeTrades(true));
   MODE_OPEN_ORDERS = modeOpenOrders;
   LOGGING = logging;
   initialization();
   ID = id;
}

Report::Report(string id, bool modeOpenOrders, bool logging){
   MODE_OPEN_ORDERS = modeOpenOrders;
   LOGGING = logging;
   initialization();
   ID = id;
}

void Report::addWarning(string warning){
   gui.addWarning(warning);
}

string guiModeTrades(bool modeTradesAllowed){
   return IsTesting() ? "Backtesting" : modeTradesAllowed ? "Trades Allowed" : "Blocked";
}

void Report::initialization(){
   INITIAL_BALANCE = AccountInfoDouble(ACCOUNT_BALANCE);
   MODE_STRATEGIES_NAMES = false;
   if(!MODE_OPEN_ORDERS){
      ArrayResize(activePendingOrders.order,100);
      activePendingOrders.counter = 0;
      ArrayResize(closedPendingOrders.order,100);
      closedPendingOrders.counter = 0;
   }
   ArrayResize(activeOrders.order,100);
   activeOrders.counter = 0;
   ArrayResize(closedOrders.order,100);
   closedOrders.counter = 0;
   sellsAmount=0;
   buysAmount=0;
   averageRiskReward=0;
   profit = 0;
   loss = 0;
   sellWinsAmount=0;
   buyWinsAmount=0;
   sellBesAmount=0;
   buyBesAmount=0;
   sellLossesAmount=0;
   buyLossesAmount=0;
   maxDrawdownPercentual=0;
   maxBalance=AccountBalance();
   maxConsecutiveWins=0;
   actualConsecutiveWins=0;
   maxSequenceWithoutLosses=0;
   actualSequenceWithoutLosses=0;
   maxConsecutiveLosses=0;
   actualConsecutiveLosses=0;
   maxSequenceWithoutWins=0;
   actualSequenceWithoutWins=0;
}

void Report::onTick(){
   if(!MODE_OPEN_ORDERS){
      for(int i = activePendingOrders.counter-1; i>=0;i--){
         updatePendingOrder(i);
         ReportOrder order = activePendingOrders.order[i];
         bool selected = OrderSelect(order.ticket,SELECT_BY_TICKET);
         if(!selected)
            Alert("Ticket not Found");
         else{
            if(OrderType() == OP_BUY || OrderType() == OP_SELL)
               openOrder(i);
            if(OrderCloseTime() != 0)
               closePendingOrder(i);
         }
      }
   }
   for(int i = activeOrders.counter-1;  i>=0;i--){
      updateActiveOrder(i);
      if(OrderCloseTime() != 0)
         closeOrder(i);
   }
}

void Report::printReport(){
   gui.end();
   int tradesAmount = sellsAmount+buysAmount;
   int winsAmount = sellWinsAmount + buyWinsAmount;
   int besAmount = sellBesAmount + buyBesAmount;
         int lossesAmount = sellLossesAmount + buyLossesAmount;
   double ratio = loss == 0 ? 100 : profit/loss;
   if(tradesAmount!=0 && (LOGGING || (tradesAmount >= 20  && AccountInfoDouble(ACCOUNT_BALANCE) / INITIAL_BALANCE >= 1 && maxDrawdownPercentual <= 0.25))){
      int file = createFile();
      if(file!=INVALID_HANDLE){
         FileWrite(file,"Summary");
         FileWrite(file,"Name;Number of trades", "Number of Sells;Number of Buys",
                        "Ratio;Average Risk Reward;Number of Wins(%) B/S",
                        "Number of BEs(%) B/S", "Number of Losses(%) B/S;Max Drawdown Percentual",
                        "Max Balance;Max Consecutive Wins;Max Sequence without Losses",
                        "Max Consecutive Losses;Max Sequence without Wins;Final Balance");
         FileWrite(file,ID,tradesAmount,sellsAmount,buysAmount,DoubleToString(ratio,2), DoubleToString(averageRiskReward*100.0,2),
                        IntegerToString(winsAmount)+"("+ IntegerToString(100*winsAmount/tradesAmount)+"%) "
                        + IntegerToString(buyWinsAmount) + "/" + IntegerToString(sellWinsAmount),
                        IntegerToString(besAmount)+"("+ IntegerToString(100*besAmount/tradesAmount)+"%)"
                        + IntegerToString(buyBesAmount) + "/" + IntegerToString(sellBesAmount),
                        IntegerToString(lossesAmount)+"("+ IntegerToString(100*lossesAmount/tradesAmount)+"%)"
                        + IntegerToString(buyLossesAmount) + "/" + IntegerToString(sellLossesAmount),
                        DoubleToString(maxDrawdownPercentual,2),DoubleToString(maxBalance,2),
                        maxConsecutiveWins,maxSequenceWithoutLosses,
                        maxConsecutiveLosses,maxSequenceWithoutWins,AccountInfoDouble(ACCOUNT_BALANCE));
         
         if(!MODE_OPEN_ORDERS){
            FileWrite(file,"PendingOrders");
            FileWrite(file,"Ticket;" + (MODE_STRATEGIES_NAMES?"Strategy;":"") + "Open Time;Close Time;Strategy ID",
                           "Type;Entry;SL;TP;Initial Balance;Distance to Open");
            
            for(int i = 0;i<closedPendingOrders.counter;i++){
               ReportOrder order = closedPendingOrders.order[i];
               FileWrite(file,IntegerToString(order.ticket) + (MODE_STRATEGIES_NAMES?(";" + order.strategy):""),order.pendingTime,
                        order.closeTime,order.strategyID,(order.type == TYPE_BUY)?"BUY":"SELL",
                        DoubleToString(order.entry,Digits()),DoubleToString(order.sl,Digits()),
                        DoubleToString(order.tp,Digits()),DoubleToString(order.initialBalance,2),
                        DoubleToString(order.distanceToOpen,Digits())); 
            }
         }
         
         FileWrite(file,"Orders");
         FileWrite(file,"Ticket;" + (MODE_STRATEGIES_NAMES?"Strategy;":"") + "Pending Time;Open Time",
                        "Close Time;Strategy ID;Type;Entry;Original SL;SL;TP;Initial Balance",
                        "Final Balance;Profit;Max Profit(%);Max Drawdown(%);Max Loss(%)");
         
         for(int i = 0;i<closedOrders.counter;i++){
            ReportOrder order = closedOrders.order[i];
            FileWrite(file,IntegerToString(order.ticket) + (MODE_STRATEGIES_NAMES?(";" + order.strategy):""),order.pendingTime,order.openTime,
                     order.closeTime,order.strategyID,(order.type == TYPE_BUY)?"BUY":"SELL",DoubleToString(order.entry,Digits()),
                     DoubleToString(order.initialSl,Digits()),DoubleToString(order.sl,Digits()),
                     DoubleToString(order.tp,Digits()),DoubleToString(order.initialBalance,2),
                     DoubleToString(order.finalBalance,2),DoubleToString(order.profit,2),
                     DoubleToString(order.maxProfitPercentual*100,2),DoubleToString(order.maxDrawdownPercentual*100,2),
                     DoubleToString(order.maxLossPercentual*100,2));
         }
         FileClose(file);
         Print("Report saved");
         Comment("Report saved");
      } 
      else{
         Print("Report not saved");
         Comment("Report not saved");
      }
   }
}

int Report::createFile(){
   int counter = 0;
   string fileName;
   do{
      fileName = "Backtesting_" +WindowExpertName()+"\\"+ ID + (counter == 0 ? "" : ("(" + IntegerToString(counter)) + ")") + ".csv";
      counter++;
   }
   while (FileIsExist(fileName));
   Print("The report will be saved in ",TerminalInfoString(TERMINAL_DATA_PATH),"\\",fileName);
   return FileOpen(fileName,FILE_WRITE|FILE_CSV);
}
void Report::addPendingOrder(int ticket, string strategy = ""){
   if(!MODE_STRATEGIES_NAMES && strategy != "")
      MODE_STRATEGIES_NAMES = true;
   gui.changeLastTrade(ticket);
   ReportOrder order;
   bool selected = OrderSelect(ticket,SELECT_BY_TICKET);
   if(!selected)
      Alert("Ticket not Found");
   else{
      order.ticket = ticket;
      order.strategy = strategy;
      order.type = (OrderType() == OP_BUY || OrderType() == OP_BUYLIMIT || OrderType() == OP_BUYSTOP) ? TYPE_BUY : TYPE_SELL;
      order.entry = OrderOpenPrice();
      order.sl = OrderStopLoss();
      order.initialSl = order.sl;
      order.tp = OrderTakeProfit();
      order.profit = 0;
      order.initialBalance = AccountBalance();
      order.finalBalance = -1;
      order.maxProfitPercentual = 0;
      order.maxDrawdownPercentual = 0;
      order.maxLossPercentual = 0;
      order.distanceToOpen = MathAbs(Bid - order.entry);
      order.strategyID = OrderMagicNumber();
      order.pendingTime = TimeCurrent();
      order.openTime = -1;
      order.closeTime = -1;
      if(ArraySize(activePendingOrders.order) == activePendingOrders.counter){
         ArrayResize(activePendingOrders.order,activePendingOrders.counter*2);
      }
      activePendingOrders.order[activePendingOrders.counter++] = order;
   }
}

void Report::addOpenOrder(int ticket, string strategy = ""){
   gui.changeLastTrade(ticket);
   gui.changeTotalTrades(gui.getTotalTrades() + 1);
   ReportOrder order;
   bool selected = OrderSelect(ticket,SELECT_BY_TICKET);
   if(!selected)
      Alert("Ticket not Found");
   else{
      order.ticket = ticket;
      order.type = (OrderType() == OP_BUY || OrderType() == OP_BUYLIMIT || OrderType() == OP_BUYSTOP) ? TYPE_BUY : TYPE_SELL;
      order.entry = OrderOpenPrice();
      order.sl = OrderStopLoss();
      order.initialSl = order.sl;
      order.tp = OrderTakeProfit();
      order.profit = 0;
      order.initialBalance = AccountBalance();
      order.finalBalance = -1;
      order.maxProfitPercentual = 0;
      order.maxDrawdownPercentual = 0;
      order.maxLossPercentual = 0;
      order.distanceToOpen = 0;
      order.strategyID = OrderMagicNumber();
      order.pendingTime = TimeCurrent();
      order.openTime = TimeCurrent();
      order.closeTime = -1;
      if(ArraySize(activeOrders.order) == activeOrders.counter){
         ArrayResize(activeOrders.order,activeOrders.counter*2);
      }
      activeOrders.order[activeOrders.counter++] = order;
   }
}

void Report::closePendingOrder(int pos){
   ReportOrder order = activePendingOrders.order[pos];
   order.closeTime = TimeCurrent();
   order.finalBalance = AccountBalance();
   removeElement(activePendingOrders,pos);
   
   if(ArraySize(closedPendingOrders.order) == closedPendingOrders.counter){
      ArrayResize(closedPendingOrders.order,closedPendingOrders.counter*2);
   }
   
   closedPendingOrders.order[closedPendingOrders.counter++] = order;
}

void Report::openOrder(int pos){
   gui.changeTotalTrades(gui.getTotalTrades() + 1);
   ReportOrder order = activePendingOrders.order[pos];
   order.openTime = TimeCurrent();
   order.distanceToOpen = 0;
   order.initialBalance = AccountBalance();
   removeElement(activePendingOrders,pos);
   
   if(ArraySize(activeOrders.order) == activeOrders.counter){
      ArrayResize(activeOrders.order,activeOrders.counter*2);
   }
   
   activeOrders.order[activeOrders.counter++] = order;
}

void Report::closeOrder(int pos){
   ReportOrder order = activeOrders.order[pos];
   bool selected = OrderSelect(order.ticket,SELECT_BY_TICKET);
   if(!selected)
      Alert("Ticket not Found");
   else{
      order.closeTime = TimeCurrent();
      order.finalBalance = AccountBalance();
      order.profit = OrderProfit();
      removeElement(activeOrders,pos);
      
      if(ArraySize(closedOrders.order) == closedOrders.counter){
         ArrayResize(closedOrders.order,closedOrders.counter*2);
      }
      
      closedOrders.order[closedOrders.counter++] = order;
      
      updateReport(order);
      gui.changeProfit(gui.getProfit() + order.profit);
   }
   
}

void Report::updateReport(ReportOrder &order){
   if((order.profit/order.initialBalance)>0.01){
      if(order.type == TYPE_BUY){
         buysAmount++;
         buyWinsAmount++;
      }
      else{
         sellsAmount++;
         sellWinsAmount++;
      }
      actualConsecutiveWins++;
      maxConsecutiveWins = MathMax(maxConsecutiveWins,actualConsecutiveWins);
      actualSequenceWithoutLosses++;
      maxSequenceWithoutLosses = MathMax(maxSequenceWithoutLosses,actualSequenceWithoutLosses);
      actualConsecutiveLosses = 0;
      actualSequenceWithoutWins = 0;
   }
   else if(order.profit<0){
      if(order.type == TYPE_BUY){
         buysAmount++;
         buyLossesAmount++;
      }
      else{
         sellsAmount++;
         sellLossesAmount++;
      }
      actualConsecutiveLosses++;
      maxConsecutiveLosses = MathMax(maxConsecutiveLosses,actualConsecutiveLosses);
      actualSequenceWithoutWins++;
      maxSequenceWithoutWins = MathMax(maxSequenceWithoutWins,actualSequenceWithoutWins);
      actualConsecutiveWins = 0;
      actualSequenceWithoutLosses = 0;
   }
   else{
      if(order.type == TYPE_BUY){
         buysAmount++;
         buyBesAmount++;
      }
      else{
         sellsAmount++;
         sellBesAmount++;
      }
      actualSequenceWithoutLosses++;
      maxSequenceWithoutLosses = MathMax(maxSequenceWithoutLosses,actualSequenceWithoutLosses);
      actualSequenceWithoutWins++;
      maxSequenceWithoutWins = MathMax(maxSequenceWithoutWins,actualSequenceWithoutWins);
      actualConsecutiveWins = 0;
      actualConsecutiveLosses = 0;
   }
   if(order.profit>0)
      profit += order.profit;
   else
      loss -= order.profit;
   averageRiskReward = ((order.profit/order.initialBalance) + ((buysAmount+sellsAmount-1) * averageRiskReward)) / (buysAmount+sellsAmount);
   maxBalance = MathMax(maxBalance,AccountBalance());
   maxDrawdownPercentual = MathMax(maxDrawdownPercentual,(maxBalance - AccountBalance())/maxBalance);
   
}

void Report::updatePendingOrder(int pos){
   ReportOrder order = activePendingOrders.order[pos];
   order.distanceToOpen = MathMin(order.distanceToOpen,MathAbs(Bid - order.entry));
   activePendingOrders.order[pos] = order;
}

void Report::updateActiveOrder(int pos){
   ReportOrder order = activeOrders.order[pos];
   bool selected = OrderSelect(order.ticket,SELECT_BY_TICKET);
   if(!selected)
      closeOrder(pos);
   else{
      order.sl = OrderStopLoss();
      order.profit = OrderProfit()-OrderCommission();
      order.maxProfitPercentual = MathMax(order.maxProfitPercentual,order.profit/AccountBalance());
      order.maxDrawdownPercentual = MathMax(order.maxDrawdownPercentual,order.maxProfitPercentual-order.profit/AccountBalance());
      order.maxLossPercentual = MathMin(order.maxLossPercentual,order.profit/AccountBalance());
      activeOrders.order[pos] = order;
   }
}

void Report::removeElement(ReportOrdersArray &array,int pos){
   for(int i = pos; i<array.counter-1;i++){
      array.order[i] = array.order[i+1];
   }
   array.counter--;
}

void Report::newModeTradesAllowedGUI(bool modeTradesAllowed){
   gui.changeMode(guiModeTrades(modeTradesAllowed));
}
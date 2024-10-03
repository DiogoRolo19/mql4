//+------------------------------------------------------------------+
//|                                                          GUI.mqh |
//|                                                       Diogo Rolo |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Diogo Rolo"
#property version   "1.00"
#property strict

class GUI{
private:
   int MARGIN_X_SIZE;
   int MAX_X_SIZE;
   double UNIT;
   string Name;
   string Mode;
   int TotalTrades;
   double Profit;
   int LastTrade;
   datetime LastBar;
   void initialize(string name, string mode);
   void load();
   void save();
   void createText(string id, string text, int yPos);
   void createLabel(string id, string text, int yPos);
   void createLine(string id,int yPos);
public:
   GUI(void);
   GUI(string name, string mode);
   void end();
   void addWarning(string warning);
   string getMode();
   void changeMode(string newMode);
   int getTotalTrades();
   void changeTotalTrades(int newValue);
   double getProfit();
   void changeProfit(double newValue);
   int getLastTrade();
   void changeLastTrade(int newValue);
};

GUI::GUI(void){}
GUI::GUI(string name,string mode){
   initialize(name,mode);
   if(!IsTesting())
      load();
}
void GUI::end(void){
   if(!IsTesting())
      save();
}

void GUI::addWarning(string warning){
   //Warning
   createText("Warning",warning,365);
}
void GUI::initialize(string name,string mode){
   MAX_X_SIZE = 300;
   MARGIN_X_SIZE = 27;
   UNIT = (double)TerminalInfoInteger(TERMINAL_SCREEN_DPI)/120;
   Name = name;
   Mode = mode;
   TotalTrades = 0;
   Profit = 0;
   LastTrade = 0;
   
   //Setting up Bg Color, Candles and Scale of Chart
   ChartSetInteger(0,CHART_MODE,CHART_CANDLES);
   //ChartSetInteger(0, CHART_COLOR_BACKGROUND, 0x8F8F8F);
   ChartSetInteger(0, CHART_SCALE, 4);
   ChartSetInteger(0,CHART_FOREGROUND,0);

   //Rectangle Interface
   ObjectCreate(0,"Interface", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0,"Interface",OBJPROP_CORNER,0);
   ObjectSetInteger(0,"Interface",OBJPROP_BGCOLOR,0x2C2C2C);
   ObjectSetInteger(0,"Interface",OBJPROP_XSIZE,(int)(MAX_X_SIZE*UNIT));
   ObjectSetInteger(0,"Interface",OBJPROP_YSIZE,(int)(400*UNIT));
   ObjectSetInteger(0,"Interface",OBJPROP_XDISTANCE,(int)(10*UNIT));
   ObjectSetInteger(0,"Interface",OBJPROP_YDISTANCE,(int)(60*UNIT));
   ObjectSetInteger(0,"Interface",OBJPROP_HIDDEN,false);
   ObjectSetInteger(0,"Interface",OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,"Interface",OBJPROP_COLOR,clrWhite);
   ObjectSetInteger(0,"Interface",OBJPROP_WIDTH,2);

   //Rectangle for Brand Name
   ObjectCreate(0,"LabelBG", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0,"LabelBG",OBJPROP_CORNER,0);
   ObjectSetInteger(0,"LabelBG",OBJPROP_BGCOLOR,0x2C2C2C);
   ObjectSetInteger(0,"LabelBG",OBJPROP_XSIZE,(int)(270*UNIT));
   ObjectSetInteger(0,"LabelBG",OBJPROP_YSIZE,(int)(37.5*UNIT));
   ObjectSetInteger(0,"LabelBG",OBJPROP_XDISTANCE,(int)(25*UNIT));
   ObjectSetInteger(0,"LabelBG",OBJPROP_YDISTANCE,(int)(40*UNIT));
   ObjectSetInteger(0,"LabelBG",OBJPROP_HIDDEN,false);
   ObjectSetInteger(0,"LabelBG",OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,"LabelBG",OBJPROP_COLOR,clrWhite);//clrDarkOrchid);
   ObjectSetInteger(0,"LabelBG",OBJPROP_WIDTH,2);
   
   

   //Brand Name
   ObjectCreate(0,"Brand", OBJ_LABEL,0,0,0);
   ObjectSetText("Brand","F1rst Million",0,"Cascadia Code Semilight");
   ObjectSetInteger(0,"Brand",OBJPROP_FONTSIZE,(int)(20*UNIT));
   ObjectSetInteger(0,"Brand",OBJPROP_CORNER,0);
   ObjectSetInteger(0,"Brand",OBJPROP_COLOR,White);
   ObjectSetInteger(0,"Brand",OBJPROP_XDISTANCE,46);
   ObjectSetInteger(0,"Brand",OBJPROP_YDISTANCE,34);

   createText("Strategy","Strategy: " + Name,80);
   createText("Status","Status: " + Mode,110);
   
   //Grid
   ObjectCreate(0,"Grid", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0,"Grid",OBJPROP_CORNER,0);
   ObjectSetInteger(0,"Grid",OBJPROP_BGCOLOR,0x2C2C2C);
   ObjectSetInteger(0,"Grid",OBJPROP_XSIZE,(int)(160*UNIT));
   ObjectSetInteger(0,"Grid",OBJPROP_YSIZE,(int)(20*UNIT));
   ObjectSetInteger(0,"Grid",OBJPROP_XDISTANCE,(int)((MARGIN_X_SIZE-2)*UNIT));
   ObjectSetInteger(0,"Grid",OBJPROP_YDISTANCE,(int)(140*UNIT));
   ObjectSetInteger(0,"Grid",OBJPROP_HIDDEN,false);
   ObjectSetInteger(0,"Grid",OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,"Grid",OBJPROP_COLOR,White);
   ObjectSetInteger(0,"Grid",OBJPROP_WIDTH,1);

   //Grid2
   ObjectCreate(0,"Grid2", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0,"Grid2",OBJPROP_CORNER,0);
   ObjectSetInteger(0,"Grid2",OBJPROP_BGCOLOR,0x2C2C2C);
   ObjectSetInteger(0,"Grid2",OBJPROP_XSIZE,(int)(160*UNIT));
   ObjectSetInteger(0,"Grid2",OBJPROP_YSIZE,(int)(20.5*UNIT));
   ObjectSetInteger(0,"Grid2",OBJPROP_XDISTANCE,(int)((MARGIN_X_SIZE-2)*UNIT));
   ObjectSetInteger(0,"Grid2",OBJPROP_YDISTANCE,(int)(160*UNIT));
   ObjectSetInteger(0,"Grid2",OBJPROP_HIDDEN,false);
   ObjectSetInteger(0,"Grid2",OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,"Grid2",OBJPROP_COLOR,White);
   ObjectSetInteger(0,"Grid2",OBJPROP_WIDTH,1);

   //Grid3
   ObjectCreate(0,"Grid3", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0,"Grid3",OBJPROP_CORNER,0);
   ObjectSetInteger(0,"Grid3",OBJPROP_BGCOLOR,0x2C2C2C);
   ObjectSetInteger(0,"Grid3",OBJPROP_XSIZE,(int)(160*UNIT));
   ObjectSetInteger(0,"Grid3",OBJPROP_YSIZE,(int)(20.5*UNIT));
   ObjectSetInteger(0,"Grid3",OBJPROP_XDISTANCE,(int)((MARGIN_X_SIZE-2)*UNIT));
   ObjectSetInteger(0,"Grid3",OBJPROP_YDISTANCE,(int)(180*UNIT));
   ObjectSetInteger(0,"Grid3",OBJPROP_HIDDEN,false);
   ObjectSetInteger(0,"Grid3",OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,"Grid3",OBJPROP_COLOR,White);
   ObjectSetInteger(0,"Grid3",OBJPROP_WIDTH,1);

   //Grid4
   ObjectCreate(0,"Grid4", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0,"Grid4",OBJPROP_CORNER,0);
   ObjectSetInteger(0,"Grid4",OBJPROP_BGCOLOR,0x2C2C2C);
   ObjectSetInteger(0,"Grid4",OBJPROP_XSIZE,(int)(110*UNIT));
   ObjectSetInteger(0,"Grid4",OBJPROP_YSIZE,(int)(20.5*UNIT));
   ObjectSetInteger(0,"Grid4",OBJPROP_XDISTANCE,(int)(185*UNIT));
   ObjectSetInteger(0,"Grid4",OBJPROP_YDISTANCE,(int)(140*UNIT));
   ObjectSetInteger(0,"Grid4",OBJPROP_HIDDEN,false);
   ObjectSetInteger(0,"Grid4",OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,"Grid4",OBJPROP_COLOR,White);
   ObjectSetInteger(0,"Grid4",OBJPROP_WIDTH,1);

   //Grid5
   ObjectCreate(0,"Grid5", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0,"Grid5",OBJPROP_CORNER,0);
   ObjectSetInteger(0,"Grid5",OBJPROP_BGCOLOR,0x2C2C2C);
   ObjectSetInteger(0,"Grid5",OBJPROP_XSIZE,(int)(110*UNIT));
   ObjectSetInteger(0,"Grid5",OBJPROP_YSIZE,(int)(20.5*UNIT));
   ObjectSetInteger(0,"Grid5",OBJPROP_XDISTANCE,(int)(185*UNIT));
   ObjectSetInteger(0,"Grid5",OBJPROP_YDISTANCE,(int)(160*UNIT));
   ObjectSetInteger(0,"Grid5",OBJPROP_HIDDEN,false);
   ObjectSetInteger(0,"Grid5",OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,"Grid5",OBJPROP_COLOR,White);
   ObjectSetInteger(0,"Grid5",OBJPROP_WIDTH,1);

   //Grid6
   ObjectCreate(0,"Grid6", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0,"Grid6",OBJPROP_CORNER,0);
   ObjectSetInteger(0,"Grid6",OBJPROP_BGCOLOR,0x2C2C2C);
   ObjectSetInteger(0,"Grid6",OBJPROP_XSIZE,(int)(110*UNIT));
   ObjectSetInteger(0,"Grid6",OBJPROP_YSIZE,(int)(20.5*UNIT));
   ObjectSetInteger(0,"Grid6",OBJPROP_XDISTANCE,(int)(185*UNIT));
   ObjectSetInteger(0,"Grid6",OBJPROP_YDISTANCE,(int)(180*UNIT));
   ObjectSetInteger(0,"Grid6",OBJPROP_HIDDEN,false);
   ObjectSetInteger(0,"Grid6",OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,"Grid6",OBJPROP_COLOR,White);
   ObjectSetInteger(0,"Grid6",OBJPROP_WIDTH,1);

   //TotalTrades
   ObjectCreate(0,"TotalTrades", OBJ_LABEL,0,0,0);
   ObjectSetText("TotalTrades","Number of trades:",0,"Cascadia Code Semilight");
   ObjectSetInteger(0,"TotalTrades",OBJPROP_COLOR,clrWhite);
   ObjectSetInteger(0,"TotalTrades",OBJPROP_FONTSIZE,8);
   ObjectSetInteger(0,"TotalTrades",OBJPROP_CORNER,0);
   ObjectSetInteger(0,"TotalTrades",OBJPROP_XDISTANCE,(int)((MARGIN_X_SIZE + 3) *UNIT));
   ObjectSetInteger(0,"TotalTrades",OBJPROP_YDISTANCE,(int)(142.5*UNIT));

   //Profit
   ObjectCreate(0,"Profit", OBJ_LABEL,0,0,0);
   ObjectSetText("Profit","Total profit:",0,"Cascadia Code Semilight");
   ObjectSetInteger(0,"Profit",OBJPROP_COLOR,clrWhite);
   ObjectSetInteger(0,"Profit",OBJPROP_FONTSIZE,8);
   ObjectSetInteger(0,"Profit",OBJPROP_CORNER,0);
   ObjectSetInteger(0,"Profit",OBJPROP_XDISTANCE,(int)((MARGIN_X_SIZE + 3) *UNIT));
   ObjectSetInteger(0,"Profit",OBJPROP_YDISTANCE,(int)(162.5*UNIT));

   //LastTrade
   ObjectCreate(0,"LastTrade", OBJ_LABEL,0,0,0);
   ObjectSetText("LastTrade","Last trade open:",0,"Cascadia Code Semilight");
   ObjectSetInteger(0,"LastTrade",OBJPROP_COLOR,clrWhite);
   ObjectSetInteger(0,"LastTrade",OBJPROP_FONTSIZE,8);
   ObjectSetInteger(0,"LastTrade",OBJPROP_CORNER,0);
   ObjectSetInteger(0,"LastTrade",OBJPROP_XDISTANCE,(int)((MARGIN_X_SIZE + 3) *UNIT));
   ObjectSetInteger(0,"LastTrade",OBJPROP_YDISTANCE,(int)(182.5*UNIT));

   //TotalTradesValue
   ObjectCreate(0,"TotalTradesValue", OBJ_LABEL,0,0,0);
   ObjectSetText("TotalTradesValue",IntegerToString(TotalTrades),0,"Cascadia Code Semilight");
   ObjectSetInteger(0,"TotalTradesValue",OBJPROP_COLOR,clrWhite);
   ObjectSetInteger(0,"TotalTradesValue",OBJPROP_FONTSIZE,8);
   ObjectSetInteger(0,"TotalTradesValue",OBJPROP_CORNER,0);
   ObjectSetInteger(0,"TotalTradesValue",OBJPROP_XDISTANCE,(int)((190+4)*UNIT));
   ObjectSetInteger(0,"TotalTradesValue",OBJPROP_YDISTANCE,(int)(142.5*UNIT));

   //ProfitValue
   ObjectCreate(0,"ProfitValue", OBJ_LABEL,0,0,0);
   ObjectSetText("ProfitValue",DoubleToString(Profit,2),0,"Cascadia Code Semilight");
   ObjectSetInteger(0,"ProfitValue",OBJPROP_COLOR,clrWhite);
   ObjectSetInteger(0,"ProfitValue",OBJPROP_FONTSIZE,8);
   ObjectSetInteger(0,"ProfitValue",OBJPROP_CORNER,0);
   ObjectSetInteger(0,"ProfitValue",OBJPROP_XDISTANCE,(int)(190*UNIT));
   ObjectSetInteger(0,"ProfitValue",OBJPROP_YDISTANCE,(int)(162.5*UNIT));

   //LastTradeID
   ObjectCreate(0,"LastTradeID", OBJ_LABEL,0,0,0);
   ObjectSetText("LastTradeID",IntegerToString(LastTrade),0,"Cascadia Code Semilight");
   ObjectSetInteger(0,"LastTradeID",OBJPROP_COLOR,clrWhite);
   ObjectSetInteger(0,"LastTradeID",OBJPROP_FONTSIZE,8);
   ObjectSetInteger(0,"LastTradeID",OBJPROP_CORNER,0);
   ObjectSetInteger(0,"LastTradeID",OBJPROP_XDISTANCE,(int)((190+4)*UNIT));
   ObjectSetInteger(0,"LastTradeID",OBJPROP_YDISTANCE,(int)(182.5*UNIT));

   //FirstMesage
   createText("FirstMesage","The magic you are looking for is in the work you are avoiding.",210);


   //Grid7
   createLine("Grid7",250);

   //Support
   createText("Support","If you need assistance or want to recommend our software, please contact our support.",260);

   //Email
   createText("Email","Email:firstmillion@outlook.pt",320);
   
   //Grid8
   createLine("Grid8",350);
}

void GUI::load(){
   string fileName = "Logs\\" + Name + ".txt";
   if(FileIsExist(fileName)){
      int file = FileOpen(fileName,FILE_READ|FILE_BIN);
      int size = (int)FileSize(file);
      string str = FileReadString(file,size);
      string arrFile[];
      StringSplit(str,'\n',arrFile);
      changeTotalTrades((int)arrFile[0]);
      changeProfit((double)arrFile[1]);
      changeLastTrade((int)arrFile[2]);
      FileClose(file);
   }
}

void GUI::save(void){
   string fileName = "Logs\\" + Name + ".txt";
   int file = FileOpen(fileName,FILE_WRITE|FILE_TXT);
   FileWrite(file,TotalTrades);
   FileWrite(file,Profit);
   FileWrite(file,LastTrade);
   FileClose(file);
}

void GUI::createText(string id,string text, int yPos){
   int fontSize = 8;
   int maxCaracteres = (int)((MAX_X_SIZE - 2 * MARGIN_X_SIZE)* UNIT / (fontSize)*1.5);
   string localText = text;
   int size = StringLen(text);
   int i = 0;
   while(size > 0){
      if(size > maxCaracteres){
         int localSize = -1;
         for(int j = maxCaracteres; j > 0 && localSize == -1; j--){
            if(StringGetCharacter(localText, j) == ' '){
               localSize = j;
            }
         }
         if(localSize != -1){
            string toWrite = StringSubstr(localText, 0, localSize);
            localText = StringSubstr(localText, localSize + 1, size - 1);
            size -= (localSize+1);
            createLabel(id + "_" + IntegerToString(i),toWrite,yPos + (15 * i));
         }
         else{
            string toWrite = StringSubstr(localText, 0, maxCaracteres);
            createLabel(id + "_" + IntegerToString(i),toWrite,yPos + (15 * i));
            size = 0;
         }
      }
      else{
         createLabel(id + "_" + IntegerToString(i),localText,yPos + (15 * i));
         size = 0;
      }
      i++;
   }
}
   
void GUI::createLabel(string id,string text, int yPos){
   ObjectCreate(0,id, OBJ_LABEL,0,0,0);
   ObjectSetText(id,text,0,"Cascadia Code Semilight");
   ObjectSetInteger(0,id,OBJPROP_COLOR,clrWhite);
   ObjectSetInteger(0,id,OBJPROP_FONTSIZE,8);
   ObjectSetInteger(0,id,OBJPROP_CORNER,0);
   ObjectSetInteger(0,id,OBJPROP_XDISTANCE,(int)(27*UNIT));
   ObjectSetInteger(0,id,OBJPROP_YDISTANCE,(int)(yPos*UNIT));
}

void GUI::createLine(string id,int yPos){
   ObjectCreate(0,id, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0,id,OBJPROP_CORNER,0);
   ObjectSetInteger(0,id,OBJPROP_BGCOLOR,0x2C2C2C);
   ObjectSetInteger(0,id,OBJPROP_XSIZE,(int)(270*UNIT));
   ObjectSetInteger(0,id,OBJPROP_YSIZE,(int)(1*UNIT));
   ObjectSetInteger(0,id,OBJPROP_XDISTANCE,(int)(25*UNIT));
   ObjectSetInteger(0,id,OBJPROP_YDISTANCE,(int)(yPos*UNIT));
   ObjectSetInteger(0,id,OBJPROP_HIDDEN,false);
   ObjectSetInteger(0,id,OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,id,OBJPROP_COLOR,White);
   ObjectSetInteger(0,id,OBJPROP_WIDTH,1);
}

string GUI::getMode(void){
   return Mode;
}

void GUI::changeMode(string newMode){
   Mode = newMode;
   ObjectSetText("Status","Status: " + Mode,0,"Cascadia Code Semilight");
}

int GUI::getTotalTrades(void){
   return TotalTrades;
}

void GUI::changeTotalTrades(int newValue){
   TotalTrades = newValue;
   ObjectSetText("TotalTradesValue",IntegerToString(TotalTrades),0,"Cascadia Code Semilight");
}

double GUI::getProfit(void){
   return Profit;
}

void GUI::changeProfit(double newValue){
   Profit = newValue;
   ObjectSetText("ProfitValue",DoubleToString(Profit,2),0,"Cascadia Code Semilight");
}

int GUI::getLastTrade(void){
   return LastTrade;
}

void GUI::changeLastTrade(int newValue){
   LastTrade = newValue;
   ObjectSetText("LastTradeID",IntegerToString(LastTrade),0,"Cascadia Code Semilight");
}
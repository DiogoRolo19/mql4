//+------------------------------------------------------------------+
//|                                                      DataSet.mqh |
//|                                                       Diogo Rolo |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Diogo Rolo"
#property link      "https://www.mql5.com"
#property strict

#include <NeuralNetwork/Enviroment.mqh>

class DataSet{
   private:
      int createFile(string name);
      void readHeader(string &header[],string fileName);
   public:
      DataSet();
      void create();
      void read(Data &data[],string fileName);
      int getSize(string fileName);
      int getImagesSize(string fileName);
      int getLabelsSize(string fileName);
};
DataSet::DataSet(void){}

void DataSet::create(void){
   int file = createFile("dataset");
   Data data[];
   ArrayResize(data,100);
   for(int i = 0; i < 100; i++){
      ArrayResize(data[i].inputs,5);
      for(int j = 0; j < 5; j++)
         data[i].inputs[j] = Random();
      if(Random() < 0.4){
         data[i].inputs[0] = Random()* 0.5 + 0.5;
         data[i].inputs[1] = Random()* 0.3;
         data[i].inputs[2] = Random() * 0.3 + 0.7;
      }
         
      data[i].label = data[i].inputs[0] > 0.5 && data[i].inputs[1] < 0.3 && data[i].inputs[2] > 0.7 ? 1:0;
   }
   
   
   FileWrite(file,"Size,Images,Labels");
   FileWrite(file,100,",",5,",",1);
   for(int i = 0; i < 100; i++){
      FileWrite(file,data[i].inputs[0],",",data[i].inputs[1],",",data[i].inputs[2],",",data[i].inputs[3],",",data[i].inputs[4],",",data[i].label);
   }
}

int DataSet::createFile(string name){
   int counter = 0;
   string fileName;
   do{
      counter++;
      fileName = "DataSets\\"+ name + IntegerToString(counter) + ".txt";
   }
   while (FileIsExist(fileName));
   return FileOpen(fileName,FILE_WRITE|FILE_TXT);
}

void DataSet::read(Data &data[],string fileName){
   int file = FileOpen("DataSets\\" + fileName + ".txt",FILE_READ);
   FileReadString(file,110);
   string head = FileReadString(file,110);
   string header[];
   ArrayResize(header,3);
   StringSplit(head,',',header);
   for(int l = 0; l < (int)StringToInteger(header[0]); l++){
      string line = FileReadString(file,110);
      string lineData[];
      ArrayResize(lineData,(int)StringToInteger(header[1]) + (int)StringToInteger(header[2]));
      StringSplit(line,',',lineData);
      ArrayResize(data[l].inputs,(int)StringToInteger(header[1]));
      for(int i = 0; i < (int)StringToInteger(header[1]); i++)
         data[l].inputs[i] = StringToDouble(lineData[i]);
      data[l].label = StringToDouble(lineData[(int)StringToInteger(header[1])]);
   }
   FileClose(file);
}

void DataSet::readHeader(string &header[],string fileName){
   int file = FileOpen("DataSets\\" + fileName + ".txt",FILE_READ);
   FileReadString(file,110);
   string head = FileReadString(file,110);
   StringSplit(head,',',header);
   FileClose(file);
}

int DataSet::getImagesSize(string fileName){
   string header[];
   ArrayResize(header,3);
   readHeader(header,fileName);
   return (int)StringToInteger(header[1]);
}

int DataSet::getLabelsSize(string fileName){
   string header[];
   ArrayResize(header,3);
   readHeader(header,fileName);
   return (int)StringToInteger(header[2]);
}

int DataSet::getSize(string fileName){
   string header[];
   ArrayResize(header,3);
   readHeader(header,fileName);
   return (int)StringToInteger(header[0]);
}
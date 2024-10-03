//+------------------------------------------------------------------+
//|                                                      Trainer.mqh |
//|                                                       Diogo Rolo |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Diogo Rolo"
#property link      ""
#property strict
#include <NeuralNetwork/NeuralNetwork.mqh>

const int MAX_AGE = 15;

struct Individual{
   NeuralNetwork network;
   double fitness;
   int age;
};

struct Data{
   double inputs[];
   double label;
};

class Enviroment{
   private:
      Individual population[];
      int populationSize;
      Data trainingData[];
      Data validationData[];
      int trainingDataSize;
      int validationDataSize;
      void sort();
      int findPos(Individual &element, Individual &array[], int arraySize);
      void insertPos(Individual &element,int pos, Individual &array[], int arraySize);
      void selection(double &comulativeProbability[], int size);
      void select(int &fathers[], double &comulativeProbability[], int size);
      void replace(int pos, double &comulativeProbability[], int survivors, double mutationRate);
      double calculateAccuracy(Data &data[], int dataSize, NeuralNetwork &network) const;
   public:
      Enviroment();
      NeuralNetwork train(int pGenerations,int pPopulationSize,Data &pData[], int pDataSize, double survivenceRate, double mutatuonRate, int terminationRepetitions, double validationRate);
      double getFitness(NeuralNetwork &network);
};

Enviroment::Enviroment(void){}

NeuralNetwork Enviroment::train(int generations, int pPopulationSize,Data &pData[], int pDataSize, double survivenceRate, double mutationRate, int terminationRepetitions, double validationRate){
   trainingDataSize = (int)MathRound(pDataSize* (1-validationRate));
   validationDataSize = pDataSize - trainingDataSize;
   ArrayResize(trainingData,trainingDataSize);
   for(int i = 0; i < trainingDataSize;i++)
      trainingData[i] = pData[i];
   ArrayResize(validationData,validationDataSize);
   for(int i = 0; i < validationDataSize;i++)
      validationData[i] = pData[i+trainingDataSize];
   populationSize = pPopulationSize;
   int survivors = (int)MathRound(survivenceRate * populationSize);

   //create population
   ArrayResize(population,populationSize);
   for(int i = 0; i < populationSize;i++){
      int inputsPerlayer[] = {5,3,2,1};
      population[i].network = NeuralNetwork(2,inputsPerlayer,RELU,SIGMOID);
      population[i].fitness = getFitness(population[i].network);
      population[i].age = 0;
   }
   sort();
   Individual bestIndividual = population[0];
   double trainingAccuracy = calculateAccuracy(trainingData,trainingDataSize,population[0].network);
   double validationAccuracy = calculateAccuracy(validationData,validationDataSize,population[0].network);
   Print("Generation 0, best fitness ",bestIndividual.fitness,", Training Accuracy ", DoubleToStr(trainingAccuracy*100,0), "%, Validation Accuracy", DoubleToStr(validationAccuracy*100,0),"%");
   
   int repeatedFitness = 0;
   //Evolving
   for(int g = 1; g <= generations && repeatedFitness < terminationRepetitions; g++){
      Print("----------Starting Generation " ,g, "----------");
      double comulativeProbability[];
      ArrayResize(comulativeProbability,survivors);
      selection(comulativeProbability,survivors);
      for(int i = survivors; i < populationSize;i++){
         replace(i,comulativeProbability,survivors,mutationRate);
      }
      for(int i = 0; i < survivors;i++){
         if(population[i].age >= MAX_AGE)
            replace(i,comulativeProbability,survivors,mutationRate);
      }
      sort();
      
      if(bestIndividual.fitness >= population[0].fitness)
         repeatedFitness++;
      else{
         bestIndividual = population[0];
         repeatedFitness = 0;
      }
      trainingAccuracy = calculateAccuracy(trainingData,trainingDataSize,population[0].network);
      validationAccuracy = calculateAccuracy(validationData,validationDataSize,population[0].network);
      Print("Generation ",g,", best fitness ",bestIndividual.fitness,", Training Accuracy ", DoubleToStr(trainingAccuracy*100,0), "%, Validation Accuracy", DoubleToStr(validationAccuracy*100,0),"%");
   }
   
   return NeuralNetwork();
}

double Enviroment::getFitness(NeuralNetwork &network){
   double fitness = 0;
   for(int i = 0; i < trainingDataSize; i++){
      DoubleArray inputs = DoubleArray(5,trainingData[i].inputs);
      fitness -= MathAbs(network.predict(inputs).array[0] - trainingData[i].label);
   }
   return fitness;
}

void Enviroment::sort(void){
   Individual sortedPopulation[];
   ArrayResize(sortedPopulation,populationSize);
   sortedPopulation[0] = population[0];
   for(int i = 1; i < populationSize; i++){
      int pos = findPos(population[i],sortedPopulation,i);
      insertPos(population[i],pos,sortedPopulation,i);
   }
   for(int i = 0; i < populationSize; i++)
      population[i] = sortedPopulation[i];
}

int Enviroment::findPos(Individual &element,Individual &array[], int arraySize){
   int pos = -1;
   bool find = false;
   for(int i = 0; i < arraySize && !find;i++){
      if(element.fitness > array[i].fitness){
         pos = i;
         find = true;
      }
   }
   if(!find)
      pos = arraySize;
   return pos;
}

void Enviroment::insertPos(Individual &element,int pos,Individual &array[],int arraySize){
   for(int i = arraySize; i > pos; i--){
      array[i] = array[i-1];
   }
   array[pos] = element;
}

void Enviroment::selection(double &comulativeProbability[],int size){
   double sum = 0;
   for(int i = 0; i < size; i++)
      sum += MathPow(NEPER,population[i].fitness);
   comulativeProbability[0] = MathPow(NEPER,population[0].fitness)/sum;
   for(int i = 1; i < size; i++){
      comulativeProbability[i] = MathPow(NEPER,population[i].fitness)/sum + comulativeProbability[i-1];
   }
}

void Enviroment::select(int &fathers[],double &comulativeProbability[],int size){
   for(int k = 0; k < 2; k++){
      double random = Random();
      bool find = false;
      for(int i = 0; i < size && !find; i++){
         if(random <= comulativeProbability[i]){
            fathers[k] = i;
            find = true;
         }
      }
   }
   if(fathers[0] == fathers[1])
      fathers[1] = fathers[0]==0 ? 1 : 0;
}

void Enviroment::replace(int pos, double &comulativeProbability[], int survivors, double mutationRate){
   int fathers[2];
   select(fathers,comulativeProbability,survivors);         
   population[pos].network = NeuralNetwork(population[fathers[0]].network);
   population[pos].network.reprodution(population[fathers[1]].network);
   population[pos].network.mutation(mutationRate);
   population[pos].fitness = getFitness(population[pos].network); 
   population[pos].age = 0;
}

double Enviroment::calculateAccuracy(Data &data[],int dataSize,NeuralNetwork &network) const{
   int match = 0;
   for(int i = 0; i < dataSize; i++){
      double output = network.predict(DoubleArray(5,data[i].inputs)).array[0];
      if((int)MathRound(output) == data[i].label)
         match++;
   }
   return match * 1.0 / dataSize;
}
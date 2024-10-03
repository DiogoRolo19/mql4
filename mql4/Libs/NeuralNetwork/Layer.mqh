//+------------------------------------------------------------------+
//|                                                        Layer.mqh |
//|                                                       Diogo Rolo |
//+------------------------------------------------------------------+
#property copyright "Diogo Rolo"
#property strict
#include <NeuralNetwork/Neuron.mqh>
#include <Lists/DoubleArray.mqh>

class Layer{
   private:
      Neuron neurons[];
      int neuronsNumber;
      int inputsNumber;
      
   public:
      Layer();
      Layer(const Layer &layer);
      Layer(int pInputsNumber,int pOutputNumber,ACTIVATION_FUNCTIONS activationFunction);
      DoubleArray predict(DoubleArray &inputs);
      int getInputsNumber() const;
      int getNeuronsNumber() const;
      Neuron getNeuron(int pos) const;
      int getWeightSize() const;
      void changeWeight(int neuron,int weight, double newValue);
      void randomWeight(int neuron,int weight);
};

Layer::Layer(void){
   neuronsNumber = 0;
}

Layer::Layer(const Layer &layer){
   neuronsNumber = layer.getNeuronsNumber();
   inputsNumber = layer.getInputsNumber();
   ArrayResize(neurons,neuronsNumber);
   for(int i = 0; i < neuronsNumber;i++){
      neurons[i] = layer.getNeuron(i);
   }
}

Layer::Layer(int pInputsNumber,int pOutputNumber,ACTIVATION_FUNCTIONS activationFunction){
   inputsNumber = pInputsNumber;
   neuronsNumber = pOutputNumber;
   ArrayResize(neurons,pOutputNumber);
   for(int i =0; i < neuronsNumber;i++)
      neurons[i] = Neuron(inputsNumber,activationFunction);
}

DoubleArray Layer::predict(DoubleArray &inputs){
   DoubleArray prediction = DoubleArray(inputsNumber);
   for(int i = 0; i < neuronsNumber; i++)
      prediction.array[i] = neurons[i].predict(inputs);
   prediction.size = neuronsNumber;
   return prediction;
}

int Layer::getInputsNumber(void) const{
   return inputsNumber;
}

int Layer::getNeuronsNumber(void) const{
   return neuronsNumber;
}

Neuron Layer::getNeuron(int pos) const{
   if(pos < neuronsNumber && pos >= 0)
      return neurons[pos];
   else
      return Neuron();
}

int Layer::getWeightSize() const{
   int weights = 0;
   for(int i = 0; i < neuronsNumber; i++){
      weights += neurons[i].getWeightSize();
   }
   return weights;
}

void Layer::changeWeight(int neuron,int weight,double newValue){
   neurons[neuron].changeWeight(weight,newValue);
}

void Layer::randomWeight(int neuron,int weight){
   neurons[neuron].randomWeight(weight);
}
//+------------------------------------------------------------------+
//|                                                neuralNetwork.mqh |
//|                                                       Diogo Rolo |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Diogo Rolo"
#property link      ""
#property strict
#include <NeuralNetwork/Layer.mqh>
#include <Lists/DoubleArray.mqh>

#define TAXA_APRENDIZADO    (0.1)
#define TAXA_PESO_INICIAL   (1.0)

class NeuralNetwork{
   private:
      Layer layers[];
      int layersSize;
      ACTIVATION_FUNCTIONS outputActivation;
      DoubleArray activateOutput(DoubleArray &outputs);
      bool exists(int value,int &array[],int size);
      void changeWeight(int layer,int neuron,int weight, double newValue);
      void randomWeight(int layer,int neuron,int weight);
   
   public:
      NeuralNetwork();
      NeuralNetwork(const NeuralNetwork &network);
      NeuralNetwork(int pLayersNumber, int &inputsPerlayer[], ACTIVATION_FUNCTIONS hiddenActivations, ACTIVATION_FUNCTIONS outputActivations);
      DoubleArray predict(DoubleArray &inputs);
      Layer getLayer(int pos) const;
      int getLayerSize() const;
      ACTIVATION_FUNCTIONS getOutputActivation() const;
      int getWeightSize() const;
      void print();
      string summary();
      void reprodution(const NeuralNetwork &father);
      void mutation(double mutationRate);
};

NeuralNetwork::NeuralNetwork(void){
   layersSize = 0;
}
NeuralNetwork::NeuralNetwork(const NeuralNetwork &network){
   layersSize = network.getLayerSize();
   ArrayResize(layers,layersSize);
   for(int i = 0; i< layersSize;i++){
      layers[i] = network.getLayer(i);
   }
   outputActivation = network.getOutputActivation();
}



NeuralNetwork::NeuralNetwork(int pHidenLayers,int &inputsPerLayer[],ACTIVATION_FUNCTIONS hiddenActivations, ACTIVATION_FUNCTIONS pOutputActivation){
   ArrayResize(layers,pHidenLayers+1);
   layersSize = pHidenLayers+1;
   for(int i = 0;i<pHidenLayers;i++){
      layers[i] = Layer(inputsPerLayer[i],inputsPerLayer[i+1],hiddenActivations);
   }
   layers[pHidenLayers] = Layer(inputsPerLayer[pHidenLayers],inputsPerLayer[pHidenLayers+1],LINEAR);
   outputActivation = pOutputActivation;
}

DoubleArray NeuralNetwork::predict(DoubleArray &inputs){
   if(inputs.size != layers[0].getInputsNumber())
      return DoubleArray();
   DoubleArray actualInputs = DoubleArray(inputs.size,inputs.array);
   for(int i = 0; i < layersSize; i++){
      actualInputs = layers[i].predict(actualInputs);
      actualInputs.size = layers[i].getNeuronsNumber();
   }
   return activateOutput(actualInputs);
}

DoubleArray NeuralNetwork::activateOutput(DoubleArray &outputs){
   switch(outputActivation){
      case LINEAR:
         break;
      case STEP:
         for(int i=0; i<outputs.size;i++)
            outputs.array[i] = outputs.array[i]>0 ? 1 : 0;
         break;
      case SIGMOID:
         for(int i=0; i<outputs.size;i++){
            double value = outputs.array[i];
            outputs.array[i] = 1/(1 + MathPow(NEPER,-value));
         }
         break;
      case HYPERBOLIC_TANGENT:
         for(int i=0; i<outputs.size;i++){
            double value = outputs.array[i];
            outputs.array[i] = (MathPow(NEPER,value)-MathPow(NEPER,-value))/(MathPow(NEPER,value)+MathPow(NEPER,-value));
         }
         break;
      case SILU:
         for(int i=0; i<outputs.size;i++){
            double value = outputs.array[i];
            outputs.array[i] = value * 1/(1 + MathPow(NEPER,-value));
         }
         break;
      default:
      case RELU:
         for(int i=0; i<outputs.size;i++){
            double value = outputs.array[i];
            outputs.array[i] = MathMax(0,value);
         }
         break;
   }
   return outputs;
}

Layer NeuralNetwork::getLayer(int pos) const{
   if(pos < layersSize && pos >= 0)
      return layers[pos];
   else
      return Layer();
}

int NeuralNetwork::getLayerSize(void) const{
   return layersSize;
}

ACTIVATION_FUNCTIONS NeuralNetwork::getOutputActivation(void) const{
   return outputActivation;
}

int NeuralNetwork::getWeightSize(void) const{
   int weights = 0;
   for(int i = 0; i < layersSize; i++){
      weights += layers[i].getWeightSize();
   }
   return weights;
}

void NeuralNetwork::print(void){
   for(int l = 0; l < layersSize; l++){
      Print("Layer number ",l,", with ",layers[l].getNeuronsNumber()," neurons");
         for(int n = 0; n < layers[l].getNeuronsNumber(); n++){
            Print("Neuron number ",n,", with ",layers[l].getNeuron(n).getWeightSize()," weights");
            for(int w = 0; w < layers[l].getNeuron(n).getWeightSize(); w++){
               Print("Weight number ",w,", with weight ",layers[l].getNeuron(n).getWeight(w));
         }
      }
   }
}

string NeuralNetwork::summary(void){
   string toPrint = "";
   for(int l = 0; l < layersSize; l++){
      toPrint += "[";
      for(int n = 0; n < layers[l].getNeuronsNumber(); n++){
         toPrint += "[";
         for(int w = 0; w < layers[l].getNeuron(n).getWeightSize(); w++){
            toPrint += DoubleToStr(layers[l].getNeuron(n).getWeight(w),4);
            if( w != layers[l].getNeuron(n).getWeightSize()-1)
               toPrint += ";";
         }
         toPrint += "]";
      }
      toPrint += "]";
   }
   return toPrint;
}

void NeuralNetwork::changeWeight(int layer,int neuron,int weight,double newValue){
   layers[layer].changeWeight(neuron,weight,newValue);
}

void NeuralNetwork::randomWeight(int layer,int neuron,int weight){
   layers[layer].randomWeight(neuron,weight);
}

void NeuralNetwork::reprodution(const NeuralNetwork &father){ //to use inicialize the network with the mother weights
   if(Random()> 0.5){
      //Whole Arithmetic Recombination
      double alpha = Random();
      for(int l = 0; l < getLayerSize(); l++){
         for(int n = 0; n < layers[l].getNeuronsNumber(); n++){
            for(int w = 0; w < layers[l].getNeuron(n).getWeightSize(); w++){
               double fatherWeight = father.getLayer(l).getNeuron(n).getWeight(w);
               double motherWeight = layers[l].getNeuron(n).getWeight(w);
               double newWeight = alpha * fatherWeight + (1-alpha) * motherWeight;
               changeWeight(l,n,w,newWeight);
            }
         }
      }
   }
   else{
      // Uniform Crossover thecnique
      int weighsSize = getWeightSize();
      int nWeightsFromFather = IntRandom(weighsSize + 1 );
      if(nWeightsFromFather > 0){
         int weightsToChange[];
         UniqueRandom(weightsToChange,nWeightsFromFather,weighsSize);
         int neuronID = -1;
         for(int l = 0; l < getLayerSize(); l++){
            for(int n = 0; n < layers[l].getNeuronsNumber(); n++){
               for(int w = 0; w < layers[l].getNeuron(n).getWeightSize(); w++){
                  neuronID++;
                  if(exists(neuronID,weightsToChange,nWeightsFromFather)){
                     double fatherWeight = father.getLayer(l).getNeuron(n).getWeight(w);
                     changeWeight(l,n,w,fatherWeight);
                  }
               }
            }
         }
      }
   }
}

bool NeuralNetwork::exists(int value,int &array[],int size){
   bool find = false;
   for(int i = 0; i < size && !find; i++){
      if(value == array[i])
         find = true;
   }
   return find;
}

void NeuralNetwork::mutation(double mutationRate){
   int weighsSize = getWeightSize();
   for(int l = 0; l < getLayerSize(); l++){
      for(int n = 0; n < layers[l].getNeuronsNumber(); n++){
         for(int w = 0; w < layers[l].getNeuron(n).getWeightSize(); w++){
            if(mutationRate/weighsSize >= Random()){
               if(Random()<0.5)
                  randomWeight(l,n,w);
               else{
                  int l2 = IntRandom(getLayerSize());
                  int n2 = IntRandom(layers[l2].getNeuronsNumber());
                  int w2 = IntRandom(layers[l2].getNeuron(n2).getWeightSize());
                  double weight1 = getLayer(l).getNeuron(n).getWeight(w);
                  double weight2 = getLayer(l2).getNeuron(n2).getWeight(w2);
                  changeWeight(l,n,w,weight2);
                  changeWeight(l2,n2,w2,weight1);
               }
            }
         }
      }
   }
}
//+------------------------------------------------------------------+
//|                                                       Neuron.mqh |
//|                                                       Diogo Rolo |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Diogo Rolo"
#property link      ""
#property strict
#include <Lists/DoubleArray.mqh>
#include <Math.mqh>


enum ACTIVATION_FUNCTIONS{
   LINEAR = 0,
   STEP = 1,
   SIGMOID = 2,
   HYPERBOLIC_TANGENT=3,
   SILU = 4,
   RELU = 5
};

class Neuron{
   private:
      double weights[];
      double bias;
      int inputsNumber;
      ACTIVATION_FUNCTIONS activationFunction;
      double activate(double value);
      void initializeWeights(void);
   
   public:
      Neuron();
      Neuron(const Neuron &neuron);
      Neuron(int inputsSize,ACTIVATION_FUNCTIONS pActivationFunction);
      double predict(DoubleArray &inputs);
      void changeWeights(double &newWeights[]);
      void changeWeight(int pos,double newWeight);
      void changeBias(double newBias);
      double getWeight(int pos) const;
      double getBias() const;
      int getWeightSize() const;
      ACTIVATION_FUNCTIONS getActivationFunction() const;
      void randomWeight(int pos);
      
};

Neuron::Neuron(void){
   
}

Neuron::Neuron(const Neuron &neuron){
   bias = neuron.getBias();
   inputsNumber = neuron.getWeightSize();
   activationFunction = neuron.getActivationFunction();
   ArrayResize(weights,inputsNumber);
   for(int i = 0; i<inputsNumber;i++){
      weights[i] = neuron.getWeight(i);
   }
}

Neuron::Neuron(int pInputsNumber,ACTIVATION_FUNCTIONS pActivationFunction){
   inputsNumber = pInputsNumber;
   activationFunction = pActivationFunction;
   ArrayResize(weights,inputsNumber);
   initializeWeights();
   bias = 0;
}

double Neuron::predict(DoubleArray &inputs){
   if(inputs.size != inputsNumber)
      return -1;
   double total = 0;
   for(int i = 0 ; i < inputs.size; i++)
      total += inputs.array[i] * weights [i];
   total += bias;
   total = activate(total);
   return total;
}

void Neuron::changeWeights(double &newWeights[]){
   for(int i = 0; i < inputsNumber;i++)
      weights[i] = newWeights[i];
}

void Neuron::changeWeight(int pos, double newWeight){
   weights[pos] = newWeight;
}

void Neuron::changeBias(double newBias){
   bias = newBias;
}

double Neuron::activate(double value){
   switch(activationFunction){
      case LINEAR:
         return value;
      case STEP:
         return value>0 ? 1 : 0;
      case SIGMOID:
         return 1/(1 + MathPow(NEPER,-value));
      case HYPERBOLIC_TANGENT:
         return (MathPow(NEPER,value)-MathPow(NEPER,-value))/(MathPow(NEPER,value)+MathPow(NEPER,-value));
      case SILU:
         return value * 1/(1 + MathPow(NEPER,-value));
      default:
      case RELU:
         return MathMax(0,value);
   }
}

void Neuron::initializeWeights(void){
   for(int i = 0; i< inputsNumber; i++)
      randomWeight(i);
}

void Neuron::randomWeight(int pos){
   double upBoundory;
   switch(activationFunction){
      case LINEAR:
      case STEP:
      case SIGMOID:
      case HYPERBOLIC_TANGENT:
         upBoundory = 1/MathSqrt(inputsNumber);
         weights[pos] = Random()*upBoundory * 2 - 1; // between -1/sqrt(inputs) and 1/sqrt(inputs)
         break;
      case SILU:
      default:
      case RELU:
         upBoundory = MathSqrt(2.0/inputsNumber);
         weights[pos] = Random()*upBoundory; // between 0 and sqrt(2/inputs)
         break;
   }
}

ACTIVATION_FUNCTIONS Neuron::getActivationFunction(void) const{
   return activationFunction;
}

double Neuron::getBias(void) const{
   return bias;
}

int Neuron::getWeightSize(void) const{
   return inputsNumber;
}

double Neuron::getWeight(int pos) const{
   return weights[pos];
}

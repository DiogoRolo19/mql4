import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from sklearn.model_selection import train_test_split
from sklearn.svm import LinearSVC, SVC
from sklearn.metrics import accuracy_score
from sklearn.preprocessing import StandardScaler
from sklearn.tree import DecisionTreeClassifier
from sklearn.ensemble import RandomForestClassifier
from tensorflow import keras
from keras.models import Sequential
from keras.layers import LSTM, Dense, Dropout
from keras.optimizers import Adam
from keras.callbacks import EarlyStopping, ModelCheckpoint
import time
from random import randint
import glob
import os

# Create results directory if it doesn't exist
os.makedirs("results_ml", exist_ok=True)

# Directory containing the CSV files
directory = "StrategiesData/"

# Use glob to find all CSV files in the directory
csv_files = glob.glob(f"{directory}/*.csv")

def write_to_file(file, content):
    print(content)
    with open(file, 'a') as f:
        f.write(content + '\n')

# Loop over each CSV file
for file_name in csv_files:#{'StrategiesData\\Bollinger bands_Summary.csv'}:
    # Create a result file for this CSV
    result_file = f"results/{os.path.basename(file_name).replace('.csv', '_results.txt')}"
    
    # Clear the file if it already exists
    open(result_file, 'w').close()

    write_to_file(result_file, f"Handling data {file_name}")

    df = pd.read_csv(file_name, delimiter=';')
    df['BinaryProfit'] = df['Profit Percentage'].apply(lambda x: 1 if x > 0 else 0)
    write_to_file(result_file, f"Sum of Profit Percentage: {df.sum()['Profit Percentage']}")

    X = df[['Price_30','Price_29','Price_28','Price_27','Price_26']]
    Y = df['BinaryProfit']
    YWithProfit = df[['BinaryProfit', 'Profit Percentage']]

    X_Normalized = pd.DataFrame({
        'Price_30': df['Price_30']/ df['Price_29']-1,
        'Price_29': df['Price_29']/ df['Price_28']-1,
        'Price_28': df['Price_28']/ df['Price_27']-1,
        'Price_27': df['Price_27']/ df['Price_26']-1,
        'Price_26': df['Price_26']/ df['Price_25']-1
    })

    write_to_file(result_file, "X head:")
    write_to_file(result_file, X.head().to_string())
    write_to_file(result_file, "X_Normalized head:")
    write_to_file(result_file, X_Normalized.head().to_string())
    write_to_file(result_file, "YWithProfit head:")
    write_to_file(result_file, YWithProfit.head().to_string())

    def getResults():
        predictions_df = pd.DataFrame({
            'Predictions': predict,
            'Profit Percentage': Y_test['Profit Percentage'],
            'BinaryProfit': Y_test['BinaryProfit']
        })
        predictions_df['profictPredictions'] = predictions_df['Predictions'] * predictions_df['Profit Percentage']
        return predictions_df.sum()['Predictions'], predictions_df.sum()[['Profit Percentage','profictPredictions']]

    def writeResults():
        nPred, profit = getResults()
        write_to_file(result_file, f"Number of predictions: {nPred}")
        write_to_file(result_file, f"Profit original vs profit model: {profit['Profit Percentage']:.2f}% vs {profit['profictPredictions']:.2f}%")

    random_state_value = 23

    X_train, X_test, Y_train, Y_test = train_test_split(X, YWithProfit, test_size=0.25, stratify=YWithProfit['BinaryProfit'], random_state=random_state_value)
    X_trainN, X_testN, Y_trainN, Y_testN = train_test_split(X_Normalized, YWithProfit, test_size=0.25, stratify=YWithProfit['BinaryProfit'], random_state=random_state_value)

    scaler = StandardScaler()
    scaler.fit(X_train)
    X_train_scaler = scaler.transform(X_train)
    X_test_scaler = scaler.transform(X_test)

    scaler = StandardScaler()
    scaler.fit(X_trainN)
    X_train_scalerN = scaler.transform(X_trainN)
    X_test_scalerN = scaler.transform(X_testN)
    
    # LinearSVC
    write_to_file(result_file, "LinearSVC")

    model = LinearSVC()
    model.fit(X_train, Y_train['BinaryProfit'])
    predict = model.predict(X_test)
    accuracy = accuracy_score(Y_test['BinaryProfit'], predict) * 100
    write_to_file(result_file, f"Accuracy: {accuracy:.2f}%")

    writeResults()

    # LinearSVC Scalar
    write_to_file(result_file, "LinearSVC Scalar")

    model = LinearSVC()
    model.fit(X_trainN, Y_trainN['BinaryProfit'])
    predict = model.predict(X_test_scalerN)
    accuracy = accuracy_score(Y_testN['BinaryProfit'], predict) * 100
    write_to_file(result_file, f"Accuracy: {accuracy:.2f}%")

    writeResults()

    # SVC
    write_to_file(result_file, "SVC")

    model = SVC(gamma='auto')
    model.fit(X_train, Y_train['BinaryProfit'])
    predict = model.predict(X_test)
    accuracy = accuracy_score(Y_test['BinaryProfit'], predict) * 100
    write_to_file(result_file, f"Accuracy: {accuracy:.2f}%")

    writeResults()

    # SVC Scalar
    write_to_file(result_file, "SVC Scalar")

    model = SVC(gamma='auto')
    model.fit(X_trainN, Y_trainN['BinaryProfit'])
    predict = model.predict(X_testN)
    accuracy = accuracy_score(Y_testN['BinaryProfit'], predict) * 100
    write_to_file(result_file, f"Accuracy: {accuracy:.2f}%")

    writeResults()
    
    # Decision Tree
    write_to_file(result_file, "Decision Tree")

    modelo = DecisionTreeClassifier(max_depth=55, min_samples_leaf=128, min_samples_split=64, criterion='gini')
    modelo.fit(X_train, Y_train['BinaryProfit'])
    predict = modelo.predict(X_test)

    acuracia = accuracy_score(Y_test['BinaryProfit'], predict) * 100
    write_to_file(result_file, f"Accuracy: {acuracia:.2f}%")

    writeResults()

    # Decision Tree Scalar
    write_to_file(result_file, "Decision Tree Scalar")

    modelo = DecisionTreeClassifier(max_depth=55, min_samples_leaf=128, min_samples_split=64, criterion='gini')
    modelo.fit(X_trainN, Y_trainN['BinaryProfit'])
    predict = modelo.predict(X_test_scalerN)

    acuracia = accuracy_score(Y_testN['BinaryProfit'], predict) * 100
    write_to_file(result_file, f"Accuracy: {acuracia:.2f}%")

    writeResults()
    
    '''
    write_to_file(result_file, "Hyperparameters v1")

    tic = time.time()
    resultados = []
    for criterion in ["gini", "entropy"]:
        for max_depth in range(5, 105, 10):
            for min_samples_leaf in [32, 64, 128, 256]:
                for min_samples_split in [32, 64, 128, 256]:
                    modelo = DecisionTreeClassifier(max_depth=max_depth, min_samples_leaf=min_samples_leaf, min_samples_split=min_samples_split, criterion=criterion)
                    modelo.fit(X_train_scaler, Y_train['BinaryProfit'])
                    predict = modelo.predict(X_test_scaler)
                    nPred, profit = getResults()
                    ratio = profit['profictPredictions'] / profit['Profit Percentage']
                    resultados.append({
                        'criterion': criterion,
                        'max_depth': max_depth,
                        'min_samples_leaf': min_samples_leaf,
                        'min_samples_split': min_samples_split,
                        'nPred': nPred,
                        'Profit Percentage': profit['Profit Percentage'],
                        'profictPredictions': profit['profictPredictions'],
                        'ratio': ratio,
                        'predict': predict
                    })
    
    tac = time.time()
    run_time = tac - tic
    write_to_file(result_file, f"Runtime: {run_time:.2f} seconds")

    resultados_df = pd.DataFrame(resultados)
    resultados_df.sort_values("ratio", ascending=False, inplace=True)
    print(resultados_df)
    best_result = resultados_df.iloc[0]
    predict = best_result['predict']

    writeResults()
    '''


    # Random Forest
    write_to_file(result_file, "Random Forest")

    modelo = RandomForestClassifier(
            max_depth=65,
            min_samples_leaf=82,
            min_samples_split=186,
            criterion='entropy',
            bootstrap=False,
            n_estimators=41
        )

    modelo.fit(X_train, Y_train['BinaryProfit'])
    predict = modelo.predict(X_test)

    acuracia = accuracy_score(Y_test['BinaryProfit'], predict) * 100
    write_to_file(result_file, f"Accuracy: {acuracia:.2f}%")

    writeResults()

    # Random Forest Scallar
    write_to_file(result_file, "Random Forest Scalar")

    modelo = RandomForestClassifier(
            max_depth=65,
            min_samples_leaf=82,
            min_samples_split=186,
            criterion='entropy',
            bootstrap=False,
            n_estimators=41
        )

    modelo.fit(X_trainN, Y_trainN['BinaryProfit'])
    predict = modelo.predict(X_test_scalerN)

    acuracia = accuracy_score(Y_testN['BinaryProfit'], predict) * 100
    write_to_file(result_file, f"Accuracy: {acuracia:.2f}%")

    writeResults()
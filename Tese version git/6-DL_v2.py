import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
from tensorflow import keras
from keras.callbacks import EarlyStopping, ModelCheckpoint
import glob
import os
import gc

# Create results directory if it doesn't exist
os.makedirs("results_dl_v2", exist_ok=True)

# Directory containing the CSV files
directory = "StrategiesData/"

# Use glob to find all CSV files in the directory
csv_files = glob.glob(f"{directory}/*.csv")

def write_to_file(file, content):
    print(content)
    with open(file, 'a') as f:
        f.write(content + '\n')

def create_model(architecture, input_shape, profit_type):
    if architecture == "small":
        model = keras.Sequential([
            keras.Input(shape=input_shape),
            keras.layers.Dense(32, activation="relu"),
            keras.layers.BatchNormalization(),
            keras.layers.Dense(16, activation="relu"),
            keras.layers.BatchNormalization(),
            keras.layers.Dense(1, activation="linear" if profit_type == "raw" else "sigmoid")
        ])
    elif architecture == "medium":
        model = keras.Sequential([
            keras.Input(shape=input_shape),
            keras.layers.Dense(64, activation="relu"),
            keras.layers.BatchNormalization(),
            keras.layers.Dropout(0.3),
            keras.layers.Dense(32, activation="relu"),
            keras.layers.BatchNormalization(),
            keras.layers.Dropout(0.3),
            keras.layers.Dense(16, activation="relu"),
            keras.layers.BatchNormalization(),
            keras.layers.Dense(1, activation="linear" if profit_type == "raw"  else "sigmoid")
        ])
    elif architecture == "large":
        model = keras.Sequential([
            keras.Input(shape=input_shape),
            keras.layers.Dense(128, activation="relu"),
            keras.layers.BatchNormalization(),
            keras.layers.Dropout(0.3),
            keras.layers.Dense(64, activation="relu"),
            keras.layers.BatchNormalization(),
            keras.layers.Dropout(0.3),
            keras.layers.Dense(32, activation="relu"),
            keras.layers.BatchNormalization(),
            keras.layers.Dropout(0.3),
            keras.layers.Dense(16, activation="relu"),
            keras.layers.BatchNormalization(),
            keras.layers.Dense(1, activation="linear" if profit_type == "raw" else "sigmoid")
        ])
    else:  # biggest
        model = keras.Sequential([
            keras.Input(shape=input_shape),
            keras.layers.Dense(512, activation="relu"),
            keras.layers.BatchNormalization(),
            keras.layers.Dropout(0.3),
            keras.layers.Dense(256, activation="relu"),
            keras.layers.BatchNormalization(),
            keras.layers.Dropout(0.3),
            keras.layers.Dense(128, activation="relu"),
            keras.layers.BatchNormalization(),
            keras.layers.Dropout(0.3),
            keras.layers.Dense(64, activation="relu"),
            keras.layers.BatchNormalization(),
            keras.layers.Dropout(0.3),
            keras.layers.Dense(32, activation="relu"),
            keras.layers.BatchNormalization(),
            keras.layers.Dropout(0.3),
            keras.layers.Dense(16, activation="relu"),
            keras.layers.BatchNormalization(),
            keras.layers.Dense(1, activation="linear" if profit_type == "raw" else "sigmoid")
        ])
    return model

def run_model(X_train, X_test, Y_train, Y_test, profit_type, result_file, architecture, input_type, original_profit_test):
    write_to_file(result_file, f"\nStarting model training for {profit_type} profit, {architecture} architecture, {input_type} input")
    write_to_file(result_file, f"Training data shape: {X_train.shape}")
    write_to_file(result_file, f"Test data shape: {X_test.shape}")

    model = create_model(architecture, (X_train.shape[1],), profit_type)

    adam = keras.optimizers.Adam(learning_rate=0.0005)  # Further reduced learning rate

    early_stop = [
        keras.callbacks.EarlyStopping(monitor='val_loss', patience=100, restore_best_weights=True),
        keras.callbacks.ModelCheckpoint(filepath=f'melhor_modelo_{profit_type}_{architecture}_{input_type}.keras', monitor='val_loss', save_best_only=True)
    ]

    if profit_type == "raw":
        loss = 'mean_squared_error'
        metrics = ['mae']
    else:
        loss = 'binary_crossentropy'
        metrics = ['accuracy']

    model.compile(optimizer=adam, loss=loss, metrics=metrics)

    historico = model.fit(X_train, Y_train,
                           batch_size=64,
                           epochs=2000, validation_split=0.2,
                           callbacks=early_stop,
                           verbose=0)

    write_to_file(result_file, f"Training completed. Final loss: {historico.history['loss'][-1]:.4f}, Final val_loss: {historico.history['val_loss'][-1]:.4f}")
    write_to_file(result_file, f"Training accuracy: {historico.history['accuracy'][-1] if 'accuracy' in historico.history else historico.history['mae'][-1]:.4f}")
    write_to_file(result_file, f"Validation accuracy: {historico.history['val_accuracy'][-1] if 'val_accuracy' in historico.history else historico.history['val_mae'][-1]:.4f}")

    predict = model.predict(X_test)

    predictions_df = pd.DataFrame({
        'Predictions': predict.flatten(),
        'Actual': Y_test,
        'OriginalProfit': original_profit_test
    })

    write_to_file(result_file, f"Predictions summary:")
    write_to_file(result_file, f"Min prediction: {predictions_df['Predictions'].min():.4f}")
    write_to_file(result_file, f"Max prediction: {predictions_df['Predictions'].max():.4f}")
    write_to_file(result_file, f"Mean prediction: {predictions_df['Predictions'].mean():.4f}")
    write_to_file(result_file, f"Std deviation of predictions: {predictions_df['Predictions'].std():.4f}")
    write_to_file(result_file, f"Predictions > 0.5: {(predictions_df['Predictions'] > 0.5).sum()} out of {len(predictions_df)}")

    if profit_type == "binary":
        predictions_df['PredictedProfit'] = np.where(predictions_df['Predictions'] > 0.5, predictions_df['OriginalProfit'], 0)
    elif profit_type == "normalized":
        predictions_df['PredictedProfit'] = np.where(predictions_df['Predictions'] > 0.5, predictions_df['OriginalProfit'], 0)
    else:  # raw
        predictions_df['PredictedProfit'] = np.where(predictions_df['Predictions'] > 0, predictions_df['OriginalProfit'], 0)

    return predictions_df

def calculate_rsi(data, window=14):
    delta = data.diff()
    gain = (delta.where(delta > 0, 0)).rolling(window=window).mean()
    loss = (-delta.where(delta < 0, 0)).rolling(window=window).mean()
    rs = gain / loss
    return 100 - (100 / (1 + rs))

# Loop over each CSV file
for file_name in csv_files:
    result_file = f"results_dl_v2/{os.path.basename(file_name).replace('.csv', '_results.txt')}"
    open(result_file, 'w').close()

    write_to_file(result_file, f"Handling data {file_name}")

    df = pd.read_csv(file_name, delimiter=';')
    
    df['BinaryProfit'] = (df['Profit Percentage'] > 0).astype(int)

    scaler = StandardScaler()
    df['NormalizedProfit'] = scaler.fit_transform(df[['Profit Percentage']])

    write_to_file(result_file, f"Total Sum of Profit Percentage: {df['Profit Percentage'].sum()}")
    write_to_file(result_file, f"Positive Profit Percentage: {(df['Profit Percentage'] > 0).sum()} out of {len(df)}")

    X_raw = df[['Price_30','Price_29','Price_28','Price_27','Price_26']]
    X_raw_scaled = scaler.fit_transform(X_raw)

    X_relative = pd.DataFrame({
        'Price_30': df['Price_30']/ df['Price_29']-1,
        'Price_29': df['Price_29']/ df['Price_28']-1,
        'Price_28': df['Price_28']/ df['Price_27']-1,
        'Price_27': df['Price_27']/ df['Price_26']-1,
        'Price_26': df['Price_26']/ df['Price_25']-1
    })
    X_relative_scaled = scaler.fit_transform(X_relative)

    
    X_Technical = pd.DataFrame({
        'RSI': calculate_rsi(df['Price_30']),
        'MACD': df['Price_30'].ewm(span=12).mean() - df['Price_30'].ewm(span=26).mean(),
        'Price_30': df['Price_30'],
        'Price_29': df['Price_29'],
        'Price_28': df['Price_28']
    })
    X_Technical = X_Technical.dropna()  # Remove NaN values at the beginning

    X_Technical_v2 = pd.DataFrame({
        'RSI': calculate_rsi(df['Price_30']),
        'MACD': df['Price_30'].ewm(span=12).mean() - df['Price_30'].ewm(span=26).mean(),
        'Price_30': df['Price_30']/ df['Price_29']-1,
        'Price_29': df['Price_29']/ df['Price_28']-1,
        'Price_28': df['Price_28']/ df['Price_27']-1
    })
    X_Technical_v2 = X_Technical_v2.dropna()  # Remove NaN values at the beginning

    # Align all datasets to have the same number of samples
    min_samples = min(len(X_raw), len(X_relative), len(X_Technical), len(X_Technical_v2))
    X_raw = X_raw.iloc[-min_samples:]
    X_raw_scaled = X_raw_scaled[-min_samples:]
    X_relative = X_relative.iloc[-min_samples:]
    X_relative_scaled = X_relative_scaled[-min_samples:]
    X_Technical = X_Technical.iloc[-min_samples:]
    X_Technical_v2 = X_Technical_v2.iloc[-min_samples:]
    
    # Align target variables
    df = df.iloc[-min_samples:]

    write_to_file(result_file, "X_raw statistics:")
    write_to_file(result_file, X_raw.describe().to_string())
    write_to_file(result_file, "\nX_relative statistics:")
    write_to_file(result_file, X_relative.describe().to_string())

    random_state_value = 23

    architectures = ['small', 'medium', 'large', 'biggest']
    input_types = ['technical', 'technical_v2']
    profit_types = ['raw']

    for architecture in architectures:
        for input_type in input_types:
            X = X_raw_scaled if input_type == 'raw' else X_relative_scaled if input_type == 'relative' else X_Technical if input_type == 'technical' else X_Technical_v2

            for profit_type in profit_types:
                if profit_type == 'binary':
                    Y = df['BinaryProfit']
                elif profit_type == 'normalized':
                    Y = df['NormalizedProfit']
                else:  # raw
                    Y = df['Profit Percentage']

                X_train, X_test, Y_train, Y_test = train_test_split(X, Y, test_size=0.25, random_state=random_state_value, stratify=df['BinaryProfit'])
                
                _, original_profit_test = train_test_split(df['Profit Percentage'], test_size=0.25, random_state=random_state_value, stratify=df['BinaryProfit'])
                
                results = run_model(X_train, X_test, Y_train, Y_test, profit_type, result_file, architecture, input_type, original_profit_test)

                write_to_file(result_file, f"\nResults Summary ({architecture} architecture, {input_type} input, {profit_type} profit):")
                write_to_file(result_file, f"Original Profit Sum (Test Set): {results['OriginalProfit'].sum():.4f}")
                write_to_file(result_file, f"Predicted Profit Sum (Test Set): {results['PredictedProfit'].sum():.4f}")
                write_to_file(result_file, f"Difference: {results['PredictedProfit'].sum() - results['OriginalProfit'].sum():.4f}")

    gc.collect()
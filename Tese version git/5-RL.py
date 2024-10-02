import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler, KBinsDiscretizer
import time
import glob
import os
import pickle
from sklearn.preprocessing import StandardScaler

# Create results directory for RL if it doesn't exist
os.makedirs("results_rl", exist_ok=True)

# Directory containing the CSV files
directory = "StrategiesData/"

# Use glob to find all CSV files in the directory
csv_files = glob.glob(f"{directory}/*.csv")

def calculate_rsi(data, window=14):
    delta = data.diff()
    gain = (delta.where(delta > 0, 0)).rolling(window=window).mean()
    loss = (-delta.where(delta < 0, 0)).rolling(window=window).mean()
    rs = gain / loss
    return 100 - (100 / (1 + rs))

def write_to_file(file, content):
    print(content)
    with open(file, 'a') as f:
        f.write(content + '\n')

class TradingEnvironment:
    def __init__(self, data):
        self.data = data
        self.reset()
        
    def reset(self):
        self.current_step = 0
        return self._next_observation()
    
    def _next_observation(self):
        return self.data[self.current_step, :5]  # Return first 5 columns (price data)
    
    def step(self, action):
        self.current_step += 1
        done = self.current_step >= len(self.data)
        reward = self.data[self.current_step-1, 5] if action == 1 else 0  # Profit Percentage is in column 5
        next_obs = self._next_observation() if not done else None
        return next_obs, reward, done

class QLearningAgent:
    def __init__(self, action_space, obs_space, learning_rate=0.1, discount_factor=0.95, epsilon=0.1):
        self.action_space = action_space
        self.obs_space = obs_space
        self.learning_rate = learning_rate
        self.discount_factor = discount_factor
        self.epsilon = epsilon
        self.q_table = np.zeros(obs_space + (action_space,))
    
    def get_action(self, state):
        if np.random.random() < self.epsilon:
            return np.random.randint(self.action_space)
        else:
            return np.argmax(self.q_table[tuple(state)])
    
    def update_q_table(self, state, action, reward, next_state):
        current_q = self.q_table[tuple(state) + (action,)]
        next_max_q = np.max(self.q_table[tuple(next_state)]) if next_state is not None else 0
        new_q = current_q + self.learning_rate * (reward + self.discount_factor * next_max_q - current_q)
        self.q_table[tuple(state) + (action,)] = new_q

def run_rl_process(X, df, file_name, data_type):
    result_file = f"results_rl/{os.path.basename(file_name).replace('.csv', f'_results_rl_{data_type}.txt')}"
    
    # Clear the file if it already exists
    open(result_file, 'w').close()

    write_to_file(result_file, f"Handling data {file_name} with {data_type} data")
    
    # Check if we have any data to process
    if X.empty or df.empty:
        write_to_file(result_file, f"Skipping {file_name} with {data_type} data - No data available after preprocessing.")
        return  # Exit the function early

    # Ensure X and df have the same number of rows
    min_rows = min(len(X), len(df))
    X = X.iloc[:min_rows]
    df = df.iloc[:min_rows]

    write_to_file(result_file, f"Sum of Profit Percentage: {df.sum()['Profit Percentage']}")

    # Convert to numpy arrays
    data = np.column_stack((X.values, df['Profit Percentage'].values))

    # Split data into training and test sets
    train_data, test_data = train_test_split(data, test_size=0.25, stratify=df['BinaryProfit'], random_state=23)

    # Preprocess data: Discretize the state space
    n_bins = 10
    discretizer = KBinsDiscretizer(n_bins=n_bins, encode='ordinal', strategy='uniform')
    discretizer.fit(train_data[:, :5])  # Fit on price data columns of training data

    # Create training environment and agent
    train_env = TradingEnvironment(train_data)
    obs_space = (n_bins,) * 5  # 5 features, each discretized into n_bins
    action_space = 2  # 0: don't buy, 1: buy
    agent = QLearningAgent(action_space, obs_space)

    # Training loop
    n_episodes = 1000
    training_rewards = []
    tic = time.time()
    for episode in range(n_episodes):
        state = train_env.reset()
        state = discretizer.transform(state.reshape(1, -1))[0].astype(int)
        done = False
        total_reward = 0
        
        while not done:
            action = agent.get_action(state)
            next_state, reward, done = train_env.step(action)
            if not done:
                next_state = discretizer.transform(next_state.reshape(1, -1))[0].astype(int)
            agent.update_q_table(state, action, reward, next_state)
            state = next_state if not done else None
            total_reward += reward
        
        training_rewards.append(total_reward)
        if episode % 100 == 0:
            write_to_file(result_file, f"Episode {episode}, Total Reward: {total_reward}")
    
    tac = time.time()
    run_time = tac - tic
    write_to_file(result_file, f"Training Runtime: {run_time:.2f} seconds")

    # Evaluation on test data
    test_env = TradingEnvironment(test_data)
    state = test_env.reset()
    state = discretizer.transform(state.reshape(1, -1))[0].astype(int)
    done = False
    total_reward = 0
    actions = []
    buy_all_reward = 0

    while not done:
        action = agent.get_action(state)
        actions.append(action)
        next_state, reward, done = test_env.step(action)
        buy_all_reward += test_data[test_env.current_step - 1, 5]  # Accumulate reward if we always buy
        if not done:
            next_state = discretizer.transform(next_state.reshape(1, -1))[0].astype(int)
        state = next_state if not done else None
        total_reward += reward

    write_to_file(result_file, f"Total reward if buying all test data: {buy_all_reward:.2f}")
    write_to_file(result_file, f"Total reward predicted: {total_reward:.2f}")
    write_to_file(result_file, f"Buy Actions: {sum(actions)}, Don't Buy Actions: {len(actions) - sum(actions)}")

    # Plotting
    plt.figure(figsize=(10, 5))
    plt.plot(training_rewards)
    plt.title(f'Training Rewards over Episodes ({data_type} data)')
    plt.xlabel('Episode')
    plt.ylabel('Total Reward')
    plt.savefig(f"results_rl/{os.path.basename(file_name).replace('.csv', f'_training_rewards_{data_type}.png')}")
    plt.close()

    # Save the model
    model_data = {
        'agent': agent,
        'discretizer': discretizer,
        'train_data': train_data,
        'test_data': test_data
    }
    with open(f"results_rl/{os.path.basename(file_name).replace('.csv', f'_rl_model_{data_type}.pkl')}", 'wb') as f:
        pickle.dump(model_data, f)

    write_to_file(result_file, f"Model saved for {file_name} with {data_type} data")

# Loop over each CSV file
for file_name in csv_files:
    df = pd.read_csv(file_name, delimiter=';')
    df['BinaryProfit'] = df['Profit Percentage'].apply(lambda x: 1 if x > 0 else 0)

    
    X = df[['Price_30', 'Price_29', 'Price_28', 'Price_27', 'Price_26']]
    X_Normalized = pd.DataFrame({
        'Price_30': df['Price_30']/ df['Price_29']-1,
        'Price_29': df['Price_29']/ df['Price_28']-1,
        'Price_28': df['Price_28']/ df['Price_27']-1,
        'Price_27': df['Price_27']/ df['Price_26']-1,
        'Price_26': df['Price_26']/ df['Price_25']-1
    })

    X_Percentage_Change = pd.DataFrame({
        'Price_30': (df['Price_30'] - df['Price_29']) / df['Price_29'] * 100,
        'Price_29': (df['Price_29'] - df['Price_28']) / df['Price_28'] * 100,
        'Price_28': (df['Price_28'] - df['Price_27']) / df['Price_27'] * 100,
        'Price_27': (df['Price_27'] - df['Price_26']) / df['Price_26'] * 100,
        'Price_26': (df['Price_26'] - df['Price_25']) / df['Price_25'] * 100
    })

    X_Log_Returns = pd.DataFrame({
        'Price_30': np.log(df['Price_30'] / df['Price_29']),
        'Price_29': np.log(df['Price_29'] / df['Price_28']),
        'Price_28': np.log(df['Price_28'] / df['Price_27']),
        'Price_27': np.log(df['Price_27'] / df['Price_26']),
        'Price_26': np.log(df['Price_26'] / df['Price_25'])
    })

    X_Moving_Averages = pd.DataFrame({
        'MA_5': df['Price_30'].rolling(window=5).mean(),
        'MA_10': df['Price_30'].rolling(window=10).mean(),
        'MA_20': df['Price_30'].rolling(window=20).mean(),
        'MA_30': df['Price_30'].rolling(window=30).mean(),
        'Current_Price': df['Price_30']
    })
    # Instead of dropping NaN values, we'll fill them with mean
    X_Moving_Averages = X_Moving_Averages.dropna()

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
    X_Technical_v2 = X_Technical.dropna()  # Remove NaN values at the beginning

    scaler = StandardScaler()
    X_Standardized = pd.DataFrame(
        scaler.fit_transform(df[['Price_30', 'Price_29', 'Price_28', 'Price_27', 'Price_26']]),
        columns=['Price_30', 'Price_29', 'Price_28', 'Price_27', 'Price_26']
    )

    preprocessing_methods = {
    #"non_normalized": X,
    #"normalized": X_Normalized,
    #"percentage_change": X_Percentage_Change,
    #"log_returns": X_Log_Returns,
    #"moving_averages": X_Moving_Averages,
    #"technical_indicators": X_Technical,
    #"standardized": X_Standardized,
    "technical_indicators_v2": X_Technical_v2,
    }

    for method_name, X_preprocessed in preprocessing_methods.items():
        run_rl_process(X_preprocessed, df, file_name, method_name)
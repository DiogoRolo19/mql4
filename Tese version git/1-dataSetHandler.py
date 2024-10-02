import pandas as pd
import matplotlib.pyplot as plt
from Simulator import run_strategy, Strategies
from itertools import combinations


def plot_price_with_moving_average(df):
    # Create the line plot
    plt.figure(figsize=(10, 6))
    plt.plot(df.index, df['Price'], marker='o', linestyle='-', color='b', label='Price')
    plt.plot(df.index, df['ShortMovingAverage'], linestyle='--', color='r', label='Moving Average (14 periods)')
    plt.title('Price and RMoving Average Over Time')
    plt.xlabel('Date')
    plt.ylabel('Price')
    plt.grid(True)
    plt.legend()
    plt.show()

def calculate_rsi(data, window=14):
    delta = data['Price'].diff(1)
    gain = delta.where(delta > 0, 0)
    loss = -delta.where(delta < 0, 0)

    avg_gain = gain.rolling(window=window).mean()
    avg_loss = loss.rolling(window=window).mean()

    rs = avg_gain / avg_loss
    rsi = 100 - (100 / (1 + rs))

    return rsi


def calculate_macd(data, short_window=12, long_window=26, signal_window=9):
    # Calculate the short-term and long-term exponential moving averages (EMAs)
    short_ema = data['Price'].ewm(span=short_window, min_periods=1, adjust=False).mean()
    long_ema = data['Price'].ewm(span=long_window, min_periods=1, adjust=False).mean()

    # Calculate MACD line
    macd_line = short_ema - long_ema

    # Calculate the signal line (9-period EMA of MACD line)
    signal_line = macd_line.ewm(span=signal_window, min_periods=1, adjust=False).mean()

    return macd_line, signal_line


def calculate_stochastic_oscillator(data, k_period=14, d_period=3):
    # Calculate the %K value
    data['Lowest_Low'] = data['Price'].rolling(window=k_period).min()
    data['Highest_High'] = data['Price'].rolling(window=k_period).max()
    k = ((data['Price'] - data['Lowest_Low']) / (data['Highest_High'] - data['Lowest_Low'])) * 100

    # Calculate the %D value (3-period simple moving average of %K)
    d = k.rolling(window=d_period).mean()

    data.drop(['Lowest_Low', 'Highest_High'], axis=1, inplace=True)

    return k, d


def calculate_bollinger_bands(data, window=20, num_std_dev=4):
    # Calculate the rolling mean and standard deviation
    rolling_mean = data['Price'].rolling(window=window).mean()
    rolling_std = data['Price'].rolling(window=window).std()

    # Calculate the upper and lower Bollinger Bands
    upper_band = rolling_mean + (rolling_std * num_std_dev)
    lower_band = rolling_mean - (rolling_std * num_std_dev)

    return upper_band, lower_band


def generate_strategy_combinations(available_strategies):
    def generate_combinations(strategies, n):
        return list(combinations(strategies, n))

    all_combinations = []
    for i in range(1, len(available_strategies) + 1):
        all_combinations.extend(generate_combinations(available_strategies, i))

    return all_combinations


def run_strategies(df, strategies, days):
    cumulative_returns = {}
    strategy_string = ""
    for strategy in strategies:
        strategy_string += strategy[0].value + ", "
    strategy_string = strategy_string.rstrip(", ")
    for strategy in strategies:
        daily_returns = run_strategy(df, strategy)
        cumulative_return = [1]  # Initialize the result array with 1 in the first position
        for i in range(len(daily_returns)):
            cumulative_return.append(daily_returns[i] + cumulative_return[i])

            # Assign a label to each strategy combination
            label = ', '.join(str(strategy_element) for strategy_element in strategy)  # Convert the strategy combination to a string for the label

            cumulative_returns[label] = cumulative_return  # Use the label as the key in the dictionary

    plt.figure(figsize=(10, 6))

    index = 0
    for strategies, cumulative_return in cumulative_returns.items():
        plt.plot(days, cumulative_return[1:], label=strategies)

        index = 0
        for label, cumulative_return in cumulative_returns.items():
            plt.plot(days, cumulative_return[1:], label=label)  # Use the label in the legend

            # Add labels at the left side of each line
            label_x = days_partition[-1]  # Adjust the x-coordinate for label placement
            label_y = cumulative_return[-1]  # Use the last value of cumulative return for label placement
            plt.annotate(label, (label_x, label_y), xytext=(-10, 0), textcoords='offset points', ha='right',
                         fontsize=10)

    plt.title('Cumulative Profit Percentages')
    plt.grid(True)
    plt.legend()


    # Save the plot to a file (e.g., 'cumulative_profit.png')
    plt.savefig(strategy_string + '.png')

    plt.show()


df = pd.read_csv('data/SPX1mSample.csv')

# print(df.head())

# print(df.dtypes)

# Concatenate the first two columns and use them as the index
df['Date'] = df['t'] + ' ' + df['ts']

# Replace 'days' with a space and Convert 'new_index' to datetime64
df['Date'] = pd.to_datetime(df['Date'].str.replace(' days', ''), format='%Y-%m-%d %H:%M:%S')

df.drop(['t', 'ts'], axis=1, inplace=True)

# Swap the order of the columns
df = df[['Date', 'Price']]

df.sort_values('Date', ascending=True, inplace=True)

df.set_index('Date', inplace=True)

days = df.index.date
days = pd.Series(days).unique()

# Calculate the rolling average of the previous 14 values
df['ShortMovingAverage'] = df['Price'].rolling(window=50).mean()
df['LongMovingAverage'] = df['Price'].rolling(window=200).mean()

df['EMA'] = df['Price'].ewm(span=14, min_periods=1, adjust=False).mean()

# Calculate the RSI with a 14-period window
df['RSI'] = calculate_rsi(df, window=14)

# Calculate the MACD and signal line
macd, signal = calculate_macd(df)

# Add MACD and Signal Line columns to the DataFrame
df['MACD'] = macd
df['Signal Line'] = signal

# Calculate the Stochastic Oscillator (%K and %D)
K, D = calculate_stochastic_oscillator(df)

# Add %K and %D columns to the DataFrame
df['stoch%K'] = K
df['stoch%D'] = D

# Calculate the Bollinger Bands (Upper and Lower)
upper_band, lower_band = calculate_bollinger_bands(df)

# Add Upper Bollinger Band and Lower Bollinger Band columns to the DataFrame
df['Upper Bollinger Band'] = upper_band
df['Lower Bollinger Band'] = lower_band

df.fillna(0, inplace=True)

# print(df[days[7]:days[11]].head(15))

# print(df.dtypes)
# list([Strategies.MOVING_AVERAGE])
strategies = generate_strategy_combinations(Strategies)

profit_percentage = {}

df_partition = df[days[1]:]

days_partition = df_partition.index.date
days_partition = pd.Series(days_partition).unique()

run_strategies(df_partition, strategies, days_partition)


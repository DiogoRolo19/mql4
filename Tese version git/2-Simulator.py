import os
import shutil
import pandas as pd
from enum import Enum


class Strategies(Enum):
    MOVING_AVERAGE = 'Moving Average'
    RSI = 'RSI'
    MACD = 'MACD'
    STOCHASTIC = 'Stochastic'
    BB = 'Bollinger bands'


# Define a function to implement a trading strategy
def run_strategy(df, strategies):
    # Initialize variables for trade details
    in_position = False
    entry_price = 0
    trade_count = 0
    trades = []
    cumulative_profit = []
    current_day = df.index[0].date()
    cumulative_profit.append(0)

    strategy_name = "StrategiesData/"
    for strategy in strategies:
        strategy_name += strategy.value + ","
    # Remove the trailing comma
    strategy_name = strategy_name.rstrip(',')

    # Create a directory for the strategy if it doesn't exist
    strategy_directory = strategy_name
    # Check if the directory already exists and delete its contents
    if os.path.exists(strategy_directory):
        shutil.rmtree(strategy_directory)

    os.makedirs(strategy_directory, exist_ok=True)

    for index, row in df.iterrows():
        if index.date() != current_day:
            current_day = index.date()
            cumulative_profit.append(0)

        entry_values = {
            Strategies.MOVING_AVERAGE: lambda: [row['ShortMovingAverage'], row['LongMovingAverage']],
            Strategies.RSI: lambda: row['RSI'],
            Strategies.MACD: lambda: [row['MACD'], row['Signal Line']],
            Strategies.STOCHASTIC: lambda: [row['stoch%K'], row['stoch%D']],
            Strategies.BB: lambda: [row['Upper Bollinger Band'], row['Lower Bollinger Band']],
            # Add other strategies and their conditions as needed
        }
        entry_conditions = True
        for strategy in strategies:
            if not entry_condition(index, row['Price'], entry_values.get(strategy)(), strategy):
                entry_conditions = False
        exit_conditions = True
        for strategy in strategies:
            if not exit_condition(index, row['Price'], entry_values.get(strategy)(), strategy):
                exit_conditions = False

        if entry_conditions and not in_position:
            entry_time = index
            # Capture the last 30 slots of data before the entry
            entry_data = df[df.index <= entry_time].tail(30)

            # Check if there are at least 30 slots of data available before the trade
            if len(entry_data) == 30:
                in_position = True
                entry_price = row['Price']
        elif exit_conditions and in_position:
            in_position = False
            exit_price = row['Price']
            exit_time = index
            profit_percentage = ((exit_price - entry_price) / entry_price) * 100

            # Append the trade details including the last 30 slots of data
            trade_count += 1
            trade_csv_file = os.path.join(strategy_directory, f'{strategy_name}_trade_{trade_count}.csv')
            trade_entry = entry_data.copy()
            trade_entry['Entry Price'] = entry_price
            trade_entry['Exit Price'] = exit_price
            trade_entry['Profit Percentage'] = profit_percentage
            trade_entry.to_csv(trade_csv_file, index=False, header=True, sep=';')

            # Create a list containing the last 30 prices leading up to the trade entry
            price_history = entry_data['Price'].tolist()

            # Append a trade entry as a list to the 'trades' list
            trade_entry = [profit_percentage] + price_history
            trades.append(trade_entry)

            cumulative_profit[-1] += profit_percentage


    # Create a DataFrame for trade summaries
    columns = ['Profit Percentage'] + [f'Price_{i}' for i in range(1, 31)]
    trade_df = pd.DataFrame(trades, columns=columns)

    # Calculate overall statistics
    total_profit = trade_df['Profit Percentage'].sum()
    num_trades = len(trade_df)

    # Save trade summaries to a CSV file
    trade_csv_file = os.path.join(strategy_directory, f'{strategy_name}_Summary.csv')
    trade_df.to_csv(trade_csv_file, index=False, sep=';')

    # Print strategy statistics
    print(f'Strategy: {strategy_name}')
    print(f'Total Profit: {total_profit:.2f}%')
    print(f'Number of Trades: {num_trades}')
    print('\n')
    return cumulative_profit


def entry_condition(index, price, entry_value, strategy):
    entry_conditions = {
        Strategies.MOVING_AVERAGE: lambda: entry_value[0] > entry_value[1],
        Strategies.RSI: lambda: entry_value < 20,
        Strategies.MACD: lambda: entry_value[0] > entry_value[1],
        Strategies.STOCHASTIC: lambda: entry_value[0] > entry_value[1],
        Strategies.BB: lambda: price < entry_value[0]
        # Add other strategies and their conditions as needed
    }
    return entry_conditions.get(strategy)()


def exit_condition(index, price, exit_value, strategy):
    exit_conditions = {
        Strategies.MOVING_AVERAGE: lambda: exit_value[0] < exit_value[1],
        Strategies.RSI: lambda: exit_value > 80,
        Strategies.MACD: lambda: exit_value[0] < exit_value[1],
        Strategies.STOCHASTIC: lambda: exit_value[0] < exit_value[1],
        Strategies.BB: lambda: price > exit_value[1]
        # Add other strategies and their conditions as needed
    }
    return exit_conditions.get(strategy)()

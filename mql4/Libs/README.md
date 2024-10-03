## Custom Trading Libraries
This directory contains a collection of custom libraries developed to support and enhance my algorithmic trading strategies. These libraries are the result of extensive development and optimization, designed to work efficiently within the MQL4 environment.

## Key Components
## Lists
The Lists directory contains custom list implementations optimized for memory usage and speed in specific trading scenarios. These data structures are tailored to the unique requirements of algorithmic trading, ensuring efficient data management during strategy execution.

## Indicators
The Indicators directory is the core of the trading system, housing the majority of the strategic components. Each indicator represents a distinct part of my trading strategies, all implemented from scratch. Notable features include:

**ZIGZAG**: The foundation for many indicators, based on existing market concepts but with a personal approach.
Various other custom indicators, each playing a crucial role in strategy formulation and execution.

## Report
The Report class is a comprehensive metric system designed to track and analyze performance during both backtesting and live trading. This custom reporting tool provides valuable insights into strategy behavior and efficacy.
##PendingOrders
The PendingOrders class is a sophisticated order management system that handles:

        Orders that should not enter the market immediately
        Tracking of potential entries during off-hours
        Management of order validity when the market reopens
        Execution of valid trades at appropriate times

This class ensures that the trading system remains responsive to market conditions even during periods of inactivity.

## Additional Components
While not detailed here, the library includes several other custom classes and components, each contributing to the overall functionality and efficiency of the trading system. These additional elements showcase the depth and breadth of the development effort invested in this project.

## Development Note
All components in this library were developed independently, representing a significant investment of time and expertise in algorithmic trading system design and implementation.

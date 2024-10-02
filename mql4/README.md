# My Algorithmic Trading Journey

## Introduction

I began my journey into algorithmic trading in December 2020. My initial goal was to implement the manual strategy I used for trading US30, focusing on price mitigation in imbalance zones. This repository documents my progress and the various projects I've undertaken.

## MQL4 and Coding Approach

Before diving into the projects, it's worth noting that I primarily used MQL4, which is similar to C++. The main difference is that pointers are not allowed, but objects can still be passed as function returns. 

In my code, I often implement methods in the header files instead of just defining them and creating separate implementation classes. While this approach isn't typical in C++, it allows for faster development in MQL4. It also simplifies file management when backtesting, as I can compile and send a single file.

## Project Overview

1. **PriceAction**: My first attempt at implementing my manual strategy. While the results were promising given its complexity, it entered the market too infrequently, leading me to abandon this approach.

2. **MAMA Indicator**: After discussing with a friend, I integrated the MAMA indicator into my strategy. I found some indicator code online and learned how to import and integrate it. Backtesting showed great results but with enormous risk and significant drawdowns.

3. **Friend-Inspired Strategies**: Projects 3 (two versions), 6, and 7 were implementations of strategies suggested by friends who had success in trading. These projects required substantial coding skills and the challenge of translating their ideas into code.

5. **Online Strategies**: Small attempts to replicate strategies found online. These weren't profitable when adjusted for reduced risk.

6-7. **Advanced Indicators**: The latest projects involve extensive use of the include library, with the trading logic located in the indicators folder (inside the Include directory).

## FMCopy

A small script created to replicate trades from one account to others using text files.

## Learning and Growth

Throughout this journey, I've significantly improved my coding skills, particularly in translating trading concepts into executable code. While I've had some success with these strategies, market conditions change, which is what makes this field so exciting and challenging.

My focus has always been on creating efficient code to increase backtesting speed rather than high-frequency trading.

## Conclusion

This journey into algorithmic trading has been the most enjoyable programming experience I've had so far. It combines my passion for coding with the exciting world of financial markets, presenting unique challenges and opportunities for continuous learning and improvement.

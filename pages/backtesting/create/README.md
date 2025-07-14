# Backtesting Creation

The Backtesting Creation page enables you to design, configure, and launch backtests for various trading strategies using historical market data.

## Features

### 🎯 Strategy Configuration
- **Pre-built Strategy Templates**: Choose from popular strategies like PMM, XEMM, Grid, and Bollinger Bands
- **Custom Parameter Settings**: Fine-tune strategy parameters including spreads, order amounts, and risk limits
- **Multi-Exchange Support**: Backtest strategies across different exchanges and trading pairs
- **Position Mode Selection**: Test strategies in ONE-WAY or HEDGE position modes

### 📅 Backtest Setup
- **Historical Data Selection**: Choose date ranges for backtesting with available market data
- **Timeframe Configuration**: Select candle intervals (1m, 5m, 15m, 1h, 1d)
- **Initial Portfolio Settings**: Set starting balances for base and quote currencies
- **Fee Structure**: Configure maker/taker fees to match real trading conditions

### 🚀 Execution Options
- **Single Backtest**: Run individual backtests with specific configurations
- **Batch Testing**: Queue multiple backtests with different parameters
- **Optimization Mode**: Automatically test parameter ranges to find optimal settings
- **Real-time Progress**: Monitor backtest execution with live progress updates

## Usage Instructions

### 1. Select Strategy
- Choose a strategy type from the dropdown menu
- Review the strategy description and requirements
- Load a saved configuration or start with defaults

### 2. Configure Parameters
- **Trading Pair**: Select the market to backtest (e.g., BTC-USDT)
- **Date Range**: Set start and end dates for historical data
- **Strategy Parameters**: Adjust strategy-specific settings
  - Spread percentages
  - Order amounts and levels
  - Risk management thresholds
  - Refresh intervals

### 3. Set Initial Conditions
- **Starting Balance**: Define initial holdings in base and quote currencies
- **Leverage**: Set leverage for perpetual/futures markets (1x for spot)
- **Fees**: Input maker and taker fee percentages

### 4. Launch Backtest
- Review all settings in the configuration summary
- Click "Run Backtest" to start execution
- Monitor progress in the status panel
- Access results in the Analyze page once complete

## Technical Notes

### Data Requirements
- Historical candle data must be available for the selected date range
- Order book snapshots are simulated based on historical spreads
- Trade data is used for volume-weighted calculations

### Execution Engine
- **Event-Driven Simulation**: Tick-by-tick processing of market events
- **Order Matching**: Realistic order filling based on historical liquidity
- **Latency Simulation**: Configurable delays to model real-world conditions

### Performance Optimization
- Backtests run on the backend server for optimal performance
- Large date ranges are processed in chunks to prevent memory issues
- Results are streamed to the UI as they become available

## Component Structure

```
create/
├── create.py              # Main page application
├── components/
│   ├── strategy_selector.py   # Strategy selection interface
│   ├── parameter_form.py      # Dynamic parameter input forms
│   └── backtest_launcher.py   # Backtest execution controls
└── configs/
    ├── strategy_defaults.py   # Default configurations
    └── validation.py          # Parameter validation rules
```

## Supported Strategies

### Market Making
- **Pure Market Making (PMM)**: Continuous bid/ask placement around mid-price
- **Cross-Exchange Market Making (XEMM)**: Arbitrage between exchanges
- **Perpetual Market Making**: Strategies for perpetual futures

### Directional
- **Bollinger Bands**: Mean reversion based on volatility bands
- **MACD + Bollinger**: Combined momentum and volatility signals
- **SuperTrend**: Trend-following with dynamic stops

### Grid Trading
- **Grid Strike**: Fixed-interval grid with customizable ranges
- **Dynamic Grid**: Adaptive grid based on market volatility

## Error Handling

The creation page handles various error scenarios:
- **Invalid Parameters**: Real-time validation with helpful error messages
- **Insufficient Data**: Clear warnings when historical data is missing
- **Configuration Conflicts**: Automatic detection of incompatible settings
- **Server Errors**: Graceful fallbacks with retry options
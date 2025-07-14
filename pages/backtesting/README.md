# Backtesting Module

## Page Purpose and Functionality

The Backtesting module enables users to test, analyze, and optimize trading strategies using historical market data. It provides a comprehensive framework for evaluating strategy performance before deploying them with real funds. The module consists of three main components: Create, Analyze, and Optimize.

## Key Features

### 1. Create (`/create`)
- Design and configure backtesting scenarios for directional trading strategies
- Set up strategy parameters including order levels, triple barrier configurations, and position sizing
- Define backtesting periods and initial portfolio settings
- Save configurations for future use

### 2. Analyze (`/analyze`)
- Load and examine results from Optuna optimization databases
- Filter and compare multiple backtesting trials based on performance metrics
- Interactive visualization of PnL vs Maximum Drawdown
- Detailed parameter inspection and modification
- Re-run backtests with adjusted parameters

### 3. Optimize (`/optimize`)
- Automated hyperparameter optimization using Optuna framework
- Multi-objective optimization targeting profit, drawdown, and accuracy
- Parallel trial execution for efficient parameter space exploration
- Real-time optimization progress tracking
- Export optimized configurations

## User Flow

1. **Strategy Creation**
   - User selects a trading strategy controller
   - Configures strategy parameters (e.g., technical indicators, thresholds)
   - Sets up order levels with triple barrier configurations
   - Defines backtesting period and initial capital
   - Runs initial backtest

2. **Optimization**
   - User selects parameters to optimize with ranges
   - Defines optimization objectives (maximize profit, minimize drawdown)
   - Sets number of trials and execution parameters
   - Monitors optimization progress in real-time
   - Reviews Pareto-optimal solutions

3. **Analysis**
   - User loads optimization database
   - Filters trials by performance metrics (accuracy, profit, drawdown)
   - Selects promising trials for detailed inspection
   - Fine-tunes parameters based on insights
   - Exports final configurations for deployment

## Technical Implementation Details

### Architecture
- **Backend Integration**: Communicates with Hummingbot's backtesting engine via the Backend API Client
- **Data Processing**: Uses pandas for data manipulation and analysis
- **Optimization Engine**: Leverages Optuna for Bayesian optimization
- **Visualization**: Plotly for interactive charts and performance metrics

### Key Classes and Components
- `DirectionalTradingBacktestingEngine`: Core backtesting engine from Hummingbot
- `OptunaDBManager`: Manages optimization databases and trial data
- `BacktestingGraphs`: Generates performance visualizations
- `StrategyAnalysis`: Computes strategy metrics and statistics

### Data Flow
1. Strategy configuration → Backtesting engine
2. Historical market data → Engine simulation
3. Trade execution results → Performance metrics
4. Metrics → Optuna optimization
5. Optimized parameters → Analysis and export

## Component Dependencies

### Internal Dependencies
- `backend.utils.optuna_database_manager`: Database management for optimization results
- `backend.utils.os_utils`: Controller loading utilities
- `frontend.st_utils`: Streamlit page initialization and utilities
- `frontend.visualization.graphs`: Chart generation for backtesting results
- `frontend.visualization.strategy_analysis`: Performance metric calculations

### External Dependencies
- `hummingbot`: Core trading strategy framework
- `streamlit`: Web UI framework
- `pandas`: Data manipulation
- `plotly`: Interactive visualizations
- `optuna`: Hyperparameter optimization

## State Management Approach

### Session State Variables
- `strategy_params`: Current strategy configuration parameters
- `backtesting_params`: Backtesting-specific settings (period, costs, etc.)
- `optimization_params`: Ranges and objectives for parameter optimization
- `selected_study`: Currently selected Optuna study
- `selected_trial`: Currently selected optimization trial

### Persistent Storage
- **Optimization Databases**: SQLite files in `data/backtesting/` directory
- **Strategy Configurations**: YAML files in `hummingbot_files/controller_configs/`
- **Candle Data**: Historical market data in `data/candles/`

### Cache Management
- `@st.cache_resource`: Used for database loading to prevent repeated file I/O
- `@st.cache_data`: Applied to expensive computations like metric calculations
- Results cached during session to improve performance when switching between trials

## Best Practices

1. **Data Validation**
   - Always verify candle data availability before running backtests
   - Validate parameter ranges to prevent invalid configurations
   - Check for sufficient historical data for the selected period

2. **Performance Optimization**
   - Use cached resources for database operations
   - Limit the number of simultaneous optimization trials
   - Filter large datasets before visualization

3. **User Experience**
   - Provide clear progress indicators during long operations
   - Display meaningful error messages for common issues
   - Offer sensible defaults for complex parameters

4. **Configuration Management**
   - Save successful configurations with descriptive names
   - Version control strategy configurations
   - Document parameter choices and rationale
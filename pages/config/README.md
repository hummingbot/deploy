# Config Module

## Page Purpose and Functionality

The Config module provides a centralized interface for creating and managing trading strategy configurations. It offers specialized configuration pages for various trading strategies and controllers, allowing users to customize parameters, set trading rules, and export configurations for use with Hummingbot instances.

## Key Features

### Strategy-Specific Configuration Pages
1. **Bollinger Bands V1** (`/bollinger_v1`)
   - Configure Bollinger Bands parameters (period, standard deviations)
   - Set entry/exit thresholds
   - Define position sizing and risk management

2. **DMAN Maker V2** (`/dman_maker_v2`)
   - Advanced market making strategy configuration
   - Dynamic spread and price adjustments
   - Inventory management settings

3. **Grid Strike** (`/grid_strike`)
   - Grid trading parameters (levels, spacing, range)
   - Order size distribution
   - Rebalancing rules

4. **Kalman Filter V1** (`/kalman_filter_v1`)
   - Statistical arbitrage configuration
   - Kalman filter parameters
   - Signal generation thresholds

5. **MACD BB V1** (`/macd_bb_v1`)
   - Combined MACD and Bollinger Bands strategy
   - Indicator parameters and signal combinations
   - Trade entry/exit rules

6. **PMM Dynamic** (`/pmm_dynamic`)
   - Dynamic Pure Market Making configuration
   - Spread and price multipliers based on market conditions
   - Advanced inventory risk parameters

7. **PMM Simple** (`/pmm_simple`)
   - Basic Pure Market Making strategy
   - Fixed spread and order amount settings
   - Simple inventory management

8. **Supertrend V1** (`/supertrend_v1`)
   - Supertrend indicator configuration
   - ATR multiplier and period settings
   - Trend-following parameters

9. **XEMM Controller** (`/xemm_controller`)
   - Cross-Exchange Market Making configuration
   - Exchange pair settings
   - Arbitrage parameters

## User Flow

1. **Strategy Selection**
   - User navigates to specific strategy configuration page
   - Views strategy description and use cases
   - Understands parameter requirements

2. **Parameter Configuration**
   - User inputs required parameters using intuitive UI controls
   - Real-time validation ensures valid configurations
   - Tooltips and help text guide parameter selection

3. **Advanced Settings**
   - Optional advanced parameters for fine-tuning
   - Risk management configurations
   - Exchange-specific settings

4. **Configuration Export**
   - Preview generated configuration
   - Save to file system or clipboard
   - Import into Hummingbot instances

## Technical Implementation Details

### Architecture
- **Modular Design**: Each strategy has its own dedicated configuration module
- **Shared Utilities**: Common functions in `utils.py` for configuration handling
- **Type Safety**: Pydantic models ensure configuration validity
- **UI Components**: Streamlit widgets for parameter input

### Configuration Structure
```python
# Common configuration pattern
{
    "strategy_name": "strategy_identifier",
    "exchange": "exchange_name",
    "trading_pair": "BASE-QUOTE",
    "parameters": {
        # Strategy-specific parameters
    },
    "risk_management": {
        # Risk controls
    }
}
```

### Validation Framework
- Input validation at UI level
- Schema validation using Pydantic
- Business logic validation for parameter combinations
- Exchange compatibility checks

## Component Dependencies

### Internal Dependencies
- `backend.services.backend_api_client`: For validating exchange connections
- `frontend.st_utils`: Streamlit utilities and page initialization
- `hummingbot.strategy_v2`: Strategy framework and configurations

### External Dependencies
- `streamlit`: Web UI framework
- `pydantic`: Data validation and settings management
- `yaml`: Configuration file handling
- `json`: Data serialization

### Shared Components
- `user_inputs.py`: Reusable input components across strategies
- `spread_and_price_multipliers.py`: Dynamic pricing components
- Configuration templates and presets

## State Management Approach

### Session State Usage
- `selected_strategy`: Currently selected strategy type
- `config_params`: Active configuration parameters
- `validation_errors`: Current validation issues
- `export_format`: Selected export format (YAML/JSON)

### Configuration Persistence
- **Draft Configs**: Temporarily stored in session state
- **Saved Configs**: Exported to `hummingbot_files/strategies/`
- **Templates**: Pre-built configurations in strategy directories

### Dynamic Updates
- Real-time parameter validation
- Dependent field updates (e.g., spread affects order placement)
- Preview updates as parameters change

## Best Practices

1. **User Input Handling**
   - Provide sensible defaults for all parameters
   - Clear labeling with units (e.g., "seconds", "percentage")
   - Group related parameters logically
   - Use appropriate input widgets (sliders for ranges, selects for options)

2. **Validation**
   - Validate individual parameters immediately
   - Check parameter combinations for conflicts
   - Verify exchange compatibility
   - Display clear error messages with solutions

3. **Configuration Management**
   - Version control configuration schemas
   - Maintain backwards compatibility
   - Document parameter changes
   - Provide migration utilities for old configs

4. **Performance**
   - Lazy load strategy modules
   - Cache exchange data for dropdowns
   - Minimize API calls during configuration
   - Optimize UI responsiveness

## Strategy Configuration Guidelines

### Essential Parameters
Every strategy configuration should include:
- Exchange selection
- Trading pair
- Order amount/size
- Basic risk limits

### Strategy-Specific Parameters
Each strategy requires unique parameters:
- **Technical Indicators**: Period, multipliers, thresholds
- **Market Making**: Spreads, order levels, inventory targets
- **Arbitrage**: Price differences, latency considerations
- **Grid Trading**: Grid levels, spacing, boundaries

### Risk Management
Common risk parameters across strategies:
- Maximum position size
- Stop loss levels
- Daily loss limits
- Inventory bounds
- Kill switch conditions
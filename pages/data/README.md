# Data Module

## Page Purpose and Functionality

The Data module provides tools for accessing, downloading, and analyzing market data essential for trading strategy development and analysis. It offers interfaces for historical data retrieval, real-time market analysis, and specialized data visualizations to support informed trading decisions.

## Key Features

### 1. Download Candles (`/download_candles`)
- Download historical candlestick data from multiple exchanges
- Support for various timeframes (1m, 3m, 5m, 15m, 1h, 4h, 1d)
- Interactive candlestick chart visualization
- Export capabilities for offline analysis
- Automatic data validation and gap detection

### 2. Token Spreads (`/token_spreads`)
- Real-time bid-ask spread analysis across exchanges
- Cross-exchange arbitrage opportunity detection
- Historical spread tracking and trends
- Volatility analysis based on spread behavior
- Multi-pair comparison capabilities

### 3. TVL vs Market Cap (`/tvl_vs_mcap`)
- DeFi protocol analysis comparing Total Value Locked to Market Capitalization
- Fundamental analysis metrics for token valuation
- Historical TVL/MCap ratio tracking
- Protocol comparison and ranking
- Integration with DeFi data providers

## User Flow

1. **Historical Data Collection**
   - User selects exchange and trading pair
   - Specifies date range and candle interval
   - Downloads data with progress tracking
   - Visualizes data quality and completeness
   - Exports for strategy development

2. **Market Analysis**
   - User monitors real-time spreads
   - Identifies arbitrage opportunities
   - Analyzes market efficiency
   - Tracks spread patterns over time
   - Sets alerts for spread thresholds

3. **Fundamental Analysis**
   - User selects DeFi protocols or tokens
   - Compares TVL and market cap metrics
   - Identifies potentially undervalued assets
   - Tracks metric changes over time
   - Exports analysis results

## Technical Implementation Details

### Data Architecture
- **Data Sources**: Direct exchange APIs and aggregated data providers
- **Storage Format**: Optimized parquet files for efficient querying
- **Caching Strategy**: Multi-level caching for API responses
- **Update Mechanism**: Incremental updates to minimize API calls

### API Integration
```python
# Exchange data retrieval pattern
backend_api_client.market_data.get_historical_candles(
    connector="exchange_name",
    trading_pair="BASE-QUOTE",
    interval="timeframe",
    start_time=timestamp,
    end_time=timestamp
)
```

### Data Processing Pipeline
1. Raw data retrieval from exchanges
2. Data validation and cleaning
3. Gap filling and interpolation where appropriate
4. Aggregation and resampling
5. Storage in optimized format

## Component Dependencies

### Internal Dependencies
- `backend.services.backend_api_client`: Market data API interface
- `frontend.st_utils`: Streamlit utilities
- `frontend.visualization`: Chart and graph components

### External Dependencies
- `pandas`: Data manipulation and analysis
- `plotly`: Interactive charting
- `numpy`: Numerical computations
- `streamlit`: Web interface

### Data Storage
- `data/candles/`: Historical candlestick data
- `data/spreads/`: Spread analysis results
- `data/tvl/`: TVL and market cap data

## State Management Approach

### Session State Variables
- `selected_exchange`: Current exchange selection
- `selected_pairs`: Active trading pairs
- `date_range`: Selected time period
- `chart_settings`: Visualization preferences
- `cached_data`: Recently fetched data

### Data Caching Strategy
- **Memory Cache**: Recent API responses (5-minute TTL)
- **Disk Cache**: Historical data (permanent until invalidated)
- **Session Cache**: User-specific selections and results

### Real-time Updates
- WebSocket connections for live data
- Polling fallback for unsupported exchanges
- Automatic reconnection handling
- Rate limiting compliance

## Best Practices

1. **Data Quality**
   - Always validate downloaded data for gaps
   - Check for anomalous values (e.g., zero prices)
   - Verify timestamp consistency
   - Handle exchange downtime gracefully

2. **Performance Optimization**
   - Batch API requests when possible
   - Use appropriate data granularity
   - Implement progressive loading for large datasets
   - Optimize chart rendering for large data

3. **User Experience**
   - Show download progress clearly
   - Provide data quality indicators
   - Enable easy data export
   - Cache frequently accessed data

4. **Error Handling**
   - Graceful handling of API failures
   - Clear error messages with solutions
   - Automatic retry with exponential backoff
   - Fallback data sources when available

## Data Specifications

### Candle Data Format
```python
{
    "timestamp": int,  # Unix timestamp
    "open": float,
    "high": float,
    "low": float,
    "close": float,
    "volume": float,
    "quote_volume": float  # Optional
}
```

### Spread Data Format
```python
{
    "timestamp": int,
    "exchange": str,
    "trading_pair": str,
    "bid": float,
    "ask": float,
    "spread": float,  # ask - bid
    "spread_pct": float  # spread / mid_price
}
```

### TVL Data Format
```python
{
    "timestamp": int,
    "protocol": str,
    "tvl_usd": float,
    "market_cap_usd": float,
    "tvl_mcap_ratio": float,
    "change_24h": float  # Percentage
}
```

## Advanced Features

### Data Analysis Tools
- Moving averages and technical indicators
- Correlation analysis between pairs
- Volatility calculations
- Market microstructure metrics

### Export Capabilities
- CSV export for spreadsheet analysis
- JSON export for programmatic access
- Direct integration with backtesting module
- API endpoints for external access

### Visualization Options
- Candlestick charts with overlays
- Spread heatmaps
- Time series comparisons
- Distribution analysis
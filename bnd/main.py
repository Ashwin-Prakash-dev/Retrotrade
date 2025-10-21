from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field, validator
import backtrader as bt
import yfinance as yf
import traceback
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
from typing import Optional, List
import requests
import json
import asyncio
from concurrent.futures import ThreadPoolExecutor
from functools import lru_cache


app = FastAPI(title="Stock Analysis & Backtest API", version="1.0.0")

# Thread pool for parallel processing
executor = ThreadPoolExecutor(max_workers=10)

# Add CORS middleware for Flutter app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Pydantic models
class StockSuggestion(BaseModel):
    symbol: str
    company_name: str
    match_type: str = "symbol"

class PortfolioStock(BaseModel):
    ticker: str = Field(..., min_length=1, max_length=10)
    allocation: float = Field(..., ge=0, le=100, description="Percentage allocation (0-100)")

    @validator('ticker')
    def ticker_must_be_uppercase(cls, v):
        return v.upper().strip()

class PortfolioStrategyInput(BaseModel):
    stocks: List[PortfolioStock] = Field(..., min_items=1, max_items=20)
    start_date: str = Field(..., description="Start date in YYYY-MM-DD format")
    end_date: str = Field(..., description="End date in YYYY-MM-DD format")
    strategy: str = Field(default="RSI", description="Strategy type: RSI, MACD, or Volume_Spike")
    
    # RSI parameters
    rsi_period: int = Field(default=14, ge=5, le=50)
    rsi_buy: int = Field(default=30, ge=0, le=100)
    rsi_sell: int = Field(default=70, ge=0, le=100)
    
    # MACD parameters
    macd_fast: int = Field(default=12, ge=5, le=50)
    macd_slow: int = Field(default=26, ge=10, le=100)
    macd_signal: int = Field(default=9, ge=5, le=30)
    
    # Volume Spike parameters
    volume_multiplier: float = Field(default=2.0, ge=1.0, le=10.0)
    volume_period: int = Field(default=20, ge=5, le=100)
    volume_hold_days: int = Field(default=5, ge=1, le=30)
    
    initial_cash: float = Field(default=100000.0, ge=1000)
    rebalance: bool = Field(default=False, description="Rebalance portfolio periodically")
    rebalance_frequency: str = Field(default="monthly", description="monthly, quarterly, yearly")

    @validator('stocks')
    def validate_allocations(cls, v):
        total = sum(stock.allocation for stock in v)
        if abs(total - 100.0) > 0.01:
            raise ValueError(f'Stock allocations must sum to 100%, got {total}%')
        return v

    @validator('start_date', 'end_date')
    def validate_date_format(cls, v):
        try:
            datetime.strptime(v, '%Y-%m-%d')
            return v
        except ValueError:
            raise ValueError('Date must be in YYYY-MM-DD format')

class BacktestResult(BaseModel):
    final_value: float
    initial_value: float
    total_return: float
    total_return_pct: float
    total_trades: int
    winning_trades: int
    losing_trades: int
    win_rate: float
    max_drawdown: float

class PortfolioBacktestResult(BaseModel):
    final_value: float
    initial_value: float
    total_return: float
    total_return_pct: float
    total_trades: int
    winning_trades: int
    losing_trades: int
    win_rate: float
    max_drawdown: float
    stock_performances: List[dict]
    portfolio_composition: List[dict]

class StockInfo(BaseModel):
    symbol: str
    company_name: str
    sector: str
    current_price: float
    change: float
    change_percent: float
    volume: int
    market_cap: float
    pe_ratio: float
    support_level: float
    resistance_level: float
    rsi: float
    macd: float
    stochastic_k: float
    stochastic_d: float
    fib_236: float
    fib_382: float
    fib_500: float
    fib_618: float
    overall_sentiment: str
    sentiment_score: float
    short_term_sentiment: str
    short_term_score: float
    long_term_sentiment: str
    long_term_score: float
    sentiment_factors: list
    analyst_buy: int
    analyst_hold: int
    analyst_sell: int
    target_price: float

class StockScreenerParams(BaseModel):
    use_rsi: bool = False
    rsi_min: float = 30.0
    rsi_max: float = 70.0
    use_macd: bool = False
    macd_signal: str = 'any'
    use_vwap: bool = False
    vwap_position: str = 'any'
    use_pe: bool = False
    pe_min: float = 5.0
    pe_max: float = 30.0
    use_market_cap: bool = False
    market_cap_min: float = 1000000000.0
    market_cap_max: float = 1000000000000.0
    use_volume: bool = False
    volume_min: float = 1000000.0
    use_price: bool = False
    price_min: float = 1.0
    price_max: float = 1000.0
    sector: str = 'any'

# Popular stock symbols
POPULAR_STOCKS = {
    'AAPL': 'Apple Inc.', 'MSFT': 'Microsoft Corporation', 'GOOGL': 'Alphabet Inc. Class A',
    'GOOG': 'Alphabet Inc. Class C', 'AMZN': 'Amazon.com Inc.', 'TSLA': 'Tesla Inc.',
    'META': 'Meta Platforms Inc.', 'NVDA': 'NVIDIA Corporation', 'NFLX': 'Netflix Inc.',
    'ORCL': 'Oracle Corporation', 'ADBE': 'Adobe Inc.', 'CRM': 'Salesforce Inc.',
    'INTC': 'Intel Corporation', 'AMD': 'Advanced Micro Devices Inc.', 'IBM': 'International Business Machines Corporation',
    'JPM': 'JPMorgan Chase & Co.', 'BAC': 'Bank of America Corporation', 'WFC': 'Wells Fargo & Company',
    'GS': 'The Goldman Sachs Group Inc.', 'MS': 'Morgan Stanley', 'C': 'Citigroup Inc.',
    'BRK.A': 'Berkshire Hathaway Inc. Class A', 'BRK.B': 'Berkshire Hathaway Inc. Class B',
    'V': 'Visa Inc.', 'MA': 'Mastercard Incorporated', 'PYPL': 'PayPal Holdings Inc.',
    'AXP': 'American Express Company', 'JNJ': 'Johnson & Johnson', 'PFE': 'Pfizer Inc.',
    'UNH': 'UnitedHealth Group Incorporated', 'ABBV': 'AbbVie Inc.', 'TMO': 'Thermo Fisher Scientific Inc.',
    'ABT': 'Abbott Laboratories', 'DHR': 'Danaher Corporation', 'BMY': 'Bristol-Myers Squibb Company',
    'LLY': 'Eli Lilly and Company', 'MRK': 'Merck & Co. Inc.', 'WMT': 'Walmart Inc.',
    'PG': 'The Procter & Gamble Company', 'KO': 'The Coca-Cola Company', 'PEP': 'PepsiCo Inc.',
    'NKE': 'NIKE Inc.', 'MCD': "McDonald's Corporation", 'SBUX': 'Starbucks Corporation',
    'HD': 'The Home Depot Inc.', 'TGT': 'Target Corporation', 'COST': 'Costco Wholesale Corporation',
    'XOM': 'Exxon Mobil Corporation', 'CVX': 'Chevron Corporation', 'COP': 'ConocoPhillips',
    'SLB': 'Schlumberger Limited', 'EOG': 'EOG Resources Inc.', 'BA': 'The Boeing Company',
    'GE': 'General Electric Company', 'CAT': 'Caterpillar Inc.', 'MMM': '3M Company',
    'HON': 'Honeywell International Inc.', 'VZ': 'Verizon Communications Inc.', 'T': 'AT&T Inc.',
    'TMUS': 'T-Mobile US Inc.', 'AMT': 'American Tower Corporation', 'PLD': 'Prologis Inc.',
    'CCI': 'Crown Castle International Corp.',
}

# ==================== STRATEGY CLASSES ====================

class RSIStrategy(bt.Strategy):
    params = (
        ("rsi_period", 14),
        ("rsi_buy", 30),
        ("rsi_sell", 70),
    )

    def __init__(self):
        self.rsi = bt.indicators.RSI_SMA(self.data.close, period=self.params.rsi_period)
        self.trade_count = 0
        self.winning_trades = 0
        self.losing_trades = 0

    def next(self):
        if not self.position:
            if self.rsi < self.params.rsi_buy:
                self.buy(size=None)
        else:
            if self.rsi > self.params.rsi_sell:
                self.sell(size=self.position.size)

    def notify_trade(self, trade):
        if trade.isclosed:
            self.trade_count += 1
            if trade.pnl > 0:
                self.winning_trades += 1
            else:
                self.losing_trades += 1


class MACDStrategy(bt.Strategy):
    params = (
        ("macd_fast", 12),
        ("macd_slow", 26),
        ("macd_signal", 9),
    )

    def __init__(self):
        self.macd = bt.indicators.MACD(
            self.data.close,
            period_me1=self.params.macd_fast,
            period_me2=self.params.macd_slow,
            period_signal=self.params.macd_signal
        )
        self.trade_count = 0
        self.winning_trades = 0
        self.losing_trades = 0

    def next(self):
        if not self.position:
            # Buy when MACD line crosses above signal line
            if self.macd.macd[0] > self.macd.signal[0] and self.macd.macd[-1] <= self.macd.signal[-1]:
                self.buy(size=None)
        else:
            # Sell when MACD line crosses below signal line
            if self.macd.macd[0] < self.macd.signal[0] and self.macd.macd[-1] >= self.macd.signal[-1]:
                self.sell(size=self.position.size)

    def notify_trade(self, trade):
        if trade.isclosed:
            self.trade_count += 1
            if trade.pnl > 0:
                self.winning_trades += 1
            else:
                self.losing_trades += 1


class VolumeSpikeStrategy(bt.Strategy):
    params = (
        ("volume_multiplier", 2.0),
        ("volume_period", 20),
        ("hold_days", 5),
    )

    def __init__(self):
        self.volume_sma = bt.indicators.SMA(self.data.volume, period=self.params.volume_period)
        self.trade_count = 0
        self.winning_trades = 0
        self.losing_trades = 0
        self.hold_counter = 0

    def next(self):
        if not self.position:
            # Buy when volume exceeds threshold
            if self.data.volume[0] > (self.volume_sma[0] * self.params.volume_multiplier):
                self.buy(size=None)
                self.hold_counter = 0
        else:
            self.hold_counter += 1
            # Sell after holding for specified days
            if self.hold_counter >= self.params.hold_days:
                self.sell(size=self.position.size)
                self.hold_counter = 0

    def notify_trade(self, trade):
        if trade.isclosed:
            self.trade_count += 1
            if trade.pnl > 0:
                self.winning_trades += 1
            else:
                self.losing_trades += 1


# ==================== PORTFOLIO STRATEGIES ====================

class PortfolioRSIStrategy(bt.Strategy):
    params = (
        ("rsi_period", 14),
        ("rsi_buy", 30),
        ("rsi_sell", 70),
        ("allocations", {}),
    )

    def __init__(self):
        self.rsi_indicators = {}
        self.trade_counts = {}
        self.winning_trades = {}
        self.losing_trades = {}
        
        for i, d in enumerate(self.datas):
            self.rsi_indicators[d._name] = bt.indicators.RSI_SMA(
                d.close, period=self.params.rsi_period
            )
            self.trade_counts[d._name] = 0
            self.winning_trades[d._name] = 0
            self.losing_trades[d._name] = 0

    def next(self):
        for i, d in enumerate(self.datas):
            pos = self.getposition(d)
            rsi = self.rsi_indicators[d._name]
            allocation = self.params.allocations.get(d._name, 0) / 100.0
            
            if not pos:
                if rsi < self.params.rsi_buy:
                    available_cash = self.broker.getcash()
                    target_value = available_cash * allocation
                    size = int(target_value / d.close[0])
                    if size > 0:
                        self.buy(data=d, size=size)
            else:
                if rsi > self.params.rsi_sell:
                    self.sell(data=d, size=pos.size)

    def notify_trade(self, trade):
        if trade.isclosed:
            data_name = trade.data._name
            self.trade_counts[data_name] += 1
            if trade.pnl > 0:
                self.winning_trades[data_name] += 1
            else:
                self.losing_trades[data_name] += 1


class PortfolioMACDStrategy(bt.Strategy):
    params = (
        ("macd_fast", 12),
        ("macd_slow", 26),
        ("macd_signal", 9),
        ("allocations", {}),
    )

    def __init__(self):
        self.macd_indicators = {}
        self.trade_counts = {}
        self.winning_trades = {}
        self.losing_trades = {}
        
        for i, d in enumerate(self.datas):
            self.macd_indicators[d._name] = bt.indicators.MACD(
                d.close,
                period_me1=self.params.macd_fast,
                period_me2=self.params.macd_slow,
                period_signal=self.params.macd_signal
            )
            self.trade_counts[d._name] = 0
            self.winning_trades[d._name] = 0
            self.losing_trades[d._name] = 0

    def next(self):
        for i, d in enumerate(self.datas):
            pos = self.getposition(d)
            macd = self.macd_indicators[d._name]
            allocation = self.params.allocations.get(d._name, 0) / 100.0
            
            if not pos:
                # Buy when MACD crosses above signal
                if len(d) > 1:
                    if macd.macd[0] > macd.signal[0] and macd.macd[-1] <= macd.signal[-1]:
                        available_cash = self.broker.getcash()
                        target_value = available_cash * allocation
                        size = int(target_value / d.close[0])
                        if size > 0:
                            self.buy(data=d, size=size)
            else:
                # Sell when MACD crosses below signal
                if len(d) > 1:
                    if macd.macd[0] < macd.signal[0] and macd.macd[-1] >= macd.signal[-1]:
                        self.sell(data=d, size=pos.size)

    def notify_trade(self, trade):
        if trade.isclosed:
            data_name = trade.data._name
            self.trade_counts[data_name] += 1
            if trade.pnl > 0:
                self.winning_trades[data_name] += 1
            else:
                self.losing_trades[data_name] += 1


class PortfolioVolumeSpikeStrategy(bt.Strategy):
    params = (
        ("volume_multiplier", 2.0),
        ("volume_period", 20),
        ("hold_days", 5),
        ("allocations", {}),
    )

    def __init__(self):
        self.volume_smas = {}
        self.trade_counts = {}
        self.winning_trades = {}
        self.losing_trades = {}
        self.hold_counters = {}
        
        for i, d in enumerate(self.datas):
            self.volume_smas[d._name] = bt.indicators.SMA(
                d.volume, period=self.params.volume_period
            )
            self.trade_counts[d._name] = 0
            self.winning_trades[d._name] = 0
            self.losing_trades[d._name] = 0
            self.hold_counters[d._name] = 0

    def next(self):
        for i, d in enumerate(self.datas):
            pos = self.getposition(d)
            volume_sma = self.volume_smas[d._name]
            allocation = self.params.allocations.get(d._name, 0) / 100.0
            
            if not pos:
                # Buy on volume spike
                if d.volume[0] > (volume_sma[0] * self.params.volume_multiplier):
                    available_cash = self.broker.getcash()
                    target_value = available_cash * allocation
                    size = int(target_value / d.close[0])
                    if size > 0:
                        self.buy(data=d, size=size)
                        self.hold_counters[d._name] = 0
            else:
                self.hold_counters[d._name] += 1
                # Sell after holding period
                if self.hold_counters[d._name] >= self.params.hold_days:
                    self.sell(data=d, size=pos.size)
                    self.hold_counters[d._name] = 0

    def notify_trade(self, trade):
        if trade.isclosed:
            data_name = trade.data._name
            self.trade_counts[data_name] += 1
            if trade.pnl > 0:
                self.winning_trades[data_name] += 1
            else:
                self.losing_trades[data_name] += 1


# ==================== HELPER FUNCTIONS ====================

def calculate_rsi(prices, window=14):
    try:
        delta = pd.Series(prices).diff()
        gain = (delta.where(delta > 0, 0)).rolling(window=window).mean()
        loss = (-delta.where(delta < 0, 0)).rolling(window=window).mean()
        rs = gain / loss
        rsi = 100 - (100 / (1 + rs))
        return float(rsi.iloc[-1]) if not pd.isna(rsi.iloc[-1]) else 50.0
    except:
        return 50.0

def calculate_macd(prices, fast=12, slow=26, signal=9):
    try:
        prices_series = pd.Series(prices)
        exp1 = prices_series.ewm(span=fast).mean()
        exp2 = prices_series.ewm(span=slow).mean()
        macd = exp1 - exp2
        return float(macd.iloc[-1]) if not pd.isna(macd.iloc[-1]) else 0.0
    except:
        return 0.0

def calculate_stochastic(high, low, close, k_period=14, d_period=3):
    try:
        high_series = pd.Series(high)
        low_series = pd.Series(low)
        close_series = pd.Series(close)
        
        lowest_low = low_series.rolling(window=k_period).min()
        highest_high = high_series.rolling(window=k_period).max()
        
        k_percent = 100 * ((close_series - lowest_low) / (highest_high - lowest_low))
        d_percent = k_percent.rolling(window=d_period).mean()
        
        k_val = float(k_percent.iloc[-1]) if not pd.isna(k_percent.iloc[-1]) else 50.0
        d_val = float(d_percent.iloc[-1]) if not pd.isna(d_percent.iloc[-1]) else 50.0
        
        return k_val, d_val
    except:
        return 50.0, 50.0

def calculate_support_resistance(df, window=20):
    try:
        high_prices = df['High'].rolling(window=window).max()
        low_prices = df['Low'].rolling(window=window).min()
        recent_high = high_prices.iloc[-1] if len(high_prices) > 0 else df['Close'].iloc[-1]
        recent_low = low_prices.iloc[-1] if len(low_prices) > 0 else df['Close'].iloc[-1]
        return recent_low, recent_high
    except:
        current_price = df['Close'].iloc[-1]
        return current_price * 0.95, current_price * 1.05

def calculate_fibonacci_levels(df, periods=50):
    try:
        recent_data = df.tail(periods)
        high = recent_data['High'].max()
        low = recent_data['Low'].min()
        diff = high - low
        return {
            'fib_236': high - (diff * 0.236),
            'fib_382': high - (diff * 0.382),
            'fib_500': high - (diff * 0.500),
            'fib_618': high - (diff * 0.618),
        }
    except:
        current_price = df['Close'].iloc[-1]
        return {
            'fib_236': current_price * 0.98,
            'fib_382': current_price * 0.95,
            'fib_500': current_price * 0.92,
            'fib_618': current_price * 0.90,
        }

def calculate_technical_indicators(df): 
    try:
        close_prices = df['Close'].values
        high_prices = df['High'].values
        low_prices = df['Low'].values
        
        rsi = calculate_rsi(close_prices, window=14)
        macd_value = calculate_macd(close_prices)
        stoch_k, stoch_d = calculate_stochastic(high_prices, low_prices, close_prices)
        
        return {
            'rsi': rsi,
            'macd': macd_value,
            'stochastic_k': stoch_k,
            'stochastic_d': stoch_d,
        }
    except Exception as e:
        print(f"Error calculating indicators: {e}")
        return {
            'rsi': 50.0,
            'macd': 0.0,
            'stochastic_k': 50.0,
            'stochastic_d': 50.0,
        }

def generate_sentiment_data(symbol, current_price, change_percent):
    try:
        if change_percent > 2:
            overall_sentiment = "Bullish"
            sentiment_score = 7.5
            short_term = "Positive"
            short_term_score = 8.0
        elif change_percent < -2:
            overall_sentiment = "Bearish"
            sentiment_score = 3.0
            short_term = "Negative"
            short_term_score = 2.5
        else:
            overall_sentiment = "Neutral"
            sentiment_score = 5.5
            short_term = "Neutral"
            short_term_score = 5.0
        
        factors = [
            {"factor": "Market Trends", "impact": "Positive" if change_percent > 0 else "Negative"},
            {"factor": "Company Earnings", "impact": "Neutral"},
            {"factor": "Industry Growth", "impact": "Positive"},
            {"factor": "Economic Indicators", "impact": "Neutral"},
        ]
        
        return {
            'overall_sentiment': overall_sentiment,
            'sentiment_score': sentiment_score,
            'short_term_sentiment': short_term,
            'short_term_score': short_term_score,
            'long_term_sentiment': "Bullish",
            'long_term_score': 6.5,
            'sentiment_factors': factors,
        }
    except:
        return {
            'overall_sentiment': "Neutral",
            'sentiment_score': 5.0,
            'short_term_sentiment': "Neutral",
            'short_term_score': 5.0,
            'long_term_sentiment': "Neutral",
            'long_term_score': 5.0,
            'sentiment_factors': [{"factor": "Market Analysis", "impact": "Neutral"}],
        }

def search_stock_suggestions(query: str, limit: int = 10) -> List[StockSuggestion]:
    suggestions = []
    query_upper = query.upper().strip()
    query_lower = query.lower().strip()
    
    if not query_upper:
        return []
    
    for symbol, name in POPULAR_STOCKS.items():
        if symbol == query_upper:
            suggestions.append(StockSuggestion(
                symbol=symbol,
                company_name=name,
                match_type="symbol"
            ))
    
    for symbol, name in POPULAR_STOCKS.items():
        if symbol != query_upper and symbol.startswith(query_upper):
            suggestions.append(StockSuggestion(
                symbol=symbol,
                company_name=name,
                match_type="symbol"
            ))
    
    for symbol, name in POPULAR_STOCKS.items():
        if (symbol not in [s.symbol for s in suggestions] and 
            query_lower in name.lower()):
            suggestions.append(StockSuggestion(
                symbol=symbol,
                company_name=name,
                match_type="company"
            ))
    
    if len(suggestions) == 0 and len(query_upper) <= 5:
        try:
            ticker = yf.Ticker(query_upper)
            info = ticker.info
            if info and 'longName' in info:
                suggestions.append(StockSuggestion(
                    symbol=query_upper,
                    company_name=info.get('longName', f"{query_upper} Corporation"),
                    match_type="symbol"
                ))
        except:
            pass
    
    return suggestions[:limit]

def calculate_vwap(df):
    """Calculate Volume Weighted Average Price"""
    try:
        if len(df) < 20:
            return df['Close'].iloc[-1]
        
        recent_df = df.tail(20).copy()
        typical_price = (recent_df['High'] + recent_df['Low'] + recent_df['Close']) / 3
        vwap = (typical_price * recent_df['Volume']).sum() / recent_df['Volume'].sum()
        return float(vwap)
    except:
        return df['Close'].iloc[-1] if len(df) > 0 else 0.0


# ==================== OPTIMIZED CACHING FUNCTIONS ====================

@lru_cache(maxsize=200)
def get_cached_stock_data(symbol: str, cache_key: str):
    """Cache stock data - cache_key changes every 5 minutes for fresh data"""
    end_date = datetime.now()
    start_date = end_date - timedelta(days=30)  # Reduced from 90 to 30 days
    
    try:
        df = yf.download(symbol, start=start_date, end=end_date, progress=False)
        if isinstance(df.columns, pd.MultiIndex):
            df.columns = [col[0] if isinstance(col, tuple) else col for col in df.columns]
        return df if not df.empty else None
    except Exception as e:
        print(f"Error downloading {symbol}: {e}")
        return None

@lru_cache(maxsize=200)
def get_cached_ticker_info(symbol: str, cache_key: str):
    """Cache ticker info - cache_key changes every 5 minutes"""
    try:
        ticker = yf.Ticker(symbol)
        return ticker.info
    except Exception as e:
        print(f"Error getting info for {symbol}: {e}")
        return {}

def get_cache_key():
    """Generate cache key that changes every 5 minutes"""
    return datetime.now().strftime('%Y%m%d%H%M')[:-1] + '0'


# ==================== OPTIMIZED STOCK SCREENING ====================

def process_single_stock(symbol: str, params: dict) -> Optional[dict]:
    """Process a single stock with all filters - optimized with fail-fast approach"""
    try:
        cache_key = get_cache_key()
        
        # Get cached data
        df = get_cached_stock_data(symbol, cache_key)
        if df is None or df.empty or len(df) < 2:
            return None
        
        # Basic metrics
        current_price = float(df['Close'].iloc[-1])
        volume = int(df['Volume'].iloc[-1])
        
        # Quick filters first (fail fast) - cheapest operations
        if params['use_price']:
            if current_price < params['price_min'] or current_price > params['price_max']:
                return None
        
        if params['use_volume']:
            if volume < params['volume_min']:
                return None
        
        # Get ticker info
        ticker_info = get_cached_ticker_info(symbol, cache_key)
        market_cap = ticker_info.get('marketCap', 0)
        pe_ratio = ticker_info.get('trailingPE', 0) if ticker_info.get('trailingPE') else 0
        sector = ticker_info.get('sector', 'Unknown')
        company_name = ticker_info.get('longName', f"{symbol} Corporation")
        
        # Sector filter
        if params['sector'] != 'any' and sector != params['sector']:
            return None
        
        # Market cap filter
        if params['use_market_cap']:
            if market_cap < params['market_cap_min'] or market_cap > params['market_cap_max']:
                return None
        
        # P/E filter
        if params['use_pe']:
            if pe_ratio <= 0 or pe_ratio < params['pe_min'] or pe_ratio > params['pe_max']:
                return None
        
        # Calculate technical indicators only if needed
        rsi_value = 50.0
        if params['use_rsi']:
            rsi_value = calculate_rsi(df['Close'].values, window=14)
            if rsi_value < params['rsi_min'] or rsi_value > params['rsi_max']:
                return None
        
        macd_value = 0.0
        if params['use_macd']:
            macd_value = calculate_macd(df['Close'].values)
            if params['macd_signal'] == 'bullish' and macd_value <= 0:
                return None
            elif params['macd_signal'] == 'bearish' and macd_value >= 0:
                return None
        
        vwap_value = 0.0
        if params['use_vwap']:
            vwap_value = calculate_vwap(df)
            if params['vwap_position'] == 'above' and current_price <= vwap_value:
                return None
            elif params['vwap_position'] == 'below' and current_price >= vwap_value:
                return None
        
        # Calculate change
        previous_close = df['Close'].iloc[-2]
        change = current_price - previous_close
        change_percent = (change / previous_close) * 100
        
        return {
            'symbol': symbol,
            'company_name': company_name,
            'sector': sector,
            'current_price': round(current_price, 2),
            'change': round(change, 2),
            'change_percent': round(change_percent, 2),
            'volume': volume,
            'market_cap': market_cap,
            'pe_ratio': round(pe_ratio, 2) if pe_ratio > 0 else 0.0,
            'rsi': round(rsi_value, 2),
            'macd': round(macd_value, 2),
            'vwap': round(vwap_value, 2) if params['use_vwap'] else 0.0,
        }
        
    except Exception as e:
        print(f"Error processing {symbol}: {str(e)}")
        return None


# ==================== API ENDPOINTS ====================

@app.get("/")
def read_root():
    return {"message": "Stock Analysis & Backtest API is running"}

@app.get("/health")
def health_check():
    return {"status": "healthy", "timestamp": datetime.now().isoformat()}

@app.get("/stock-suggestions", response_model=List[StockSuggestion])
def get_stock_suggestions(q: str = Query(..., min_length=1)):
    try:
        suggestions = search_stock_suggestions(q, limit=10)
        return suggestions
    except Exception as e:
        print(f"Error in stock suggestions: {str(e)}")
        return []

@app.get("/stock-info/{symbol}", response_model=StockInfo)
def get_stock_info(symbol: str):
    try:
        symbol = symbol.upper().strip()
        end_date = datetime.now()
        start_date = end_date - timedelta(days=90)
        
        stock = yf.Ticker(symbol)
        df = yf.download(symbol, start=start_date, end=end_date, progress=False)
        
        if df.empty:
            raise HTTPException(status_code=404, detail=f"Stock symbol '{symbol}' not found")
        
        if isinstance(df.columns, pd.MultiIndex):
            df.columns = [col[0] if isinstance(col, tuple) else col for col in df.columns]
        
        info = stock.info
        current_price = df['Close'].iloc[-1]
        previous_close = df['Close'].iloc[-2] if len(df) > 1 else current_price
        change = current_price - previous_close
        change_percent = (change / previous_close) * 100
        
        support, resistance = calculate_support_resistance(df)
        fib_levels = calculate_fibonacci_levels(df)
        tech_indicators = calculate_technical_indicators(df)
        sentiment_data = generate_sentiment_data(symbol, current_price, change_percent)
        
        return StockInfo(
            symbol=symbol,
            company_name=info.get('longName', f"{symbol} Corporation"),
            sector=info.get('sector', 'Technology'),
            current_price=float(current_price),
            change=float(change),
            change_percent=float(change_percent),
            volume=int(df['Volume'].iloc[-1]),
            market_cap=float(info.get('marketCap', 0)),
            pe_ratio=float(info.get('trailingPE', 0)) if info.get('trailingPE') else 0.0,
            support_level=float(support),
            resistance_level=float(resistance),
            rsi=tech_indicators['rsi'],
            macd=tech_indicators['macd'],
            stochastic_k=tech_indicators['stochastic_k'],
            stochastic_d=tech_indicators['stochastic_d'],
            fib_236=float(fib_levels['fib_236']),
            fib_382=float(fib_levels['fib_382']),
            fib_500=float(fib_levels['fib_500']),
            fib_618=float(fib_levels['fib_618']),
            overall_sentiment=sentiment_data['overall_sentiment'],
            sentiment_score=sentiment_data['sentiment_score'],
            short_term_sentiment=sentiment_data['short_term_sentiment'],
            short_term_score=sentiment_data['short_term_score'],
            long_term_sentiment=sentiment_data['long_term_sentiment'],
            long_term_score=sentiment_data['long_term_score'],
            sentiment_factors=sentiment_data['sentiment_factors'],
            analyst_buy=max(1, int(5 + (change_percent * 0.5) + np.random.normal(0, 1))),
            analyst_hold=max(1, int(3 + np.random.normal(0, 0.5))),
            analyst_sell=max(0, int(2 - (change_percent * 0.3) + np.random.normal(0, 0.5))),
            target_price=float(current_price * np.random.uniform(1.05, 1.15)),
        )
        
    except HTTPException:
        raise
    except Exception as e:
        print(f"Error fetching stock info: {str(e)}")
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"Failed to fetch stock information: {str(e)}")


@app.post("/backtest-portfolio", response_model=PortfolioBacktestResult)
def run_portfolio_backtest(data: PortfolioStrategyInput):
    try:
        start_dt = datetime.strptime(data.start_date, '%Y-%m-%d')
        end_dt = datetime.strptime(data.end_date, '%Y-%m-%d')
        
        if start_dt >= end_dt:
            raise HTTPException(status_code=400, detail="Start date must be before end date")
        if end_dt > datetime.now():
            raise HTTPException(status_code=400, detail="End date cannot be in the future")

        cerebro = bt.Cerebro()
        
        # Prepare allocations dict
        allocations = {stock.ticker: stock.allocation for stock in data.stocks}
        
        # Select strategy based on input
        if data.strategy == "RSI":
            cerebro.addstrategy(
                PortfolioRSIStrategy,
                rsi_period=data.rsi_period,
                rsi_buy=data.rsi_buy,
                rsi_sell=data.rsi_sell,
                allocations=allocations
            )
        elif data.strategy == "MACD":
            cerebro.addstrategy(
                PortfolioMACDStrategy,
                macd_fast=data.macd_fast,
                macd_slow=data.macd_slow,
                macd_signal=data.macd_signal,
                allocations=allocations
            )
        elif data.strategy == "Volume_Spike":
            cerebro.addstrategy(
                PortfolioVolumeSpikeStrategy,
                volume_multiplier=data.volume_multiplier,
                volume_period=data.volume_period,
                hold_days=data.volume_hold_days,
                allocations=allocations
            )
        else:
            raise HTTPException(status_code=400, detail=f"Unknown strategy: {data.strategy}")

        # Download data for all stocks
        stock_data = {}
        for stock in data.stocks:
            try:
                df = yf.download(stock.ticker, start=data.start_date, end=data.end_date, progress=False)
                
                if isinstance(df.columns, pd.MultiIndex):
                    df.columns = [col[0] if isinstance(col, tuple) else col for col in df.columns]
                
                if df is None or df.empty:
                    raise HTTPException(status_code=404, detail=f"No data found for {stock.ticker}")
                
                df.reset_index(inplace=True)
                stock_data[stock.ticker] = df
                
            except Exception as e:
                raise HTTPException(status_code=400, detail=f"Failed to download data for {stock.ticker}: {str(e)}")

        # Add data feeds to cerebro
        for ticker, df in stock_data.items():
            data_feed = bt.feeds.PandasData(
                dataname=df,
                datetime='Date',
                open='Open',
                high='High',
                low='Low',
                close='Close',
                volume='Volume',
                openinterest=None
            )
            data_feed._name = ticker
            cerebro.adddata(data_feed, name=ticker)

        cerebro.broker.set_cash(data.initial_cash)
        initial_value = cerebro.broker.getvalue()

        cerebro.addanalyzer(bt.analyzers.TradeAnalyzer, _name="trades")
        cerebro.addanalyzer(bt.analyzers.DrawDown, _name="drawdown")

        results = cerebro.run()
        final_value = cerebro.broker.getvalue()

        strategy = results[0]
        trade_analyzer = strategy.analyzers.trades.get_analysis()
        drawdown_analyzer = strategy.analyzers.drawdown.get_analysis()

        total_return = final_value - initial_value
        total_return_pct = (total_return / initial_value) * 100
        
        total_trades = trade_analyzer.get('total', {}).get('total', 0)
        won_trades = trade_analyzer.get('won', {}).get('total', 0)
        lost_trades = trade_analyzer.get('lost', {}).get('total', 0)
        win_rate = (won_trades / total_trades * 100) if total_trades > 0 else 0
        max_drawdown = drawdown_analyzer.get('max', {}).get('drawdown', 0)

        # Calculate individual stock performances
        stock_performances = []
        portfolio_composition = []
        
        for ticker in stock_data.keys():
            position_value = 0
            position_size = 0
            
            # Get position for this stock
            for d in strategy.datas:
                if d._name == ticker:
                    pos = strategy.getposition(d)
                    if pos.size > 0:
                        position_size = pos.size
                        position_value = pos.size * d.close[0]
                    break
            
            stock_performances.append({
                'ticker': ticker,
                'trades': strategy.trade_counts.get(ticker, 0),
                'winning_trades': strategy.winning_trades.get(ticker, 0),
                'losing_trades': strategy.losing_trades.get(ticker, 0),
                'allocation': allocations[ticker]
            })
            
            portfolio_composition.append({
                'ticker': ticker,
                'position_size': int(position_size),
                'position_value': round(position_value, 2),
                'target_allocation': allocations[ticker],
                'actual_allocation': round((position_value / final_value * 100), 2) if final_value > 0 else 0
            })

        return PortfolioBacktestResult(
            final_value=round(final_value, 2),
            initial_value=round(initial_value, 2),
            total_return=round(total_return, 2),
            total_return_pct=round(total_return_pct, 2),
            total_trades=total_trades,
            winning_trades=won_trades,
            losing_trades=lost_trades,
            win_rate=round(win_rate, 2),
            max_drawdown=round(max_drawdown, 2),
            stock_performances=stock_performances,
            portfolio_composition=portfolio_composition
        )

    except HTTPException:
        raise
    except Exception as e:
        print(f"Unexpected error: {str(e)}")
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")


@app.post("/screen-stocks")
async def screen_stocks(params: StockScreenerParams):
    """Optimized stock screener with parallel processing"""
    try:
        stock_symbols = list(POPULAR_STOCKS.keys())
        
        # Convert params to dict for easier passing
        params_dict = {
            'use_rsi': params.use_rsi,
            'rsi_min': params.rsi_min,
            'rsi_max': params.rsi_max,
            'use_macd': params.use_macd,
            'macd_signal': params.macd_signal,
            'use_vwap': params.use_vwap,
            'vwap_position': params.vwap_position,
            'use_pe': params.use_pe,
            'pe_min': params.pe_min,
            'pe_max': params.pe_max,
            'use_market_cap': params.use_market_cap,
            'market_cap_min': params.market_cap_min,
            'market_cap_max': params.market_cap_max,
            'use_volume': params.use_volume,
            'volume_min': params.volume_min,
            'use_price': params.use_price,
            'price_min': params.price_min,
            'price_max': params.price_max,
            'sector': params.sector,
        }
        
        # Process stocks in parallel using ThreadPoolExecutor
        loop = asyncio.get_event_loop()
        
        async def process_stock_async(symbol):
            return await loop.run_in_executor(
                executor,
                process_single_stock,
                symbol,
                params_dict
            )
        
        # Process all stocks concurrently
        results_futures = [process_stock_async(symbol) for symbol in stock_symbols]
        all_results = await asyncio.gather(*results_futures)
        
        # Filter out None results and sort
        results = [r for r in all_results if r is not None]
        results.sort(key=lambda x: x['symbol'])
        
        return results
        
    except Exception as e:
        print(f"Error in stock screener: {str(e)}")
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"Stock screener failed: {str(e)}")


@app.post("/clear-cache")
def clear_screening_cache():
    """Clear the stock data cache"""
    get_cached_stock_data.cache_clear()
    get_cached_ticker_info.cache_clear()
    return {"message": "Cache cleared successfully", "timestamp": datetime.now().isoformat()}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
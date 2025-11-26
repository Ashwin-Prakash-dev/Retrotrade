def rate_limited_download(symbol: str, start, end, max_retries=3):
    """Download stock data with rate limiting and retry logic"""
    global LAST_REQUEST_TIME
    
    # Rate limiting
    current_time = time.time()
    if symbol in LAST_REQUEST_TIME:
        time_since_last = current_time - LAST_REQUEST_TIME[symbol]
        if time_since_last < MIN_REQUEST_INTERVAL:
            time.sleep(MIN_REQUEST_INTERVAL - time_since_last)
    
    for attempt in range(max_retries):
        try:
            # Add random delay to avoid burst requests
            if attempt > 0:
                delay = random.uniform(1, 3) * (attempt + 1)
                print(f"Retry {attempt + 1} for {symbol} after {delay:.2f}s delay")
                time.sleep(delay)
            
            LAST_REQUEST_TIME[symbol] = time.time()
            
            # Simple approach: just use period which works more reliably
            print(f"Downloading {symbol} with period='3mo'")
            ticker = yf.Ticker(symbol)
            df = ticker.history(period="3mo")
            
            if isinstance(df.columns, pd.MultiIndex):
                df.columns = [col[0] if isinstance(col, tuple) else col for col in df.columns]
            
            if df.empty:
                print(f"No data returned for {symbol}")
                return None
            
            # Ensure required columns exist
            required_cols = ['Open', 'High', 'Low', 'Close', 'Volume']
            missing_cols = [col for col in required_cols if col not in df.columns]
            if missing_cols:
                print(f"Missing columns for {symbol}: {missing_cols}")
                return None
            
            print(f"Successfully downloaded {len(df)} rows for {symbol}")
            return df
            
        except Exception as e:
            error_msg = str(e).lower()
            print(f"Error downloading {symbol} (attempt {attempt + 1}): {type(e).__name__}: {e}")
            print(f"Full traceback: {traceback.format_exc()}")
            
            if '429' in error_msg or 'too many requests' in error_msg:
                if attempt < max_retries - 1:
                    wait_time = (attempt + 1) * 5
                    print(f"Rate limited on {symbol}, waiting {wait_time}s...")
                    time.sleep(wait_time)
                    continue
                else:
                    print(f"Max retries reached for {symbol} due to rate limiting")
                    return None
            else:
                if attempt < max_retries - 1:
                    time.sleep(2)
                    continue
                return None
    
    return None

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
import asyncio
from concurrent.futures import ThreadPoolExecutor
from functools import lru_cache
import time
import random
import os

# CRITICAL: Setting timezone environment variable BEFORE importing yfinance
os.environ['TZ'] = 'America/New_York'
if hasattr(time, 'tzset'):
    time.tzset()

app = FastAPI(title="Stock Analysis & Backtest API", version="1.0.0")

# Thread pool for parallel processing - REDUCED for rate limiting
executor = ThreadPoolExecutor(max_workers=3)

# CORS middleware for Flutter app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Rate limiting globals
LAST_REQUEST_TIME = {}
MIN_REQUEST_INTERVAL = 0.5  # 500ms between requests per symbol

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
    
    rsi_period: int = Field(default=14, ge=5, le=50)
    rsi_buy: int = Field(default=30, ge=0, le=100)
    rsi_sell: int = Field(default=70, ge=0, le=100)
    
    macd_fast: int = Field(default=12, ge=5, le=50)
    macd_slow: int = Field(default=26, ge=10, le=100)
    macd_signal: int = Field(default=9, ge=5, le=30)
    
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
    roe: float = 0.0
    debt_to_equity: float = 0.0
    pb_ratio: float = 0.0
    promoter_holding: float = 0.0
    public_holding: float = 0.0
    institutional_holding: float = 0.0
    shareholding_date: str = "Latest Quarter"
    major_shareholders: list = []
    recent_news: list = []

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

# Popular stock symbols (keeping your existing list)
POPULAR_STOCKS = {
    'AAPL': 'Apple Inc.', 'MSFT': 'Microsoft Corporation', 'GOOGL': 'Alphabet Inc. Class A',
    'GOOG': 'Alphabet Inc. Class C', 'AMZN': 'Amazon.com Inc.', 'TSLA': 'Tesla Inc.',
    'META': 'Meta Platforms Inc.', 'NVDA': 'NVIDIA Corporation', 'NFLX': 'Netflix Inc.',
    'ORCL': 'Oracle Corporation', 'ADBE': 'Adobe Inc.', 'CRM': 'Salesforce Inc.',
    'INTC': 'Intel Corporation', 'AMD': 'Advanced Micro Devices Inc.', 'IBM': 'International Business Machines Corporation',
    'JPM': 'JPMorgan Chase & Co.', 'BAC': 'Bank of America Corporation', 'WFC': 'Wells Fargo & Company',
    'GS': 'The Goldman Sachs Group Inc.', 'MS': 'Morgan Stanley', 'C': 'Citigroup Inc.',
    'V': 'Visa Inc.', 'MA': 'Mastercard Incorporated', 'PYPL': 'PayPal Holdings Inc.',
    'JNJ': 'Johnson & Johnson', 'PFE': 'Pfizer Inc.',
    'WMT': 'Walmart Inc.', 'PG': 'The Procter & Gamble Company', 'KO': 'The Coca-Cola Company',
}

# ==================== RATE LIMITED DOWNLOAD ====================

def rate_limited_download(symbol: str, start, end, max_retries=3):
    """Download stock data with rate limiting and retry logic"""
    global LAST_REQUEST_TIME
    
    # Rate limiting
    current_time = time.time()
    if symbol in LAST_REQUEST_TIME:
        time_since_last = current_time - LAST_REQUEST_TIME[symbol]
        if time_since_last < MIN_REQUEST_INTERVAL:
            time.sleep(MIN_REQUEST_INTERVAL - time_since_last)
    
    for attempt in range(max_retries):
        try:
            # Adding random delay to avoid burst requests
            if attempt > 0:
                delay = random.uniform(1, 3) * (attempt + 1)
                print(f"Retry {attempt + 1} for {symbol} after {delay:.2f}s delay")
                time.sleep(delay)
            
            LAST_REQUEST_TIME[symbol] = time.time()
            
            # Trying Ticker.history() first as it's more reliable
            print(f"Attempting to download {symbol} using Ticker.history()")
            ticker = yf.Ticker(symbol)
            df = ticker.history(start=start, end=end)
            
            # If fails or returns empty, ->standard download
            if df.empty:
                print(f"Ticker.history() returned empty for {symbol}, trying yf.download()")
                df = yf.download(
                    symbol, 
                    start=start, 
                    end=end, 
                    progress=False,
                    timeout=10
                )
            
            if isinstance(df.columns, pd.MultiIndex):
                df.columns = [col[0] if isinstance(col, tuple) else col for col in df.columns]
            
            if df.empty:
                print(f"No data returned for {symbol}")
                return None
            
            # Ensure required columns exist
            required_cols = ['Open', 'High', 'Low', 'Close', 'Volume']
            missing_cols = [col for col in required_cols if col not in df.columns]
            if missing_cols:
                print(f"Missing columns for {symbol}: {missing_cols}")
                return None
            
            print(f"Successfully downloaded {len(df)} rows for {symbol}")
            return df
            
        except Exception as e:
            error_msg = str(e).lower()
            print(f"Error downloading {symbol} (attempt {attempt + 1}): {e}")
            
            if '429' in error_msg or 'too many requests' in error_msg:
                if attempt < max_retries - 1:
                    wait_time = (attempt + 1) * 5  # Exponential backoff
                    print(f"Rate limited on {symbol}, waiting {wait_time}s...")
                    time.sleep(wait_time)
                    continue
                else:
                    print(f"Max retries reached for {symbol} due to rate limiting")
                    return None
            elif 'delisted' in error_msg or 'timezone' in error_msg or 'yftz' in error_msg:
                # known yfinance issues
                print(f"Known yfinance issue for {symbol}: {error_msg}")
                if attempt < max_retries - 1:
                    # Trying once more with increased delay
                    time.sleep(2)
                    continue
                return None
            else:
                if attempt < max_retries - 1:
                    continue
                return None
    
    return None

def rate_limited_ticker_info(symbol: str, max_retries=3):
    """Get ticker info with rate limiting and retry logic"""
    global LAST_REQUEST_TIME
    
    # Rate limiting
    current_time = time.time()
    if symbol in LAST_REQUEST_TIME:
        time_since_last = current_time - LAST_REQUEST_TIME[symbol]
        if time_since_last < MIN_REQUEST_INTERVAL:
            time.sleep(MIN_REQUEST_INTERVAL - time_since_last)
    
    for attempt in range(max_retries):
        try:
            if attempt > 0:
                delay = random.uniform(1, 3) * (attempt + 1)
                print(f"Retry {attempt + 1} for {symbol} info after {delay:.2f}s delay")
                time.sleep(delay)
            
            LAST_REQUEST_TIME[symbol] = time.time()
            
            ticker = yf.Ticker(symbol)
            
            # get info with error handling
            try:
                info = ticker.info
            except Exception as info_error:
                error_str = str(info_error).lower()
                if 'expecting value' in error_str or 'json' in error_str:
                    print(f"JSON decode error for {symbol}, trying fast_info...")
                    # Try fast_info as fallback
                    try:
                        fast_info = ticker.fast_info
                        # Convert fast_info to dict-like structure
                        info = {
                            'symbol': symbol,
                            'longName': f"{symbol} Corporation",
                            'sector': 'Technology',
                            'marketCap': getattr(fast_info, 'market_cap', 0),
                            'previousClose': getattr(fast_info, 'previous_close', 0),
                        }
                    except:
                        print(f"fast_info also failed for {symbol}, returning minimal info")
                        info = {
                            'symbol': symbol,
                            'longName': f"{symbol} Corporation",
                            'sector': 'Technology',
                        }
                else:
                    raise info_error
            
            # Check if valid info
            if not info or len(info) < 2:
                print(f"Invalid or empty info returned for {symbol}")
                if attempt < max_retries - 1:
                    continue
                # Return minimal info instead of empty dict
                return {
                    'symbol': symbol,
                    'longName': f"{symbol} Corporation",
                    'sector': 'Technology',
                }
            
            return info
            
        except Exception as e:
            error_msg = str(e).lower()
            print(f"Error getting info for {symbol} (attempt {attempt + 1}): {e}")
            
            if '429' in error_msg or 'too many requests' in error_msg:
                if attempt < max_retries - 1:
                    wait_time = (attempt + 1) * 5
                    print(f"Rate limited on {symbol} info, waiting {wait_time}s...")
                    time.sleep(wait_time)
                    continue
                else:
                    print(f"Max retries reached for {symbol} info due to rate limiting")
                    return {
                        'symbol': symbol,
                        'longName': f"{symbol} Corporation",
                        'sector': 'Technology',
                    }
            else:
                if attempt < max_retries - 1:
                    continue
                # Return minimal info on final failure
                return {
                    'symbol': symbol,
                    'longName': f"{symbol} Corporation",
                    'sector': 'Technology',
                }
    
    return {
        'symbol': symbol,
        'longName': f"{symbol} Corporation",
        'sector': 'Technology',
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
            if self.macd.macd[0] > self.macd.signal[0] and self.macd.macd[-1] <= self.macd.signal[-1]:
                self.buy(size=None)
        else:
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
            if self.data.volume[0] > (self.volume_sma[0] * self.params.volume_multiplier):
                self.buy(size=None)
                self.hold_counter = 0
        else:
            self.hold_counter += 1
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


# Portfolio strategies 
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
                if len(d) > 1:
                    if macd.macd[0] > macd.signal[0] and macd.macd[-1] <= macd.signal[-1]:
                        available_cash = self.broker.getcash()
                        target_value = available_cash * allocation
                        size = int(target_value / d.close[0])
                        if size > 0:
                            self.buy(data=d, size=size)
            else:
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
                if d.volume[0] > (volume_sma[0] * self.params.volume_multiplier):
                    available_cash = self.broker.getcash()
                    target_value = available_cash * allocation
                    size = int(target_value / d.close[0])
                    if size > 0:
                        self.buy(data=d, size=size)
                        self.hold_counters[d._name] = 0
            else:
                self.hold_counters[d._name] += 1
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


# ==================== API ENDPOINTS ====================

@app.get("/")
def read_root():
    return {"message": "Stock Analysis & Backtest API is running with rate limiting"}

@app.get("/health")
def health_check():
    return {"status": "healthy", "timestamp": datetime.now().isoformat()}

@app.get("/debug/yfinance-test")
def test_yfinance():
    """Test endpoint to diagnose Yahoo Finance API issues"""
    results = {
        "timestamp": datetime.now().isoformat(),
        "yfinance_version": yf.__version__,
        "tests": []
    }
    
    # Test a simple ticker
    test_symbol = "AAPL"
    try:
        ticker = yf.Ticker(test_symbol)
        df = ticker.history(period="5d")
        
        results["tests"].append({
            "method": "Ticker.history()",
            "symbol": test_symbol,
            "status": "success" if not df.empty else "empty_data",
            "rows": len(df),
            "columns": list(df.columns) if not df.empty else []
        })
    except Exception as e:
        results["tests"].append({
            "method": "Ticker.history()",
            "symbol": test_symbol,
            "status": "error",
            "error": str(e)
        })
    
    try:
        df = yf.download(test_symbol, period="5d", progress=False)
        results["tests"].append({
            "method": "yf.download()",
            "symbol": test_symbol,
            "status": "success" if not df.empty else "empty_data",
            "rows": len(df),
            "columns": list(df.columns) if not df.empty else []
        })
    except Exception as e:
        results["tests"].append({
            "method": "yf.download()",
            "symbol": test_symbol,
            "status": "error",
            "error": str(e)
        })
    
    return results

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
        
        print(f"Fetching stock info for: {symbol}")
        df = rate_limited_download(symbol, start_date, end_date)
        
        if df is None or df.empty:
            # To check if this is Yahoo Finance issue 
            error_detail = (
                f"Unable to fetch data for '{symbol}'. This could be due to:\n"
                f"1. Invalid ticker symbol\n"
                f"2. Yahoo Finance API issues (common with timezone errors)\n"
                f"3. The stock may be delisted\n\n"
                f"Try:\n"
                f"- Using a different ticker symbol\n"
                f"- Waiting a few minutes if Yahoo Finance is having issues\n"
                f"- Checking if the symbol is correct (e.g., use 'AAPL' not 'APPLE')"
            )
            raise HTTPException(status_code=404, detail=error_detail)
        
        info = rate_limited_ticker_info(symbol)
        current_price = df['Close'].iloc[-1]
        previous_close = df['Close'].iloc[-2] if len(df) > 1 else current_price
        change = current_price - previous_close
        change_percent = (change / previous_close) * 100
        
        support, resistance = calculate_support_resistance(df)
        fib_levels = calculate_fibonacci_levels(df)
        tech_indicators = calculate_technical_indicators(df)
        sentiment_data = generate_sentiment_data(symbol, current_price, change_percent)
        
        # Safely extract info with fallbacks
        roe = 0.0
        if info.get('returnOnEquity'):
            try:
                roe = float(info.get('returnOnEquity', 0) * 100)
            except:
                roe = 0.0
        
        debt_to_equity = 0.0
        if info.get('debtToEquity'):
            try:
                debt_to_equity = float(info.get('debtToEquity', 0) / 100)
            except:
                debt_to_equity = 0.0
        
        pb_ratio = 0.0
        if info.get('priceToBook'):
            try:
                pb_ratio = float(info.get('priceToBook', 0))
            except:
                pb_ratio = 0.0
        
        pe_ratio = 0.0
        if info.get('trailingPE'):
            try:
                pe_ratio = float(info.get('trailingPE', 0))
            except:
                pe_ratio = 0.0
        
        market_cap = 0.0
        if info.get('marketCap'):
            try:
                market_cap = float(info.get('marketCap', 0))
            except:
                market_cap = 0.0
        
        return StockInfo(
            symbol=symbol,
            company_name=info.get('longName', f"{symbol} Corporation"),
            sector=info.get('sector', 'Technology'),
            current_price=float(current_price),
            change=float(change),
            change_percent=float(change_percent),
            volume=int(df['Volume'].iloc[-1]),
            market_cap=market_cap,
            pe_ratio=pe_ratio,
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
            roe=roe,
            debt_to_equity=debt_to_equity,
            pb_ratio=pb_ratio,
        )
        
    except HTTPException:
        raise
    except Exception as e:
        print(f"Error fetching stock info: {str(e)}")
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"Failed to fetch stock information: {str(e)}")


@app.post("/backtest-portfolio")
def run_portfolio_backtest(data: PortfolioStrategyInput):
    try:
        start_dt = datetime.strptime(data.start_date, '%Y-%m-%d')
        end_dt = datetime.strptime(data.end_date, '%Y-%m-%d')
        
        if start_dt >= end_dt:
            raise HTTPException(status_code=400, detail="Start date must be before end date")
        if end_dt > datetime.now():
            raise HTTPException(status_code=400, detail="End date cannot be in the future")

        cerebro = bt.Cerebro()
        
        allocations = {stock.ticker: stock.allocation for stock in data.stocks}
        
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

        stock_data = {}
        for stock in data.stocks:
            try:
                print(f"Downloading data for {stock.ticker}")
                df = rate_limited_download(stock.ticker, data.start_date, data.end_date)
                
                if df is None or df.empty:
                    raise HTTPException(status_code=404, detail=f"No data found for {stock.ticker}")
                
                df.reset_index(inplace=True)
                stock_data[stock.ticker] = df
                
            except Exception as e:
                raise HTTPException(status_code=400, detail=f"Failed to download data for {stock.ticker}: {str(e)}")

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

        stock_performances = []
        portfolio_composition = []
        
        for ticker in stock_data.keys():
            position_value = 0
            position_size = 0
            
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

        return {
            'final_value': round(final_value, 2),
            'initial_value': round(initial_value, 2),
            'total_return': round(total_return, 2),
            'total_return_pct': round(total_return_pct, 2),
            'total_trades': total_trades,
            'winning_trades': won_trades,
            'losing_trades': lost_trades,
            'win_rate': round(win_rate, 2),
            'max_drawdown': round(max_drawdown, 2),
            'stock_performances': stock_performances,
            'portfolio_composition': portfolio_composition
        }

    except HTTPException:
        raise
    except Exception as e:
        print(f"Unexpected error: {str(e)}")
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")


def process_single_stock(symbol: str, params: dict) -> Optional[dict]:
    """Process a single stock with all filters - WITH RATE LIMITING"""
    try:
        end_date = datetime.now()
        start_date = end_date - timedelta(days=30)
        
        df = rate_limited_download(symbol, start_date, end_date)
        if df is None or df.empty or len(df) < 2:
            return None
        
        current_price = float(df['Close'].iloc[-1])
        volume = int(df['Volume'].iloc[-1])
        
        if params['use_price']:
            if current_price < params['price_min'] or current_price > params['price_max']:
                return None
        
        if params['use_volume']:
            if volume < params['volume_min']:
                return None
        
        ticker_info = rate_limited_ticker_info(symbol)
        market_cap = ticker_info.get('marketCap', 0)
        pe_ratio = ticker_info.get('trailingPE', 0) if ticker_info.get('trailingPE') else 0
        sector = ticker_info.get('sector', 'Unknown')
        company_name = ticker_info.get('longName', f"{symbol} Corporation")
        
        if params['sector'] != 'any' and sector != params['sector']:
            return None
        
        if params['use_market_cap']:
            if market_cap < params['market_cap_min'] or market_cap > params['market_cap_max']:
                return None
        
        if params['use_pe']:
            if pe_ratio <= 0 or pe_ratio < params['pe_min'] or pe_ratio > params['pe_max']:
                return None
        
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


@app.post("/screen-stocks")
async def screen_stocks(params: StockScreenerParams):
    """Stock screener with SEQUENTIAL processing to avoid rate limiting"""
    try:
        # Using a smaller subset of stocks to avoid rate limits
        stock_symbols = list(POPULAR_STOCKS.keys())[:30]  # Limit to 30 stocks
        
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
        
        # Process stocks SEQUENTIALLY to avoid rate limiting
        results = []
        for symbol in stock_symbols:
            result = process_single_stock(symbol, params_dict)
            if result is not None:
                results.append(result)
            # Small delay between requests
            await asyncio.sleep(0.2)
        
        results.sort(key=lambda x: x['symbol'])
        
        return results
        
    except Exception as e:
        print(f"Error in stock screener: {str(e)}")
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"Stock screener failed: {str(e)}")


@app.get("/market-overview")
def get_market_overview():
    """Get market overview data including indices, commodities, and news"""
    try:
        indices_symbols = {
            '^NSEI': 'NIFTY 50',
            '^BSESN': 'SENSEX',
            '^NSEBANK': 'NIFTY BANK',
            '^GSPC': 'S&P 500',
        }
        
        indices = []
        for symbol, name in indices_symbols.items():
            try:
                ticker = yf.Ticker(symbol)
                hist = ticker.history(period="2d")
                
                if not hist.empty and len(hist) >= 2:
                    current_price = float(hist['Close'].iloc[-1])
                    previous_price = float(hist['Close'].iloc[-2])
                    change = current_price - previous_price
                    change_percent = (change / previous_price) * 100
                    
                    indices.append({
                        'name': name,
                        'value': round(current_price, 2),
                        'change': round(change, 2),
                        'changePercent': round(change_percent, 2)
                    })
            except Exception as e:
                print(f"Error fetching {name}: {e}")
                continue
        
        # Commodities 
        commodities_symbols = {
            'GC=F': {'name': 'Gold', 'unit': 'USD/oz'},
            'CL=F': {'name': 'Crude Oil', 'unit': 'USD/bbl'},
            'SI=F': {'name': 'Silver', 'unit': 'USD/oz'},
        }
        
        commodities = []
        for symbol, info in commodities_symbols.items():
            try:
                ticker = yf.Ticker(symbol)
                hist = ticker.history(period="2d")
                
                if not hist.empty and len(hist) >= 2:
                    current_price = float(hist['Close'].iloc[-1])
                    previous_price = float(hist['Close'].iloc[-2])
                    change = current_price - previous_price
                    
                    commodities.append({
                        'name': info['name'],
                        'value': round(current_price, 2),
                        'change': round(change, 2),
                        'unit': info['unit']
                    })
            except Exception as e:
                print(f"Error fetching {info['name']}: {e}")
                continue
        
        # Generate sample news 
        from datetime import datetime, timedelta
        
        news = [
            {
                'title': 'Markets show mixed signals amid global economic data',
                'time': _get_time_ago(datetime.now() - timedelta(hours=2)),
                'source': 'Reuters'
            },
            {
                'title': 'Tech stocks rally on AI optimism and earnings',
                'time': _get_time_ago(datetime.now() - timedelta(hours=4)),
                'source': 'Bloomberg'
            },
            {
                'title': 'Central banks signal cautious approach to rate cuts',
                'time': _get_time_ago(datetime.now() - timedelta(hours=5)),
                'source': 'CNBC'
            },
        ]
        
        return {
            'indices': indices,
            'commodities': commodities,
            'news': news,
            'timestamp': datetime.now().isoformat()
        }
        
    except Exception as e:
        print(f"Error in market overview: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Failed to fetch market data: {str(e)}")

def _get_time_ago(dt: datetime) -> str:
    """Convert datetime to human-readable time ago format"""
    now = datetime.now()
    diff = now - dt
    
    hours = int(diff.total_seconds() / 3600)
    minutes = int((diff.total_seconds() % 3600) / 60)
    
    if hours > 0:
        return f"{hours} hour{'s' if hours > 1 else ''} ago"
    elif minutes > 0:
        return f"{minutes} minute{'s' if minutes > 1 else ''} ago"
    else:
        return "Just now"

@app.post("/clear-cache")
def clear_screening_cache():
    """Clear rate limiting history"""
    global LAST_REQUEST_TIME
    LAST_REQUEST_TIME = {}
    return {"message": "Rate limit cache cleared", "timestamp": datetime.now().isoformat()}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
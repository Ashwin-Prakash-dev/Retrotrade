# RetroTrade 

> A full-stack mobile application for real-time stock analysis, technical screening, and algorithmic backtesting — built with Flutter and a FastAPI Python backend.

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white" />
  <img src="https://img.shields.io/badge/Dart-3.x-0175C2?style=for-the-badge&logo=dart&logoColor=white" />
  <img src="https://img.shields.io/badge/FastAPI-0.115-009688?style=for-the-badge&logo=fastapi&logoColor=white" />
  <img src="https://img.shields.io/badge/Python-3.10+-3776AB?style=for-the-badge&logo=python&logoColor=white" />
  <img src="https://img.shields.io/badge/Platform-Android%20%7C%20iOS-lightgrey?style=for-the-badge" />
</p>

---

## Overview

RetroTrade is a cross-platform stock analysis app that gives traders and investors a professional-grade toolkit in the palm of their hand. The app fetches live market data via Yahoo Finance, performs technical indicator calculations on the backend, and lets users run configurable algorithmic backtests on multi-stock portfolios — all wrapped in a dark, data-dense UI designed for readability at a glance.

---

## Features

### Market Dashboard
- Live Indian indices: NIFTY 50, SENSEX, NIFTY BANK, NIFTY MIDCAP, NIFTY SMALL CAP, India VIX
- Global indices: S&P 500, EURO STOXX 50, NIKKEI 225, HANG SENG
- Commodity prices: Gold, Crude Oil, Silver
- Auto-refresh with curated market news feed

### Stock Analysis
- Search any stock by ticker symbol or company name with real-time autocomplete
- Full company profile: sector, market cap, P/E, ROE, D/E ratio, P/B ratio
- Technical indicators: RSI, MACD, Stochastic Oscillator
- Support & resistance levels computed from rolling price windows
- Fibonacci retracement levels (23.6%, 38.2%, 50.0%, 61.8%)
- Sentiment scoring (bullish/bearish/neutral) with contributing factors

### Stock Screener
Filter the market across multiple simultaneous criteria:
- RSI range (configurable thresholds)
- MACD signal direction (bullish / bearish / any)
- VWAP position (above / below / any)
- P/E ratio range
- Market capitalization range
- Price range
- Minimum daily volume
- Sector filter (12 sectors)

### Portfolio Backtester
- Build a multi-stock portfolio with custom allocation weights
- Choose a strategy: **RSI**, **MACD**, or **Volume Spike**
- Configure all strategy parameters (periods, thresholds, hold days)
- Set a custom date range and initial capital
- Optional periodic rebalancing (monthly / quarterly / yearly)
- Results: total return, win rate, max drawdown, per-stock performance, final composition

---

## Tech Stack

| Layer | Technology |
|---|---|
| Mobile Frontend | Flutter (Dart) |
| Backend API | FastAPI (Python) |
| Market Data | yfinance |
| Backtesting Engine | Backtrader |
| Data Processing | Pandas, NumPy |
| Deployment | Render (HTTPS) |
| Platforms | Android, iOS, Web, macOS, Linux, Windows |

---

## Architecture

```
┌─────────────────────────────────┐
│         Flutter Frontend        │
│  ┌────────┐  ┌───────────────┐  │
│  │  Home  │  │   Screener    │  │
│  │ Screen │  │    Screen     │  │
│  └────────┘  └───────────────┘  │
│  ┌─────────────────────────┐    │
│  │    Backtest Screen      │    │
│  └─────────────────────────┘    │
│           ApiService            │
└──────────────┬──────────────────┘
               │ HTTPS / REST
┌──────────────▼──────────────────┐
│        FastAPI Backend          │
│  ┌──────────┐  ┌─────────────┐  │
│  │ /stock-  │  │  /backtest- │  │
│  │  info    │  │  portfolio  │  │
│  └──────────┘  └─────────────┘  │
│  ┌──────────┐  ┌─────────────┐  │
│  │ /screen- │  │  /market-   │  │
│  │  stocks  │  │  overview   │  │
│  └──────────┘  └─────────────┘  │
│         yfinance + Backtrader   │
└─────────────────────────────────┘
```

---

## Getting Started

### Prerequisites

- Flutter SDK ≥ 3.x ([install guide](https://docs.flutter.dev/get-started/install))
- Python 3.10+
- pip

### 1. Clone the repository

```bash
git clone https://github.com/your-username/retrotrade.git
cd retrotrade
```

### 2. Start the backend

```bash
cd bnd
pip install -r requirements.txt
python main.py
```

The API will be available at `http://localhost:8000`. Interactive docs at `http://localhost:8000/docs`.

### 3. Configure the API URL

By default the app points to the hosted Render deployment. To use your local backend, update `lib/services/api_service.dart`:

```dart
String get baseUrl {
  return 'http://10.0.2.2:8000'; // Android emulator
  // return 'http://localhost:8000'; // iOS simulator / desktop
}
```

### 4. Run the Flutter app

```bash
flutter pub get
flutter run
```

---

## Backend API Reference

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/health` | Health check |
| `GET` | `/stock-info/{symbol}` | Full stock analysis for a ticker |
| `GET` | `/stock-suggestions?q=` | Autocomplete stock search |
| `GET` | `/market-overview` | Indices, VIX, commodities, news |
| `POST` | `/backtest-portfolio` | Run a multi-stock backtest |
| `POST` | `/screen-stocks` | Screen stocks by technical/fundamental filters |
| `GET` | `/debug/yfinance-test` | Diagnose Yahoo Finance connectivity |

---

## Project Structure

```
retrotrade/
├── lib/
│   ├── main.dart
│   ├── screens/
│   │   ├── home_screen.dart          # Dashboard + market overview
│   │   ├── backtest_screen.dart      # Portfolio backtester
│   │   ├── stock_screener_screen.dart
│   │   └── connection_test_screen.dart
│   ├── services/
│   │   └── api_service.dart          # All HTTP calls to the backend
│   └── widgets/
│       ├── company_info_card.dart
│       ├── technical_analysis_card.dart
│       ├── backtest_results_card.dart
│       ├── stock_autocomplete.dart
│       └── stock_result_card.dart
└── bnd/
    ├── main.py                       # FastAPI app — all endpoints
    └── requirements.txt
```

---

## Backtesting Strategies

### RSI Strategy
Buys when RSI falls below the oversold threshold, sells when it rises above the overbought threshold. Parameters: period, buy threshold, sell threshold.

### MACD Strategy
Buys on a bullish MACD crossover (MACD line crosses above signal line), sells on a bearish crossover. Parameters: fast EMA period, slow EMA period, signal period.

### Volume Spike Strategy
Buys when volume exceeds a multiple of the rolling average volume, then holds for a fixed number of days before selling. Parameters: volume multiplier, lookback period, hold duration.

---

## Known Limitations

- Market data is sourced from Yahoo Finance via `yfinance`. Occasional rate-limiting (HTTP 429) may delay responses; the backend includes exponential-backoff retry logic.
- The free-tier Render deployment cold-starts after inactivity — the first request may take 30–60 seconds.
- Indian stock screener uses a curated list of 30 popular US-listed symbols as a demonstration. NSE/BSE integration requires a paid data provider.

---

<img width="338" height="748" alt="Screenshot 2025-11-30 224612" src="https://github.com/user-attachments/assets/e95bd470-d6f5-460b-9f1d-2067410ae54c" />
<img width="322" height="682" alt="Screenshot 2025-12-01 001132" src="https://github.com/user-attachments/assets/4ce81e98-f8b4-4587-8ba1-79ee9a765797" />
<img width="361" height="736" alt="Screenshot 2025-11-30 195013" src="https://github.com/user-attachments/assets/c110969a-f8ac-4942-88f8-c75003bf0401" />
<img width="362" height="727" alt="Screenshot 2025-11-30 195041" src="https://github.com/user-attachments/assets/e06467f6-07bd-49ca-baed-765e4eda25f8" />

## Contributing

Pull requests are welcome. For major changes, please open an issue first to discuss what you'd like to change.

1. Fork the repo
2. Create a feature branch (`git checkout -b feature/your-feature`)
3. Commit your changes (`git commit -m 'Add your feature'`)
4. Push to the branch (`git push origin feature/your-feature`)
5. Open a Pull Request

---

## License

This project is licensed under the MIT License.

---

## Acknowledgements

- [yfinance](https://github.com/ranaroussi/yfinance) — market data
- [Backtrader](https://www.backtrader.com/) — backtesting engine
- [FastAPI](https://fastapi.tiangolo.com/) — backend framework
- [Flutter](https://flutter.dev/) — cross-platform UI

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class StockSuggestion {
  final String symbol;
  final String companyName;
  final String matchType;

  StockSuggestion({
    required this.symbol,
    required this.companyName,
    required this.matchType,
  });

  factory StockSuggestion.fromJson(Map<String, dynamic> json) {
    return StockSuggestion(
      symbol: json['symbol'] ?? '',
      companyName: json['company_name'] ?? '',
      matchType: json['match_type'] ?? 'symbol',
    );
  }
}

class PortfolioStock {
  final String ticker;
  final double allocation;

  PortfolioStock({
    required this.ticker,
    required this.allocation,
  });

  Map<String, dynamic> toJson() {
    return {
      'ticker': ticker,
      'allocation': allocation,
    };
  }
}

class ApiService {
  // API URL based on platform
  String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:8000';
    } else if (Platform.isAndroid) {
      return 'http://10.0.2.2:8000';
    } else {
      return 'http://localhost:8000';
    }
  }

  Future<List<StockSuggestion>> getStockSuggestions(String query) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/stock-suggestions?q=${Uri.encodeComponent(query)}'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((item) => StockSuggestion.fromJson(item)).toList();
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> getStockInfo(String symbol) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/stock-info/$symbol'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 404) {
        throw 'Stock symbol "$symbol" not found';
      } else {
        final errorData = jsonDecode(response.body);
        throw errorData['detail'] ?? 'Failed to fetch stock data';
      }
    } catch (e) {
      if (e is String) rethrow;
      throw 'Failed to connect to server: $e';
    }
  }

  Future<Map<String, dynamic>> runBacktest({
    required String ticker,
    required String startDate,
    required String endDate,
    required int rsiPeriod,
    required int rsiBuy,
    required int rsiSell,
    required double initialCash,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/backtest'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'ticker': ticker,
          'start_date': startDate,
          'end_date': endDate,
          'strategy': 'RSI',
          'rsi_period': rsiPeriod,
          'rsi_buy': rsiBuy,
          'rsi_sell': rsiSell,
          'initial_cash': initialCash,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final errorData = jsonDecode(response.body);
        throw errorData['detail'] ?? 'Backtest failed';
      }
    } catch (e) {
      if (e is String) rethrow;
      throw 'Failed to connect to server: $e';
    }
  }

  Future<Map<String, dynamic>> runPortfolioBacktest({
    required List<PortfolioStock> stocks,
    required String startDate,
    required String endDate,
    required double initialCash,
    bool rebalance = false,
    String rebalanceFrequency = 'monthly',
    required Map<String, dynamic> strategyParams,
  }) async {
    try {
      // Build the request body with strategy parameters
      final Map<String, dynamic> requestBody = {
        'stocks': stocks.map((s) => s.toJson()).toList(),
        'start_date': startDate,
        'end_date': endDate,
        'initial_cash': initialCash,
        'rebalance': rebalance,
        'rebalance_frequency': rebalanceFrequency,
      };

      // Add all strategy parameters to the request
      requestBody.addAll(strategyParams);

      final response = await http.post(
        Uri.parse('$baseUrl/backtest-portfolio'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final errorData = jsonDecode(response.body);
        throw errorData['detail'] ?? 'Portfolio backtest failed';
      }
    } catch (e) {
      if (e is String) rethrow;
      throw 'Failed to connect to server: $e';
    }
  }

  Future<List<Map<String, dynamic>>> screenStocks({
    bool useRsi = false,
    double rsiMin = 30.0,
    double rsiMax = 70.0,
    bool useMacd = false,
    String macdSignal = 'any',
    bool useVwap = false,
    String vwapPosition = 'any',
    bool usePe = false,
    double peMin = 5.0,
    double peMax = 30.0,
    bool useMarketCap = false,
    double marketCapMin = 1000000000,
    double marketCapMax = 1000000000000,
    bool useVolume = false,
    double volumeMin = 1000000,
    bool usePrice = false,
    double priceMin = 1.0,
    double priceMax = 1000.0,
    String sector = 'any',
  }) async {
    try {
      final Map<String, dynamic> requestBody = {
        'use_rsi': useRsi,
        'rsi_min': rsiMin,
        'rsi_max': rsiMax,
        'use_macd': useMacd,
        'macd_signal': macdSignal,
        'use_vwap': useVwap,
        'vwap_position': vwapPosition,
        'use_pe': usePe,
        'pe_min': peMin,
        'pe_max': peMax,
        'use_market_cap': useMarketCap,
        'market_cap_min': marketCapMin,
        'market_cap_max': marketCapMax,
        'use_volume': useVolume,
        'volume_min': volumeMin,
        'use_price': usePrice,
        'price_min': priceMin,
        'price_max': priceMax,
        'sector': sector,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/screen-stocks'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((item) => item as Map<String, dynamic>).toList();
      } else {
        final errorData = jsonDecode(response.body);
        throw errorData['detail'] ?? 'Stock screening failed';
      }
    } catch (e) {
      if (e is String) rethrow;
      throw 'Failed to connect to server: $e';
    }
  }

  Future<bool> checkConnection() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
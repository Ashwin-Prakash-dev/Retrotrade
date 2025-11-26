import 'dart:async';
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
  // FIXED: Changed to HTTPS for Render deployment
  String get baseUrl {
    return 'https://rtdebnd.onrender.com';
  }

  // Add timeout and better error handling
  final Duration _timeout = const Duration(seconds: 30);

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  Future<List<StockSuggestion>> getStockSuggestions(String query) async {
    try {
      print('Fetching suggestions for: $query');
      print('URL: $baseUrl/stock-suggestions?q=${Uri.encodeComponent(query)}');
      
      final response = await http.get(
        Uri.parse('$baseUrl/stock-suggestions?q=${Uri.encodeComponent(query)}'),
        headers: _headers,
      ).timeout(_timeout);

      print('Suggestions response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((item) => StockSuggestion.fromJson(item)).toList();
      } else {
        print('Suggestions error: ${response.body}');
        return [];
      }
    } catch (e) {
      print('Error fetching suggestions: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getMarketOverview() async {
  try {
    print('Fetching market overview');
    print('URL: $baseUrl/market-overview');
    
    final response = await http.get(
      Uri.parse('$baseUrl/market-overview'),
      headers: _headers,
    ).timeout(_timeout);

    print('Market overview response status: ${response.statusCode}');

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      print('Market overview error: ${response.body}');
      throw 'Failed to fetch market overview';
    }
  } on TimeoutException {
    throw 'Request timed out. Please check your internet connection.';
  } on SocketException {
    throw 'No internet connection. Please check your network.';
  } catch (e) {
    print('Error in getMarketOverview: $e');
    if (e is String) rethrow;
    throw 'Failed to connect to server: $e';
  }
  }

  Future<Map<String, dynamic>> getStockInfo(String symbol) async {
    try {
      print('Fetching stock info for: $symbol');
      print('URL: $baseUrl/stock-info/$symbol');
      
      final response = await http.get(
        Uri.parse('$baseUrl/stock-info/$symbol'),
        headers: _headers,
      ).timeout(_timeout);

      print('Stock info response status: ${response.statusCode}');
      print('Stock info response body: ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 404) {
        throw 'Stock symbol "$symbol" not found. Please check the symbol and try again.';
      } else {
        final errorData = jsonDecode(response.body);
        throw errorData['detail'] ?? 'Failed to fetch stock data';
      }
    } on TimeoutException {
      throw 'Request timed out. Please check your internet connection and try again.';
    } on SocketException {
      throw 'No internet connection. Please check your network and try again.';
    } on FormatException {
      throw 'Invalid response from server. Please try again later.';
    } catch (e) {
      print('Error in getStockInfo: $e');
      if (e is String) rethrow;
      throw 'Failed to connect to server. Please check your internet connection.';
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
      print('Running backtest for: $ticker');
      
      final response = await http.post(
        Uri.parse('$baseUrl/backtest'),
        headers: _headers,
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
      ).timeout(_timeout);

      print('Backtest response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final errorData = jsonDecode(response.body);
        throw errorData['detail'] ?? 'Backtest failed';
      }
    } on TimeoutException {
      throw 'Request timed out. Backtest may take longer for large date ranges.';
    } on SocketException {
      throw 'No internet connection. Please check your network and try again.';
    } catch (e) {
      print('Error in runBacktest: $e');
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
      print('Running portfolio backtest');
      
      final Map<String, dynamic> requestBody = {
        'stocks': stocks.map((s) => s.toJson()).toList(),
        'start_date': startDate,
        'end_date': endDate,
        'initial_cash': initialCash,
        'rebalance': rebalance,
        'rebalance_frequency': rebalanceFrequency,
      };

      requestBody.addAll(strategyParams);

      print('Request body: ${jsonEncode(requestBody)}');

      final response = await http.post(
        Uri.parse('$baseUrl/backtest-portfolio'),
        headers: _headers,
        body: jsonEncode(requestBody),
      ).timeout(_timeout);

      print('Portfolio backtest response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print('Portfolio backtest error: ${response.body}');
        final errorData = jsonDecode(response.body);
        throw errorData['detail'] ?? 'Portfolio backtest failed';
      }
    } on TimeoutException {
      throw 'Request timed out. Portfolio backtest may take longer.';
    } on SocketException {
      throw 'No internet connection. Please check your network and try again.';
    } catch (e) {
      print('Error in runPortfolioBacktest: $e');
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
      print('Screening stocks with filters');
      
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
        headers: _headers,
        body: jsonEncode(requestBody),
      ).timeout(_timeout);

      print('Screen stocks response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((item) => item as Map<String, dynamic>).toList();
      } else {
        print('Screen stocks error: ${response.body}');
        final errorData = jsonDecode(response.body);
        throw errorData['detail'] ?? 'Stock screening failed';
      }
    } on TimeoutException {
      throw 'Request timed out. Stock screening may take a while.';
    } on SocketException {
      throw 'No internet connection. Please check your network and try again.';
    } catch (e) {
      print('Error in screenStocks: $e');
      if (e is String) rethrow;
      throw 'Failed to connect to server: $e';
    }
  }

  Future<bool> checkConnection() async {
    try {
      print('Checking connection to: $baseUrl/health');
      
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

      print('Health check response status: ${response.statusCode}');
      print('Health check response body: ${response.body}');

      return response.statusCode == 200;
    } catch (e) {
      print('Health check error: $e');
      return false;
    }
  }
}
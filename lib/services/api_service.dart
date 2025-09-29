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
        // Return empty list on error rather than throwing
        return [];
      }
    } catch (e) {
      // Return empty list on network error
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
        'filters': <String, dynamic>{},
      };

      // Add filters based on what's enabled
      if (useRsi) {
        requestBody['filters']['rsi'] = {
          'min': rsiMin,
          'max': rsiMax,
        };
      }

      if (useMacd) {
        requestBody['filters']['macd'] = {
          'signal': macdSignal,
        };
      }

      if (useVwap) {
        requestBody['filters']['vwap'] = {
          'position': vwapPosition,
        };
      }

      if (usePe) {
        requestBody['filters']['pe_ratio'] = {
          'min': peMin,
          'max': peMax,
        };
      }

      if (useMarketCap) {
        requestBody['filters']['market_cap'] = {
          'min': marketCapMin,
          'max': marketCapMax,
        };
      }

      if (useVolume) {
        requestBody['filters']['volume'] = {
          'min': volumeMin,
        };
      }

      if (usePrice) {
        requestBody['filters']['price'] = {
          'min': priceMin,
          'max': priceMax,
        };
      }

      if (sector != 'any') {
        requestBody['filters']['sector'] = sector;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/screen-stocks'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final List<dynamic> stocks = responseData['stocks'] ?? [];
        return stocks.cast<Map<String, dynamic>>();
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
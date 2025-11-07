import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ConnectionTestScreen extends StatefulWidget {
  const ConnectionTestScreen({super.key});

  @override
  State<ConnectionTestScreen> createState() => _ConnectionTestScreenState();
}

class _ConnectionTestScreenState extends State<ConnectionTestScreen> {
  final _apiService = ApiService();
  bool _isLoading = false;
  String _result = '';
  Color _resultColor = Colors.black;

  Future<void> _testConnection() async {
    setState(() {
      _isLoading = true;
      _result = 'Testing connection...';
      _resultColor = Colors.blue;
    });

    try {
      // Test 1: Health check
      setState(() {
        _result += '\n\n[1/3] Testing health endpoint...';
      });
      
      final healthCheck = await _apiService.checkConnection();
      
      if (healthCheck) {
        setState(() {
          _result += '\n✅ Health check passed!';
        });
      } else {
        setState(() {
          _result += '\n❌ Health check failed!';
          _resultColor = Colors.red;
        });
        return;
      }

      // Test 2: Stock suggestions
      setState(() {
        _result += '\n\n[2/3] Testing stock suggestions...';
      });
      
      final suggestions = await _apiService.getStockSuggestions('AAPL');
      
      setState(() {
        _result += '\n✅ Got ${suggestions.length} suggestions';
        if (suggestions.isNotEmpty) {
          _result += '\n   First: ${suggestions[0].symbol} - ${suggestions[0].companyName}';
        }
      });

      // Test 3: Stock info
      setState(() {
        _result += '\n\n[3/3] Testing stock info...';
      });
      
      final stockInfo = await _apiService.getStockInfo('AAPL');
      
      setState(() {
        _result += '\n✅ Stock info retrieved!';
        _result += '\n   Symbol: ${stockInfo['symbol']}';
        _result += '\n   Price: \$${stockInfo['current_price']}';
        _result += '\n   Company: ${stockInfo['company_name']}';
        _resultColor = Colors.green;
      });

      setState(() {
        _result += '\n\n✅ ALL TESTS PASSED!';
      });

    } catch (e) {
      setState(() {
        _result += '\n\n❌ ERROR: $e';
        _resultColor = Colors.red;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connection Test'),
        backgroundColor: const Color(0xFF121836),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'API Base URL:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _apiService.baseUrl,
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _testConnection,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: const Color(0xFF00F5FF),
                foregroundColor: Colors.black,
              ),
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text(
                      'RUN CONNECTION TEST',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Card(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    _result.isEmpty ? 'Press the button to test connection' : _result,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: _resultColor,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/company_info_card.dart';
import '../widgets/technical_analysis_card.dart';
import '../widgets/sentiment_card.dart';
import '../widgets/stock_autocomplete.dart';
import 'backtest_screen.dart';
import 'stock_screener_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  final _apiService = ApiService();
  bool _isLoading = false;
  Map<String, dynamic>? _stockData;
  String? _error;
  String? _currentSymbol;

  // Market data
  bool _isLoadingMarketData = true;
  Map<String, dynamic> _marketData = {};

  @override
  void initState() {
    super.initState();
    _loadMarketData();
  }

  Future<void> _loadMarketData() async {
    setState(() {
      _isLoadingMarketData = true;
    });

    try {
      // TODO: Replace with actual API calls
      await Future.delayed(const Duration(milliseconds: 800));
      
      // Mock data - replace with actual API service calls
      setState(() {
        _marketData = {
          'indices': [
            {'name': 'NIFTY 50', 'value': 24634.90, 'change': -19.80, 'changePercent': -0.08},
            {'name': 'SENSEX', 'value': 80364.94, 'change': -61.52, 'changePercent': -0.08},
            {'name': 'NIFTY BANK', 'value': 54461.00, 'change': 71.65, 'changePercent': 0.13},
            {'name': 'S&P 500', 'value': 6660.02, 'change': 16.32, 'changePercent': 0.25},
          ],
          'commodities': [
            {'name': 'Gold', 'value': 2642.50, 'change': 12.30, 'unit': 'USD/oz'},
            {'name': 'Crude Oil', 'value': 68.25, 'change': -1.45, 'unit': 'USD/bbl'},
            {'name': 'Silver', 'value': 31.85, 'change': 0.52, 'unit': 'USD/oz'},
          ],
          'news': [
            {
              'title': 'Fed holds rates steady, signals potential cut',
              'time': '2 hours ago',
              'source': 'Reuters'
            },
            {
              'title': 'Tech stocks rally on AI optimism',
              'time': '4 hours ago',
              'source': 'Bloomberg'
            },
            {
              'title': 'Crude oil drops on demand concerns',
              'time': '5 hours ago',
              'source': 'CNBC'
            },
          ],
        };
        _isLoadingMarketData = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingMarketData = false;
      });
    }
  }

  Future<void> _searchCompany([String? symbol]) async {
    final searchTerm = symbol ?? _extractSymbolFromText(_searchController.text);
    if (searchTerm.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _stockData = null;
    });

    try {
      final data = await _apiService.getStockInfo(searchTerm.toUpperCase());
      setState(() {
        _stockData = data;
        _currentSymbol = searchTerm.toUpperCase();
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _extractSymbolFromText(String text) {
    if (text.contains(' - ')) {
      return text.split(' - ')[0].trim();
    }
    return text.trim();
  }

  void _onStockSelected(String symbol, String companyName) {
    _searchController.text = '$symbol - $companyName';
    _searchCompany(symbol);
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _stockData = null;
      _currentSymbol = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Analysis'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_stockData != null)
            IconButton(
              icon: const Icon(Icons.home),
              onPressed: _clearSearch,
              tooltip: 'Back to Home',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMarketData,
            tooltip: 'Refresh Market Data',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Search Bar with Autocomplete
            StockAutocomplete(
              controller: _searchController,
              onStockSelected: _onStockSelected,
              onSearch: () => _searchCompany(),
              isLoading: _isLoading,
            ),

            const SizedBox(height: 16),

            // Results
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    if (_error != null)
                      Card(
                        color: Colors.red.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              Icon(Icons.error, color: Colors.red.shade700),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: TextStyle(color: Colors.red.shade700),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    if (_stockData != null) ...[
                      CompanyInfoCard(stockData: _stockData!),
                      const SizedBox(height: 16),
                      TechnicalAnalysisCard(stockData: _stockData!),
                      const SizedBox(height: 16),
                      SentimentCard(stockData: _stockData!),
                    ],

                    // Market Overview - shown when no stock is searched
                    if (_stockData == null && !_isLoading && _error == null)
                      _buildMarketOverview(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        onTap: (index) {
          if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const StockScreenerScreen(),
              ),
            );
          } else if (index == 2) {
            if (_currentSymbol != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BacktestScreen(
                    initialTicker: _currentSymbol!,
                  ),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please search for a stock first'),
                  duration: Duration(seconds: 2),
                ),
              );
            }
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.filter_list),
            label: 'Screener',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Backtest',
          ),
        ],
      ),
    );
  }

  Widget _buildMarketOverview() {
    if (_isLoadingMarketData) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Welcome Message
        Card(
          color: Colors.blue.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(Icons.wb_sunny, color: Colors.orange.shade700, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Good ${_getGreeting()}!',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Here\'s what\'s happening in the markets today',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Major Indices
        _buildSectionHeader('Major Indices', Icons.trending_up),
        const SizedBox(height: 8),
        _buildIndicesGrid(),

        const SizedBox(height: 16),

        // Commodities
        _buildSectionHeader('Commodities', Icons.bar_chart),
        const SizedBox(height: 8),
        _buildCommoditiesCard(),

        const SizedBox(height: 16),

        // Economic News
        _buildSectionHeader('Market News', Icons.newspaper),
        const SizedBox(height: 8),
        _buildNewsCard(),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.blue.shade700),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
      ],
    );
  }

  Widget _buildIndicesGrid() {
    final indices = _marketData['indices'] as List<dynamic>? ?? [];
    
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.5,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: indices.length,
      itemBuilder: (context, index) {
        final item = indices[index];
        final isPositive = (item['change'] ?? 0.0) >= 0;
        
        return Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  item['name'],
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  item['value'].toStringAsFixed(2),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    Icon(
                      isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                      size: 14,
                      color: isPositive ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${item['change'].toStringAsFixed(2)} (${item['changePercent'].toStringAsFixed(2)}%)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isPositive ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCommoditiesCard() {
    final commodities = _marketData['commodities'] as List<dynamic>? ?? [];
    
    return Card(
      elevation: 2,
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: commodities.length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          color: Colors.grey.shade300,
        ),
        itemBuilder: (context, index) {
          final item = commodities[index];
          final isPositive = (item['change'] ?? 0.0) >= 0;
          
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.amber.shade100,
              child: Icon(
                _getCommodityIcon(item['name']),
                color: Colors.amber.shade800,
                size: 20,
              ),
            ),
            title: Text(
              item['name'],
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            subtitle: Text(
              item['unit'],
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$${item['value'].toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                      size: 12,
                      color: isPositive ? Colors.green : Colors.red,
                    ),
                    Text(
                      item['change'].abs().toStringAsFixed(2),
                      style: TextStyle(
                        fontSize: 12,
                        color: isPositive ? Colors.green : Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildNewsCard() {
    final news = _marketData['news'] as List<dynamic>? ?? [];
    
    return Card(
      elevation: 2,
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: news.length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          color: Colors.grey.shade300,
        ),
        itemBuilder: (context, index) {
          final item = news[index];
          
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue.shade100,
              child: Icon(
                Icons.article,
                color: Colors.blue.shade800,
                size: 20,
              ),
            ),
            title: Text(
              item['title'],
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Row(
                children: [
                  Text(
                    item['source'],
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '• ${item['time']}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            trailing: Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: Colors.grey.shade400,
            ),
            onTap: () {
              // TODO: Open news article
            },
          );
        },
      ),
    );
  }

  IconData _getCommodityIcon(String name) {
    switch (name.toLowerCase()) {
      case 'gold':
        return Icons.monetization_on;
      case 'crude oil':
        return Icons.oil_barrel;
      case 'silver':
        return Icons.diamond;
      default:
        return Icons.bar_chart;
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
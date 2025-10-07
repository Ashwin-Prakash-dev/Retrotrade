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

  static const Color primaryBg = Color(0xFF0A0E27);
  static const Color secondaryBg = Color(0xFF121836);
  static const Color cardBg = Color(0xFF1A2138);
  static const Color accentCyan = Color(0xFF00F5FF);
  static const Color accentPurple = Color(0xFF8B5CF6);
  static const Color accentGreen = Color(0xFF00FF88);
  static const Color accentRed = Color(0xFFFF0055);
  static const Color textPrimary = Color(0xFFE2E8F0);
  static const Color textSecondary = Color(0xFF94A3B8);

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
      await Future.delayed(const Duration(milliseconds: 800));
      
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
      backgroundColor: primaryBg,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accentCyan, accentPurple],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: accentCyan.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Icon(Icons.auto_graph, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              'RETROTRADE',
              style: TextStyle(
                color: textPrimary,
                fontWeight: FontWeight.w300,
                letterSpacing: 2,
                fontSize: 16,
              ),
            ),
          ],
        ),
        backgroundColor: secondaryBg,
        elevation: 0,
        actions: [
          if (_stockData != null)
            IconButton(
              icon: Icon(Icons.home_outlined, color: accentCyan),
              onPressed: _clearSearch,
              tooltip: 'Back to Home',
            ),
          IconButton(
            icon: Icon(Icons.refresh_outlined, color: accentCyan),
            onPressed: _loadMarketData,
            tooltip: 'Refresh Market Data',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [secondaryBg, primaryBg],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
 
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
                        Container(
                          decoration: BoxDecoration(
                            color: accentRed.withOpacity(0.1),
                            border: Border.all(color: accentRed.withOpacity(0.3)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                Icon(Icons.warning_amber_rounded, color: accentRed),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: TextStyle(color: accentRed, fontWeight: FontWeight.w500),
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
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: secondaryBg,
          boxShadow: [
            BoxShadow(
              color: accentCyan.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.transparent,
          currentIndex: 0,
          selectedItemColor: accentCyan,
          unselectedItemColor: textSecondary,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          onTap: (index) {
            if (index == 1) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const StockScreenerScreen(),
                ),
              );
            } else if (index == 2) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BacktestScreen(
                    initialTicker: _currentSymbol,
                  ),
                ),
              );
            }
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.filter_list_outlined),
              activeIcon: Icon(Icons.filter_list),
              label: 'Screener',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.analytics_outlined),
              activeIcon: Icon(Icons.analytics),
              label: 'Backtest',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarketOverview() {
    if (_isLoadingMarketData) {
      return Container(
        padding: const EdgeInsets.all(48.0),
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(accentCyan),
            strokeWidth: 3,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Welcome Message
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [accentCyan.withOpacity(0.15), accentPurple.withOpacity(0.15)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: accentCyan.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [accentCyan, accentPurple],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: accentCyan.withOpacity(0.4),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.wb_sunny_outlined, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'GOOD ${_getGreeting().toUpperCase()}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Real-time market intelligence at your fingertips',
                        style: TextStyle(
                          fontSize: 13,
                          color: textSecondary,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Major Indices
        _buildSectionHeader('GLOBAL INDICES', Icons.trending_up),
        const SizedBox(height: 12),
        _buildIndicesGrid(),

        const SizedBox(height: 24),

        // Commodities
        _buildSectionHeader('COMMODITIES', Icons.diamond_outlined),
        const SizedBox(height: 12),
        _buildCommoditiesCard(),

        const SizedBox(height: 24),

        // Economic News
        _buildSectionHeader('MARKET PULSE', Icons.newspaper_outlined),
        const SizedBox(height: 12),
        _buildNewsCard(),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: accentCyan),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: textSecondary,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [accentCyan.withOpacity(0.3), Colors.transparent],
              ),
            ),
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
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: indices.length,
      itemBuilder: (context, index) {
        final item = indices[index];
        final isPositive = (item['change'] ?? 0.0) >= 0;
        
        return Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isPositive 
                  ? accentGreen.withOpacity(0.2)
                  : accentRed.withOpacity(0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: (isPositive ? accentGreen : accentRed).withOpacity(0.1),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        item['name'],
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: textSecondary,
                          letterSpacing: 0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (isPositive ? accentGreen : accentRed).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Icon(
                        isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 12,
                        color: isPositive ? accentGreen : accentRed,
                      ),
                    ),
                  ],
                ),
                Text(
                  item['value'].toStringAsFixed(2),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
                Text(
                  '${item['change'].toStringAsFixed(2)} (${item['changePercent'].toStringAsFixed(2)}%)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isPositive ? accentGreen : accentRed,
                  ),
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
    
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentCyan.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: commodities.length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          color: textSecondary.withOpacity(0.1),
        ),
        itemBuilder: (context, index) {
          final item = commodities[index];
          final isPositive = (item['change'] ?? 0.0) >= 0;
          
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [accentCyan.withOpacity(0.2), accentPurple.withOpacity(0.2)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getCommodityIcon(item['name']),
                    color: accentCyan,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['name'],
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item['unit'],
                        style: TextStyle(
                          fontSize: 11,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${item['value'].toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                          size: 12,
                          color: isPositive ? accentGreen : accentRed,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          item['change'].abs().toStringAsFixed(2),
                          style: TextStyle(
                            fontSize: 12,
                            color: isPositive ? accentGreen : accentRed,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
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
    
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentPurple.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: news.length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          color: textSecondary.withOpacity(0.1),
        ),
        itemBuilder: (context, index) {
          final item = news[index];
          
          return InkWell(
            onTap: () {
              // TODO: Open news article
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [accentPurple.withOpacity(0.2), accentCyan.withOpacity(0.2)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.article_outlined,
                      color: accentPurple,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['title'],
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: accentCyan.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                item['source'],
                                style: TextStyle(
                                  fontSize: 10,
                                  color: accentCyan,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '• ${item['time']}',
                              style: TextStyle(
                                fontSize: 11,
                                color: textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: textSecondary.withOpacity(0.5),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  IconData _getCommodityIcon(String name) {
    switch (name.toLowerCase()) {
      case 'gold':
        return Icons.monetization_on_outlined;
      case 'crude oil':
        return Icons.oil_barrel_outlined;
      case 'silver':
        return Icons.diamond_outlined;
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
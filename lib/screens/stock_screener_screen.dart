import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/stock_result_card.dart';

class StockScreenerScreen extends StatefulWidget {
  const StockScreenerScreen({super.key});

  @override
  State<StockScreenerScreen> createState() => _StockScreenerScreenState();
}

class _StockScreenerScreenState extends State<StockScreenerScreen> {
  final _apiService = ApiService();
  bool _isLoading = false;
  List<Map<String, dynamic>>? _results;
  String? _error;

  // Filter states
  bool _useRSI = false;
  double _rsiMin = 30.0;
  double _rsiMax = 70.0;

  bool _useMacd = false;
  String _macdSignal = 'bullish'; // bullish, bearish, any

  bool _useVWAP = false;
  String _vwapPosition = 'above'; // above, below, any

  bool _usePE = false;
  double _peMin = 5.0;
  double _peMax = 30.0;

  bool _useMarketCap = false;
  double _marketCapMin = 1000000000; // 1B
  double _marketCapMax = 1000000000000; // 1T

  bool _useVolume = false;
  double _volumeMin = 1000000; // 1M

  bool _usePrice = false;
  double _priceMin = 1.0;
  double _priceMax = 1000.0;

  String _selectedSector = 'any';
  final List<String> _sectors = [
    'any',
    'Technology',
    'Healthcare',
    'Financial Services',
    'Consumer Cyclical',
    'Industrials',
    'Energy',
    'Utilities',
    'Real Estate',
    'Materials',
    'Consumer Defensive',
    'Communication Services'
  ];

  Future<void> _runScreener() async {
    // Validate that at least one filter is enabled
    if (!_useRSI && !_useMacd && !_useVWAP && !_usePE && 
        !_useMarketCap && !_useVolume && !_usePrice && _selectedSector == 'any') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one filter criteria'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _results = null;
    });

    try {
      final results = await _apiService.screenStocks(
        useRsi: _useRSI,
        rsiMin: _rsiMin,
        rsiMax: _rsiMax,
        useMacd: _useMacd,
        macdSignal: _macdSignal,
        useVwap: _useVWAP,
        vwapPosition: _vwapPosition,
        usePe: _usePE,
        peMin: _peMin,
        peMax: _peMax,
        useMarketCap: _useMarketCap,
        marketCapMin: _marketCapMin,
        marketCapMax: _marketCapMax,
        useVolume: _useVolume,
        volumeMin: _volumeMin,
        usePrice: _usePrice,
        priceMin: _priceMin,
        priceMax: _priceMax,
        sector: _selectedSector,
      );
      
      setState(() {
        _results = results;
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

  void _resetFilters() {
    setState(() {
      _useRSI = false;
      _rsiMin = 30.0;
      _rsiMax = 70.0;
      _useMacd = false;
      _macdSignal = 'bullish';
      _useVWAP = false;
      _vwapPosition = 'above';
      _usePE = false;
      _peMin = 5.0;
      _peMax = 30.0;
      _useMarketCap = false;
      _marketCapMin = 1000000000;
      _marketCapMax = 1000000000000;
      _useVolume = false;
      _volumeMin = 1000000;
      _usePrice = false;
      _priceMin = 1.0;
      _priceMax = 1000.0;
      _selectedSector = 'any';
      _results = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Screener'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetFilters,
            tooltip: 'Reset Filters',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filters Section
          Expanded(
            flex: 3,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Icon(Icons.filter_list, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'Filter Criteria',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Sector Filter
                  _buildSectorFilter(),
                  const SizedBox(height: 16),

                  // Technical Indicators
                  _buildExpandableSection(
                    'Technical Indicators',
                    Icons.show_chart,
                    [
                      _buildRSIFilter(),
                      _buildMACDFilter(),
                      _buildVWAPFilter(),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Fundamental Filters
                  _buildExpandableSection(
                    'Fundamental Analysis',
                    Icons.account_balance,
                    [
                      _buildPEFilter(),
                      _buildMarketCapFilter(),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Trading Filters
                  _buildExpandableSection(
                    'Trading Metrics',
                    Icons.trending_up,
                    [
                      _buildPriceFilter(),
                      _buildVolumeFilter(),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Screen Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _runScreener,
                      icon: _isLoading 
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.search),
                      label: Text(
                        _isLoading ? 'Screening...' : 'Screen Stocks',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Results Section
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border(
                  top: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              child: Column(
                children: [
                  // Results Header
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Icon(Icons.list, color: Colors.green.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'Results',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        if (_results != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_results!.length} stocks',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade800,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Results Content
                  Expanded(
                    child: _buildResultsContent(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectorFilter() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.category, size: 18, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                const Text(
                  'Sector',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedSector,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: _sectors.map((sector) {
                return DropdownMenuItem(
                  value: sector,
                  child: Text(sector == 'any' ? 'Any Sector' : sector),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedSector = value!;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandableSection(String title, IconData icon, List<Widget> children) {
    return Card(
      child: ExpansionTile(
        leading: Icon(icon, color: Colors.blue.shade700),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRSIFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CheckboxListTile(
          title: const Text('RSI Filter'),
          subtitle: Text(_useRSI ? 'Between ${_rsiMin.round()} - ${_rsiMax.round()}' : 'Disabled'),
          value: _useRSI,
          onChanged: (value) {
            setState(() {
              _useRSI = value!;
            });
          },
        ),
        if (_useRSI) ...[
          const SizedBox(height: 8),
          const Text('RSI Range:', style: TextStyle(fontWeight: FontWeight.w500)),
          RangeSlider(
            values: RangeValues(_rsiMin, _rsiMax),
            min: 0,
            max: 100,
            divisions: 20,
            labels: RangeLabels(_rsiMin.round().toString(), _rsiMax.round().toString()),
            onChanged: (values) {
              setState(() {
                _rsiMin = values.start;
                _rsiMax = values.end;
              });
            },
          ),
        ],
        const Divider(),
      ],
    );
  }

  Widget _buildMACDFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CheckboxListTile(
          title: const Text('MACD Filter'),
          subtitle: Text(_useMacd ? 'Signal: ${_macdSignal.toUpperCase()}' : 'Disabled'),
          value: _useMacd,
          onChanged: (value) {
            setState(() {
              _useMacd = value!;
            });
          },
        ),
        if (_useMacd) ...[
          const SizedBox(height: 8),
          const Text('MACD Signal:', style: TextStyle(fontWeight: FontWeight.w500)),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'bullish', label: Text('Bullish')),
              ButtonSegment(value: 'bearish', label: Text('Bearish')),
              ButtonSegment(value: 'any', label: Text('Any')),
            ],
            selected: {_macdSignal},
            onSelectionChanged: (Set<String> selection) {
              setState(() {
                _macdSignal = selection.first;
              });
            },
          ),
        ],
        const Divider(),
      ],
    );
  }

  Widget _buildVWAPFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CheckboxListTile(
          title: const Text('VWAP Filter'),
          subtitle: Text(_useVWAP ? 'Price ${_vwapPosition} VWAP' : 'Disabled'),
          value: _useVWAP,
          onChanged: (value) {
            setState(() {
              _useVWAP = value!;
            });
          },
        ),
        if (_useVWAP) ...[
          const SizedBox(height: 8),
          const Text('Price vs VWAP:', style: TextStyle(fontWeight: FontWeight.w500)),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'above', label: Text('Above')),
              ButtonSegment(value: 'below', label: Text('Below')),
              ButtonSegment(value: 'any', label: Text('Any')),
            ],
            selected: {_vwapPosition},
            onSelectionChanged: (Set<String> selection) {
              setState(() {
                _vwapPosition = selection.first;
              });
            },
          ),
        ],
      ],
    );
  }

  Widget _buildPEFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CheckboxListTile(
          title: const Text('P/E Ratio Filter'),
          subtitle: Text(_usePE ? 'Between ${_peMin.round()} - ${_peMax.round()}' : 'Disabled'),
          value: _usePE,
          onChanged: (value) {
            setState(() {
              _usePE = value!;
            });
          },
        ),
        if (_usePE) ...[
          const SizedBox(height: 8),
          const Text('P/E Ratio Range:', style: TextStyle(fontWeight: FontWeight.w500)),
          RangeSlider(
            values: RangeValues(_peMin, _peMax),
            min: 1,
            max: 100,
            divisions: 99,
            labels: RangeLabels(_peMin.round().toString(), _peMax.round().toString()),
            onChanged: (values) {
              setState(() {
                _peMin = values.start;
                _peMax = values.end;
              });
            },
          ),
        ],
        const Divider(),
      ],
    );
  }

  Widget _buildMarketCapFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CheckboxListTile(
          title: const Text('Market Cap Filter'),
          subtitle: Text(_useMarketCap 
              ? 'Between \$${_formatNumber(_marketCapMin)} - \$${_formatNumber(_marketCapMax)}' 
              : 'Disabled'),
          value: _useMarketCap,
          onChanged: (value) {
            setState(() {
              _useMarketCap = value!;
            });
          },
        ),
        if (_useMarketCap) ...[
          const SizedBox(height: 8),
          const Text('Market Cap Range:', style: TextStyle(fontWeight: FontWeight.w500)),
          RangeSlider(
            values: RangeValues(_marketCapMin, _marketCapMax),
            min: 100000000, // 100M
            max: 3000000000000, // 3T
            divisions: 20,
            labels: RangeLabels(
              '\$${_formatNumber(_marketCapMin)}',
              '\$${_formatNumber(_marketCapMax)}',
            ),
            onChanged: (values) {
              setState(() {
                _marketCapMin = values.start;
                _marketCapMax = values.end;
              });
            },
          ),
        ],
      ],
    );
  }

  Widget _buildPriceFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CheckboxListTile(
          title: const Text('Price Filter'),
          subtitle: Text(_usePrice ? 'Between \$${_priceMin.round()} - \$${_priceMax.round()}' : 'Disabled'),
          value: _usePrice,
          onChanged: (value) {
            setState(() {
              _usePrice = value!;
            });
          },
        ),
        if (_usePrice) ...[
          const SizedBox(height: 8),
          const Text('Price Range:', style: TextStyle(fontWeight: FontWeight.w500)),
          RangeSlider(
            values: RangeValues(_priceMin, _priceMax),
            min: 1,
            max: 1000,
            divisions: 100,
            labels: RangeLabels('\$${_priceMin.round()}', '\$${_priceMax.round()}'),
            onChanged: (values) {
              setState(() {
                _priceMin = values.start;
                _priceMax = values.end;
              });
            },
          ),
        ],
        const Divider(),
      ],
    );
  }

  Widget _buildVolumeFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CheckboxListTile(
          title: const Text('Volume Filter'),
          subtitle: Text(_useVolume ? 'Min: ${_formatNumber(_volumeMin)}' : 'Disabled'),
          value: _useVolume,
          onChanged: (value) {
            setState(() {
              _useVolume = value!;
            });
          },
        ),
        if (_useVolume) ...[
          const SizedBox(height: 8),
          Text('Minimum Volume: ${_formatNumber(_volumeMin)}', 
               style: const TextStyle(fontWeight: FontWeight.w500)),
          Slider(
            value: _volumeMin,
            min: 100000, // 100K
            max: 100000000, // 100M
            divisions: 20,
            onChanged: (value) {
              setState(() {
                _volumeMin = value;
              });
            },
          ),
        ],
      ],
    );
  }

  Widget _buildResultsContent() {
    if (_error != null) {
      return Center(
        child: Card(
          color: Colors.red.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error, color: Colors.red.shade700, size: 48),
                const SizedBox(height: 8),
                Text(
                  'Error',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _error!,
                  style: TextStyle(color: Colors.red.shade700),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_results == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.filter_list,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'Set your filters above and click "Screen Stocks"',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Find stocks that match your criteria',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }

    if (_results!.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'No stocks match your criteria',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Try adjusting your filters',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      itemCount: _results!.length,
      itemBuilder: (context, index) {
        return StockResultCard(stockData: _results![index]);
      },
    );
  }

  String _formatNumber(double number) {
    if (number >= 1000000000000) {
      return '${(number / 1000000000000).toStringAsFixed(1)}T';
    } else if (number >= 1000000000) {
      return '${(number / 1000000000).toStringAsFixed(1)}B';
    } else if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toStringAsFixed(0);
  }
}
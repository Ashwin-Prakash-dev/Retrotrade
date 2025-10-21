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

  // Colors matching the app theme
  static const Color primaryBg = Color(0xFF0A0E27);
  static const Color secondaryBg = Color(0xFF121836);
  static const Color cardBg = Color(0xFF1A2138);
  static const Color accentCyan = Color(0xFF00F5FF);
  static const Color accentPurple = Color(0xFF8B5CF6);
  static const Color accentGreen = Color(0xFF00FF88);
  static const Color accentRed = Color(0xFFFF0055);
  static const Color accentOrange = Color(0xFFFFB84D);
  static const Color textPrimary = Color(0xFFE2E8F0);
  static const Color textSecondary = Color(0xFF94A3B8);

  // Filter states
  bool _useRSI = false;
  double _rsiMin = 30.0;
  double _rsiMax = 70.0;

  bool _useMacd = false;
  String _macdSignal = 'bullish';

  bool _useVWAP = false;
  String _vwapPosition = 'above';

  bool _usePE = false;
  double _peMin = 5.0;
  double _peMax = 30.0;

  bool _useMarketCap = false;
  double _marketCapMin = 1000000000;
  double _marketCapMax = 1000000000000;

  bool _useVolume = false;
  double _volumeMin = 1000000;

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
    if (!_useRSI && !_useMacd && !_useVWAP && !_usePE && 
        !_useMarketCap && !_useVolume && !_usePrice && _selectedSector == 'any') {
      setState(() {
        _error = 'Please select at least one filter criteria';
      });
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
      backgroundColor: primaryBg,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
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
              child: const Icon(Icons.filter_list, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              'STOCK SCREENER',
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
        iconTheme: const IconThemeData(color: accentCyan),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: _resetFilters,
            tooltip: 'Reset Filters',
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [secondaryBg, primaryBg],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sector Filter
              _buildSectionHeader('SECTOR', Icons.category),
              const SizedBox(height: 12),
              _buildSectorFilter(),

              const SizedBox(height: 24),

              // Technical Indicators
              _buildSectionHeader('TECHNICAL INDICATORS', Icons.show_chart),
              const SizedBox(height: 12),
              _buildRSIFilter(),
              const SizedBox(height: 12),
              _buildMACDFilter(),
              const SizedBox(height: 12),
              _buildVWAPFilter(),

              const SizedBox(height: 24),

              // Fundamental Analysis
              _buildSectionHeader('FUNDAMENTAL ANALYSIS', Icons.account_balance),
              const SizedBox(height: 12),
              _buildPEFilter(),
              const SizedBox(height: 12),
              _buildMarketCapFilter(),

              const SizedBox(height: 24),

              // Trading Metrics
              _buildSectionHeader('TRADING METRICS', Icons.trending_up),
              const SizedBox(height: 12),
              _buildPriceFilter(),
              const SizedBox(height: 12),
              _buildVolumeFilter(),

              const SizedBox(height: 32),

              // Screen Button
              _buildGradientButton(
                onPressed: _isLoading ? null : _runScreener,
                icon: _isLoading ? null : Icons.search,
                label: _isLoading ? 'SCREENING STOCKS...' : 'SCREEN STOCKS',
                gradientColors: [accentGreen, const Color(0xFF00CC66)],
                isLoading: _isLoading,
                height: 56,
              ),

              const SizedBox(height: 24),

              // Error Display
              if (_error != null) _buildErrorCard(),

              // Results Display
              if (_results != null) ...[
                _buildResultsHeader(),
                const SizedBox(height: 16),
                if (_results!.isEmpty)
                  _buildEmptyResults()
                else
                  ..._results!.map((stock) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: StockResultCard(stockData: stock),
                  )),
              ],
            ],
          ),
        ),
      ),
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

  Widget _buildSectorFilter() {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentCyan.withOpacity(0.2),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SELECT SECTOR',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textSecondary,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedSector,
            dropdownColor: cardBg,
            style: const TextStyle(color: textPrimary),
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: textSecondary.withOpacity(0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: textSecondary.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: accentCyan, width: 2),
              ),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
    );
  }

  Widget _buildRSIFilter() {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _useRSI ? accentCyan.withOpacity(0.5) : accentCyan.withOpacity(0.2),
          width: _useRSI ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          Theme(
            data: ThemeData.dark(),
            child: CheckboxListTile(
              title: const Text(
                'RSI Filter',
                style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                _useRSI ? 'Between ${_rsiMin.round()} - ${_rsiMax.round()}' : 'Disabled',
                style: TextStyle(color: textSecondary.withOpacity(0.8), fontSize: 12),
              ),
              value: _useRSI,
              activeColor: accentCyan,
              onChanged: (value) {
                setState(() {
                  _useRSI = value!;
                });
              },
            ),
          ),
          if (_useRSI) ...[
            Divider(height: 1, color: textSecondary.withOpacity(0.1)),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'RSI RANGE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: textSecondary,
                          letterSpacing: 1,
                        ),
                      ),
                      Text(
                        '${_rsiMin.round()} - ${_rsiMax.round()}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: accentCyan,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: accentCyan,
                      inactiveTrackColor: textSecondary.withOpacity(0.2),
                      thumbColor: accentCyan,
                      overlayColor: accentCyan.withOpacity(0.2),
                      rangeThumbShape: const RoundRangeSliderThumbShape(
                        enabledThumbRadius: 10,
                      ),
                    ),
                    child: RangeSlider(
                      values: RangeValues(_rsiMin, _rsiMax),
                      min: 0,
                      max: 100,
                      divisions: 20,
                      onChanged: (values) {
                        setState(() {
                          _rsiMin = values.start;
                          _rsiMax = values.end;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMACDFilter() {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _useMacd ? accentGreen.withOpacity(0.5) : accentCyan.withOpacity(0.2),
          width: _useMacd ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          Theme(
            data: ThemeData.dark(),
            child: CheckboxListTile(
              title: const Text(
                'MACD Filter',
                style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                _useMacd ? 'Signal: ${_macdSignal.toUpperCase()}' : 'Disabled',
                style: TextStyle(color: textSecondary.withOpacity(0.8), fontSize: 12),
              ),
              value: _useMacd,
              activeColor: accentGreen,
              onChanged: (value) {
                setState(() {
                  _useMacd = value!;
                });
              },
            ),
          ),
          if (_useMacd) ...[
            Divider(height: 1, color: textSecondary.withOpacity(0.1)),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MACD SIGNAL',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: textSecondary,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildSignalButton('bullish', 'Bullish', Icons.trending_up, accentGreen)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildSignalButton('bearish', 'Bearish', Icons.trending_down, accentRed)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildSignalButton('any', 'Any', Icons.remove, accentCyan)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSignalButton(String value, String label, IconData icon, Color color) {
    final isSelected = _macdSignal == value;
    return InkWell(
      onTap: () {
        setState(() {
          _macdSignal = value;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [color.withOpacity(0.2), color.withOpacity(0.1)],
                )
              : null,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : textSecondary.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? color : textSecondary,
              size: 20,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isSelected ? color : textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVWAPFilter() {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _useVWAP ? accentPurple.withOpacity(0.5) : accentCyan.withOpacity(0.2),
          width: _useVWAP ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          Theme(
            data: ThemeData.dark(),
            child: CheckboxListTile(
              title: const Text(
                'VWAP Filter',
                style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                _useVWAP ? 'Price ${_vwapPosition} VWAP' : 'Disabled',
                style: TextStyle(color: textSecondary.withOpacity(0.8), fontSize: 12),
              ),
              value: _useVWAP,
              activeColor: accentPurple,
              onChanged: (value) {
                setState(() {
                  _useVWAP = value!;
                });
              },
            ),
          ),
          if (_useVWAP) ...[
            Divider(height: 1, color: textSecondary.withOpacity(0.1)),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PRICE VS VWAP',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: textSecondary,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildPositionButton('above', 'Above', Icons.arrow_upward)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildPositionButton('below', 'Below', Icons.arrow_downward)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildPositionButton('any', 'Any', Icons.remove)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPositionButton(String value, String label, IconData icon) {
    final isSelected = _vwapPosition == value;
    return InkWell(
      onTap: () {
        setState(() {
          _vwapPosition = value;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [accentPurple.withOpacity(0.2), accentPurple.withOpacity(0.1)],
                )
              : null,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? accentPurple : textSecondary.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? accentPurple : textSecondary,
              size: 20,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isSelected ? accentPurple : textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPEFilter() {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _usePE ? accentOrange.withOpacity(0.5) : accentCyan.withOpacity(0.2),
          width: _usePE ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          Theme(
            data: ThemeData.dark(),
            child: CheckboxListTile(
              title: const Text(
                'P/E Ratio Filter',
                style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                _usePE ? 'Between ${_peMin.round()} - ${_peMax.round()}' : 'Disabled',
                style: TextStyle(color: textSecondary.withOpacity(0.8), fontSize: 12),
              ),
              value: _usePE,
              activeColor: accentOrange,
              onChanged: (value) {
                setState(() {
                  _usePE = value!;
                });
              },
            ),
          ),
          if (_usePE) ...[
            Divider(height: 1, color: textSecondary.withOpacity(0.1)),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'P/E RATIO RANGE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: textSecondary,
                          letterSpacing: 1,
                        ),
                      ),
                      Text(
                        '${_peMin.round()} - ${_peMax.round()}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: accentOrange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: accentOrange,
                      inactiveTrackColor: textSecondary.withOpacity(0.2),
                      thumbColor: accentOrange,
                      overlayColor: accentOrange.withOpacity(0.2),
                      rangeThumbShape: const RoundRangeSliderThumbShape(
                        enabledThumbRadius: 10,
                      ),
                    ),
                    child: RangeSlider(
                      values: RangeValues(_peMin, _peMax),
                      min: 1,
                      max: 100,
                      divisions: 99,
                      onChanged: (values) {
                        setState(() {
                          _peMin = values.start;
                          _peMax = values.end;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMarketCapFilter() {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _useMarketCap ? accentGreen.withOpacity(0.5) : accentCyan.withOpacity(0.2),
          width: _useMarketCap ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          Theme(
            data: ThemeData.dark(),
            child: CheckboxListTile(
              title: const Text(
                'Market Cap Filter',
                style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                _useMarketCap 
                    ? 'Between \$${_formatNumber(_marketCapMin)} - \$${_formatNumber(_marketCapMax)}' 
                    : 'Disabled',
                style: TextStyle(color: textSecondary.withOpacity(0.8), fontSize: 12),
              ),
              value: _useMarketCap,
              activeColor: accentGreen,
              onChanged: (value) {
                setState(() {
                  _useMarketCap = value!;
                });
              },
            ),
          ),
          if (_useMarketCap) ...[
            Divider(height: 1, color: textSecondary.withOpacity(0.1)),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'MARKET CAP RANGE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: textSecondary,
                          letterSpacing: 1,
                        ),
                      ),
                      Text(
                        '\$${_formatNumber(_marketCapMin)} - \$${_formatNumber(_marketCapMax)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: accentGreen,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: accentGreen,
                      inactiveTrackColor: textSecondary.withOpacity(0.2),
                      thumbColor: accentGreen,
                      overlayColor: accentGreen.withOpacity(0.2),
                      rangeThumbShape: const RoundRangeSliderThumbShape(
                        enabledThumbRadius: 10,
                      ),
                    ),
                    child: RangeSlider(
                      values: RangeValues(_marketCapMin, _marketCapMax),
                      min: 100000000,
                      max: 3000000000000,
                      divisions: 20,
                      onChanged: (values) {
                        setState(() {
                          _marketCapMin = values.start;
                          _marketCapMax = values.end;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPriceFilter() {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _usePrice ? accentCyan.withOpacity(0.5) : accentCyan.withOpacity(0.2),
          width: _usePrice ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          Theme(
            data: ThemeData.dark(),
            child: CheckboxListTile(
              title: const Text(
                'Price Filter',
                style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                _usePrice ? 'Between \${_priceMin.round()} - \${_priceMax.round()}' : 'Disabled',
                style: TextStyle(color: textSecondary.withOpacity(0.8), fontSize: 12),
              ),
              value: _usePrice,
              activeColor: accentCyan,
              onChanged: (value) {
                setState(() {
                  _usePrice = value!;
                });
              },
            ),
          ),
          if (_usePrice) ...[
            Divider(height: 1, color: textSecondary.withOpacity(0.1)),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'PRICE RANGE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: textSecondary,
                          letterSpacing: 1,
                        ),
                      ),
                      Text(
                        '\${_priceMin.round()} - \${_priceMax.round()}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: accentCyan,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: accentCyan,
                      inactiveTrackColor: textSecondary.withOpacity(0.2),
                      thumbColor: accentCyan,
                      overlayColor: accentCyan.withOpacity(0.2),
                      rangeThumbShape: const RoundRangeSliderThumbShape(
                        enabledThumbRadius: 10,
                      ),
                    ),
                    child: RangeSlider(
                      values: RangeValues(_priceMin, _priceMax),
                      min: 1,
                      max: 1000,
                      divisions: 100,
                      onChanged: (values) {
                        setState(() {
                          _priceMin = values.start;
                          _priceMax = values.end;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVolumeFilter() {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _useVolume ? accentPurple.withOpacity(0.5) : accentCyan.withOpacity(0.2),
          width: _useVolume ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          Theme(
            data: ThemeData.dark(),
            child: CheckboxListTile(
              title: const Text(
                'Volume Filter',
                style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                _useVolume ? 'Min: ${_formatNumber(_volumeMin)}' : 'Disabled',
                style: TextStyle(color: textSecondary.withOpacity(0.8), fontSize: 12),
              ),
              value: _useVolume,
              activeColor: accentPurple,
              onChanged: (value) {
                setState(() {
                  _useVolume = value!;
                });
              },
            ),
          ),
          if (_useVolume) ...[
            Divider(height: 1, color: textSecondary.withOpacity(0.1)),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'MINIMUM VOLUME',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: textSecondary,
                          letterSpacing: 1,
                        ),
                      ),
                      Text(
                        _formatNumber(_volumeMin),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: accentPurple,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: accentPurple,
                      inactiveTrackColor: textSecondary.withOpacity(0.2),
                      thumbColor: accentPurple,
                      overlayColor: accentPurple.withOpacity(0.2),
                    ),
                    child: Slider(
                      value: _volumeMin,
                      min: 100000,
                      max: 100000000,
                      divisions: 20,
                      onChanged: (value) {
                        setState(() {
                          _volumeMin = value;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGradientButton({
    required VoidCallback? onPressed,
    IconData? icon,
    required String label,
    required List<Color> gradientColors,
    bool isLoading = false,
    double height = 48,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          gradient: onPressed == null
              ? LinearGradient(colors: [Colors.grey.shade700, Colors.grey.shade800])
              : LinearGradient(colors: gradientColors),
          borderRadius: BorderRadius.circular(16),
          boxShadow: onPressed != null
              ? [
                  BoxShadow(
                    color: gradientColors[0].withOpacity(0.3),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, color: Colors.white),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      decoration: BoxDecoration(
        color: accentRed.withOpacity(0.1),
        border: Border.all(color: accentRed.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: accentRed),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _error!,
                style: TextStyle(
                  color: accentRed,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsHeader() {
    return Container(
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
                gradient: const LinearGradient(
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
              child: const Icon(Icons.check_circle_outline, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SCREENING COMPLETE',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Found ${_results!.length} matching ${_results!.length == 1 ? 'stock' : 'stocks'}',
                    style: TextStyle(
                      fontSize: 13,
                      color: textSecondary,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [accentGreen, Color(0xFF00CC66)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_results!.length}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyResults() {
    return Container(
      padding: const EdgeInsets.all(48.0),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accentCyan.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [textSecondary.withOpacity(0.2), textSecondary.withOpacity(0.1)],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_off,
                size: 64,
                color: textSecondary.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'NO STOCKS FOUND',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textPrimary,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No stocks match your current filter criteria',
              style: TextStyle(
                fontSize: 14,
                color: textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Try adjusting your filters or reset to defaults',
              style: TextStyle(
                fontSize: 12,
                color: textSecondary.withOpacity(0.7),
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _buildGradientButton(
              onPressed: _resetFilters,
              icon: Icons.refresh,
              label: 'RESET FILTERS',
              gradientColors: [accentCyan, accentPurple],
              height: 44,
            ),
          ],
        ),
      ),
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
import 'package:flutter/material.dart';
import 'dart:async';
import '../services/api_service.dart';
import '../widgets/backtest_results_card.dart';

class BacktestScreen extends StatefulWidget {
  final String? initialTicker;

  const BacktestScreen({super.key, this.initialTicker});

  @override
  State<BacktestScreen> createState() => _BacktestScreenState();
}

class _BacktestScreenState extends State<BacktestScreen> {
  final _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  
  // Colors matching home screen
  static const Color primaryBg = Color(0xFF0A0E27);
  static const Color secondaryBg = Color(0xFF121836);
  static const Color cardBg = Color(0xFF1A2138);
  static const Color accentCyan = Color(0xFF00F5FF);
  static const Color accentPurple = Color(0xFF8B5CF6);
  static const Color accentGreen = Color(0xFF00FF88);
  static const Color accentRed = Color(0xFFFF0055);
  static const Color textPrimary = Color(0xFFE2E8F0);
  static const Color textSecondary = Color(0xFF94A3B8);
  
  // Strategy selection
  String _selectedStrategy = 'RSI';
  
  // RSI Controllers
  final _rsiPeriodController = TextEditingController(text: '14');
  final _rsiBuyController = TextEditingController(text: '30');
  final _rsiSellController = TextEditingController(text: '70');
  
  // MACD Controllers
  final _macdFastController = TextEditingController(text: '12');
  final _macdSlowController = TextEditingController(text: '26');
  final _macdSignalController = TextEditingController(text: '9');
  
  // Volume Spike Controllers
  final _volumeMultiplierController = TextEditingController(text: '2.0');
  final _volumePeriodController = TextEditingController(text: '20');
  final _volumeHoldDaysController = TextEditingController(text: '5');
  
  final _initialCashController = TextEditingController(text: '100000');
  
  // State
  bool _isLoading = false;
  Map<String, dynamic>? _results;
  String? _error;
  
  // Date range
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 365));
  DateTime _endDate = DateTime.now();
  
  // Portfolio stocks
  List<PortfolioStockInput> _portfolioStocks = [];
  bool _rebalance = false;
  String _rebalanceFrequency = 'monthly';

  @override
  void initState() {
    super.initState();
    if (widget.initialTicker != null) {
      _portfolioStocks.add(PortfolioStockInput(
        ticker: widget.initialTicker!,
        allocation: 100.0,
      ));
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate : _endDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: accentCyan,
              onPrimary: Colors.black,
              surface: cardBg,
              onSurface: textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          if (_startDate.isAfter(_endDate)) {
            _endDate = _startDate.add(const Duration(days: 30));
          }
        } else {
          _endDate = picked;
          if (_endDate.isBefore(_startDate)) {
            _startDate = _endDate.subtract(const Duration(days: 30));
          }
        }
      });
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _runBacktest() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _results = null;
    });

    try {
      if (_portfolioStocks.isEmpty) {
        throw 'Please add at least one stock to the portfolio';
      }
      
      final totalAllocation = _portfolioStocks.fold<double>(
        0, (sum, stock) => sum + stock.allocation
      );
      
      if ((totalAllocation - 100.0).abs() > 0.01) {
        throw 'Portfolio allocations must sum to 100% (current: ${totalAllocation.toStringAsFixed(1)}%)';
      }
      
      // Build strategy parameters based on selected strategy
      final Map<String, dynamic> strategyParams = {
        'strategy': _selectedStrategy,
      };
      
      switch (_selectedStrategy) {
        case 'RSI':
          strategyParams['rsi_period'] = int.parse(_rsiPeriodController.text);
          strategyParams['rsi_buy'] = int.parse(_rsiBuyController.text);
          strategyParams['rsi_sell'] = int.parse(_rsiSellController.text);
          break;
        case 'MACD':
          strategyParams['macd_fast'] = int.parse(_macdFastController.text);
          strategyParams['macd_slow'] = int.parse(_macdSlowController.text);
          strategyParams['macd_signal'] = int.parse(_macdSignalController.text);
          break;
        case 'Volume_Spike':
          strategyParams['volume_multiplier'] = double.parse(_volumeMultiplierController.text);
          strategyParams['volume_period'] = int.parse(_volumePeriodController.text);
          strategyParams['volume_hold_days'] = int.parse(_volumeHoldDaysController.text);
          break;
      }
      
      final results = await _apiService.runPortfolioBacktest(
        stocks: _portfolioStocks.map((s) => PortfolioStock(
          ticker: s.ticker,
          allocation: s.allocation,
        )).toList(),
        startDate: _formatDate(_startDate),
        endDate: _formatDate(_endDate),
        initialCash: double.parse(_initialCashController.text),
        rebalance: _rebalance,
        rebalanceFrequency: _rebalanceFrequency,
        strategyParams: strategyParams,
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

  void _addPortfolioStock() {
    showDialog(
      context: context,
      builder: (context) => _AddStockDialog(
        onAdd: (ticker, allocation) {
          setState(() {
            _portfolioStocks.add(PortfolioStockInput(
              ticker: ticker,
              allocation: allocation,
            ));
          });
        },
      ),
    );
  }

  void _removePortfolioStock(int index) {
    setState(() {
      _portfolioStocks.removeAt(index);
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
              child: const Icon(Icons.analytics, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              'PORTFOLIO BACKTEST',
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
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Portfolio Stocks Section
                _buildSectionHeader('PORTFOLIO STOCKS', Icons.pie_chart),
                const SizedBox(height: 12),
                _buildPortfolioList(),
                const SizedBox(height: 12),
                _buildGradientButton(
                  onPressed: _addPortfolioStock,
                  icon: Icons.add,
                  label: 'Add Stock',
                  gradientColors: [accentCyan, accentPurple],
                ),

                const SizedBox(height: 24),

                // Date Range Section
                _buildSectionHeader('DATE RANGE', Icons.calendar_today),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildDateCard(
                        'Start Date',
                        _startDate,
                        () => _selectDate(context, true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildDateCard(
                        'End Date',
                        _endDate,
                        () => _selectDate(context, false),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Strategy Selection
                _buildSectionHeader('TRADING STRATEGY', Icons.psychology),
                const SizedBox(height: 12),
                _buildStrategySelector(),

                const SizedBox(height: 24),

                // Strategy Parameters Section
                _buildStrategyParameters(),

                const SizedBox(height: 24),

                // Initial Cash
                _buildSectionHeader('INITIAL INVESTMENT', Icons.account_balance_wallet),
                const SizedBox(height: 12),
                _buildInputCard(
                  child: _buildNumberField(
                    controller: _initialCashController,
                    label: 'Initial Cash (\$)',
                    hint: '100000',
                    min: 1000,
                  ),
                ),

                // Portfolio Options
                const SizedBox(height: 24),
                _buildSectionHeader('PORTFOLIO OPTIONS', Icons.settings_suggest),
                const SizedBox(height: 12),
                _buildPortfolioOptions(),

                const SizedBox(height: 32),

                // Run Backtest Button
                _buildGradientButton(
                  onPressed: _isLoading ? null : _runBacktest,
                  icon: _isLoading ? null : Icons.play_arrow,
                  label: _isLoading ? 'RUNNING BACKTEST...' : 'RUN PORTFOLIO BACKTEST',
                  gradientColors: [accentGreen, const Color(0xFF00CC66)],
                  isLoading: _isLoading,
                  height: 56,
                ),

                const SizedBox(height: 24),

                // Error Display
                if (_error != null) _buildErrorCard(),

                // Results Display
                if (_results != null) ...[
                  BacktestResultsCard(results: _results!),
                  
                  if (_results!.containsKey('stock_performances')) ...[
                    const SizedBox(height: 16),
                    _buildPortfolioPerformanceCard(),
                    
                    const SizedBox(height: 16),
                    _buildPortfolioCompositionCard(),
                  ],
                ],
              ],
            ),
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

  Widget _buildPortfolioList() {
    if (_portfolioStocks.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: accentCyan.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            children: [
              Icon(Icons.pie_chart_outline, size: 48, color: textSecondary.withOpacity(0.5)),
              const SizedBox(height: 12),
              const Text(
                'No stocks added',
                style: TextStyle(color: textSecondary, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                'Add stocks to create your portfolio',
                style: TextStyle(fontSize: 12, color: textSecondary.withOpacity(0.7)),
              ),
            ],
          ),
        ),
      );
    }

    final totalAllocation = _portfolioStocks.fold<double>(
      0, (sum, stock) => sum + stock.allocation
    );

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentCyan.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'TOTAL ALLOCATION',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: textSecondary,
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      '${totalAllocation.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: (totalAllocation - 100.0).abs() < 0.01
                            ? accentGreen
                            : const Color(0xFFFFB84D),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: FractionallySizedBox(
                    widthFactor: (totalAllocation / 100).clamp(0.0, 1.0),
                    alignment: Alignment.centerLeft,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: (totalAllocation - 100.0).abs() < 0.01
                              ? [accentGreen, accentGreen]
                              : [const Color(0xFFFFB84D), const Color(0xFFFF9800)],
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: textSecondary.withOpacity(0.1)),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _portfolioStocks.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              color: textSecondary.withOpacity(0.1),
            ),
            itemBuilder: (context, index) {
              final stock = _portfolioStocks[index];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [accentCyan.withOpacity(0.3), accentPurple.withOpacity(0.3)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          stock.ticker.substring(0, 1),
                          style: const TextStyle(
                            color: accentCyan,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stock.ticker,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: textPrimary,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            '${stock.allocation.toStringAsFixed(1)}% allocation',
                            style: TextStyle(
                              fontSize: 12,
                              color: textSecondary.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: accentRed),
                      onPressed: () => _removePortfolioStock(index),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDateCard(String label, DateTime date, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: accentCyan.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                color: textSecondary,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDate(date),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
                Icon(Icons.calendar_today, size: 16, color: accentCyan),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStrategySelector() {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentCyan.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SELECT STRATEGY',
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
                Expanded(child: _buildStrategyButton('RSI', Icons.show_chart)),
                const SizedBox(width: 8),
                Expanded(child: _buildStrategyButton('MACD', Icons.trending_up)),
                const SizedBox(width: 8),
                Expanded(child: _buildStrategyButton('Volume_Spike', Icons.bar_chart)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStrategyButton(String strategy, IconData icon) {
    final isSelected = _selectedStrategy == strategy;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedStrategy = strategy;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [accentCyan.withOpacity(0.2), accentPurple.withOpacity(0.2)],
                )
              : null,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? accentCyan : textSecondary.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? accentCyan : textSecondary,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              strategy.replaceAll('_', '\n'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isSelected ? accentCyan : textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStrategyParameters() {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentPurple.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: accentPurple.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(Icons.settings, size: 16, color: accentPurple),
                ),
                const SizedBox(width: 8),
                Text(
                  '${_selectedStrategy.replaceAll('_', ' ').toUpperCase()} PARAMETERS',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildStrategySpecificFields(),
          ],
        ),
      ),
    );
  }

  Widget _buildStrategySpecificFields() {
    switch (_selectedStrategy) {
      case 'RSI':
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildNumberField(
                    controller: _rsiPeriodController,
                    label: 'RSI Period',
                    hint: '14',
                    min: 5,
                    max: 50,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildNumberField(
                    controller: _rsiBuyController,
                    label: 'Buy Threshold',
                    hint: '30',
                    min: 0,
                    max: 100,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildNumberField(
              controller: _rsiSellController,
              label: 'Sell Threshold',
              hint: '70',
              min: 0,
              max: 100,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: accentCyan.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: accentCyan.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: accentCyan),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Buy when RSI < ${_rsiBuyController.text} (oversold), Sell when RSI > ${_rsiSellController.text} (overbought)',
                      style: TextStyle(fontSize: 11, color: accentCyan.withOpacity(0.9)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      
      case 'MACD':
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildNumberField(
                    controller: _macdFastController,
                    label: 'Fast Period',
                    hint: '12',
                    min: 5,
                    max: 50,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildNumberField(
                    controller: _macdSlowController,
                    label: 'Slow Period',
                    hint: '26',
                    min: 10,
                    max: 100,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildNumberField(
              controller: _macdSignalController,
              label: 'Signal Period',
              hint: '9',
              min: 5,
              max: 30,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: accentGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: accentGreen.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: accentGreen),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Buy when MACD crosses above Signal (bullish), Sell when MACD crosses below Signal (bearish)',
                      style: TextStyle(fontSize: 11, color: accentGreen.withOpacity(0.9)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      
      case 'Volume_Spike':
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildNumberField(
                    controller: _volumeMultiplierController,
                    label: 'Volume Multiplier',
                    hint: '2.0',
                    min: 1.0,
                    max: 10.0,
                    isDecimal: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildNumberField(
                    controller: _volumePeriodController,
                    label: 'Average Period',
                    hint: '20',
                    min: 5,
                    max: 100,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildNumberField(
              controller: _volumeHoldDaysController,
              label: 'Hold Days',
              hint: '5',
              min: 1,
              max: 30,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFB84D).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFFB84D).withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Color(0xFFFFB84D)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Buy when volume exceeds ${_volumeMultiplierController.text}x average, Hold for ${_volumeHoldDaysController.text} days',
                      style: const TextStyle(fontSize: 11, color: Color(0xFFFFB84D)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildInputCard({required Widget child}) {
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
      child: child,
    );
  }

  Widget _buildNumberField({
    required TextEditingController controller,
    required String label,
    required String hint,
    double? min,
    double? max,
    bool isDecimal = false,
  }) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: textSecondary),
        hintText: hint,
        hintStyle: TextStyle(color: textSecondary.withOpacity(0.5)),
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accentRed),
        ),
        isDense: true,
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
      ),
      keyboardType: TextInputType.numberWithOptions(decimal: isDecimal),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Required';
        }
        final num = double.tryParse(value);
        if (num == null) {
          return 'Invalid number';
        }
        if (min != null && num < min) {
          return 'Min: $min';
        }
        if (max != null && num > max) {
          return 'Max: $max';
        }
        return null;
      },
    );
  }

  Widget _buildPortfolioOptions() {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentPurple.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Theme(
            data: ThemeData.dark(),
            child: SwitchListTile(
              title: const Text(
                'Enable Rebalancing',
                style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                'Periodically adjust portfolio allocations',
                style: TextStyle(color: textSecondary.withOpacity(0.8), fontSize: 12),
              ),
              value: _rebalance,
              activeColor: accentCyan,
              onChanged: (value) {
                setState(() {
                  _rebalance = value;
                });
              },
            ),
          ),
          if (_rebalance) ...[
            Divider(height: 1, color: textSecondary.withOpacity(0.1)),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'REBALANCE FREQUENCY',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: textSecondary,
                      letterSpacing: 1,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: accentCyan.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: accentCyan.withOpacity(0.3)),
                    ),
                    child: DropdownButton<String>(
                      value: _rebalanceFrequency,
                      dropdownColor: cardBg,
                      underline: const SizedBox(),
                      style: const TextStyle(color: accentCyan, fontWeight: FontWeight.w600),
                      items: const [
                        DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                        DropdownMenuItem(value: 'quarterly', child: Text('Quarterly')),
                        DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _rebalanceFrequency = value;
                          });
                        }
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

  Widget _buildPortfolioPerformanceCard() {
    final performances = _results!['stock_performances'] as List<dynamic>;
    
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accentCyan.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [accentCyan.withOpacity(0.3), accentPurple.withOpacity(0.3)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.analytics, color: accentCyan, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'INDIVIDUAL STOCK PERFORMANCE',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: performances.length,
              separatorBuilder: (context, index) => Divider(
                color: textSecondary.withOpacity(0.1),
              ),
              itemBuilder: (context, index) {
                final perf = performances[index] as Map<String, dynamic>;
                final ticker = perf['ticker'] as String;
                final trades = perf['trades'] as int;
                final winningTrades = perf['winning_trades'] as int;
                final allocation = perf['allocation'] as num;
                final winRate = trades > 0 ? (winningTrades / trades * 100) : 0.0;
                
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [accentCyan.withOpacity(0.2), accentPurple.withOpacity(0.2)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            ticker.substring(0, 1),
                            style: const TextStyle(
                              color: accentCyan,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ticker,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: textPrimary,
                              ),
                            ),
                            Text(
                              '$trades trades • ${allocation.toStringAsFixed(1)}% allocation',
                              style: TextStyle(
                                fontSize: 12,
                                color: textSecondary.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${winRate.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: winRate >= 50 ? accentGreen : accentRed,
                            ),
                          ),
                          Text(
                            'win rate',
                            style: TextStyle(
                              fontSize: 10,
                              color: textSecondary.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPortfolioCompositionCard() {
    final composition = _results!['portfolio_composition'] as List<dynamic>;
    
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accentGreen.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [accentGreen.withOpacity(0.3), const Color(0xFF00CC66).withOpacity(0.3)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.pie_chart, color: accentGreen, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'FINAL PORTFOLIO COMPOSITION',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: composition.length,
              separatorBuilder: (context, index) => Divider(
                color: textSecondary.withOpacity(0.1),
              ),
              itemBuilder: (context, index) {
                final comp = composition[index];
                
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [accentGreen.withOpacity(0.2), const Color(0xFF00CC66).withOpacity(0.2)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            (comp['ticker'] as String).substring(0, 1),
                            style: const TextStyle(
                              color: accentGreen,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              comp['ticker'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: textPrimary,
                              ),
                            ),
                            Text(
                              '${comp['position_size']} shares • ${comp['position_value'].toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: textSecondary.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${(comp['actual_allocation'] as num).toStringAsFixed(1)}%',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: textPrimary,
                            ),
                          ),
                          Text(
                            'target: ${(comp['target_allocation'] as num).toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 10,
                              color: textSecondary.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _rsiPeriodController.dispose();
    _rsiBuyController.dispose();
    _rsiSellController.dispose();
    _macdFastController.dispose();
    _macdSlowController.dispose();
    _macdSignalController.dispose();
    _volumeMultiplierController.dispose();
    _volumePeriodController.dispose();
    _volumeHoldDaysController.dispose();
    _initialCashController.dispose();
    super.dispose();
  }
}

class PortfolioStockInput {
  final String ticker;
  final double allocation;

  PortfolioStockInput({
    required this.ticker,
    required this.allocation,
  });
}

// Updated dialog with autocomplete
class _AddStockDialog extends StatefulWidget {
  final Function(String ticker, double allocation) onAdd;

  const _AddStockDialog({required this.onAdd});

  @override
  State<_AddStockDialog> createState() => _AddStockDialogState();
}

class _AddStockDialogState extends State<_AddStockDialog> {
  static const Color cardBg = Color(0xFF1A2138);
  static const Color accentCyan = Color(0xFF00F5FF);
  static const Color textPrimary = Color(0xFFE2E8F0);
  static const Color textSecondary = Color(0xFF94A3B8);
  
  final _formKey = GlobalKey<FormState>();
  final _tickerController = TextEditingController();
  final _allocationController = TextEditingController();
  String _selectedSymbol = '';

  void _onStockSelected(String symbol, String companyName) {
    setState(() {
      _selectedSymbol = symbol;
      _tickerController.text = symbol;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: accentCyan.withOpacity(0.3)),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ADD STOCK TO PORTFOLIO',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              
              // Custom autocomplete field without search button
              _StockAutocompleteField(
                controller: _tickerController,
                onStockSelected: _onStockSelected,
              ),
              
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _allocationController,
                style: const TextStyle(color: textPrimary),
                decoration: InputDecoration(
                  labelText: 'Allocation (%)',
                  labelStyle: TextStyle(color: textSecondary),
                  hintText: 'e.g., 25',
                  hintStyle: TextStyle(color: textSecondary.withOpacity(0.5)),
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
                  suffixText: '%',
                  suffixStyle: TextStyle(color: textSecondary),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter allocation';
                  }
                  final num = double.tryParse(value);
                  if (num == null || num <= 0 || num > 100) {
                    return 'Enter 0-100';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 24),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'CANCEL',
                      style: TextStyle(color: textSecondary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [accentCyan, Color(0xFF8B5CF6)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextButton(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          final symbol = _selectedSymbol.isNotEmpty 
                              ? _selectedSymbol 
                              : _tickerController.text.split(' ').first.toUpperCase().trim();
                          
                          if (symbol.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter a valid ticker symbol'),
                                backgroundColor: Color(0xFFFF0055),
                              ),
                            );
                            return;
                          }
                          
                          widget.onAdd(
                            symbol,
                            double.parse(_allocationController.text),
                          );
                          Navigator.pop(context);
                        }
                      },
                      child: const Text(
                        'ADD',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tickerController.dispose();
    _allocationController.dispose();
    super.dispose();
  }
}

// Custom autocomplete field without search button
class _StockAutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final Function(String symbol, String companyName) onStockSelected;

  const _StockAutocompleteField({
    required this.controller,
    required this.onStockSelected,
  });

  @override
  State<_StockAutocompleteField> createState() => _StockAutocompleteFieldState();
}

class _StockAutocompleteFieldState extends State<_StockAutocompleteField> {
  static const Color cardBg = Color(0xFF1A2138);
  static const Color accentCyan = Color(0xFF00F5FF);
  static const Color accentPurple = Color(0xFF8B5CF6);
  static const Color textPrimary = Color(0xFFE2E8F0);
  static const Color textSecondary = Color(0xFF94A3B8);
  
  final _focusNode = FocusNode();
  final _apiService = ApiService();
  
  List<StockSuggestion> _suggestions = [];
  bool _isLoadingSuggestions = false;
  bool _showSuggestions = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onTextChanged() {
    final text = widget.controller.text.trim();
    
    if (text.isEmpty) {
      setState(() {
        _suggestions.clear();
        _showSuggestions = false;
      });
      return;
    }

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _fetchSuggestions(text);
    });
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) {
          setState(() {
            _showSuggestions = false;
          });
        }
      });
    }
  }

  Future<void> _fetchSuggestions(String query) async {
    if (query.length < 1) return;

    setState(() {
      _isLoadingSuggestions = true;
    });

    try {
      final results = await _apiService.getStockSuggestions(query);
      
      if (mounted) {
        setState(() {
          _suggestions = results;
          _showSuggestions = results.isNotEmpty;
          _isLoadingSuggestions = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _suggestions.clear();
          _showSuggestions = false;
          _isLoadingSuggestions = false;
        });
      }
    }
  }

  void _selectSuggestion(StockSuggestion suggestion) {
    setState(() {
      _showSuggestions = false;
    });
    _focusNode.unfocus();
    widget.onStockSelected(suggestion.symbol, suggestion.companyName);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextFormField(
          controller: widget.controller,
          focusNode: _focusNode,
          style: const TextStyle(color: textPrimary),
          decoration: InputDecoration(
            labelText: 'Ticker Symbol',
            labelStyle: TextStyle(color: textSecondary),
            hintText: 'Search by symbol or company name',
            hintStyle: TextStyle(color: textSecondary.withOpacity(0.5)),
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
            prefixIcon: const Icon(Icons.search, color: textSecondary),
            suffixIcon: _isLoadingSuggestions
                ? const Padding(
                    padding: EdgeInsets.all(14.0),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: accentCyan,
                      ),
                    ),
                  )
                : widget.controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: textSecondary),
                        onPressed: () {
                          widget.controller.clear();
                          setState(() {
                            _suggestions.clear();
                            _showSuggestions = false;
                          });
                        },
                      )
                    : null,
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
          ),
          textCapitalization: TextCapitalization.characters,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter a ticker';
            }
            return null;
          },
        ),
        
        // Suggestions List
        if (_showSuggestions && _suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: accentCyan.withOpacity(0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _suggestions.length,
              itemBuilder: (context, index) {
                final suggestion = _suggestions[index];
                return InkWell(
                  onTap: () => _selectSuggestion(suggestion),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      border: index < _suggestions.length - 1
                          ? Border(
                              bottom: BorderSide(
                                color: textSecondary.withOpacity(0.1),
                                width: 1,
                              ),
                            )
                          : null,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                accentCyan.withOpacity(0.2),
                                accentPurple.withOpacity(0.2),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            suggestion.symbol,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: accentCyan,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            suggestion.companyName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
          ),
      ],
    );
  }
}
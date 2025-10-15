import 'package:flutter/material.dart';
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
      appBar: AppBar(
        title: const Text('Portfolio Backtest'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Portfolio Stocks Section
              _buildSectionHeader('Portfolio Stocks', Icons.pie_chart),
              const SizedBox(height: 8),
              _buildPortfolioList(),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _addPortfolioStock,
                icon: const Icon(Icons.add),
                label: const Text('Add Stock'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 45),
                ),
              ),

              const SizedBox(height: 20),

              // Date Range Section
              _buildSectionHeader('Date Range', Icons.calendar_today),
              const SizedBox(height: 8),
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

              const SizedBox(height: 20),

              // Strategy Selection
              _buildSectionHeader('Trading Strategy', Icons.psychology),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select Strategy:',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: 'RSI',
                            label: Text('RSI'),
                            icon: Icon(Icons.show_chart),
                          ),
                          ButtonSegment(
                            value: 'MACD',
                            label: Text('MACD'),
                            icon: Icon(Icons.trending_up),
                          ),
                          ButtonSegment(
                            value: 'Volume_Spike',
                            label: Text('Volume'),
                            icon: Icon(Icons.bar_chart),
                          ),
                        ],
                        selected: {_selectedStrategy},
                        onSelectionChanged: (Set<String> selection) {
                          setState(() {
                            _selectedStrategy = selection.first;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Strategy Parameters Section
              _buildStrategyParameters(),

              const SizedBox(height: 20),

              // Initial Cash
              _buildSectionHeader('Initial Investment', Icons.account_balance_wallet),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: _buildNumberField(
                    controller: _initialCashController,
                    label: 'Initial Cash (\$)',
                    hint: '100000',
                    min: 1000,
                  ),
                ),
              ),

              // Portfolio Options
              const SizedBox(height: 20),
              _buildSectionHeader('Portfolio Options', Icons.settings_suggest),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('Enable Rebalancing'),
                        subtitle: const Text('Periodically adjust portfolio allocations'),
                        value: _rebalance,
                        onChanged: (value) {
                          setState(() {
                            _rebalance = value;
                          });
                        },
                      ),
                      if (_rebalance) ...[
                        const Divider(),
                        ListTile(
                          title: const Text('Rebalance Frequency'),
                          trailing: DropdownButton<String>(
                            value: _rebalanceFrequency,
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
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Run Backtest Button
              ElevatedButton(
                onPressed: _isLoading ? null : _runBacktest,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.play_arrow),
                          SizedBox(width: 8),
                          Text(
                            'Run Portfolio Backtest',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ),

              const SizedBox(height: 24),

              // Error Display
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
    );
  }

  Widget _buildStrategyParameters() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings, size: 20, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(
                  '${_selectedStrategy.replaceAll('_', ' ')} Parameters',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
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
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Buy when RSI < Buy Threshold (oversold), Sell when RSI > Sell Threshold (overbought)',
                      style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
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
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.green.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Buy when MACD crosses above Signal line (bullish), Sell when MACD crosses below Signal line (bearish)',
                      style: TextStyle(fontSize: 12, color: Colors.green.shade700),
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
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Buy when volume exceeds ${_volumeMultiplierController.text}x average, Hold for ${_volumeHoldDaysController.text} days',
                      style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
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

  Widget _buildDateCard(String label, DateTime date, VoidCallback onTap) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDate(date),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Icon(Icons.edit_calendar, size: 18, color: Colors.grey.shade600),
                ],
              ),
            ],
          ),
        ),
      ),
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
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        isDense: true,
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

  Widget _buildPortfolioList() {
    if (_portfolioStocks.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            children: [
              Icon(Icons.pie_chart_outline, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 8),
              Text(
                'No stocks added',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 4),
              Text(
                'Add stocks to create your portfolio',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      );
    }

    final totalAllocation = _portfolioStocks.fold<double>(
      0, (sum, stock) => sum + stock.allocation
    );

    return Card(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Allocation',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${totalAllocation.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: (totalAllocation - 100.0).abs() < 0.01
                            ? Colors.green.shade700
                            : Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: totalAllocation / 100,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation(
                    (totalAllocation - 100.0).abs() < 0.01
                        ? Colors.green
                        : Colors.orange,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _portfolioStocks.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final stock = _portfolioStocks[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.shade100,
                  child: Text(
                    stock.ticker.substring(0, 1),
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  stock.ticker,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text('${stock.allocation.toStringAsFixed(1)}% allocation'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _removePortfolioStock(index),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPortfolioPerformanceCard() {
    final performances = _results!['stock_performances'] as List<dynamic>;
    
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: Colors.blue.shade700, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Individual Stock Performance',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: performances.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final perf = performances[index];
                final winRate = perf['trades'] > 0
                    ? (perf['winning_trades'] / perf['trades'] * 100)
                    : 0.0;
                
                return ListTile(
                  title: Text(
                    perf['ticker'],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${perf['trades']} trades • ${perf['allocation'].toStringAsFixed(1)}% allocation',
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${winRate.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: winRate >= 50 ? Colors.green.shade700 : Colors.red.shade700,
                        ),
                      ),
                      Text(
                        'win rate',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
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
    
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.pie_chart, color: Colors.green.shade700, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Final Portfolio Composition',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: composition.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final comp = composition[index];
                
                return ListTile(
                  title: Text(
                    comp['ticker'],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Position: ${comp['position_size']} shares'),
                      Text('Value: \$${comp['position_value'].toStringAsFixed(2)}'),
                    ],
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${comp['actual_allocation'].toStringAsFixed(1)}%',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'target: ${comp['target_allocation'].toStringAsFixed(1)}%',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
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

class _AddStockDialog extends StatefulWidget {
  final Function(String ticker, double allocation) onAdd;

  const _AddStockDialog({required this.onAdd});

  @override
  State<_AddStockDialog> createState() => _AddStockDialogState();
}

class _AddStockDialogState extends State<_AddStockDialog> {
  final _formKey = GlobalKey<FormState>();
  final _tickerController = TextEditingController();
  final _allocationController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Stock to Portfolio'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _tickerController,
              decoration: const InputDecoration(
                labelText: 'Ticker Symbol',
                hintText: 'e.g., AAPL',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.characters,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a ticker';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _allocationController,
              decoration: const InputDecoration(
                labelText: 'Allocation (%)',
                hintText: 'e.g., 25',
                border: OutlineInputBorder(),
                suffixText: '%',
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
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              widget.onAdd(
                _tickerController.text.toUpperCase().trim(),
                double.parse(_allocationController.text),
              );
              Navigator.pop(context);
            }
          },
          child: const Text('Add'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _tickerController.dispose();
    _allocationController.dispose();
    super.dispose();
  }
}
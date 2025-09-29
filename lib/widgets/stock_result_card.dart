import 'package:flutter/material.dart';

class StockResultCard extends StatelessWidget {
  final Map<String, dynamic> stockData;

  const StockResultCard({super.key, required this.stockData});

  @override
  Widget build(BuildContext context) {
    final symbol = stockData['symbol'] ?? 'N/A';
    final companyName = stockData['company_name'] ?? 'Unknown Company';
    final currentPrice = (stockData['current_price'] ?? 0.0) as num;
    final change = (stockData['change'] ?? 0.0) as num;
    final changePercent = (stockData['change_percent'] ?? 0.0) as num;
    final volume = (stockData['volume'] ?? 0) as int;
    final marketCap = (stockData['market_cap'] ?? 0.0) as num;
    final sector = stockData['sector'] ?? 'N/A';
    
    final isPositive = change >= 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      elevation: 2,
      child: InkWell(
        onTap: () {
          // Navigate to detailed view or show more info
          _showStockDetails(context);
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  // Symbol and Company
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              symbol,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                sector,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.blue.shade800,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          companyName,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  
                  // Price and Change
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '\$${currentPrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isPositive 
                              ? Colors.green.shade100 
                              : Colors.red.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isPositive 
                                  ? Icons.arrow_upward 
                                  : Icons.arrow_downward,
                              size: 14,
                              color: isPositive 
                                  ? Colors.green.shade700 
                                  : Colors.red.shade700,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${changePercent.toStringAsFixed(2)}%',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isPositive 
                                    ? Colors.green.shade700 
                                    : Colors.red.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Metrics Row
              Row(
                children: [
                  Expanded(
                    child: _buildMetricItem(
                      'Volume',
                      _formatVolume(volume),
                      Icons.bar_chart,
                      Colors.blue,
                    ),
                  ),
                  Expanded(
                    child: _buildMetricItem(
                      'Market Cap',
                      _formatMarketCap(marketCap.toDouble()),
                      Icons.account_balance,
                      Colors.green,
                    ),
                  ),
                  Expanded(
                    child: _buildMetricItem(
                      'P/E',
                      (stockData['pe_ratio'] ?? 0.0).toStringAsFixed(1),
                      Icons.trending_up,
                      Colors.orange,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Technical Indicators Row
              Row(
                children: [
                  if (stockData['rsi'] != null)
                    Expanded(
                      child: _buildIndicatorChip(
                        'RSI',
                        (stockData['rsi'] as num).toStringAsFixed(1),
                        _getRSIColor((stockData['rsi'] as num).toDouble()),
                      ),
                    ),
                  if (stockData['macd'] != null)
                    Expanded(
                      child: _buildIndicatorChip(
                        'MACD',
                        (stockData['macd'] as num) >= 0 ? 'Bullish' : 'Bearish',
                        (stockData['macd'] as num) >= 0 ? Colors.green : Colors.red,
                      ),
                    ),
                  if (stockData['vwap_signal'] != null)
                    Expanded(
                      child: _buildIndicatorChip(
                        'VWAP',
                        stockData['vwap_signal'],
                        _getVWAPColor(stockData['vwap_signal']),
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

  Widget _buildMetricItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildIndicatorChip(String label, String value, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showStockDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${stockData['symbol']} Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Company', stockData['company_name'] ?? 'N/A'),
              _buildDetailRow('Sector', stockData['sector'] ?? 'N/A'),
              _buildDetailRow('Current Price', '\$${((stockData['current_price'] ?? 0.0) as num).toStringAsFixed(2)}'),
              _buildDetailRow('Market Cap', _formatMarketCap((stockData['market_cap'] ?? 0.0) as num)),
              _buildDetailRow('Volume', _formatVolume((stockData['volume'] ?? 0) as int)),
              _buildDetailRow('P/E Ratio', (stockData['pe_ratio'] ?? 0.0).toStringAsFixed(2)),
              if (stockData['rsi'] != null)
                _buildDetailRow('RSI', (stockData['rsi'] as num).toStringAsFixed(2)),
              if (stockData['macd'] != null)
                _buildDetailRow('MACD', (stockData['macd'] as num).toStringAsFixed(4)),
              if (stockData['vwap'] != null)
                _buildDetailRow('VWAP', '\$${(stockData['vwap'] as num).toStringAsFixed(2)}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Navigate to detailed analysis screen
              // You can implement navigation to HomeScreen with this symbol
            },
            child: const Text('Analyze'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Text(value),
        ],
      ),
    );
  }

  Color _getRSIColor(double rsi) {
    if (rsi > 70) return Colors.red;
    if (rsi < 30) return Colors.green;
    return Colors.blue;
  }

  Color _getVWAPColor(String signal) {
    switch (signal.toLowerCase()) {
      case 'above':
        return Colors.green;
      case 'below':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  String _formatVolume(int volume) {
    if (volume >= 1000000000) {
      return '${(volume / 1000000000).toStringAsFixed(1)}B';
    } else if (volume >= 1000000) {
      return '${(volume / 1000000).toStringAsFixed(1)}M';
    } else if (volume >= 1000) {
      return '${(volume / 1000).toStringAsFixed(1)}K';
    }
    return volume.toString();
  }

  String _formatMarketCap(num marketCap) {
    if (marketCap >= 1000000000000) {
      return '\$${(marketCap / 1000000000000).toStringAsFixed(1)}T';
    } else if (marketCap >= 1000000000) {
      return '\$${(marketCap / 1000000000).toStringAsFixed(1)}B';
    } else if (marketCap >= 1000000) {
      return '\$${(marketCap / 1000000).toStringAsFixed(1)}M';
    }
    return '\$${marketCap.toStringAsFixed(0)}';
  }
}
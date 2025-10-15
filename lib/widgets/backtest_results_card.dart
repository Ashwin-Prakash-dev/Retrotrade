import 'package:flutter/material.dart';

class BacktestResultsCard extends StatelessWidget {
  final Map<String, dynamic> results;

  const BacktestResultsCard({super.key, required this.results});

  @override
  Widget build(BuildContext context) {
    final totalReturn = (results['total_return'] ?? 0.0) as num;
    final totalReturnPct = (results['total_return_pct'] ?? 0.0) as num;
    final isProfit = totalReturn > 0;
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
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
                      colors: isProfit 
                          ? [const Color(0xFF00FF88), const Color(0xFF00CC66)]
                          : [const Color(0xFFFF6B6B), const Color(0xFFCC5555)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isProfit ? Icons.trending_up : Icons.trending_down,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'BACKTEST RESULTS',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),

            // Performance Summary
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isProfit 
                      ? [
                          const Color(0xFF00FF88).withOpacity(0.1),
                          const Color(0xFF00FF88).withOpacity(0.05),
                        ]
                      : [
                          const Color(0xFFFF6B6B).withOpacity(0.1),
                          const Color(0xFFFF6B6B).withOpacity(0.05),
                        ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isProfit 
                      ? const Color(0xFF00FF88).withOpacity(0.3)
                      : const Color(0xFFFF6B6B).withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'TOTAL RETURN',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.6),
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${totalReturnPct >= 0 ? '+' : ''}${totalReturnPct.toStringAsFixed(2)}%',
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      color: isProfit ? const Color(0xFF00FF88) : const Color(0xFFFF6B6B),
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${totalReturn >= 0 ? '+' : ''}\$${totalReturn.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isProfit 
                          ? const Color(0xFF00FF88).withOpacity(0.8)
                          : const Color(0xFFFF6B6B).withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Portfolio Values
            Row(
              children: [
                Expanded(
                  child: _buildValueTile(
                    'INITIAL VALUE',
                    '\$${((results['initial_value'] ?? 0.0) as num).toStringAsFixed(2)}',
                    Icons.account_balance_wallet_outlined,
                    const Color(0xFF00D9FF),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildValueTile(
                    'FINAL VALUE',
                    '\$${((results['final_value'] ?? 0.0) as num).toStringAsFixed(2)}',
                    Icons.account_balance_outlined,
                    isProfit ? const Color(0xFF00FF88) : const Color(0xFFFF6B6B),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Trading Statistics
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00D9FF).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.analytics_outlined,
                    size: 14,
                    color: const Color(0xFF00D9FF),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'TRADING STATISTICS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Column(
                children: [
                  _buildResultRow(
                    'Total Trades',
                    '${(results['total_trades'] ?? 0) as int}',
                    Icons.swap_horiz,
                  ),
                  const SizedBox(height: 8),
                  _buildResultRow(
                    'Winning Trades',
                    '${(results['winning_trades'] ?? 0) as int}',
                    Icons.arrow_upward,
                    valueColor: const Color(0xFF00FF88),
                  ),
                  const SizedBox(height: 8),
                  _buildResultRow(
                    'Losing Trades',
                    '${(results['losing_trades'] ?? 0) as int}',
                    Icons.arrow_downward,
                    valueColor: const Color(0xFFFF6B6B),
                  ),
                  Divider(height: 24, color: Colors.white.withOpacity(0.1)),
                  _buildResultRow(
                    'Win Rate',
                    '${((results['win_rate'] ?? 0.0) as num).toStringAsFixed(1)}%',
                    Icons.percent,
                    valueColor: _getWinRateColor((results['win_rate'] ?? 0.0) as num),
                  ),
                  const SizedBox(height: 8),
                  _buildResultRow(
                    'Max Drawdown',
                    '${((results['max_drawdown'] ?? 0.0) as num).toStringAsFixed(1)}%',
                    Icons.trending_down,
                    valueColor: const Color(0xFFFF6B6B),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Performance Insights
            _buildPerformanceInsights(),
          ],
        ),
      ),
    );
  }

  Widget _buildValueTile(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.white.withOpacity(0.6),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildResultRow(String label, String value, IconData icon, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: Colors.white.withOpacity(0.5),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          ],
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: valueColor ?? Colors.white,
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  Widget _buildPerformanceInsights() {
    final insights = _generateInsights();
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF00D9FF).withOpacity(0.1),
            const Color(0xFF0099CC).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF00D9FF).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF00D9FF).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.lightbulb_outline,
                  color: Color(0xFF00D9FF),
                  size: 14,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'INSIGHTS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...insights.map((insight) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00D9FF),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    insight,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.8),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Color _getWinRateColor(num winRate) {
    final rate = winRate.toDouble();
    if (rate >= 60) return const Color(0xFF00FF88);
    if (rate >= 40) return const Color(0xFFFFB84D);
    return const Color(0xFFFF6B6B);
  }

  List<String> _generateInsights() {
    final insights = <String>[];
    
    final winRate = (results['win_rate'] ?? 0.0) as num;
    final totalReturn = (results['total_return_pct'] ?? 0.0) as num;
    final maxDrawdown = (results['max_drawdown'] ?? 0.0) as num;
    final totalTrades = (results['total_trades'] ?? 0) as int;

    if (winRate >= 70) {
      insights.add('Excellent win rate of ${winRate.toStringAsFixed(1)}% indicates strong strategy performance');
    } else if (winRate >= 50) {
      insights.add('Good win rate of ${winRate.toStringAsFixed(1)}% shows consistent strategy execution');
    } else if (winRate < 40) {
      insights.add('Low win rate of ${winRate.toStringAsFixed(1)}% suggests strategy needs optimization');
    }

    if (totalReturn > 20) {
      insights.add('Strong returns of ${totalReturn.toStringAsFixed(1)}% outperformed typical market returns');
    } else if (totalReturn > 0) {
      insights.add('Positive returns of ${totalReturn.toStringAsFixed(1)}% show profitable strategy');
    } else {
      insights.add('Negative returns of ${totalReturn.toStringAsFixed(1)}% indicate strategy underperformance');
    }

    if (maxDrawdown < 10) {
      insights.add('Low maximum drawdown of ${maxDrawdown.toStringAsFixed(1)}% shows good risk management');
    } else if (maxDrawdown > 25) {
      insights.add('High maximum drawdown of ${maxDrawdown.toStringAsFixed(1)}% indicates significant risk exposure');
    }

    if (totalTrades < 5) {
      insights.add('Low trading frequency may indicate limited market opportunities or conservative settings');
    } else if (totalTrades > 50) {
      insights.add('High trading frequency suggests active strategy - monitor transaction costs');
    }

    if (totalReturn > 0 && maxDrawdown > 0) {
      final riskRewardRatio = totalReturn.toDouble() / maxDrawdown.toDouble();
      if (riskRewardRatio > 2) {
        insights.add('Favorable risk-reward ratio indicates efficient capital utilization');
      } else if (riskRewardRatio < 0.5) {
        insights.add('Poor risk-reward ratio suggests high risk for modest returns');
      }
    }

    return insights.isEmpty 
        ? ['Strategy performance analysis completed. Consider adjusting parameters for optimization.']
        : insights;
  }
}
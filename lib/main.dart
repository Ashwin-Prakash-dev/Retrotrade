import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const BacktestApp());
}

class BacktestApp extends StatelessWidget {
  const BacktestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stock Analysis & Backtest',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
import 'package:flutter/material.dart';

void main() {
  runApp(const AllCommerceApp());
}

class AllCommerceApp extends StatelessWidget {
  const AllCommerceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AllCommerce',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0052FF)),
        useMaterial3: true,
      ),
      home: const Scaffold(
        backgroundColor: Color(0xFFF8F9FF),
        body: Center(child: Text('AllCommerce')),
      ),
    );
  }
}

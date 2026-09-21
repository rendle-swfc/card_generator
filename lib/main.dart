import 'package:flutter/material.dart';
import 'card_builder_ui.dart';

void main() {
  runApp(const CardGeneratorApp());
}

class CardGeneratorApp extends StatelessWidget {
  const CardGeneratorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SWFC Card Generator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const CardBuilderScreen(),
    );
  }
}

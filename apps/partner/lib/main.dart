import 'package:flutter/material.dart';

void main() {
  runApp(const CyclePartnerApp());
}

class CyclePartnerApp extends StatelessWidget {
  const CyclePartnerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Cycle Partner',
      theme: ThemeData(useMaterial3: true),
      home: const Scaffold(
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cycle Partner',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 12),
                Text(
                  'Only the health information explicitly shared with you will appear here.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

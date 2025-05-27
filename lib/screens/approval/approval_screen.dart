import 'package:flutter/material.dart';

class ApprovalScreen extends StatelessWidget {
  const ApprovalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('승인')),
      body: const Center(child: Text('승인 화면')),
    );
  }
} 
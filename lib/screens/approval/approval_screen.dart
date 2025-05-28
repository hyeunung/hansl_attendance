import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/leave_provider.dart';

class ApprovalScreen extends StatelessWidget {
  const ApprovalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('승인')),
      body: Consumer<LeaveProvider>(
        builder: (context, provider, _) {
          final leaves = provider.myLeaves;
          if (leaves.isEmpty) {
            return const Center(child: Text('신청 내역이 없습니다.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: leaves.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, idx) {
              final l = leaves[idx];
              final type = l['type'] == 'biztrip' ? '출장 신청' : '연차 신청';
              final start = l['start_date'] ?? '';
              final end = l['end_date'] ?? '';
              final status = l['status'] == 'approved'
                  ? '승인됨'
                  : l['status'] == 'pending'
                      ? '대기중'
                      : '반려';
              return Text('$type: $start ~ $end ($status)',
                  style: const TextStyle(fontSize: 17));
            },
          );
        },
      ),
    );
  }
} 
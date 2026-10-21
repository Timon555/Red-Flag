import 'package:flutter/material.dart';

import '../models.dart';
import '../services/profile_service.dart';
import '../verdict_style.dart';
import 'check_screen.dart';

/// Restaurants the user has checked before, newest first.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verlauf')),
      body: StreamBuilder<List<CheckResult>>(
        stream: ProfileService().history(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('${snapshot.error}'));
          }
          final checks = snapshot.data;
          if (checks == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (checks.isEmpty) {
            return const Center(
              child: Text('Du hast noch kein Restaurant geprüft.'),
            );
          }
          return ListView.separated(
            itemCount: checks.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final check = checks[index];
              final style = VerdictStyle.of(check.verdict);
              return ListTile(
                leading: Icon(style.icon, color: style.color),
                title: Text(check.name),
                subtitle: Text(style.title),
                trailing: check.checkedAt == null
                    ? null
                    : Text(_formatDate(check.checkedAt!)),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => CheckScreen(result: check)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

String _formatDate(DateTime date) => '${date.day}.${date.month}.${date.year}';

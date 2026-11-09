import 'package:flutter/material.dart';

import '../models/scenora_models.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({
    super.key,
    required this.items,
    required this.isLoggedIn,
    required this.onRefresh,
  });

  final List<ActivityItem> items;
  final bool isLoggedIn;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text(
        'Activity',
        style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
      ),
    ),
    body: RefreshIndicator(
      onRefresh: isLoggedIn ? onRefresh : () async {},
      child: items.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: MediaQuery.sizeOf(context).height * .25),
                Icon(
                  isLoggedIn
                      ? Icons.notifications_none_rounded
                      : Icons.lock_outline_rounded,
                  size: 52,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: 14),
                Text(
                  isLoggedIn
                      ? 'No activity yet'
                      : 'Log in to see your activity',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 30),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      radius: 24,
                      backgroundColor: item.color.withValues(alpha: .15),
                      child: Icon(item.icon, color: item.color, size: 22),
                    ),
                    title: Text(
                      item.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(item.subtitle),
                    ),
                    trailing: Text(
                      item.time,
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                );
              },
            ),
    ),
  );
}

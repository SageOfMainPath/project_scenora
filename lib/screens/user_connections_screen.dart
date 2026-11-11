import 'package:flutter/material.dart';

import '../widgets/scenora_widgets.dart';

class UserConnectionsScreen extends StatefulWidget {
  const UserConnectionsScreen({
    super.key,
    required this.title,
    required this.currentUserId,
    required this.loadUsers,
    required this.onToggleFollow,
  });

  final String title;
  final String currentUserId;
  final Future<List<Map<String, dynamic>>> Function() loadUsers;
  final Future<bool?> Function(String userId) onToggleFollow;

  @override
  State<UserConnectionsScreen> createState() => _UserConnectionsScreenState();
}

class _UserConnectionsScreenState extends State<UserConnectionsScreen> {
  late Future<List<Map<String, dynamic>>> _users;
  final Set<String> _busyUsers = {};

  @override
  void initState() {
    super.initState();
    _users = widget.loadUsers();
  }

  Future<void> _refresh() async {
    final next = widget.loadUsers();
    setState(() => _users = next);
    await next;
  }

  Future<void> _toggle(Map<String, dynamic> user) async {
    final userId = '${user['id'] ?? ''}';
    if (userId.isEmpty || _busyUsers.contains(userId)) return;
    setState(() => _busyUsers.add(userId));
    final following = await widget.onToggleFollow(userId);
    if (!mounted) return;
    setState(() {
      _busyUsers.remove(userId);
      if (following != null) user['isFollowing'] = following;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _users,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 120),
                const Icon(Icons.cloud_off_outlined, size: 48),
                const SizedBox(height: 16),
                Text(
                  '${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(onPressed: _refresh, child: const Text('Retry')),
              ],
            );
          }
          final users = snapshot.data ?? const [];
          if (users.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 120),
                const Icon(Icons.people_outline_rounded, size: 56),
                const SizedBox(height: 16),
                Text(
                  'No ${widget.title.toLowerCase()} yet.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            );
          }
          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: users.length,
            separatorBuilder: (_, _) => const Divider(height: 1, indent: 76),
            itemBuilder: (context, index) {
              final user = users[index];
              final userId = '${user['id'] ?? ''}';
              final name = '${user['displayName'] ?? user['username'] ?? 'User'}';
              final username = '${user['username'] ?? 'member'}';
              final isMe = userId == widget.currentUserId;
              final isFollowing = user['isFollowing'] == true;
              final isBusy = _busyUsers.contains(userId);
              return ListTile(
                key: ValueKey('connection-$userId'),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                leading: UserAvatar(
                  name: name,
                  color: const Color(0xFF5F6BEA),
                  radius: 23,
                ),
                title: Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text('@$username'),
                trailing: isMe
                    ? const Text('You')
                    : OutlinedButton(
                        onPressed: isBusy ? null : () => _toggle(user),
                        child: isBusy
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(isFollowing ? 'Following' : 'Follow'),
                      ),
              );
            },
          );
        },
      ),
    ),
  );
}

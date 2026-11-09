import 'package:flutter/material.dart';

import '../models/scenora_models.dart';
import '../widgets/scenora_widgets.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.watchlist,
    required this.themeMode,
    required this.onThemeChanged,
    required this.onMovieTap,
    required this.isLoggedIn,
    required this.onLogin,
    required this.onLogout,
    required this.user,
    required this.reviews,
    required this.serverUrl,
    required this.onServerUrlChanged,
    required this.onUpdateProfile,
  });

  final Set<Movie> watchlist;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;
  final ValueChanged<Movie> onMovieTap;
  final bool isLoggedIn;
  final Future<bool> Function() onLogin;
  final VoidCallback onLogout;
  final Map<String, dynamic>? user;
  final List<Review> reviews;
  final String serverUrl;
  final Future<String?> Function(String value) onServerUrlChanged;
  final Future<String?> Function(
    String displayName,
    String bio,
    String location,
  )
  onUpdateProfile;

  @override
  Widget build(BuildContext context) {
    final username = '${user?['username'] ?? 'guest'}';
    final displayName = '${user?['displayName'] ?? 'Guest'}';
    final userId = '${user?['id'] ?? ''}';
    final ownReviews = reviews
        .where((review) => review.userId == userId)
        .toList();
    final bio = '${user?['bio'] ?? ''}'.trim();
    final location = '${user?['location'] ?? ''}'.trim();

    return Scaffold(
      appBar: AppBar(
        title: const BrandMark(compact: true),
        actions: [
          IconButton(
            onPressed: () => _showSettings(context),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 30),
        children: [
          if (!isLoggedIn) _guestBanner(context),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Column(
              children: [
                UserAvatar(
                  name: displayName,
                  color: const Color(0xFF5F6BEA),
                  radius: 46,
                ),
                const SizedBox(height: 13),
                Text(
                  displayName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '@$username',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                if (bio.isNotEmpty || location.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    [
                      bio,
                      location,
                    ].where((value) => value.isNotEmpty).join('\n'),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _Stat(
                      value: '${user?['reviewCount'] ?? ownReviews.length}',
                      label: 'Reviews',
                    ),
                    _Stat(
                      value: '${user?['followerCount'] ?? 0}',
                      label: 'Followers',
                    ),
                    _Stat(
                      value: '${user?['followingCount'] ?? 0}',
                      label: 'Following',
                    ),
                  ],
                ),
                if (isLoggedIn) ...[
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _showProfileEditor(context),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit profile'),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SectionTitle(title: 'My watchlist'),
          if (watchlist.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Text('Your watchlist is empty.'),
            )
          else
            SizedBox(
              height: 195,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: watchlist.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (_, index) {
                  final movie = watchlist.elementAt(index);
                  return InkWell(
                    onTap: () => onMovieTap(movie),
                    child: SizedBox(
                      width: 108,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          PosterArt(
                            movie: movie,
                            width: 108,
                            height: 156,
                            radius: 13,
                          ),
                          const SizedBox(height: 7),
                          Text(
                            movie.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          const SectionTitle(title: 'My reviews'),
          if (!isLoggedIn || ownReviews.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Text(
                isLoggedIn
                    ? 'You have not written any reviews yet.'
                    : 'Log in to see your reviews.',
              ),
            )
          else
            ...ownReviews.map(
              (review) => ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                onTap: () => onMovieTap(review.movie),
                leading: PosterArt(
                  movie: review.movie,
                  width: 44,
                  height: 62,
                  radius: 8,
                ),
                title: Text(
                  review.movie.title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  review.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: StarRating(rating: review.rating, size: 13),
              ),
            ),
        ],
      ),
    );
  }

  Widget _guestBanner(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(20, 8, 20, 18),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(
        context,
      ).colorScheme.primaryContainer.withValues(alpha: .35),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      children: [
        const Expanded(child: Text('Log in or create an account to continue.')),
        FilledButton(onPressed: onLogin, child: const Text('Log in')),
      ],
    ),
  );

  void _showSettings(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: themeMode == ThemeMode.dark,
              onChanged: (value) {
                onThemeChanged(value ? ThemeMode.dark : ThemeMode.light);
                Navigator.pop(context);
              },
              secondary: const Icon(Icons.dark_mode_outlined),
              title: const Text('Dark mode'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.dns_outlined),
              title: const Text('Backend server'),
              subtitle: Text(
                serverUrl,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () {
                Navigator.pop(context);
                _showServerSettings(context);
              },
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                isLoggedIn ? Icons.logout_rounded : Icons.login_rounded,
              ),
              title: Text(isLoggedIn ? 'Log out' : 'Log in'),
              onTap: () {
                Navigator.pop(context);
                if (isLoggedIn) {
                  onLogout();
                } else {
                  onLogin();
                }
              },
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _showServerSettings(BuildContext context) async {
    final controller = TextEditingController(text: serverUrl);
    var saving = false;
    String? error;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Backend server'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Run ipconfig on the PC and enter its Wi-Fi IPv4 address with port 8080.',
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: 'Server address',
                  hintText: 'http://192.168.1.10:8080',
                  errorText: error,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: saving
                  ? null
                  : () async {
                      setDialogState(() {
                        saving = true;
                        error = null;
                      });
                      final result = await onServerUrlChanged(controller.text);
                      if (!dialogContext.mounted) return;
                      if (result == null) {
                        Navigator.pop(dialogContext);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Server saved. Log in to the selected server.',
                            ),
                          ),
                        );
                      } else {
                        setDialogState(() {
                          saving = false;
                          error = result;
                        });
                      }
                    },
              icon: saving
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.wifi_find_rounded),
              label: Text(saving ? 'Testing…' : 'Test & save'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
  }

  Future<void> _showProfileEditor(BuildContext context) async {
    final nameController = TextEditingController(
      text: '${user?['displayName'] ?? ''}',
    );
    final bioController = TextEditingController(text: '${user?['bio'] ?? ''}');
    final locationController = TextEditingController(
      text: '${user?['location'] ?? ''}',
    );
    var saving = false;
    String? error;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit profile'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Display name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bioController,
                  maxLength: 300,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Bio'),
                ),
                TextField(
                  controller: locationController,
                  decoration: InputDecoration(
                    labelText: 'Location',
                    errorText: error,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (nameController.text.trim().isEmpty) {
                        setDialogState(
                          () => error = 'Display name is required.',
                        );
                        return;
                      }
                      setDialogState(() {
                        saving = true;
                        error = null;
                      });
                      final result = await onUpdateProfile(
                        nameController.text.trim(),
                        bioController.text.trim(),
                        locationController.text.trim(),
                      );
                      if (!dialogContext.mounted) return;
                      if (result == null) {
                        Navigator.pop(dialogContext);
                      } else {
                        setDialogState(() {
                          saving = false;
                          error = result;
                        });
                      }
                    },
              child: Text(saving ? 'Saving…' : 'Save'),
            ),
          ],
        ),
      ),
    );
    nameController.dispose();
    bioController.dispose();
    locationController.dispose();
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        value,
        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
      ),
      Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ],
  );
}

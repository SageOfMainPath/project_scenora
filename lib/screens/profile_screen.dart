import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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
    required this.canChangeServer,
    required this.onFollowersTap,
    required this.onFollowingTap,
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
    String? avatarUrl,
  )
  onUpdateProfile;
  final bool canChangeServer;
  final VoidCallback onFollowersTap;
  final VoidCallback onFollowingTap;

  @override
  Widget build(BuildContext context) {
    final username = '${user?['username'] ?? 'guest'}';
    final displayName = '${user?['displayName'] ?? 'Guest'}';
    // The backend endpoint is already scoped to the signed-in user. Avoid a
    // second client-side ID filter, which could hide valid persisted reviews.
    final ownReviews = isLoggedIn ? reviews : const <Review>[];
    final effectiveWatchlist = isLoggedIn ? watchlist : const <Movie>{};
    final bio = '${user?['bio'] ?? ''}'.trim();
    final location = '${user?['location'] ?? ''}'.trim();
    final joined = DateTime.tryParse('${user?['createdAt'] ?? ''}');
    final sortedReviews = [...ownReviews]
      ..sort((a, b) {
        final score = b.reviewRating.compareTo(a.reviewRating);
        return score != 0
            ? score
            : b.reviewRatingCount.compareTo(a.reviewRatingCount);
      });

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const ScenoraWordmark(width: 164, height: 46),
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
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    UserAvatar(
                      name: displayName,
                      color: const Color(0xFF5F6BEA),
                      radius: 48,
                      imageUrl: '${user?['avatarUrl'] ?? ''}',
                    ),
                    const Spacer(),
                    _Stat(
                      value: '${user?['reviewCount'] ?? ownReviews.length}',
                      label: 'Reviews\nposted',
                    ),
                    _Stat(
                      value: '${effectiveWatchlist.length}',
                      label: 'Saved\nmovies',
                    ),
                  ],
                ),
                const SizedBox(height: 15),
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
                const SizedBox(height: 18),
                Text(
                  bio.isEmpty ? 'Building my movie profile on SCENORA.' : bio,
                  style: const TextStyle(fontSize: 16, height: 1.35),
                ),
                if (location.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _ProfileInfoLine(
                    icon: Icons.location_on_outlined,
                    label: location,
                  ),
                ],
                const SizedBox(height: 13),
                Row(
                  children: [
                    Expanded(
                      child: _ProfileInfoLine(
                        icon: Icons.group_outlined,
                        label: '${user?['followerCount'] ?? 0} Followers',
                        onTap: isLoggedIn ? onFollowersTap : null,
                      ),
                    ),
                    TextButton(
                      onPressed: isLoggedIn ? onFollowingTap : null,
                      child: Text('${user?['followingCount'] ?? 0} Following'),
                    ),
                  ],
                ),
                if (joined != null) ...[
                  const SizedBox(height: 8),
                  _ProfileInfoLine(
                    icon: Icons.calendar_month_outlined,
                    label: 'Joined ${_monthName(joined.month)} ${joined.year}',
                  ),
                ],
                if (isLoggedIn) ...[
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFA43BFF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () => _showProfileEditor(context),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text(
                        'Edit profile',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 27, 20, 12),
            child: Text(
              'Interested In',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
          ),
          if (effectiveWatchlist.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Text('Your watchlist is empty.'),
            )
          else
            SizedBox(
              height: 112,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: effectiveWatchlist.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (_, index) {
                  final movie = effectiveWatchlist.elementAt(index);
                  return _InterestMovieCard(
                    movie: movie,
                    onTap: () => onMovieTap(movie),
                  );
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 32, 12, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'My reviews',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                  ),
                ),
                IconButton(
                  tooltip: 'Search my reviews',
                  onPressed: ownReviews.isEmpty
                      ? null
                      : () => _searchReviews(context, ownReviews),
                  icon: const Icon(Icons.search_rounded),
                ),
                const Tooltip(
                  message: 'Sorted by community rating',
                  child: Icon(Icons.sort_rounded),
                ),
              ],
            ),
          ),
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
            ...sortedReviews.map(
              (review) => _profileReviewCard(context, review),
            ),
        ],
      ),
    );
  }

  String _monthName(int month) => const [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ][month - 1];

  Widget _profileReviewCard(BuildContext context, Review review) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 20),
    padding: const EdgeInsets.symmetric(vertical: 14),
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
    ),
    child: InkWell(
      onTap: () => onMovieTap(review.movie),
      borderRadius: BorderRadius.circular(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PosterArt(movie: review.movie, width: 88, height: 124, radius: 10),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        review.movie.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFB800),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        '${review.rating}/5',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Movie  •  ${review.movie.year}  •  ${review.movie.genre}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Text(review.text, maxLines: 3, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                Text(
                  review.reviewRatingCount == 0
                      ? 'No community ratings yet'
                      : '${review.reviewRating.toStringAsFixed(1)}/5 • ${review.reviewRatingCount} community rating${review.reviewRatingCount == 1 ? '' : 's'}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                if (review.imageUrls.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ReviewPhotoGallery(imageUrls: review.imageUrls),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Future<void> _searchReviews(BuildContext context, List<Review> items) async {
    final controller = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final query = controller.text.trim().toLowerCase();
          final matches = items
              .where(
                (review) =>
                    query.isEmpty ||
                    review.movie.title.toLowerCase().contains(query) ||
                    review.text.toLowerCase().contains(query),
              )
              .toList();
          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              4,
              20,
              MediaQuery.viewInsetsOf(context).bottom + 24,
            ),
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * .65,
              child: Column(
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    onChanged: (_) => setSheetState(() {}),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search_rounded),
                      hintText: 'Search movie or review text',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: matches.isEmpty
                        ? const Center(child: Text('No matching reviews.'))
                        : ListView.builder(
                            itemCount: matches.length,
                            itemBuilder: (_, index) {
                              final review = matches[index];
                              return ListTile(
                                leading: PosterArt(
                                  movie: review.movie,
                                  width: 40,
                                  height: 56,
                                  radius: 7,
                                ),
                                title: Text(review.movie.title),
                                subtitle: Text(
                                  review.text,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onTap: () {
                                  Navigator.pop(sheetContext);
                                  onMovieTap(review.movie);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    controller.dispose();
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
              trailing: Icon(
                canChangeServer ? Icons.edit_outlined : Icons.cloud_done,
              ),
              onTap: canChangeServer
                  ? () {
                      Navigator.pop(context);
                      _showServerSettings(context);
                    }
                  : null,
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
    var avatarUrl = '${user?['avatarUrl'] ?? ''}'.trim();
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
                UserAvatar(
                  name: nameController.text.trim().isEmpty
                      ? 'User'
                      : nameController.text.trim(),
                  color: const Color(0xFF5F6BEA),
                  radius: 38,
                  imageUrl: avatarUrl,
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: saving
                      ? null
                      : () async {
                          try {
                            final photo = await ImagePicker().pickImage(
                              source: ImageSource.gallery,
                              maxWidth: 512,
                              maxHeight: 512,
                              imageQuality: 75,
                            );
                            if (photo == null) return;
                            final bytes = await photo.readAsBytes();
                            if (bytes.length > 900 * 1024) {
                              setDialogState(
                                () => error =
                                    'Choose a smaller photo (maximum 900 KB).',
                              );
                              return;
                            }
                            final mime =
                                photo.mimeType?.startsWith('image/') == true
                                ? photo.mimeType!
                                : 'image/jpeg';
                            setDialogState(() {
                              avatarUrl =
                                  'data:$mime;base64,${base64Encode(bytes)}';
                              error = null;
                            });
                          } on Object {
                            setDialogState(
                              () => error = 'Could not open the photo gallery.',
                            );
                          }
                        },
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: Text(
                    avatarUrl.isEmpty ? 'Add profile photo' : 'Change photo',
                  ),
                ),
                if (avatarUrl.isNotEmpty)
                  TextButton(
                    onPressed: saving
                        ? null
                        : () => setDialogState(() => avatarUrl = ''),
                    child: const Text('Remove photo'),
                  ),
                const SizedBox(height: 8),
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
                        avatarUrl,
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

class _ProfileInfoLine extends StatelessWidget {
  const _ProfileInfoLine({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 9),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          if (onTap != null) const Icon(Icons.chevron_right_rounded, size: 18),
        ],
      ),
    ),
  );
}

class _InterestMovieCard extends StatelessWidget {
  const _InterestMovieCard({required this.movie, required this.onTap});

  final Movie movie;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 220,
    child: Material(
      color: Theme.of(context).colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              PosterArt(movie: movie, width: 54, height: 78, radius: 8),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      movie.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${movie.year}  •  ${movie.genre}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    key: ValueKey('profile-stat-${label.toLowerCase()}'),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    child: Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}

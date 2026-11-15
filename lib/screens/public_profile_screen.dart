import 'package:flutter/material.dart';

import '../core/scenora_theme.dart';
import '../models/scenora_models.dart';
import '../widgets/scenora_widgets.dart';

class PublicProfileScreen extends StatefulWidget {
  const PublicProfileScreen({
    super.key,
    required this.initialUser,
    required this.currentUserId,
    required this.loadUser,
    required this.loadReviews,
    required this.onToggleFollow,
  });

  final Map<String, dynamic> initialUser;
  final String currentUserId;
  final Future<Map<String, dynamic>> Function() loadUser;
  final Future<List<Review>> Function() loadReviews;
  final Future<bool?> Function() onToggleFollow;

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  late Map<String, dynamic> _user = Map.of(widget.initialUser);
  List<Review> _reviews = const [];
  bool _loading = true;
  bool _followBusy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    if (mounted) setState(() => _loading = true);
    try {
      final results = await Future.wait<Object>([
        widget.loadUser(),
        widget.loadReviews(),
      ]);
      if (!mounted) return;
      setState(() {
        _user = Map<String, dynamic>.from(results[0] as Map<String, dynamic>);
        _reviews = results[1] as List<Review>;
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleFollow() async {
    if (_followBusy) return;
    setState(() => _followBusy = true);
    final following = await widget.onToggleFollow();
    if (!mounted) return;
    setState(() {
      _followBusy = false;
      if (following != null) _user['isFollowing'] = following;
    });
  }

  @override
  Widget build(BuildContext context) {
    final userId = '${_user['id'] ?? ''}';
    final name = '${_user['displayName'] ?? _user['username'] ?? 'Member'}';
    final username = '${_user['username'] ?? 'member'}';
    final isMe = userId == widget.currentUserId;
    final following = _user['isFollowing'] == true;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const ScenoraWordmark(width: 150, height: 42),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
          children: [
            UserAvatar(
              name: name,
              color: const Color(0xFF5F6BEA),
              radius: 48,
              imageUrl: '${_user['avatarUrl'] ?? ''}',
            ),
            const SizedBox(height: 12),
            Text(
              name,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
            ),
            Text(
              '@$username',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if ('${_user['bio'] ?? ''}'.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('${_user['bio']}', textAlign: TextAlign.center),
            ],
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _Stat(value: _reviews.length, label: 'Reviews'),
                _Stat(
                  value: _asInt(_user['followerCount']),
                  label: 'Followers',
                ),
                _Stat(
                  value: _asInt(_user['followingCount']),
                  label: 'Following',
                ),
              ],
            ),
            if (!isMe) ...[
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: _followBusy ? null : _toggleFollow,
                icon: _followBusy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        following
                            ? Icons.person_remove_alt_1_rounded
                            : Icons.person_add_alt_1_rounded,
                      ),
                label: Text(following ? 'Following' : 'Follow'),
              ),
            ],
            const SizedBox(height: 26),
            const Text(
              'Reviews',
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Reviews could not be loaded. $_error'),
                ),
              )
            else if (_reviews.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 36),
                child: Text(
                  'This user has not written any reviews yet.',
                  textAlign: TextAlign.center,
                ),
              )
            else
              ..._reviews.map((review) => _ReviewCard(review: review)),
          ],
        ),
      ),
    );
  }

  int _asInt(Object? value) => value is num ? value.toInt() : 0;
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        '$value',
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
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

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final Review review;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PosterArt(movie: review.movie, width: 66, height: 94, radius: 10),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  review.movie.title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                StarRating(rating: review.rating, size: 17),
                const SizedBox(height: 8),
                Text(
                  review.text,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(height: 1.35),
                ),
                if (review.reviewRatingCount > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${review.reviewRating.toStringAsFixed(1)}/5 community rating',
                    style: const TextStyle(
                      color: ScenoraTheme.gold,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

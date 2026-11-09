import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/scenora_theme.dart';
import '../models/scenora_models.dart';
import '../widgets/scenora_widgets.dart';
import 'movie_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.reviews,
    required this.currentUserId,
    required this.onCreateReview,
    required this.watchlist,
    required this.onToggleWatchlist,
    required this.requireAuth,
    required this.onToggleLike,
    required this.onRateReview,
    required this.onToggleFollow,
    required this.onEditReview,
    required this.onDeleteReview,
    required this.loadMovieReviews,
    required this.addComment,
    required this.getComments,
    required this.onRefresh,
    required this.onOpenSearch,
    required this.onOpenMessages,
  });
  final List<Review> reviews;
  final String currentUserId;
  final ValueChanged<Movie?> onCreateReview;
  final Set<Movie> watchlist;
  final ValueChanged<Movie> onToggleWatchlist;
  final Future<bool> Function(String reason) requireAuth;
  final Future<({bool liked, int likeCount})?> Function(Review review)
  onToggleLike;
  final Future<({double score, int count, int viewerRating})?> Function(
    Review review,
    int rating,
  )
  onRateReview;
  final Future<bool?> Function(Review review) onToggleFollow;
  final Future<Review?> Function(
    Review review,
    int rating,
    String text,
    bool spoiler,
  )
  onEditReview;
  final Future<bool> Function(Review review) onDeleteReview;
  final Future<List<Review>> Function(String movieId) loadMovieReviews;
  final Future<String?> Function(Review review, String text) addComment;
  final Future<List<Map<String, dynamic>>> Function(Review review) getComments;
  final Future<void> Function() onRefresh;
  final VoidCallback onOpenSearch;
  final VoidCallback onOpenMessages;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _followingOnly = false;

  void _openMovie(Movie movie) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => MovieDetailScreen(
        movie: movie,
        isSaved: widget.watchlist.contains(movie),
        onToggleSaved: () => widget.onToggleWatchlist(movie),
        onWriteReview: () => widget.onCreateReview(movie),
        reviews: widget.reviews,
        requireAuth: widget.requireAuth,
        onRateReview: widget.onRateReview,
        loadReviews: widget.loadMovieReviews,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final displayedReviews = _followingOnly
        ? widget.reviews.where((review) => review.isFollowing).toList()
        : widget.reviews;
    return Scaffold(
      appBar: AppBar(
        title: const BrandMark(),
        actions: [
          IconButton(
            tooltip: 'Search',
            onPressed: widget.onOpenSearch,
            icon: const Icon(Icons.search_rounded),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton.filledTonal(
              tooltip: 'Messages',
              onPressed: widget.onOpenMessages,
              icon: const Icon(Icons.mail_outline_rounded),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: widget.onRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                child: Row(
                  children: [
                    _FeedPill(
                      label: 'For you',
                      selected: !_followingOnly,
                      onTap: () => setState(() => _followingOnly = false),
                    ),
                    const SizedBox(width: 8),
                    _FeedPill(
                      label: 'Following',
                      selected: _followingOnly,
                      onTap: () async {
                        final allowed = await widget.requireAuth(
                          'Log in to see reviews from people you follow.',
                        );
                        if (allowed && mounted) {
                          setState(() => _followingOnly = true);
                        }
                      },
                    ),
                    const Spacer(),
                    Icon(
                      Icons.tune_rounded,
                      size: 20,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
            if (displayedReviews.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      _followingOnly
                          ? 'No followed reviews yet. Follow a reviewer from the For you feed.'
                          : 'No reviews yet. Search for a movie and write the first review!',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              )
            else
              SliverList.separated(
                itemCount: displayedReviews.length,
                separatorBuilder: (_, _) => const SizedBox(height: 14),
                itemBuilder: (context, index) => Padding(
                  padding: EdgeInsets.fromLTRB(
                    12,
                    0,
                    12,
                    index == displayedReviews.length - 1 ? 100 : 0,
                  ),
                  child: ReviewCard(
                    review: displayedReviews[index],
                    currentUserId: widget.currentUserId,
                    onMovieTap: () => _openMovie(displayedReviews[index].movie),
                    requireAuth: widget.requireAuth,
                    onToggleLike: widget.onToggleLike,
                    onRateReview: widget.onRateReview,
                    onToggleFollow: widget.onToggleFollow,
                    onEditReview: widget.onEditReview,
                    onDeleteReview: widget.onDeleteReview,
                    addComment: widget.addComment,
                    getComments: widget.getComments,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FeedPill extends StatelessWidget {
  const _FeedPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ChoiceChip(
    label: Text(label),
    selected: selected,
    showCheckmark: false,
    onSelected: (_) => onTap(),
    selectedColor: ScenoraTheme.crimson,
    labelStyle: TextStyle(
      color: selected ? Colors.white : null,
      fontWeight: FontWeight.w700,
    ),
  );
}

class ReviewCard extends StatefulWidget {
  const ReviewCard({
    super.key,
    required this.review,
    required this.currentUserId,
    required this.onMovieTap,
    required this.requireAuth,
    required this.onToggleLike,
    required this.onRateReview,
    required this.onToggleFollow,
    required this.onEditReview,
    required this.onDeleteReview,
    required this.addComment,
    required this.getComments,
  });
  final Review review;
  final String currentUserId;
  final VoidCallback onMovieTap;
  final Future<bool> Function(String reason) requireAuth;
  final Future<({bool liked, int likeCount})?> Function(Review review)
  onToggleLike;
  final Future<({double score, int count, int viewerRating})?> Function(
    Review review,
    int rating,
  )
  onRateReview;
  final Future<bool?> Function(Review review) onToggleFollow;
  final Future<Review?> Function(
    Review review,
    int rating,
    String text,
    bool spoiler,
  )
  onEditReview;
  final Future<bool> Function(Review review) onDeleteReview;
  final Future<String?> Function(Review review, String text) addComment;
  final Future<List<Map<String, dynamic>>> Function(Review review) getComments;

  @override
  State<ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<ReviewCard> {
  bool get _isMine =>
      widget.currentUserId.isNotEmpty &&
      widget.currentUserId == widget.review.userId;

  Future<void> _toggleLike() async {
    final allowed = await widget.requireAuth(
      'Log in to like reviews and support other movie fans.',
    );
    if (!allowed || !mounted) return;
    final backendResult = await widget.onToggleLike(widget.review);
    if (!mounted) return;
    if (backendResult != null) {
      setState(() {
        widget.review.liked = backendResult.liked;
        widget.review.likes = backendResult.likeCount;
      });
      return;
    }
    setState(() {
      widget.review.liked = !widget.review.liked;
      widget.review.likes += widget.review.liked ? 1 : -1;
    });
  }

  Future<void> _rateReview(int rating) async {
    final allowed = await widget.requireAuth('Log in to rate this review.');
    if (!allowed || !mounted) return;
    final result = await widget.onRateReview(widget.review, rating);
    if (!mounted || result == null) return;
    setState(() {
      widget.review
        ..reviewRating = result.score
        ..reviewRatingCount = result.count
        ..viewerRating = result.viewerRating;
    });
  }

  Future<void> _toggleFollow() async {
    final allowed = await widget.requireAuth(
      'Log in to follow reviewers and build your Following feed.',
    );
    if (!allowed || !mounted) return;
    final following = await widget.onToggleFollow(widget.review);
    if (!mounted || following == null) return;
    setState(() => widget.review.isFollowing = following);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          following
              ? 'You are now following ${widget.review.handle}.'
              : 'You unfollowed ${widget.review.handle}.',
        ),
      ),
    );
  }

  Future<void> _copyReview() async {
    await Clipboard.setData(ClipboardData(text: widget.review.text));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Review text copied.')));
  }

  Future<void> _editReview() async {
    var rating = widget.review.rating;
    var spoiler = widget.review.spoiler;
    final controller = TextEditingController(text: widget.review.text);
    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit review'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Your movie rating'),
                Row(
                  children: List.generate(5, (index) {
                    final value = index + 1;
                    return IconButton(
                      onPressed: () => setDialogState(() => rating = value),
                      icon: Icon(
                        value <= rating
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: ScenoraTheme.gold,
                      ),
                    );
                  }),
                ),
                TextField(
                  controller: controller,
                  minLines: 3,
                  maxLines: 7,
                  maxLength: 2000,
                  decoration: const InputDecoration(labelText: 'Review'),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: spoiler,
                  onChanged: (value) =>
                      setDialogState(() => spoiler = value == true),
                  title: const Text('Contains spoilers'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    final text = controller.text.trim();
    controller.dispose();
    if (save != true || text.isEmpty || !mounted) return;
    final updated = await widget.onEditReview(
      widget.review,
      rating,
      text,
      spoiler,
    );
    if (!mounted || updated == null) return;
    setState(() {});
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Review updated.')));
  }

  Future<void> _deleteReview() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete review?'),
        content: const Text(
          'This will also remove its likes, comments, and ratings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final deleted = await widget.onDeleteReview(widget.review);
    if (!mounted || !deleted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Review deleted.')));
  }

  void _handleMenu(String action) {
    switch (action) {
      case 'follow':
        _toggleFollow();
      case 'copy':
        _copyReview();
      case 'edit':
        _editReview();
      case 'delete':
        _deleteReview();
    }
  }

  @override
  Widget build(BuildContext context) {
    final review = widget.review;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                UserAvatar(
                  name: review.user,
                  color: review.avatarColor,
                  radius: 21,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review.user,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        '${review.handle} · ${review.time}',
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!_isMine)
                  TextButton(
                    onPressed: _toggleFollow,
                    child: Text(review.isFollowing ? 'Following' : 'Follow'),
                  ),
                PopupMenuButton<String>(
                  tooltip: 'Review options',
                  onSelected: _handleMenu,
                  itemBuilder: (_) => [
                    if (!_isMine)
                      PopupMenuItem(
                        value: 'follow',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            review.isFollowing
                                ? Icons.person_remove_outlined
                                : Icons.person_add_alt_1_rounded,
                          ),
                          title: Text(
                            review.isFollowing ? 'Unfollow' : 'Follow user',
                          ),
                        ),
                      ),
                    if (_isMine)
                      const PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Edit review'),
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'copy',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.copy_rounded),
                        title: Text('Copy review'),
                      ),
                    ),
                    if (_isMine)
                      const PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.delete_outline_rounded),
                          title: Text('Delete review'),
                        ),
                      ),
                  ],
                  icon: const Icon(Icons.more_horiz_rounded),
                ),
              ],
            ),
            const SizedBox(height: 14),
            InkWell(
              onTap: widget.onMovieTap,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: .42),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    PosterArt(
                      movie: review.movie,
                      width: 54,
                      height: 76,
                      radius: 10,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            review.movie.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${review.movie.year} · ${review.movie.genre}',
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 7),
                          StarRating(rating: review.rating),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 13),
            if (review.spoiler)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: ScenoraTheme.crimson.withValues(alpha: .13),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Text(
                  'SPOILER',
                  style: TextStyle(
                    fontSize: 10,
                    color: ScenoraTheme.crimson,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            Text(
              review.text,
              style: const TextStyle(height: 1.5, fontSize: 15),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: .35),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Rate this review',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Row(
                          children: List.generate(5, (index) {
                            final value = index + 1;
                            return InkWell(
                              onTap: () => _rateReview(value),
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  top: 4,
                                  right: 4,
                                ),
                                child: Icon(
                                  value <= (review.viewerRating ?? 0)
                                      ? Icons.star_rounded
                                      : Icons.star_outline_rounded,
                                  size: 22,
                                  color: ScenoraTheme.gold,
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    review.reviewRatingCount == 0
                        ? 'Not rated'
                        : '${review.reviewRating.toStringAsFixed(1)}/5\n${review.reviewRatingCount} rating${review.reviewRatingCount == 1 ? '' : 's'}',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Divider(color: scheme.outlineVariant.withValues(alpha: .5)),
            Row(
              children: [
                EmptyActionButton(
                  icon: review.liked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  label: '${review.likes}',
                  onTap: _toggleLike,
                ),
                EmptyActionButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: '${review.comments}',
                  onTap: _showComments,
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Share',
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Share link copied')),
                  ),
                  icon: const Icon(Icons.ios_share_rounded, size: 20),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showComments() async {
    try {
      final comments = await widget.getComments(widget.review);
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => _CommentsSheet(
          review: widget.review,
          initialComments: comments,
          requireAuth: widget.requireAuth,
          getComments: widget.getComments,
          addComment: widget.addComment,
          onCountChanged: (count) {
            if (mounted) setState(() => widget.review.comments = count);
          },
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }
}

class _CommentsSheet extends StatefulWidget {
  const _CommentsSheet({
    required this.review,
    required this.initialComments,
    required this.requireAuth,
    required this.getComments,
    required this.addComment,
    required this.onCountChanged,
  });

  final Review review;
  final List<Map<String, dynamic>> initialComments;
  final Future<bool> Function(String reason) requireAuth;
  final Future<List<Map<String, dynamic>>> Function(Review review) getComments;
  final Future<String?> Function(Review review, String text) addComment;
  final ValueChanged<int> onCountChanged;

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  late List<Map<String, dynamic>> _comments;
  final _controller = TextEditingController();
  bool _posting = false;

  @override
  void initState() {
    super.initState();
    _comments = List.of(widget.initialComments);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final comments = await widget.getComments(widget.review);
    if (!mounted) return;
    setState(() => _comments = comments);
    widget.onCountChanged(comments.length);
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _posting) return;
    final allowed = await widget.requireAuth(
      'Log in to add a comment to this review.',
    );
    if (!allowed || !mounted) return;
    setState(() => _posting = true);
    final error = await widget.addComment(widget.review, text);
    if (!mounted) return;
    if (error != null) {
      setState(() => _posting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    _controller.clear();
    await _refresh();
    if (mounted) setState(() => _posting = false);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      14,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 24,
    ),
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .65,
      child: Column(
        children: [
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Comments',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                tooltip: 'Refresh comments',
                onPressed: _refresh,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          Expanded(
            child: _comments.isEmpty
                ? const Center(child: Text('No comments yet.'))
                : ListView.builder(
                    itemCount: _comments.length,
                    itemBuilder: (context, index) {
                      final comment = _comments[index];
                      final user =
                          comment['user'] as Map<String, dynamic>? ?? const {};
                      final name =
                          '${user['displayName'] ?? user['username'] ?? 'Member'}';
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: UserAvatar(
                          name: name,
                          color: const Color(0xFF5F6BEA),
                        ),
                        title: Text(
                          '$name  @${user['username'] ?? 'member'}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text('${comment['text'] ?? ''}'),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _controller,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              hintText: 'Add a thoughtful comment…',
              suffixIcon: IconButton(
                onPressed: _posting ? null : _submit,
                icon: _posting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

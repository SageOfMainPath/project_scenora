import 'dart:async';

import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/google_auth.dart';
import '../models/scenora_models.dart';
import 'explore_screen.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'review_composer.dart';
import 'shoutbox_screen.dart';
import 'user_connections_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    required this.themeMode,
    required this.onThemeChanged,
  });
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  bool _isLoggedIn = false;
  final ScenoraApiClient _api = ScenoraApiClient();
  final List<Review> _reviews = [];
  final List<Review> _profileReviews = [];
  final Set<Movie> _watchlist = {};
  final List<ActivityItem> _activities = [];
  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();
    _initializeApp();
    _syncTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _silentRefresh(),
    );
  }

  Future<void> _initializeApp() async {
    final restored = await _api.initialize();
    if (!mounted) return;
    setState(() => _isLoggedIn = restored);
    await _refreshAll();
  }

  Future<String?> _updateServerUrl(String value) async {
    try {
      await _api.updateBaseUrl(value);
      if (!mounted) return null;
      setState(() {
        _isLoggedIn = false;
        _reviews.clear();
        _profileReviews.clear();
        _activities.clear();
        _watchlist.clear();
      });
      await _loadReviews();
      return null;
    } on ApiException catch (error) {
      return error.message;
    }
  }

  Future<String?> _updateProfile(
    String displayName,
    String bio,
    String location,
  ) async {
    try {
      await _api.updateProfile(
        displayName: displayName,
        bio: bio,
        location: location,
      );
      if (mounted) setState(() {});
      return null;
    } on ApiException catch (error) {
      return error.message;
    }
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  Future<void> _silentRefresh() async {
    await _loadReviews(showErrors: false);
    if (_isLoggedIn) {
      try {
        await _loadActivity();
      } on ApiException {
        // The next background refresh will try again.
      }
    }
  }

  Future<void> _loadReviews({bool showErrors = true}) async {
    try {
      final remote = await _api.reviews();
      if (!mounted) return;
      setState(() {
        _reviews
          ..clear()
          ..addAll(remote);
      });
    } on ApiException catch (error) {
      if (mounted && showErrors) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _loadAccountData() async {
    if (!_isLoggedIn) return;
    try {
      final profile = await _api.profile();
      await Future.wait([
        _loadActivity(),
        _loadWatchlist(),
        _loadProfileReviews('${profile['id']}'),
      ]);
      if (mounted) setState(() {});
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _loadProfileReviews(String userId) async {
    final items = await _api.reviewsForUser(userId);
    if (!mounted) return;
    setState(() {
      _profileReviews
        ..clear()
        ..addAll(items);
    });
  }

  Future<void> _loadActivity() async {
    if (!_isLoggedIn) return;
    final items = await _api.activity();
    if (!mounted) return;
    setState(() {
      _activities
        ..clear()
        ..addAll(items);
    });
  }

  Future<void> _loadWatchlist() async {
    if (!_isLoggedIn) return;
    final items = await _api.watchlist();
    if (!mounted) return;
    setState(() {
      _watchlist
        ..clear()
        ..addAll(items);
    });
  }

  Future<void> _refreshAll() async {
    await _loadReviews();
    if (_isLoggedIn) await _loadAccountData();
  }

  void _openComposer([Movie? selected]) async {
    if (!await _ensureAuthenticated(
      'Log in to publish reviews and join the SCENORA community.',
    )) {
      return;
    }
    if (!mounted) return;
    final review = await showModalBottomSheet<Review>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (_) => ReviewComposer(initialMovie: selected),
    );
    if (review != null) {
      try {
        final saved = await _api.createReview(
          movie: review.movie,
          rating: review.rating,
          text: review.text,
          containsSpoiler: review.spoiler,
        );
        if (!mounted) return;
        setState(() {
          _reviews.insert(0, saved);
          _index = 0;
        });
        await _loadAccountData();
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Your review is live.')));
      } on ApiException catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error.message)));
        }
      }
    }
  }

  Future<String?> _login(String email, String password) async {
    try {
      await _api.login(email, password);
      return null;
    } on ApiException catch (error) {
      return error.message;
    }
  }

  Future<String?> _register(
    String username,
    String email,
    String password,
  ) async {
    try {
      await _api.register(username: username, email: email, password: password);
      return null;
    } on ApiException catch (error) {
      return error.message;
    }
  }

  Future<String?> _googleLogin() async {
    try {
      final token = await signInWithGoogle();
      await _api.loginWithGoogle(token);
      return null;
    } on GoogleAuthException catch (error) {
      return error.message;
    } on ApiException catch (error) {
      return error.message;
    } on Object catch (error) {
      return 'Google Sign-In failed: $error';
    }
  }

  Future<bool> _ensureAuthenticated(String reason) async {
    if (_isLoggedIn) return true;
    final loggedIn = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LoginScreen(
          reason: reason,
          onLogin: _login,
          onRegister: _register,
          onGoogleLogin: _googleLogin,
        ),
      ),
    );
    if (loggedIn == true && mounted) {
      setState(() => _isLoggedIn = true);
      await _refreshAll();
      if (!mounted) return true;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('You are now logged in.')));
      return true;
    }
    return false;
  }

  void _logout() async {
    await _api.logout();
    if (!mounted) return;
    setState(() => _isLoggedIn = false);
    _activities.clear();
    _profileReviews.clear();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('You have been logged out.')));
  }

  Future<({bool liked, int likeCount})?> _toggleLike(Review review) async {
    if (review.id == null) return null;
    try {
      return await _api.toggleLike(review.id!);
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
      return null;
    }
  }

  Future<({double score, int count, int viewerRating})?> _rateReview(
    Review review,
    int rating,
  ) async {
    if (review.id == null) return null;
    try {
      final result = await _api.rateReview(review.id!, rating);
      review
        ..reviewRating = result.score
        ..reviewRatingCount = result.count
        ..viewerRating = result.viewerRating;
      if (mounted) {
        setState(() {
          _reviews.sort((a, b) {
            final score = b.reviewRating.compareTo(a.reviewRating);
            if (score != 0) return score;
            return b.reviewRatingCount.compareTo(a.reviewRatingCount);
          });
        });
      }
      return result;
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
      return null;
    }
  }

  Future<bool?> _toggleFollow(Review review) async {
    if (review.userId == null || review.userId!.isEmpty) return null;
    try {
      final following = await _api.toggleFollow(review.userId!);
      if (mounted) {
        setState(() {
          for (final item in _reviews) {
            if (item.userId == review.userId) item.isFollowing = following;
          }
        });
      }
      return following;
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
      return null;
    }
  }

  Future<bool?> _toggleFollowUser(String userId) async {
    try {
      final following = await _api.toggleFollow(userId);
      if (mounted) {
        setState(() {
          for (final item in _reviews) {
            if (item.userId == userId) item.isFollowing = following;
          }
        });
      }
      return following;
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
      return null;
    }
  }

  Future<void> _openConnections({required bool followers}) async {
    final userId = '${_api.currentUser?['id'] ?? ''}';
    if (userId.isEmpty) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => UserConnectionsScreen(
          title: followers ? 'Followers' : 'Following',
          currentUserId: userId,
          loadUsers: () =>
              followers ? _api.followers(userId) : _api.following(userId),
          onToggleFollow: _toggleFollowUser,
        ),
      ),
    );
    if (mounted) await _loadAccountData();
  }

  Future<Review?> _editReview(
    Review review,
    int rating,
    String text,
    bool spoiler,
  ) async {
    if (review.id == null) return null;
    try {
      final updated = await _api.updateReview(
        reviewId: review.id!,
        rating: rating,
        text: text,
        containsSpoiler: spoiler,
      );
      review
        ..rating = updated.rating
        ..text = updated.text
        ..spoiler = updated.spoiler;
      if (mounted) setState(() {});
      return review;
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
      return null;
    }
  }

  Future<bool> _deleteReview(Review review) async {
    if (review.id == null) return false;
    try {
      await _api.deleteReview(review.id!);
      if (mounted) {
        setState(() => _reviews.removeWhere((item) => item.id == review.id));
      }
      await _loadAccountData();
      return true;
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
      return false;
    }
  }

  Future<String?> _addComment(Review review, String text) async {
    if (review.id == null) {
      return 'Demo reviews cannot be changed on the server.';
    }
    try {
      await _api.addComment(review.id!, text);
      review.comments++;
      return null;
    } on ApiException catch (error) {
      return error.message;
    }
  }

  Future<List<Map<String, dynamic>>> _getComments(Review review) async {
    if (review.id == null) return [];
    return _api.comments(review.id!);
  }

  void _toggleWatchlist(Movie movie) async {
    if (!await _ensureAuthenticated(
      'Log in to save movies to your watchlist.',
    )) {
      return;
    }
    if (movie.id == null) return;
    try {
      final saved = await _api.toggleWatchlist(movie.id!);
      if (!mounted) return;
      setState(() {
        _watchlist.removeWhere((item) => item.id == movie.id);
        if (saved) _watchlist.add(movie);
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _watchlist.any((item) => item.id == movie.id)
              ? 'Added to your watchlist'
              : 'Removed from your watchlist',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(
        reviews: _reviews,
        currentUserId: '${_api.currentUser?['id'] ?? ''}',
        onCreateReview: _openComposer,
        watchlist: _watchlist,
        onToggleWatchlist: _toggleWatchlist,
        requireAuth: _ensureAuthenticated,
        onToggleLike: _toggleLike,
        onRateReview: _rateReview,
        onToggleFollow: _toggleFollow,
        onEditReview: _editReview,
        onDeleteReview: _deleteReview,
        loadMovieReviews: _api.reviewsForMovie,
        searchReviews: _api.searchReviews,
        addComment: _addComment,
        getComments: _getComments,
        onRefresh: _refreshAll,
        onOpenMessages: () => setState(() => _index = 2),
      ),
      ExploreScreen(
        reviews: _reviews,
        watchlist: _watchlist,
        onToggleWatchlist: _toggleWatchlist,
        onWriteReview: _openComposer,
        onSearch: _api.searchMovies,
        onLoadPopular: _api.popularMovies,
        requireAuth: _ensureAuthenticated,
        onRateReview: _rateReview,
        loadMovieReviews: _api.reviewsForMovie,
      ),
      ShoutboxScreen(
        isLoggedIn: _isLoggedIn,
        requireAuth: _ensureAuthenticated,
        loadMessages: _api.messages,
        sendMessage: _api.sendMessage,
      ),
      NotificationsScreen(
        items: _activities,
        isLoggedIn: _isLoggedIn,
        onRefresh: _loadActivity,
      ),
      ProfileScreen(
        watchlist: _watchlist,
        themeMode: widget.themeMode,
        onThemeChanged: widget.onThemeChanged,
        onMovieTap: (movie) => _openComposer(movie),
        isLoggedIn: _isLoggedIn,
        onLogin: () => _ensureAuthenticated(
          'Log in to see your complete profile and community activity.',
        ),
        onLogout: _logout,
        user: _api.currentUser,
        reviews: _profileReviews,
        serverUrl: _api.baseUrl,
        onServerUrlChanged: _updateServerUrl,
        onUpdateProfile: _updateProfile,
        canChangeServer: !_api.isProductionServerLocked,
        onFollowersTap: () => _openConnections(followers: true),
        onFollowingTap: () => _openConnections(followers: false),
      ),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: screens),
      floatingActionButton: _index == 0
          ? FloatingActionButton.extended(
              onPressed: _openComposer,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Review'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) {
          setState(() => _index = value);
          if (value == 0) _loadReviews();
          if (value == 3 && _isLoggedIn) _loadActivity();
          if (value == 4 && _isLoggedIn) _loadAccountData();
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          const NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore_rounded),
            label: 'Explore',
          ),
          const NavigationDestination(
            icon: Icon(Icons.forum_outlined),
            selectedIcon: Icon(Icons.forum_rounded),
            label: 'Shoutbox',
          ),
          NavigationDestination(
            icon: _activities.isEmpty
                ? const Icon(Icons.notifications_outlined)
                : Badge(
                    label: Text('${_activities.length}'),
                    child: const Icon(Icons.notifications_outlined),
                  ),
            selectedIcon: const Icon(Icons.notifications_rounded),
            label: 'Activity',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';

import '../core/scenora_theme.dart';
import '../data/mock_data.dart';
import '../models/scenora_models.dart';
import '../widgets/scenora_widgets.dart';
import 'movie_detail_screen.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({
    super.key,
    required this.watchlist,
    required this.onToggleWatchlist,
    required this.onWriteReview,
    required this.onSearch,
    required this.onLoadPopular,
    required this.reviews,
    required this.requireAuth,
    required this.onRateReview,
    required this.loadMovieReviews,
  });
  final Set<Movie> watchlist;
  final ValueChanged<Movie> onToggleWatchlist;
  final ValueChanged<Movie?> onWriteReview;
  final Future<List<Movie>> Function(String query) onSearch;
  final Future<List<Movie>> Function() onLoadPopular;
  final List<Review> reviews;
  final Future<bool> Function(String reason) requireAuth;
  final Future<({double score, int count, int viewerRating})?> Function(
    Review review,
    int rating,
  )
  onRateReview;
  final Future<List<Review>> Function(String movieId) loadMovieReviews;

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  String _query = '';
  String _genre = 'All';
  List<Movie> _remoteResults = const [];
  List<Movie> _popularResults = const [];
  Timer? _searchTimer;
  bool _searching = false;
  String? _searchError;

  List<Movie> get _popularMovies =>
      _popularResults.isEmpty ? movies : _popularResults;

  List<Movie> get _results => (_query.isEmpty ? _popularMovies : _remoteResults)
      .where(
        (movie) =>
            (_query.isEmpty ||
                movie.title.toLowerCase().contains(_query.toLowerCase())) &&
            (_genre == 'All' || movie.genre.contains(_genre)),
      )
      .toList();

  @override
  void initState() {
    super.initState();
    _loadPopular();
  }

  Future<void> _loadPopular() async {
    if (mounted) setState(() => _searching = true);
    try {
      final result = await widget.onLoadPopular();
      if (!mounted) return;
      setState(() {
        _popularResults = result;
        _searchError = null;
      });
    } catch (error) {
      if (mounted) setState(() => _searchError = '$error');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() {
      _query = value.trim();
      _searchError = null;
      if (_query.isEmpty) _remoteResults = const [];
    });
    _searchTimer?.cancel();
    if (_query.isEmpty) return;
    _searchTimer = Timer(const Duration(milliseconds: 450), () async {
      final submittedQuery = _query;
      setState(() => _searching = true);
      try {
        final result = await widget.onSearch(submittedQuery);
        if (!mounted || submittedQuery != _query) return;
        setState(() => _remoteResults = result);
      } catch (error) {
        if (!mounted || submittedQuery != _query) return;
        setState(() => _searchError = '$error');
      } finally {
        if (mounted && submittedQuery == _query) {
          setState(() => _searching = false);
        }
      }
    });
  }

  void _open(Movie movie) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => MovieDetailScreen(
        movie: movie,
        isSaved: widget.watchlist.contains(movie),
        onToggleSaved: () => widget.onToggleWatchlist(movie),
        onWriteReview: () => widget.onWriteReview(movie),
        reviews: widget.reviews,
        requireAuth: widget.requireAuth,
        onRateReview: widget.onRateReview,
        loadReviews: widget.loadMovieReviews,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text(
        'Explore',
        style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
      ),
    ),
    body: CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: TextField(
              onChanged: _onSearchChanged,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Search movies, series, people…',
                suffixIcon: Icon(Icons.tune_rounded),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 54,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              scrollDirection: Axis.horizontal,
              itemBuilder: (_, index) {
                final genre = [
                  'All',
                  'Drama',
                  'Sci-Fi',
                  'Action',
                  'Comedy',
                  'Romance',
                ][index];
                return ChoiceChip(
                  label: Text(genre),
                  selected: _genre == genre,
                  showCheckmark: false,
                  selectedColor: ScenoraTheme.crimson,
                  labelStyle: TextStyle(
                    color: _genre == genre ? Colors.white : null,
                    fontWeight: FontWeight.w700,
                  ),
                  onSelected: (_) => setState(() => _genre = genre),
                );
              },
              separatorBuilder: (_, _) => const SizedBox(width: 7),
              itemCount: 6,
            ),
          ),
        ),
        if (_query.isNotEmpty || _genre != 'All') ...[
          if (_searching)
            const SliverToBoxAdapter(
              child: LinearProgressIndicator(minHeight: 2),
            ),
          if (_searchError != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Text(
                  _searchError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ),
          const SliverToBoxAdapter(
            child: SectionTitle(title: 'Search results'),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: .58,
                crossAxisSpacing: 12,
                mainAxisSpacing: 14,
              ),
              itemCount: _results.length,
              itemBuilder: (_, i) => _MovieTile(
                movie: _results[i],
                onTap: () => _open(_results[i]),
              ),
            ),
          ),
        ] else ...[
          const SliverToBoxAdapter(
            child: SectionTitle(
              title: 'Trending now',
              subtitle: 'What everyone is watching',
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 240,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: _popularMovies.length,
                separatorBuilder: (_, _) => const SizedBox(width: 14),
                itemBuilder: (_, i) => _MovieTile(
                  movie: _popularMovies[i],
                  onTap: () => _open(_popularMovies[i]),
                  width: 125,
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(
            child: SectionTitle(
              title: 'Made for movie night',
              subtitle: 'Highly rated by the community',
            ),
          ),
          SliverList.builder(
            itemCount: 4,
            itemBuilder: (_, i) {
              final movie = _popularMovies[(i + 2) % _popularMovies.length];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 5,
                ),
                onTap: () => _open(movie),
                leading: PosterArt(
                  movie: movie,
                  width: 54,
                  height: 74,
                  radius: 9,
                ),
                title: Text(
                  movie.title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  '${movie.year} · ${movie.genre}\n★ ${movie.score} TMDB',
                ),
                isThreeLine: true,
                trailing: IconButton(
                  onPressed: () => widget.onToggleWatchlist(movie),
                  icon: Icon(
                    widget.watchlist.contains(movie)
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    color: widget.watchlist.contains(movie)
                        ? ScenoraTheme.crimson
                        : null,
                  ),
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 30)),
        ],
      ],
    ),
  );
}

class _MovieTile extends StatelessWidget {
  const _MovieTile({required this.movie, required this.onTap, this.width});
  final Movie movie;
  final VoidCallback onTap;
  final double? width;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: PosterArt(
              movie: movie,
              width: width ?? double.infinity,
              height: double.infinity,
              radius: 14,
              hero: true,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            movie.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            '${movie.year}  ★ ${movie.score}',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ),
  );
}

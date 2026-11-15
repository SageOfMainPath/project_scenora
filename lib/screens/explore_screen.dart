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
    required this.onLoadGenre,
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
  final Future<List<Movie>> Function(String genre) onLoadGenre;
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
  final Map<String, List<Movie>> _genreResults = {};
  Timer? _searchTimer;
  bool _searching = false;
  String? _searchError;

  List<Movie> get _popularMovies =>
      _popularResults.isEmpty ? movies : _popularResults;

  List<Movie> get _results =>
      (_query.isEmpty
              ? (_genre == 'All'
                    ? _popularMovies
                    : (_genreResults[_genre] ?? _popularMovies))
              : _remoteResults)
          .where(
            (movie) =>
                (_query.isEmpty ||
                    movie.title.toLowerCase().contains(_query.toLowerCase())) &&
                (_genre == 'All' || movie.genre.contains(_genre)),
          )
          .toList();

  Future<void> _selectGenre(String genre) async {
    setState(() {
      _genre = genre;
      _searchError = null;
    });
    if (genre == 'All' ||
        _query.isNotEmpty ||
        _genreResults.containsKey(genre)) {
      return;
    }
    setState(() => _searching = true);
    try {
      final movies = await widget.onLoadGenre(genre);
      if (!mounted || _genre != genre) return;
      setState(() => _genreResults[genre] = movies);
    } catch (error) {
      if (mounted && _genre == genre) setState(() => _searchError = '$error');
    } finally {
      if (mounted && _genre == genre) setState(() => _searching = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadPopular();
    _loadDiscoverySections();
  }

  Future<void> _loadDiscoverySections() async {
    const genres = ['Drama', 'Sci-Fi', 'Action', 'Comedy', 'Romance'];
    final results = await Future.wait(
      genres.map((genre) async {
        try {
          return MapEntry(genre, await widget.onLoadGenre(genre));
        } on Object {
          return MapEntry(genre, const <Movie>[]);
        }
      }),
    );
    if (mounted) setState(() => _genreResults.addEntries(results));
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
      centerTitle: true,
      title: const ScenoraWordmark(width: 164, height: 46),
    ),
    body: CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Text(
              'Explore',
              style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
            ),
          ),
        ),
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
                  onSelected: (_) => _selectGenre(genre),
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
          SliverToBoxAdapter(
            child: _DiscoveryJumpBar(onSelected: _selectGenre),
          ),
          if (_popularMovies.isNotEmpty)
            SliverToBoxAdapter(
              child: _FeaturedMovie(
                movie: _popularMovies.first,
                saved: widget.watchlist.contains(_popularMovies.first),
                onOpen: () => _open(_popularMovies.first),
                onSave: () => widget.onToggleWatchlist(_popularMovies.first),
              ),
            ),
          SliverToBoxAdapter(
            child: _DiscoveryShelf(
              title: 'Latest',
              accent: 'Releases',
              subtitle: 'Trending in theaters this week',
              icon: Icons.new_releases_outlined,
              movies: ([
                ..._popularMovies,
              ]..sort((a, b) => b.year.compareTo(a.year))).take(15).toList(),
              onOpen: _open,
            ),
          ),
          SliverToBoxAdapter(
            child: _DiscoveryShelf(
              title: 'Trending',
              accent: 'Now',
              subtitle: 'What everyone is watching',
              icon: Icons.local_fire_department_rounded,
              movies: _popularMovies.take(15).toList(),
              onOpen: _open,
            ),
          ),
          SliverToBoxAdapter(
            child: _DailyMoviePoll(
              left: _popularMovies.isEmpty ? null : _popularMovies.first,
              right: _popularMovies.length < 2 ? null : _popularMovies[1],
            ),
          ),
          SliverToBoxAdapter(
            child: _DiscoveryShelf(
              title: 'Top Rated',
              accent: 'Masterpieces',
              subtitle: 'Critically acclaimed',
              icon: Icons.workspace_premium_outlined,
              movies: ([
                ..._popularMovies,
              ]..sort((a, b) => b.score.compareTo(a.score))).take(15).toList(),
              onOpen: _open,
            ),
          ),
          for (final section in const [
            (
              'Action',
              'Blockbusters',
              'Big, loud and fast',
              Icons.bolt_rounded,
            ),
            (
              'Sci-Fi',
              'Fantasy',
              'Worlds beyond ours',
              Icons.rocket_launch_outlined,
            ),
            (
              'Drama',
              'Stories',
              'Stories that stay with you',
              Icons.theater_comedy_outlined,
            ),
            (
              'Comedy',
              'Favourites',
              'Easy laughs for movie night',
              Icons.sentiment_very_satisfied_outlined,
            ),
          ])
            SliverToBoxAdapter(
              child: _DiscoveryShelf(
                title: section.$1,
                accent: section.$2,
                subtitle: section.$3,
                icon: section.$4,
                movies: (_genreResults[section.$1] ?? const <Movie>[])
                    .take(15)
                    .toList(),
                onOpen: _open,
              ),
            ),
          if (_query == '__legacy_discovery_layout__') ...[
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
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 30)),
        ],
      ],
    ),
  );
}

class _DiscoveryJumpBar extends StatelessWidget {
  const _DiscoveryJumpBar({required this.onSelected});
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      scrollDirection: Axis.horizontal,
      children: [
        for (final item in const [
          ('New releases', 'All'),
          ('Top rated', 'All'),
          ('Action', 'Action'),
          ('Sci-Fi', 'Sci-Fi'),
          ('Drama', 'Drama'),
          ('Comedy', 'Comedy'),
        ]) ...[
          ActionChip(
            label: Text(item.$1),
            onPressed: () => onSelected(item.$2),
            side: BorderSide.none,
          ),
          const SizedBox(width: 7),
        ],
      ],
    ),
  );
}

class _FeaturedMovie extends StatelessWidget {
  const _FeaturedMovie({
    required this.movie,
    required this.saved,
    required this.onOpen,
    required this.onSave,
  });
  final Movie movie;
  final bool saved;
  final VoidCallback onOpen;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) => Container(
    height: 260,
    margin: const EdgeInsets.fromLTRB(20, 8, 20, 8),
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(26),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
    ),
    child: Stack(
      fit: StackFit.expand,
      children: [
        if (movie.posterUrl != null)
          Image.network(
            movie.posterUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black12, Colors.black54, Colors.black],
            ),
          ),
        ),
        Positioned(
          left: 18,
          right: 18,
          bottom: 18,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'FEATURED THIS WEEK',
                style: TextStyle(
                  color: ScenoraTheme.gold,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                movie.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                '${movie.year}  •  ${movie.genre}  •  ★ ${movie.score.toStringAsFixed(1)}',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: onOpen,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('View movie'),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: onSave,
                    icon: Icon(
                      saved
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _DiscoveryShelf extends StatelessWidget {
  const _DiscoveryShelf({
    required this.title,
    required this.accent,
    required this.subtitle,
    required this.icon,
    required this.movies,
    required this.onOpen,
  });
  final String title;
  final String accent;
  final String subtitle;
  final IconData icon;
  final List<Movie> movies;
  final ValueChanged<Movie> onOpen;

  @override
  Widget build(BuildContext context) {
    if (movies.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(icon, color: ScenoraTheme.gold, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          style: DefaultTextStyle.of(context).style.copyWith(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                          children: [
                            TextSpan(text: '$title '),
                            TextSpan(
                              text: accent,
                              style: const TextStyle(color: ScenoraTheme.gold),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_rounded, size: 18),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 238,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: movies.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, index) => _MovieTile(
                movie: movies[index],
                onTap: () => onOpen(movies[index]),
                width: 126,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyMoviePoll extends StatefulWidget {
  const _DailyMoviePoll({required this.left, required this.right});
  final Movie? left;
  final Movie? right;

  @override
  State<_DailyMoviePoll> createState() => _DailyMoviePollState();
}

class _DailyMoviePollState extends State<_DailyMoviePoll> {
  String? _vote;

  @override
  Widget build(BuildContext context) {
    if (widget.left == null || widget.right == null) {
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 24, 20, 4),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [
            ScenoraTheme.gold.withValues(alpha: .18),
            ScenoraTheme.crimson.withValues(alpha: .13),
          ],
        ),
        border: Border.all(color: ScenoraTheme.gold.withValues(alpha: .3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DAILY MOVIE POLL',
            style: TextStyle(
              color: ScenoraTheme.gold,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Which movie would you watch tonight?',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final movie in [widget.left!, widget.right!])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(
                        movie.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      selected: _vote == movie.id,
                      onSelected: (_) => setState(() => _vote = movie.id),
                    ),
                  ),
                ),
            ],
          ),
          if (_vote != null) ...[
            const SizedBox(height: 8),
            const Text(
              'Vote recorded on this device.',
              style: TextStyle(fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
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
              hero: false,
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

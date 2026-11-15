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
  Timer? _autoRefreshTimer;
  bool _searching = false;
  bool _refreshing = false;
  bool _showSearch = false;
  String? _searchError;
  final Map<String, List<Movie>> _franchiseResults = {};

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
    unawaited(_refreshAll());
    _autoRefreshTimer = Timer.periodic(
      const Duration(minutes: 15),
      (_) => unawaited(_refreshAll()),
    );
  }

  Future<void> _refreshAll() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      await Future.wait([
        _loadPopular(),
        _loadDiscoverySections(),
        _loadFranchises(),
      ]);
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _loadFranchises() async {
    const searches = {
      'Marvel / MCU': 'Avengers',
      'Harry Potter': 'Harry Potter',
      'DC Universe': 'Batman',
      'Star Wars': 'Star Wars',
      'Middle-earth': 'Lord of the Rings',
    };
    final results = await Future.wait(
      searches.entries.map((entry) async {
        try {
          return MapEntry(entry.key, await widget.onSearch(entry.value));
        } on Object {
          return MapEntry(entry.key, const <Movie>[]);
        }
      }),
    );
    if (mounted) setState(() => _franchiseResults.addEntries(results));
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
    _autoRefreshTimer?.cancel();
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
      actions: [
        IconButton(
          tooltip: _showSearch ? 'Close search' : 'Search movies',
          onPressed: () => setState(() {
            _showSearch = !_showSearch;
            if (!_showSearch) {
              _query = '';
              _remoteResults = const [];
            }
          }),
          icon: Icon(_showSearch ? Icons.close_rounded : Icons.search_rounded),
        ),
        const SizedBox(width: 8),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: _refreshAll,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (_showSearch)
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
          if (_showSearch)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 54,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
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
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
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
            const SliverToBoxAdapter(child: _TmdbLiveStatus()),
            SliverToBoxAdapter(
              child: _PremieresLaunches(movies: _popularMovies, onOpen: _open),
            ),
            SliverToBoxAdapter(
              child: _FranchiseShowcase(
                franchises: _franchiseResults,
                fallback: _popularMovies,
                onOpen: _open,
              ),
            ),
            SliverToBoxAdapter(
              child: _DiscoveryShelf(
                title: 'Trending',
                accent: 'Worldwide',
                subtitle: 'Global audience favourites and high-heat releases',
                icon: Icons.public_rounded,
                movies: _popularMovies.take(15).toList(),
                onOpen: _open,
              ),
            ),
            for (final streaming in [
              (
                'Worth Watching on',
                'Prime',
                Icons.live_tv_outlined,
                _popularMovies.skip(1).take(15).toList(),
              ),
              (
                'Don’t Miss These on',
                'Netflix',
                Icons.movie_filter_outlined,
                _popularMovies.skip(3).take(15).toList(),
              ),
              (
                'Don’t Miss These on',
                'JioHotstar',
                Icons.auto_awesome_rounded,
                (_genreResults['Drama'] ?? _popularMovies).take(15).toList(),
              ),
              (
                'Watch It With',
                'District',
                Icons.confirmation_number_outlined,
                (_genreResults['Action'] ?? _popularMovies).take(15).toList(),
              ),
            ])
              SliverToBoxAdapter(
                child: _DiscoveryShelf(
                  title: streaming.$1,
                  accent: streaming.$2,
                  subtitle: 'Fresh TMDB titles • updates automatically',
                  icon: streaming.$3,
                  movies: streaming.$4,
                  onOpen: _open,
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
              child: _MovieCharts(movies: _popularMovies, onOpen: _open),
            ),
            SliverToBoxAdapter(child: _GenreBrowser(onSelected: _selectGenre)),
            SliverToBoxAdapter(
              child: _DiscoveryShelf(
                title: 'Most Anticipated',
                accent: 'Movies',
                subtitle: 'The releases SCENORA members cannot wait for',
                icon: Icons.hourglass_top_rounded,
                movies: ([
                  ..._popularMovies,
                ]..sort((a, b) => b.year.compareTo(a.year))).take(15).toList(),
                onOpen: _open,
              ),
            ),
            SliverToBoxAdapter(
              child: _DiscoveryShelf(
                title: 'Top Rated',
                accent: 'Masterpieces',
                subtitle: 'Critically acclaimed',
                icon: Icons.workspace_premium_outlined,
                movies:
                    ([..._popularMovies]
                          ..sort((a, b) => b.score.compareTo(a.score)))
                        .take(15)
                        .toList(),
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
            SliverToBoxAdapter(
              child: _DiscoveryShelf(
                title: 'Popular',
                accent: 'TV Series',
                subtitle: 'Worth binging',
                icon: Icons.tv_rounded,
                movies: _popularMovies.reversed.take(15).toList(),
                onOpen: _open,
              ),
            ),
            SliverToBoxAdapter(
              child: _DiscoveryShelf(
                title: 'Airing',
                accent: 'Today',
                subtitle: 'New episodes live',
                icon: Icons.podcasts_rounded,
                movies: (_genreResults['Drama'] ?? _popularMovies).reversed
                    .take(15)
                    .toList(),
                onOpen: _open,
              ),
            ),
            SliverToBoxAdapter(
              child: _DiscoveryShelf(
                title: 'Top Rated',
                accent: 'TV Shows',
                subtitle: 'The best of television',
                icon: Icons.emoji_events_outlined,
                movies:
                    ([..._popularMovies]
                          ..sort((a, b) => b.score.compareTo(a.score)))
                        .reversed
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
    ),
  );
}

class _PremieresLaunches extends StatefulWidget {
  const _PremieresLaunches({required this.movies, required this.onOpen});
  final List<Movie> movies;
  final ValueChanged<Movie> onOpen;

  @override
  State<_PremieresLaunches> createState() => _PremieresLaunchesState();
}

class _PremieresLaunchesState extends State<_PremieresLaunches> {
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    final items = switch (_filter) {
      'Upcoming' => ([
        ...widget.movies,
      ]..sort((a, b) => b.year.compareTo(a.year))),
      'Trailers' => widget.movies.reversed.toList(),
      'Bollywood' => widget.movies.skip(2).toList(),
      'Hollywood' => widget.movies.skip(4).toList(),
      _ => widget.movies,
    };
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _DiscoveryHeading(
            icon: Icons.rocket_launch_outlined,
            title: 'Premieres & launches',
            subtitle: 'Released recently or arriving in the next two months',
          ),
          _DiscoveryTextTabs(
            labels: const [
              'All  40',
              'Upcoming  22',
              'Trailers  32',
              'Bollywood  18',
              'Hollywood  22',
            ],
            selectedIndex: const [
              'All',
              'Upcoming',
              'Trailers',
              'Bollywood',
              'Hollywood',
            ].indexOf(_filter),
            onSelected: (index) => setState(
              () => _filter = const [
                'All',
                'Upcoming',
                'Trailers',
                'Bollywood',
                'Hollywood',
              ][index],
            ),
          ),
          SizedBox(
            height: 238,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: items.take(15).length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, index) => Stack(
                children: [
                  _MovieTile(
                    movie: items[index],
                    width: 126,
                    onTap: () => widget.onOpen(items[index]),
                  ),
                  Positioned(
                    left: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        index.isEven ? '● New movie' : '● Teaser',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DirectorsVault extends StatefulWidget {
  const _DirectorsVault({required this.movies, required this.onOpen});
  final List<Movie> movies;
  final ValueChanged<Movie> onOpen;

  @override
  State<_DirectorsVault> createState() => _DirectorsVaultState();
}

class _DirectorsVaultState extends State<_DirectorsVault> {
  int _selected = 0;
  static const _directors = [
    'Denis Villeneuve',
    'David Fincher',
    'Steven Spielberg',
    'Christopher Nolan',
  ];

  @override
  Widget build(BuildContext context) {
    if (widget.movies.isEmpty) return const SizedBox.shrink();
    final offset = (_selected * 3) % widget.movies.length;
    final films = [
      ...widget.movies.skip(offset),
      ...widget.movies.take(offset),
    ].take(5).toList();
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _DiscoveryHeading(
            icon: Icons.movie_filter_outlined,
            title: 'Directors Vault',
            subtitle: 'Visionary auteurs, signature filmographies',
          ),
          SizedBox(
            height: 44,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
              scrollDirection: Axis.horizontal,
              itemCount: _directors.length,
              separatorBuilder: (_, _) => const SizedBox(width: 7),
              itemBuilder: (_, index) => ChoiceChip(
                label: Text(_directors[index]),
                selected: _selected == index,
                onSelected: (_) => setState(() => _selected = index),
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF180C11),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: ScenoraTheme.gold.withValues(alpha: .18),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: ScenoraTheme.gold,
                      child: Text(
                        _directors[_selected][0],
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _directors[_selected],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            '${films.length}+ essential films',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 405,
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: .56,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 12,
                        ),
                    itemCount: films.length,
                    itemBuilder: (_, index) => _MovieTile(
                      movie: films[index],
                      onTap: () => widget.onOpen(films[index]),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FranchiseShowcase extends StatefulWidget {
  const _FranchiseShowcase({
    required this.franchises,
    required this.fallback,
    required this.onOpen,
  });
  final Map<String, List<Movie>> franchises;
  final List<Movie> fallback;
  final ValueChanged<Movie> onOpen;

  @override
  State<_FranchiseShowcase> createState() => _FranchiseShowcaseState();
}

class _FranchiseShowcaseState extends State<_FranchiseShowcase> {
  String _selected = 'Marvel / MCU';

  @override
  Widget build(BuildContext context) {
    final items = widget.franchises[_selected] ?? widget.fallback;
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _DiscoveryHeading(
            icon: Icons.hub_outlined,
            title: 'Franchises & sagas',
            subtitle: 'Cinema’s biggest universes and timeless worlds',
          ),
          _DiscoveryTextTabs(
            labels: const [
              'Marvel / MCU',
              'Harry Potter',
              'DC Universe',
              'Star Wars',
              'Middle-earth',
            ],
            selectedIndex: const [
              'Marvel / MCU',
              'Harry Potter',
              'DC Universe',
              'Star Wars',
              'Middle-earth',
            ].indexOf(_selected),
            onSelected: (index) => setState(
              () => _selected = const [
                'Marvel / MCU',
                'Harry Potter',
                'DC Universe',
                'Star Wars',
                'Middle-earth',
              ][index],
            ),
          ),
          SizedBox(
            height: 238,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: items.take(15).length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, index) => _MovieTile(
                movie: items[index],
                width: 126,
                onTap: () => widget.onOpen(items[index]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PickASide extends StatefulWidget {
  const _PickASide({required this.movies});
  final List<Movie> movies;

  @override
  State<_PickASide> createState() => _PickASideState();
}

class _PickASideState extends State<_PickASide> {
  String? _vote;

  @override
  Widget build(BuildContext context) {
    if (widget.movies.length < 2) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 28, 16, 4),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF170D12), Color(0xFF0B0B0F)],
        ),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pick a side',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            'New matchup today • ${_vote == null ? 0 : 1}/${widget.movies.length} voted',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          const Text(
            'Which movie owns movie night?',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.movies.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: .72,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemBuilder: (_, index) {
              final movie = widget.movies[index];
              final selected = _vote == movie.id;
              return InkWell(
                onTap: () => setState(() => _vote = movie.id),
                borderRadius: BorderRadius.circular(15),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: selected ? ScenoraTheme.gold : Colors.white12,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: PosterArt(
                          movie: movie,
                          width: 160,
                          height: 190,
                          radius: 11,
                          hero: false,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        movie.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        selected ? 'Voted' : 'Vote',
                        style: TextStyle(
                          color: selected ? ScenoraTheme.gold : null,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// Kept only for backwards-compatible source history; no longer shown.
// ignore: unused_element
class _ReleaseSchedule extends StatelessWidget {
  const _ReleaseSchedule({required this.movies, required this.onOpen});
  final List<Movie> movies;
  final ValueChanged<Movie> onOpen;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 24),
    child: Column(
      children: [
        const _DiscoveryHeading(
          icon: Icons.calendar_month_outlined,
          title: 'Movie Release Schedule',
          subtitle: 'Theatrical premieres and streaming release calendar',
        ),
        SizedBox(
          height: 238,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: movies.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, index) => Stack(
              children: [
                _MovieTile(
                  movie: movies[index],
                  width: 126,
                  onTap: () => onOpen(movies[index]),
                ),
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'NOV ${16 + index}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _MovieCharts extends StatefulWidget {
  const _MovieCharts({required this.movies, required this.onOpen});
  final List<Movie> movies;
  final ValueChanged<Movie> onOpen;

  @override
  State<_MovieCharts> createState() => _MovieChartsState();
}

class _MovieChartsState extends State<_MovieCharts> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final ranked = [...widget.movies]
      ..sort(
        (a, b) =>
            _tab >= 2 ? b.score.compareTo(a.score) : b.year.compareTo(a.year),
      );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Charts',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 4,
              separatorBuilder: (_, _) => const SizedBox(width: 7),
              itemBuilder: (_, index) {
                final label = const [
                  'Top movies',
                  'Trending shows',
                  'Top rated TV',
                  'Hidden gems',
                ][index];
                return ChoiceChip(
                  label: Text(label),
                  selected: _tab == index,
                  onSelected: (_) => setState(() => _tab = index),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          for (var index = 0; index < ranked.take(5).length; index++)
            ListTile(
              contentPadding: EdgeInsets.zero,
              onTap: () => widget.onOpen(ranked[index]),
              leading: Text(
                '${index + 1}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: ScenoraTheme.gold,
                ),
              ),
              title: Text(
                ranked[index].title,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                '${ranked[index].year}  •  ★ ${ranked[index].score.toStringAsFixed(1)}',
              ),
              trailing: PosterArt(
                movie: ranked[index],
                width: 36,
                height: 50,
                radius: 7,
              ),
            ),
        ],
      ),
    );
  }
}

// Kept only for backwards-compatible source history; no longer shown.
// ignore: unused_element
class _CommunityInvite extends StatelessWidget {
  const _CommunityInvite();

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(16, 24, 16, 0),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(20),
    ),
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Join the conversation',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
        ),
        SizedBox(height: 4),
        Text('See what cinephiles are saying, and add your own take.'),
        SizedBox(height: 12),
        Row(
          children: [
            Icon(Icons.forum_outlined),
            SizedBox(width: 8),
            Text(
              'Use Shoutbox or publish a review',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ],
    ),
  );
}

class _GenreBrowser extends StatelessWidget {
  const _GenreBrowser({required this.onSelected});
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 26, 20, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Browse by genre',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            for (final genre in const [
              'Action',
              'Sci-Fi',
              'Comedy',
              'Drama',
              'Romance',
            ])
              ActionChip(
                label: Text(genre),
                onPressed: () => onSelected(genre),
              ),
          ],
        ),
      ],
    ),
  );
}

class _DiscoveryTextTabs extends StatelessWidget {
  const _DiscoveryTextTabs({
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      scrollDirection: Axis.horizontal,
      itemCount: labels.length,
      separatorBuilder: (_, _) => const SizedBox(width: 24),
      itemBuilder: (_, index) {
        final selected = selectedIndex == index;
        return InkWell(
          onTap: () => onSelected(index),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.only(top: 3),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: selected ? ScenoraTheme.gold : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: Text(
              labels[index],
              style: TextStyle(
                color: selected
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _DiscoveryHeading extends StatelessWidget {
  const _DiscoveryHeading({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: ScenoraTheme.gold, size: 21),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
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
          ('Franchises', 'All'),
          ('For You', 'All'),
          ('Top rated', 'All'),
          ('Genres', 'All'),
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

class _TmdbLiveStatus extends StatelessWidget {
  const _TmdbLiveStatus();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 5, 20, 0),
    child: Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: Color(0xFF35C990),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Live TMDB catalogue • auto-refreshes every 15 minutes',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );
}

// Kept as an alternate compact hero for future tablet layouts.
// ignore: unused_element
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
              width: width ?? 112,
              height: 180,
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

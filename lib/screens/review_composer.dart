import 'package:flutter/material.dart';

import '../core/scenora_theme.dart';
import '../data/mock_data.dart';
import '../models/scenora_models.dart';
import '../widgets/scenora_widgets.dart';

class ReviewComposer extends StatefulWidget {
  const ReviewComposer({super.key, this.initialMovie});
  final Movie? initialMovie;

  @override
  State<ReviewComposer> createState() => _ReviewComposerState();
}

class _ReviewComposerState extends State<ReviewComposer> {
  late Movie? _movie = widget.initialMovie;
  final _controller = TextEditingController();
  int _rating = 0;
  bool _spoiler = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canPost =
        _movie != null && _rating > 0 && _controller.text.trim().isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded),
        ),
        title: const Text(
          'Create review',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              onPressed: canPost ? _submit : null,
              child: const Text('Post'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'What did you watch?',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          if (_movie == null)
            TextField(
              readOnly: true,
              onTap: _pickMovie,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Search for a movie or series',
              ),
            )
          else
            InkWell(
              onTap: _pickMovie,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: .5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    PosterArt(movie: _movie!, width: 54, height: 72, radius: 9),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _movie!.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            '${_movie!.year} · ${_movie!.genre}',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.swap_horiz_rounded),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 28),
          Center(
            child: Column(
              children: [
                Text(
                  'Your rating',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    5,
                    (i) => IconButton(
                      iconSize: 38,
                      onPressed: () => setState(() => _rating = i + 1),
                      icon: Icon(
                        i < _rating
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: ScenoraTheme.gold,
                      ),
                    ),
                  ),
                ),
                if (_rating > 0)
                  Text(
                    [
                      '',
                      'Not for me',
                      'It was okay',
                      'Liked it',
                      'Really good',
                      'Loved it!',
                    ][_rating],
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 25),
          TextField(
            controller: _controller,
            maxLines: 8,
            maxLength: 2000,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText:
                  'Share what moved you, surprised you, or stayed with you…',
              alignLabelWithHint: true,
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _spoiler,
            onChanged: (value) => setState(() => _spoiler = value),
            title: const Text(
              'Contains spoilers',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: const Text(
              'Readers will see a warning before your review',
            ),
            secondary: const Icon(Icons.visibility_off_outlined),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Image picker will be enabled with backend setup.',
                ),
              ),
            ),
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 13),
              child: Text('Add photos (optional)'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickMovie() async {
    final chosen = await showModalBottomSheet<Movie>(
      context: context,
      builder: (context) => ListView(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
        children: [
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text(
              'Choose a title',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
          ),
          ...movies.map(
            (movie) => ListTile(
              onTap: () => Navigator.pop(context, movie),
              leading: PosterArt(
                movie: movie,
                width: 42,
                height: 56,
                radius: 7,
              ),
              title: Text(
                movie.title,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text('${movie.year} · ${movie.genre}'),
            ),
          ),
        ],
      ),
    );
    if (chosen != null) setState(() => _movie = chosen);
  }

  void _submit() => Navigator.pop(
    context,
    Review(
      user: '',
      handle: '',
      avatarColor: const Color(0xFF5F6BEA),
      movie: _movie!,
      rating: _rating,
      text: _controller.text.trim(),
      time: 'now',
      likes: 0,
      comments: 0,
      spoiler: _spoiler,
    ),
  );
}

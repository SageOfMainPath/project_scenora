import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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
  final List<String> _imageUrls = [];
  bool _pickingImages = false;

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
        centerTitle: true,
        title: const ScenoraWordmark(width: 150, height: 42),
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
          const Text(
            'Create review',
            style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 18),
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
          if (_imageUrls.isNotEmpty) ...[
            SizedBox(
              height: 112,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _imageUrls.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (_, index) => Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.memory(
                        base64Decode(_imageUrls[index].split(',').last),
                        width: 112,
                        height: 112,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      right: 4,
                      top: 4,
                      child: IconButton.filled(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Remove photo',
                        onPressed: () => setState(() => _imageUrls.removeAt(index)),
                        icon: const Icon(Icons.close_rounded, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          OutlinedButton.icon(
            onPressed: _pickingImages || _imageUrls.length >= 3
                ? null
                : _pickImages,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: Padding(
              padding: const EdgeInsets.symmetric(vertical: 13),
              child: Text(
                _pickingImages
                    ? 'Opening gallery…'
                    : _imageUrls.isEmpty
                    ? 'Add photos (optional)'
                    : 'Add more (${_imageUrls.length}/3)',
              ),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'Up to 3 photos. Images are compressed and saved with your review.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Future<void> _pickImages() async {
    setState(() => _pickingImages = true);
    try {
      final picked = await ImagePicker().pickMultiImage(
        imageQuality: 68,
        maxWidth: 1440,
        maxHeight: 1440,
      );
      if (!mounted || picked.isEmpty) return;
      final remaining = 3 - _imageUrls.length;
      var skipped = 0;
      final additions = <String>[];
      for (final photo in picked.take(remaining)) {
        final bytes = await photo.readAsBytes();
        if (bytes.length > 1400 * 1024) {
          skipped++;
          continue;
        }
        final mime = photo.mimeType?.startsWith('image/') == true
            ? photo.mimeType!
            : 'image/jpeg';
        additions.add('data:$mime;base64,${base64Encode(bytes)}');
      }
      if (!mounted) return;
      setState(() => _imageUrls.addAll(additions));
      if (picked.length > remaining || skipped > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              skipped > 0
                  ? '$skipped large photo was skipped. Maximum size is 1.4 MB.'
                  : 'You can attach up to 3 photos.',
            ),
          ),
        );
      }
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the photo gallery.')),
        );
      }
    } finally {
      if (mounted) setState(() => _pickingImages = false);
    }
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
      imageUrls: List.unmodifiable(_imageUrls),
    ),
  );
}

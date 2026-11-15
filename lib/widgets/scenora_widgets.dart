import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/scenora_theme.dart';
import '../models/scenora_models.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: compact ? 26 : 32,
        height: compact ? 26 : 32,
        decoration: BoxDecoration(
          color: ScenoraTheme.crimson,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(
          Icons.play_arrow_rounded,
          size: compact ? 19 : 23,
          color: Colors.white,
        ),
      ),
      const SizedBox(width: 9),
      Text(
        'SCENORA',
        style: TextStyle(
          fontSize: compact ? 18 : 21,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
        ),
      ),
    ],
  );
}

class ScenoraLogo extends StatelessWidget {
  const ScenoraLogo({super.key, this.size = 52});

  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'SCENORA logo',
    image: true,
    child: Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(size * .25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Image.asset(
        'assets/branding/scenora_logo_transparent.png',
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => const Icon(Icons.movie_creation_rounded),
      ),
    ),
  );
}

class ScenoraWordmark extends StatelessWidget {
  const ScenoraWordmark({super.key, this.width = 170, this.height = 48});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'SCENORA',
    image: true,
    child: SizedBox(
      width: width,
      height: height,
      child: Image.asset(
        'assets/branding/scenora_wordmark.png',
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, _, _) => const BrandMark(compact: true),
      ),
    ),
  );
}

class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.name,
    required this.color,
    this.radius = 20,
    this.imageUrl,
  });
  final String name;
  final Color color;
  final double radius;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final initials = name.split(' ').take(2).map((part) => part[0]).join();
    final fallback = ColoredBox(
      color: color,
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: radius * .62,
          ),
        ),
      ),
    );
    final value = imageUrl?.trim() ?? '';
    Widget image = fallback;
    if (value.startsWith('data:image/') && value.contains(',')) {
      try {
        image = Image.memory(
          base64Decode(value.substring(value.indexOf(',') + 1)),
          fit: BoxFit.cover,
          width: radius * 2,
          height: radius * 2,
          errorBuilder: (_, _, _) => fallback,
        );
      } on FormatException {
        image = fallback;
      }
    } else if (value.startsWith('https://') || value.startsWith('http://')) {
      image = Image.network(
        value,
        fit: BoxFit.cover,
        width: radius * 2,
        height: radius * 2,
        errorBuilder: (_, _, _) => fallback,
      );
    }
    return ClipOval(
      child: SizedBox.square(dimension: radius * 2, child: image),
    );
  }
}

class ReviewPhotoGallery extends StatelessWidget {
  const ReviewPhotoGallery({super.key, required this.imageUrls});

  final List<String> imageUrls;

  @override
  Widget build(BuildContext context) {
    if (imageUrls.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: imageUrls.length == 1 ? 230 : 170,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: imageUrls.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final value = imageUrls[index];
          final fallback = Container(
            width: 180,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Icon(Icons.broken_image_outlined),
          );
          Widget image = fallback;
          if (value.startsWith('data:image/') && value.contains(',')) {
            try {
              image = Image.memory(
                base64Decode(value.substring(value.indexOf(',') + 1)),
                width: imageUrls.length == 1 ? 320 : 180,
                height: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
              );
            } on FormatException {
              image = fallback;
            }
          } else if (value.startsWith('http://') || value.startsWith('https://')) {
            image = Image.network(
              value,
              width: imageUrls.length == 1 ? 320 : 180,
              height: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => fallback,
            );
          }
          return ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: image,
          );
        },
      ),
    );
  }
}

class PosterArt extends StatelessWidget {
  const PosterArt({
    super.key,
    required this.movie,
    this.width = 112,
    this.height = 164,
    this.radius = 16,
    this.hero = false,
  });
  final Movie movie;
  final double width;
  final double height;
  final double radius;
  final bool hero;

  @override
  Widget build(BuildContext context) {
    final fallback = Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          right: -28,
          top: -12,
          child: Container(
            width: width,
            height: width,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: .14),
                width: 14,
              ),
            ),
          ),
        ),
        Positioned(
          left: 10,
          right: 10,
          bottom: 16,
          child: Text(
            movie.initials,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: width * .23,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              shadows: const [Shadow(blurRadius: 10, color: Colors.black54)],
            ),
          ),
        ),
      ],
    );
    final art = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: movie.colors,
        ),
        boxShadow: [
          BoxShadow(
            color: movie.colors.first.withValues(alpha: .25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (movie.posterUrl == null)
              fallback
            else
              Image.network(
                movie.posterUrl!,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
                loadingBuilder: (context, child, progress) => progress == null
                    ? child
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          fallback,
                          const Center(
                            child: SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ],
                      ),
                errorBuilder: (_, _, _) => fallback,
              ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black12, Colors.transparent, Colors.black45],
                ),
              ),
            ),
            Positioned(
              left: 10,
              top: 10,
              child: Text(
                '${movie.year}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return hero ? Hero(tag: 'poster-${movie.title}', child: art) : art;
  }
}

class StarRating extends StatelessWidget {
  const StarRating({super.key, required this.rating, this.size = 16});
  final int rating;
  final double size;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: List.generate(
      5,
      (i) => Icon(
        i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
        size: size,
        color: ScenoraTheme.gold,
      ),
    ),
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.onSeeAll,
  });
  final String title;
  final String? subtitle;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 22, 12, 12),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (onSeeAll != null)
          TextButton(onPressed: onSeeAll, child: const Text('See all')),
      ],
    ),
  );
}

class EmptyActionButton extends StatelessWidget {
  const EmptyActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(12),
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    ),
  );
}

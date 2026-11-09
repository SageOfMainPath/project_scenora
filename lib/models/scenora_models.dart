import 'package:flutter/material.dart';

class Movie {
  const Movie({
    this.id,
    this.posterUrl,
    required this.title,
    required this.year,
    required this.genre,
    required this.score,
    required this.communityScore,
    required this.colors,
    required this.initials,
    required this.synopsis,
  });

  final String? id;
  final String? posterUrl;
  final String title;
  final int year;
  final String genre;
  final double score;
  final double communityScore;
  final List<Color> colors;
  final String initials;
  final String synopsis;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Movie && id != null && other.id != null && id == other.id);

  @override
  int get hashCode => id?.hashCode ?? identityHashCode(this);
}

class Review {
  Review({
    this.id,
    this.userId,
    required this.user,
    required this.handle,
    required this.avatarColor,
    required this.movie,
    required this.rating,
    required this.text,
    required this.time,
    required this.likes,
    required this.comments,
    this.liked = false,
    this.spoiler = false,
    this.reviewRating = 0,
    this.reviewRatingCount = 0,
    this.viewerRating,
    this.isFollowing = false,
  });

  final String? id;
  final String? userId;
  final String user;
  final String handle;
  final Color avatarColor;
  final Movie movie;
  int rating;
  String text;
  final String time;
  int likes;
  int comments;
  bool liked;
  bool spoiler;
  double reviewRating;
  int reviewRatingCount;
  int? viewerRating;
  bool isFollowing;
}

class ChatMessage {
  const ChatMessage({
    this.id,
    this.userId,
    required this.user,
    required this.text,
    required this.time,
    required this.color,
    this.isMine = false,
  });

  final String? id;
  final String? userId;
  final String user;
  final String text;
  final String time;
  final Color color;
  final bool isMine;
}

class ActivityItem {
  ActivityItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.time,
    this.read = false,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String time;
  bool read;
}

import 'package:flutter/material.dart';

import '../models/scenora_models.dart';

const movies = <Movie>[
  Movie(
    id: '693134',
    title: 'Dune: Part Two',
    year: 2024,
    genre: 'Sci-Fi · Adventure',
    score: 8.5,
    communityScore: 4.6,
    colors: [Color(0xFFE19355), Color(0xFF4A241A)],
    initials: 'D II',
    synopsis:
        'Paul Atreides unites with Chani and the Fremen while seeking revenge against the conspirators who destroyed his family.',
  ),
  Movie(
    id: '872585',
    title: 'Oppenheimer',
    year: 2023,
    genre: 'Biography · Drama',
    score: 8.6,
    communityScore: 4.7,
    colors: [Color(0xFFF25A2B), Color(0xFF171316)],
    initials: 'O',
    synopsis:
        'The story of J. Robert Oppenheimer and his role in the development of the atomic bomb during World War II.',
  ),
  Movie(
    id: '666277',
    title: 'Past Lives',
    year: 2023,
    genre: 'Drama · Romance',
    score: 7.8,
    communityScore: 4.4,
    colors: [Color(0xFF75BBD3), Color(0xFFE8B18E)],
    initials: 'PL',
    synopsis:
        'Two deeply connected childhood friends are reunited in New York for one fateful week as they confront destiny, love, and choice.',
  ),
  Movie(
    id: '414906',
    title: 'The Batman',
    year: 2022,
    genre: 'Crime · Mystery',
    score: 7.8,
    communityScore: 4.3,
    colors: [Color(0xFFE1242F), Color(0xFF16151A)],
    initials: 'TB',
    synopsis:
        'Batman ventures into Gotham City’s underworld when a sadistic killer leaves behind a trail of cryptic clues.',
  ),
  Movie(
    id: '569094',
    title: 'Spider-Verse',
    year: 2023,
    genre: 'Animation · Action',
    score: 8.6,
    communityScore: 4.8,
    colors: [Color(0xFF8C48E8), Color(0xFFEC3B61)],
    initials: 'SV',
    synopsis:
        'Miles Morales catapults across the Multiverse, where he encounters a team of Spider-People charged with protecting its existence.',
  ),
  Movie(
    id: '136315',
    title: 'The Bear',
    year: 2024,
    genre: 'Drama · Comedy',
    score: 8.6,
    communityScore: 4.5,
    colors: [Color(0xFF2E79BD), Color(0xFFEEE6D9)],
    initials: 'BEAR',
    synopsis:
        'A young chef returns home to Chicago to run his family sandwich shop and finds a chosen family among the kitchen crew.',
  ),
];

final seedReviews = <Review>[
  Review(
    user: 'Nadia Rahman',
    handle: '@nadiaseesfilms',
    avatarColor: const Color(0xFF5F6BEA),
    movie: movies[0],
    rating: 5,
    text:
        'A monumental sci-fi experience. The sound, scale, and stillness all work together—this is what the big screen was made for.',
    time: '18m',
    likes: 248,
    comments: 31,
  ),
  Review(
    user: 'Tanvir Hasan',
    handle: '@tanvirframes',
    avatarColor: const Color(0xFF2BAA82),
    movie: movies[2],
    rating: 4,
    text:
        'Quietly devastating. It understands how the smallest decisions can echo through an entire life.',
    time: '1h',
    likes: 142,
    comments: 18,
  ),
  Review(
    user: 'Mim Chowdhury',
    handle: '@mimwatching',
    avatarColor: const Color(0xFFD75D8B),
    movie: movies[4],
    rating: 5,
    text:
        'Every frame is overflowing with ideas. Bold, emotional, and somehow even more inventive than the first.',
    time: '3h',
    likes: 391,
    comments: 46,
  ),
];

const seedMessages = <ChatMessage>[
  ChatMessage(
    user: 'Rafi',
    text: 'Who else is watching the new Dune tonight? 👀',
    time: '9:41 PM',
    color: Color(0xFFE47450),
  ),
  ChatMessage(
    user: 'Mim',
    text: 'Already booked IMAX! No spoilers until tomorrow please.',
    time: '9:42 PM',
    color: Color(0xFFD75D8B),
  ),
  ChatMessage(
    user: 'Tanvir',
    text: 'The score alone is worth the ticket. Absolutely unreal.',
    time: '9:43 PM',
    color: Color(0xFF2BAA82),
  ),
  ChatMessage(
    user: 'You',
    text: 'I’m going this weekend. The hype is getting impossible to ignore.',
    time: '9:44 PM',
    color: Color(0xFF5F6BEA),
    isMine: true,
  ),
];

final seedActivities = <ActivityItem>[
  ActivityItem(
    icon: Icons.favorite_rounded,
    color: const Color(0xFFE5384F),
    title: 'Nadia liked your review',
    subtitle: '“The cinematography stayed with me…”',
    time: '4m',
  ),
  ActivityItem(
    icon: Icons.chat_bubble_rounded,
    color: const Color(0xFF4B8DF8),
    title: 'Rafi commented on your review',
    subtitle: 'Couldn’t agree more about that ending!',
    time: '22m',
  ),
  ActivityItem(
    icon: Icons.person_add_alt_1_rounded,
    color: const Color(0xFF25B487),
    title: 'Mim started following you',
    subtitle: '@mimwatching',
    time: '1h',
  ),
  ActivityItem(
    icon: Icons.alternate_email_rounded,
    color: const Color(0xFFFFA43A),
    title: 'Tanvir mentioned you',
    subtitle: 'What did you think of the final act?',
    time: '3h',
    read: true,
  ),
  ActivityItem(
    icon: Icons.movie_filter_rounded,
    color: const Color(0xFF9C6ADE),
    title: 'Your watchlist title is now streaming',
    subtitle: 'Past Lives is available tonight',
    time: '1d',
    read: true,
  ),
];

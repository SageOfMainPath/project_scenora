import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scenora/models/scenora_models.dart';
import 'package:scenora/screens/profile_screen.dart';

const movie = Movie(
  id: 'movie-1',
  title: 'Persisted Movie',
  year: 2026,
  genre: 'Drama',
  score: 8,
  communityScore: 4,
  colors: [Colors.red, Colors.black],
  initials: 'PM',
  synopsis: 'A persisted movie.',
);

ProfileScreen profile({
  required bool loggedIn,
  required Set<Movie> watchlist,
  List<Review> reviews = const [],
}) => ProfileScreen(
  watchlist: watchlist,
  themeMode: ThemeMode.dark,
  onThemeChanged: (_) {},
  onMovieTap: (_) {},
  isLoggedIn: loggedIn,
  onLogin: () async => true,
  onLogout: () {},
  user: loggedIn
      ? {
          'id': 'user-1',
          'username': 'tester',
          'displayName': 'Tester',
          'reviewCount': reviews.length,
        }
      : null,
  reviews: reviews,
  serverUrl: 'https://example.com',
  onServerUrlChanged: (_) async => null,
  onUpdateProfile: (_, _, _, _) async => null,
  canChangeServer: false,
  onFollowersTap: () {},
  onFollowingTap: () {},
);

void main() {
  testWidgets('server-scoped profile reviews are displayed', (tester) async {
    final review = Review(
      id: 'review-1',
      // This deliberately differs from the profile ID. The API endpoint is
      // already user-scoped, so a redundant UI filter must not hide it.
      userId: 'legacy-id-format',
      user: 'Tester',
      handle: '@tester',
      avatarColor: Colors.blue,
      movie: movie,
      rating: 5,
      text: 'Saved in Supabase',
      time: 'now',
      likes: 0,
      comments: 0,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: profile(loggedIn: true, watchlist: {}, reviews: [review]),
      ),
    );
    await tester.scrollUntilVisible(find.text('Persisted Movie'), 300);

    expect(find.text('Persisted Movie'), findsOneWidget);
    expect(find.textContaining('Saved in Supabase'), findsOneWidget);
  });

  testWidgets('guest never sees a previous account watchlist', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: profile(loggedIn: false, watchlist: {movie})),
    );

    expect(find.text('Your watchlist is empty.'), findsOneWidget);
    expect(find.text('Persisted Movie'), findsNothing);
  });
}

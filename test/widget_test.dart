import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scenora/main.dart';

void main() {
  testWidgets('shows the SCENORA home feed and navigation', (tester) async {
    await tester.pumpWidget(const ScenoraApp());
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('SCENORA'), findsWidgets);
    expect(find.text('For you'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Explore'), findsOneWidget);
    expect(find.text('Shoutbox'), findsOneWidget);
  });

  testWidgets('opens Explore from bottom navigation', (tester) async {
    await tester.pumpWidget(const ScenoraApp());
    await tester.tap(find.byIcon(Icons.explore_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Premieres & launches'), findsOneWidget);
    expect(find.text('Dune: Part Two'), findsWidgets);
    expect(
      find.text('Live TMDB catalogue • auto-refreshes every 15 minutes'),
      findsOneWidget,
    );
    expect(find.text('Directors Vault'), findsNothing);
    expect(find.text('Pick a side'), findsNothing);
    expect(find.text('Movie Release Schedule'), findsNothing);
    expect(find.text('Join the conversation'), findsNothing);
  });

  testWidgets('requires login before a guest can publish a review', (
    tester,
  ) async {
    await tester.pumpWidget(const ScenoraApp());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FloatingActionButton, 'Review'));
    await tester.pumpAndSettle();

    expect(find.text('Login'), findsWidgets);
    expect(
      find.text('Log in to publish reviews and join the SCENORA community.'),
      findsOneWidget,
    );
    expect(find.text('Continue browsing as guest'), findsOneWidget);
    expect(find.text('Continue with Google'), findsNothing);
    expect(find.text('Email address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
  });
}

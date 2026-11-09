import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scenora/main.dart';

void main() {
  testWidgets('shows the SCENORA home feed and navigation', (tester) async {
    await tester.pumpWidget(const ScenoraApp());
    await tester.pumpAndSettle();

    expect(find.text('SCENORA'), findsOneWidget);
    expect(find.text('For you'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Explore'), findsOneWidget);
    expect(find.text('Shoutbox'), findsOneWidget);
  });

  testWidgets('opens Explore from bottom navigation', (tester) async {
    await tester.pumpWidget(const ScenoraApp());
    await tester.tap(find.byIcon(Icons.explore_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Trending now'), findsOneWidget);
    expect(find.text('Dune: Part Two'), findsWidgets);
  });

  testWidgets('requires login before a guest can publish a review', (
    tester,
  ) async {
    await tester.pumpWidget(const ScenoraApp());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FloatingActionButton, 'Review'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(
      find.text('Log in to publish reviews and join the SCENORA community.'),
      findsOneWidget,
    );
    expect(find.text('Continue browsing as guest'), findsOneWidget);
  });
}

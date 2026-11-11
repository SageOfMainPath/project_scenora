import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scenora/screens/user_connections_screen.dart';

void main() {
  testWidgets('shows connected users and toggles follow state', (tester) async {
    var toggles = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: UserConnectionsScreen(
          title: 'Followers',
          currentUserId: 'me',
          loadUsers: () async => [
            {
              'id': 'friend',
              'displayName': 'Rony',
              'username': 'rony',
              'isFollowing': false,
            },
          ],
          onToggleFollow: (userId) async {
            toggles++;
            return true;
          },
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Rony'), findsOneWidget);
    expect(find.text('@rony'), findsOneWidget);
    expect(find.text('Follow'), findsOneWidget);

    await tester.tap(find.text('Follow'));
    await tester.pumpAndSettle();

    expect(toggles, 1);
    expect(find.text('Following'), findsOneWidget);
  });
}

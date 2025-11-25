import 'package:flutter_test/flutter_test.dart';

import 'package:app/main.dart';

void main() {
  testWidgets('Chat Studio app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ChatStudioApp());

    // Verify that the app title is displayed
    expect(find.text('Chat Studio'), findsOneWidget);

    // Verify that the new conversation button exists
    expect(find.text('New Conversation'), findsOneWidget);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:world_connect/src/app.dart';

void main() {
  testWidgets('shows the authentication screen', (tester) async {
    await tester.pumpWidget(const WorldConnectApp());
    expect(find.text('World Connect'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });
}

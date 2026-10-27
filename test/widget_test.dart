import 'package:boom_party/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets("l'application démarre sur l'accueil", (tester) async {
    await tester.pumpWidget(const BoomPartyApp());
    expect(find.text('Jouer'), findsOneWidget);
  });
}

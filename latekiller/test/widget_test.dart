import 'package:flutter_test/flutter_test.dart';
import 'package:latekiller/main.dart';

void main() {
  testWidgets('App boots', (tester) async {
    await tester.pumpWidget(const LateKillerApp());
  });
}

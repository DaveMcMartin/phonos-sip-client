import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phonos_sip_client/main.dart';

void main() {
  testWidgets('App launches successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const PhonosSipClient());
    expect(find.text('Phonos SIP Client'), findsOneWidget);
  });
}

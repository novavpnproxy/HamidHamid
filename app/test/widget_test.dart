import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_vpn_app/app.dart';

void main() {
  testWidgets('renders JEYRAN GROUP branding on the splash screen', (tester) async {
    await tester.pumpWidget(const NovaVpnApp());

    expect(find.text('JEYRAN GROUP'), findsOneWidget);
    expect(find.text('اینترنت آزاد را با ما تجربه کنید'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });
}

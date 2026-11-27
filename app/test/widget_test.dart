import 'package:flutter_test/flutter_test.dart';
import 'package:nova_vpn_app/app.dart';
import 'package:nova_vpn_app/widgets/nova_animations.dart';

void main() {
  testWidgets('renders NOVA particle splash branding', (tester) async {
    await tester.pumpWidget(const NovaVpnApp());

    expect(find.text('NOVA VPN'), findsOneWidget);
    expect(find.text('JEYRAN GROUP'), findsOneWidget);
    expect(find.text('اتصال هوشمند، سریع و امن'), findsOneWidget);
    expect(find.byType(NovaParticleLogo), findsOneWidget);
  });
}

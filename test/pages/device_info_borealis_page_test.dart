import 'package:borealis/src/device_info/device_info.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'page_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const page = DeviceInfoBorealisPage();

  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'Borealis Example',
      packageName: 'com.infinum.borealis',
      version: '1.2.3',
      buildNumber: '42',
      buildSignature: '',
      installerStore: null,
    );
  });

  group('page wiring', () {
    test('title and icon', () {
      expect(page.title, 'Device info');
      expect(page.icon, Icons.bug_report_outlined);
    });

    test('has no clear action or badge', () {
      expect(page.onClearTap, isNull);
      expect(page.badgeListenable, isNull);
    });
  });

  group('render', () {
    // `PackageInfo.fromPlatform()` never completes without a platform channel,
    // so pumpAndSettle would hang. Only the synchronous parts are asserted.
    testWidgets('shows the app flavor row', (tester) async {
      await tester.pumpWidget(host(page));

      expect(find.byType(DeviceInfoPage), findsOneWidget);
      expect(find.text('appFlavor'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('reports unsupported platform', (tester) async {
      // Flutter widget tests default to TargetPlatform.android, so a
      // non-mobile platform must be forced to hit the fallback branch.
      final previousPlatform = debugDefaultTargetPlatformOverride;
      // Backstop: if pumpWidget/expect throws, the inline restore below is
      // skipped, so this tearDown prevents the override leaking to later tests.
      addTearDown(() => debugDefaultTargetPlatformOverride = previousPlatform);
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;

      await tester.pumpWidget(host(page));

      expect(find.text('Unsupported platform'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());

      // Restore in-body too: Flutter asserts foundation debug vars are unset at
      // the end of a passing test body, before addTearDown callbacks run.
      debugDefaultTargetPlatformOverride = previousPlatform;
    });
  });
}

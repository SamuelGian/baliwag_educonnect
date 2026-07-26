import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:baliwag_educonnect/main.dart';

void main() {
  testWidgets('App launches and all four tabs render without errors', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const BaliwagEduConnectApp());
    await tester.pumpAndSettle();

    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.textContaining('Kumusta,'), findsOneWidget);
    expect(tester.takeException(), isNull);

    for (final label in ['Apply', 'Tracker', 'Admin', 'Dashboard']) {
      await tester.tap(find.byKey(ValueKey('nav-$label')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Error on $label tab');
    }
  });

  testWidgets('Wide layout renders the navigation rail without errors', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const BaliwagEduConnectApp());
    await tester.pumpAndSettle();

    expect(find.text('Baliwag\nEduConnect'), findsOneWidget);
    expect(tester.takeException(), isNull);

    for (final label in ['Apply', 'Tracker', 'Admin', 'Dashboard']) {
      await tester.tap(find.byKey(ValueKey('nav-$label')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Error on $label tab (wide)');
    }
  });
}

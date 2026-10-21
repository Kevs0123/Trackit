import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:trackit_app/screens/landing_screen.dart';
import 'package:trackit_app/state/auth_state.dart';
import 'package:trackit_app/widgets/parcel_form.dart';
import 'package:trackit_app/widgets/stat_card.dart';
import 'package:trackit_app/widgets/stat_grid.dart';

void main() {
  for (final size in [
    const Size(320, 800),
    const Size(375, 812),
    const Size(768, 1024),
    const Size(1440, 900),
  ]) {
    testWidgets('layouts fit a ${size.width.toInt()}px viewport',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: StatGrid(
                  children: [
                    for (var i = 0; i < 6; i++)
                      StatCard(
                        icon: Icons.inventory_2,
                        label: 'Delivered parcels',
                        value: '$i',
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        MaterialApp(
            home: MediaQuery(
                data: MediaQueryData(size: size),
                child: const LandingScreen())),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => AuthState(),
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => const ParcelFormDialog(isStaff: false),
                    ),
                    child: const Text('Open booking form'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open booking form'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:airdog_mobile/app/app.dart';
import 'package:airdog_mobile/core/settings/appearance.dart';

void main() {
  testWidgets('未登录时进入登录页', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const WorkbenchApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('小窝'), findsOneWidget);
    expect(find.text('登录'), findsOneWidget);
  });
}

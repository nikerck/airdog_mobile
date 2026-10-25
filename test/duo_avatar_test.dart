import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:airdog_mobile/shared/widgets/duo_avatar.dart';

Widget wrap(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  testWidgets('没有伙伴时只画自己一个', (tester) async {
    await tester.pumpWidget(wrap(const DuoAvatar(first: 'Z')));
    expect(find.text('Z'), findsOneWidget);
    expect(find.textContaining('+'), findsNothing);
  });

  testWidgets('一个伙伴画两个', (tester) async {
    await tester.pumpWidget(wrap(const DuoAvatar(first: 'Z', second: 'M')));
    expect(find.text('Z'), findsOneWidget);
    expect(find.text('M'), findsOneWidget);
    expect(find.textContaining('+'), findsNothing);
  });

  testWidgets('伙伴多于两个时折叠成 +N', (tester) async {
    await tester.pumpWidget(
      wrap(const DuoAvatar(first: 'Z', second: 'M', extra: 2)),
    );
    expect(find.text('Z'), findsOneWidget);
    expect(find.text('M'), findsOneWidget);
    expect(find.text('+2'), findsOneWidget);
  });
}

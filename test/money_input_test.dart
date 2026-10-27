import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:airdog_mobile/modules/wish/ui/money_input.dart';

/// 把「弹出金额输入 → 拿返回值」包成一个小页面方便测试
Widget host(void Function(int?) onResult) => MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                final cents = await showMoneyInput(
                  context,
                  accent: Colors.orange,
                );
                onResult(cents);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('弹层里有输入框、快捷金额和确定按钮', (tester) async {
    await tester.pumpWidget(host((_) {}));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('¥100'), findsOneWidget);
    expect(find.text('¥500'), findsOneWidget);
    expect(find.text('¥1,000'), findsOneWidget);
    expect(find.text('确定'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
  });

  testWidgets('直接点确定会提示金额无效', (tester) async {
    int? result;
    await tester.pumpWidget(host((v) => result = v));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(find.text('请输入大于 0 的金额'), findsOneWidget);
    expect(result, isNull);
  });

  testWidgets('输入金额后确定返回分', (tester) async {
    int? result;
    await tester.pumpWidget(host((v) => result = v));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '500');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(result, 50000);
  });

  testWidgets('点快捷金额会填进输入框', (tester) async {
    int? result;
    await tester.pumpWidget(host((v) => result = v));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('¥1,000'));
    await tester.pump();

    expect(find.text('1000'), findsOneWidget);

    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(result, 100000);
  });
}

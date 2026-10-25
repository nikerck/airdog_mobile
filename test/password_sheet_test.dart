import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:airdog_mobile/features/me/ui/password_sheet.dart';

Widget host() => MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showChangePasswordSheet(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

Future<void> openSheet(WidgetTester tester) async {
  await tester.pumpWidget(host());
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('弹层能渲染三个输入框', (tester) async {
    await openSheet(tester);
    expect(find.text('修改密码'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(3));
  });

  testWidgets('两次新密码不一致时给出提示', (tester) async {
    await openSheet(tester);
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'old-pass');
    await tester.enterText(fields.at(1), 'new-pass-1');
    await tester.enterText(fields.at(2), 'new-pass-2');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('两次输入的新密码不一致'), findsOneWidget);
  });

  testWidgets('太短的新密码会被拦下', (tester) async {
    await openSheet(tester);
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'old-pass');
    await tester.enterText(fields.at(1), '123');
    await tester.enterText(fields.at(2), '123');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('新密码至少 6 位'), findsOneWidget);
  });

  testWidgets('和当前密码相同会被拦下', (tester) async {
    await openSheet(tester);
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'same-pass');
    await tester.enterText(fields.at(1), 'same-pass');
    await tester.enterText(fields.at(2), 'same-pass');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('新密码不能和当前密码一样'), findsOneWidget);
  });

  testWidgets('填对了会带着两个值关闭', (tester) async {
    ({String current, String next})? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await showChangePasswordSheet(context);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'old-pass');
    await tester.enterText(fields.at(1), 'new-pass');
    await tester.enterText(fields.at(2), 'new-pass');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(result?.current, 'old-pass');
    expect(result?.next, 'new-pass');
  });
}

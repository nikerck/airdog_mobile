/// 模块注册表：唯一的「模块清单」。
///
/// 加模块只改这里一行；顺序由 module.order 决定，首页宫格据此排序。
/// 路由表也由这个列表生成（见 app/router.dart），不用手动加 GoRoute。
library;
import 'package:flutter/material.dart';

import 'module.dart';
import 'period/period_module.dart';
import 'todo/todo_module.dart';
import 'wish/wish_module.dart';

/// 新增一个模块 = 建一个文件夹 + 在这里加一行。外壳代码不用动。
final List<AppModule> appModules = <AppModule>[
  TodoModule(),
  PeriodModule(),
  WishModule(),
].toList()
  ..sort((a, b) => a.order.compareTo(b.order));

AppModule? moduleById(String id) {
  for (final m in appModules) {
    if (m.id == id) return m;
  }
  return null;
}

/// 模块主题色的公共取色：浅色用深一档，深色用亮一档。
Color moduleColor(ThemeData theme, {required Color light, required Color dark}) {
  return theme.brightness == Brightness.dark ? dark : light;
}

import 'package:flutter/material.dart';

/// 数据归属：生理期永远是个人空间，待办/愿望单是共享空间。
enum SpaceKind { personal, shared }

/// 模块契约 —— 外壳只认这个接口，不认识任何具体模块。
abstract class AppModule {
  String get id;
  String get name;

  /// 宫格里的副标题，不含敏感数据。
  String get tagline;

  IconData get icon;
  String get route;
  int get order;
  SpaceKind get space;

  Color accent(ThemeData theme);
  Color accentSoft(ThemeData theme);

  Widget buildPage(BuildContext context);
}

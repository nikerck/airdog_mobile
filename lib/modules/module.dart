/// 模块契约 —— 这是整个「一个 App 装多个模块」的核心抽象。
///
/// 外壳（首页宫格、路由、我的页模块开关）只认这个接口，不认识任何具体模块。
/// 新增一个模块 = 写一个实现 + 在 registry.dart 里加一行，其余不用改。
///
/// 字段含义：
/// - `id`：稳定标识，用于路由、开关存储、埋点，改了会丢用户配置
/// - `space`：personal 只在个人空间（生理期），shared 会同步给对方（待办、愿望单）
/// - `accent/accentSoft`：模块自己的强调色，**不跟主题色变**，用来区分模块
library;
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

/// 愿望单模块描述。space = shared，和对方一起攒钱。
library;
import 'package:flutter/material.dart';

import 'ui/wish_page.dart';
import '../module.dart';

class WishModule extends AppModule {
  @override
  String get id => 'wish';

  @override
  String get name => '愿望单';

  @override
  String get tagline => '攒钱买想要的东西';

  @override
  IconData get icon => Icons.card_giftcard_rounded;

  @override
  String get route => '/wish';

  @override
  int get order => 2;

  @override
  SpaceKind get space => SpaceKind.shared;

  @override
  Color accent(ThemeData theme) => theme.brightness == Brightness.dark
      ? const Color(0xFFF0B23E)
      : const Color(0xFF9A6A12);

  @override
  Color accentSoft(ThemeData theme) => theme.brightness == Brightness.dark
      ? const Color(0xFF2A2214)
      : const Color(0xFFFFF2D9);

  @override
  Widget buildPage(BuildContext context) => const WishPage();
}

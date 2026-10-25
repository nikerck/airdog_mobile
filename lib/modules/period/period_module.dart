import 'package:flutter/material.dart';

import '../module.dart';
import 'ui/period_page.dart';

class PeriodModule extends AppModule {
  @override
  String get id => 'period';

  @override
  String get name => '生理期';

  @override
  String get tagline => '经期记录';

  @override
  IconData get icon => Icons.favorite_rounded;

  @override
  String get route => '/period';

  @override
  int get order => 0;

  @override
  SpaceKind get space => SpaceKind.personal;

  @override
  Color accent(ThemeData theme) => theme.brightness == Brightness.dark
      ? const Color(0xFFF472B6)
      : const Color(0xFFB3325F);

  @override
  Color accentSoft(ThemeData theme) => theme.brightness == Brightness.dark
      ? const Color(0xFF2A1A24)
      : const Color(0xFFFBE7EF);

  @override
  Widget buildPage(BuildContext context) => const PeriodPage();
}

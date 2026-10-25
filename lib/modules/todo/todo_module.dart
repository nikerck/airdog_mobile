import 'package:flutter/material.dart';

import '../module.dart';
import 'ui/todo_page.dart';

class TodoModule extends AppModule {
  @override
  String get id => 'todo';

  @override
  String get name => '待办';

  @override
  String get tagline => '2 项未完成';

  @override
  IconData get icon => Icons.checklist_rounded;

  @override
  String get route => '/todo';

  @override
  int get order => 1;

  @override
  SpaceKind get space => SpaceKind.shared;

  @override
  Color accent(ThemeData theme) => theme.colorScheme.primary;

  @override
  Color accentSoft(ThemeData theme) => theme.colorScheme.primaryContainer;

  @override
  Widget buildPage(BuildContext context) => const TodoPage();
}

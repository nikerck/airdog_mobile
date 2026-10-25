import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/auth_controller.dart';
import '../features/login/login_page.dart';
import '../features/shell/shell_page.dart';
import '../core/db/app_database.dart';
import '../modules/registry.dart';
import '../modules/todo/ui/edit_todo_page.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(path: '/home', builder: (context, state) => const ShellPage()),
      GoRoute(
        path: '/todo/edit',
        builder: (context, state) =>
            EditTodoPage(item: state.extra! as TodoItem),
      ),
      // 模块路由由注册表生成，加模块不用改这里
      for (final module in appModules)
        GoRoute(
          path: module.route,
          builder: (context, state) => module.buildPage(context),
        ),
    ],
    redirect: (context, state) {
      final session = ref.read(authProvider);
      final atLogin = state.matchedLocation == '/login';
      if (session == null) return atLogin ? null : '/login';
      if (atLogin) return '/home';
      return null;
    },
  );
});

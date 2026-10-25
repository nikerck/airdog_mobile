import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 当前选中的底部 tab。
///
/// 底部导航不是路由，所以「从头像跳到我的」这类跨页跳转要靠这个 provider，
/// 而不是 context.go('/me')。
final shellTabProvider = StateProvider<int>((ref) => 0);

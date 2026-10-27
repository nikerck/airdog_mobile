/// 把「一次可能失败的操作」包起来：失败时用 SnackBar 显示人话错误。
///
/// 所有网络写操作都应该走它，避免每个页面重复 try/catch，
/// 也避免 DioException 冒到 UI 层。
library;
import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';

/// 包一层网络调用：失败时用 SnackBar 把「人话」错误显示出来，
/// 不让 DioException 冒到界面层。
Future<bool> runGuarded(
  BuildContext context,
  Future<void> Function() action, {
  String? successMessage,
}) async {
  try {
    await action();
    if (successMessage != null && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(successMessage)));
    }
    return true;
  } on ApiException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
    return false;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('操作失败：$e')));
    }
    return false;
  }
}

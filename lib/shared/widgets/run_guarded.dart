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

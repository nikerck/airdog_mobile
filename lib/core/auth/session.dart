import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 一次登录会话。离线模式下 token 为空。
class Session {
  const Session({
    required this.baseUrl,
    required this.userName,
    required this.offline,
    this.token,
    this.userId,
  });

  final String baseUrl;
  final String userName;
  final bool offline;
  final String? token;
  final String? userId;

  Session copyWith({
    String? baseUrl,
    String? userName,
    bool? offline,
    String? token,
    String? userId,
  }) {
    return Session(
      baseUrl: baseUrl ?? this.baseUrl,
      userName: userName ?? this.userName,
      offline: offline ?? this.offline,
      token: token ?? this.token,
      userId: userId ?? this.userId,
    );
  }
}

/// 启动时从本地恢复的会话；在 main() 里通过 override 注入。
final initialSessionProvider = Provider<Session?>((ref) => null);

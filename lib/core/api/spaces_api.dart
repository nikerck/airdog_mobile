import 'package:dio/dio.dart';

import '../network/api_client.dart';

class SpaceMember {
  const SpaceMember({
    required this.id,
    required this.name,
    required this.initial,
    required this.isMe,
    this.avatarUrl,
  });

  factory SpaceMember.fromJson(Map<String, dynamic> j) => SpaceMember(
        id: (j['id'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        initial: (j['initial'] ?? '').toString(),
        isMe: j['isMe'] == true,
        avatarUrl: (j['avatarUrl'] as String?)?.trim().isEmpty ?? true
            ? null
            : j['avatarUrl'] as String,
      );

  final String id;
  final String name;
  final String initial;
  final bool isMe;

  /// 服务端给的绝对地址，展示前要用 resolveMediaUrl 换成当前 baseUrl
  final String? avatarUrl;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'initial': initial,
        'isMe': isMe,
        'avatarUrl': avatarUrl,
      };
}

class SpaceInfo {
  const SpaceInfo({
    required this.id,
    required this.name,
    required this.kind,
    required this.members,
  });

  factory SpaceInfo.fromJson(Map<String, dynamic> j) => SpaceInfo(
        id: (j['id'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        kind: (j['kind'] ?? '').toString(),
        members: (j['members'] is List)
            ? (j['members'] as List)
                .whereType<Map>()
                .map((e) => SpaceMember.fromJson(Map<String, dynamic>.from(e)))
                .toList()
            : const [],
      );

  final String id;
  final String name;
  final String kind;
  final List<SpaceMember> members;

  bool get isPersonal => kind == 'personal';

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'kind': kind,
        'members': members.map((m) => m.toJson()).toList(),
      };
}

class SpacesApi {
  SpacesApi(this._dio);

  final Dio _dio;

  Future<List<SpaceInfo>> list() async {
    try {
      final res = await _dio.get<dynamic>('/api/spaces');
      final data = ApiClient.unwrap(res);
      final spaces = data['spaces'];
      if (spaces is! List) return const [];
      return spaces
          .whereType<Map>()
          .map((e) => SpaceInfo.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }
}

/// 共享空间里「不是自己」的那个人；没有就返回 null。
///
/// 单伙伴场景（比如「只有 X 能编辑」）用这个；多人场景用 [pickPartners]。
SpaceMember? pickPartner(List<SpaceMember> members) {
  for (final m in members) {
    if (!m.isMe) return m;
  }
  return null;
}

/// 共享空间里除我之外的所有人，按接口返回顺序。
List<SpaceMember> pickPartners(List<SpaceMember> members) =>
    [for (final m in members) if (!m.isMe) m];

/// 「与 X 共享」这句文案。人多时只列前两个，其余折叠成「等 N 人」。
String sharingTitle(List<SpaceMember> partners) {
  if (partners.isEmpty) return '自己用';

  final names =
      partners.map((m) => m.name.trim()).where((n) => n.isNotEmpty).toList();
  if (names.isEmpty) return '共享';
  if (names.length == 1) return '与 ${names.first} 共享';
  if (names.length == 2) return '与 ${names.join('、')} 共享';
  return '与 ${names.take(2).join('、')} 等 ${names.length} 人共享';
}

/// id → 显示名。查不到就退回 id，再不行给个兜底词。
String memberName(
  Map<String, SpaceMember> byId,
  String? id, {
  String fallback = '我',
}) {
  if (id == null || id.isEmpty) return fallback;
  final member = byId[id];
  if (member != null && member.name.isNotEmpty) return member.name;
  // 查不到就显示 id，别猜「这就是我」
  return id;
}

/// 头像里的那个字：优先用后端给的 initial，没有就取名字首字。
String memberInitial(
  Map<String, SpaceMember> byId,
  String? id, {
  String fallback = '我',
}) {
  if (id == null) return fallback;
  final member = byId[id];
  if (member == null) return id.isEmpty ? fallback : id.substring(0, 1);
  if (member.initial.isNotEmpty) return member.initial;
  return member.name.isEmpty ? fallback : member.name.substring(0, 1);
}

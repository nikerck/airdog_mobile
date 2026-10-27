import 'package:flutter_test/flutter_test.dart';

import 'package:airdog_mobile/core/api/spaces_api.dart';

SpaceMember m(String id, String name,
        {String initial = '', bool isMe = false, String? avatar}) =>
    SpaceMember(
      id: id,
      name: name,
      initial: initial,
      isMe: isMe,
      avatarUrl: avatar,
    );

SpaceInfo space(String id, List<SpaceMember> members) =>
    SpaceInfo(id: id, name: id, kind: 'shared', members: members);

void main() {
  group('成员数据比较（决定要不要刷新界面）', () {
    test('完全一样', () {
      final a = [space('sp_shared', [m('u_me', 'Zyy', initial: 'Z')])];
      final b = [space('sp_shared', [m('u_me', 'Zyy', initial: 'Z')])];
      expect(spacesEqual(a, b), isTrue);
    });

    test('对方换了头像 → 需要刷新', () {
      final a = [
        space('sp_shared', [m('u_momo', 'Momo', avatar: null)]),
      ];
      final b = [
        space('sp_shared', [m('u_momo', 'Momo', avatar: 'http://h/f/1')]),
      ];
      expect(spacesEqual(a, b), isFalse);
    });

    test('对方改了名字 → 需要刷新', () {
      final a = [space('sp_shared', [m('u_momo', 'Momo')])];
      final b = [space('sp_shared', [m('u_momo', '小沫')])];
      expect(spacesEqual(a, b), isFalse);
    });

    test('成员数量变了 → 需要刷新', () {
      final a = [space('sp_shared', [m('u_me', 'Zyy')])];
      final b = [
        space('sp_shared', [m('u_me', 'Zyy'), m('u_momo', 'Momo')]),
      ];
      expect(spacesEqual(a, b), isFalse);
    });

    test('空对空算一样', () {
      expect(spacesEqual(const [], const []), isTrue);
    });
  });
}

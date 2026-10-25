import 'package:flutter_test/flutter_test.dart';

import 'package:airdog_mobile/core/api/spaces_api.dart';

SpaceMember member(String id, String name,
        {String initial = '', bool isMe = false}) =>
    SpaceMember(id: id, name: name, initial: initial, isMe: isMe);

void main() {
  group('找共享伙伴', () {
    test('只有一个非自己的成员', () {
      final p = pickPartner([
        member('u_me', 'Zyy', initial: 'Z', isMe: true),
        member('u_momo', 'Momo', initial: 'M'),
      ]);
      expect(p?.name, 'Momo');
    });

    test('只有自己时返回 null', () {
      expect(pickPartner([member('u_me', 'Zyy', isMe: true)]), isNull);
      expect(pickPartner(const []), isNull);
    });

    test('多人时取第一个非自己的', () {
      final p = pickPartner([
        member('u_me', 'Zyy', isMe: true),
        member('u_a', '阿哲'),
        member('u_b', '小美'),
      ]);
      expect(p?.id, 'u_a');
    });
  });

  group('多人共享', () {
    final three = [
      member('u_me', 'Zyy', isMe: true),
      member('u_momo', 'Momo'),
      member('u_a', '阿哲'),
      member('u_b', '小美'),
    ];

    test('取出所有人（不含自己）', () {
      expect(pickPartners(three).map((m) => m.id), ['u_momo', 'u_a', 'u_b']);
      expect(pickPartners([member('u_me', 'Zyy', isMe: true)]), isEmpty);
    });
  });

  group('共享文案', () {
    test('没有伙伴', () {
      expect(sharingTitle(const []), '自己用');
    });

    test('一个人', () {
      expect(sharingTitle([member('u_momo', 'Momo')]), '与 Momo 共享');
    });

    test('两个人全列出来', () {
      expect(
        sharingTitle([member('u_a', '阿哲'), member('u_b', '小美')]),
        '与 阿哲、小美 共享',
      );
    });

    test('三个人折叠成「等 N 人」', () {
      expect(
        sharingTitle([
          member('u_momo', 'Momo'),
          member('u_a', '阿哲'),
          member('u_b', '小美'),
        ]),
        '与 Momo、阿哲 等 3 人共享',
      );
    });

    test('名字为空也不会出现空档', () {
      expect(sharingTitle([member('u_x', '')]), '共享');
    });
  });

  group('显示名', () {
    final byId = {
      'u_me': member('u_me', 'Zyy', initial: 'Z', isMe: true),
      'u_momo': member('u_momo', '小沫', initial: '沫'),
    };

    test('查得到就用后端名字', () {
      expect(memberName(byId, 'u_momo'), '小沫');
      expect(memberName(byId, 'u_me'), 'Zyy');
    });

    test('查不到退回 id', () {
      expect(memberName(byId, 'u_unknown'), 'u_unknown');
    });

    test('null 用兜底词', () {
      expect(memberName(byId, null), '我');
      expect(memberName(byId, null, fallback: '某人'), '某人');
    });
  });

  group('头像字', () {
    final byId = {
      'u_momo': member('u_momo', '小沫', initial: '沫'),
      'u_plain': member('u_plain', 'Momo'),
    };

    test('优先用 initial', () {
      expect(memberInitial(byId, 'u_momo'), '沫');
    });

    test('没 initial 就取名字首字', () {
      expect(memberInitial(byId, 'u_plain'), 'M');
    });

    test('查不到用 id 首字', () {
      expect(memberInitial(byId, 'u_x'), 'u');
    });
  });
}

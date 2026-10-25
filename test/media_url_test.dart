import 'package:flutter_test/flutter_test.dart';

import 'package:airdog_mobile/core/api/media_url.dart';

void main() {
  group('头像地址解析', () {
    test('空值返回 null', () {
      expect(resolveMediaUrl(null, 'http://192.168.31.27:8080'), isNull);
      expect(resolveMediaUrl('', 'http://192.168.31.27:8080'), isNull);
      expect(resolveMediaUrl('   ', 'http://192.168.31.27:8080'), isNull);
    });

    test('服务端给 localhost，手机连局域网 IP → 换主机', () {
      expect(
        resolveMediaUrl(
          'http://localhost:8080/api/files/file_x',
          'http://192.168.31.27:8080',
        ),
        'http://192.168.31.27:8080/api/files/file_x',
      );
    });

    test('服务端给 127.0.0.1，客户端也是本机 → 原样保留', () {
      expect(
        resolveMediaUrl(
          'http://127.0.0.1:8080/api/files/file_x',
          'http://127.0.0.1:8080',
        ),
        'http://127.0.0.1:8080/api/files/file_x',
      );
    });

    test('本来就是公网/局域网地址 → 不动', () {
      expect(
        resolveMediaUrl(
          'https://cdn.example.com/a.png',
          'http://192.168.31.27:8080',
        ),
        'https://cdn.example.com/a.png',
      );
    });

    test('相对路径拼到 baseUrl 后面', () {
      expect(
        resolveMediaUrl('/api/files/file_x', 'http://192.168.31.27:8080'),
        'http://192.168.31.27:8080/api/files/file_x',
      );
    });

    test('带查询参数', () {
      expect(
        resolveMediaUrl(
          'http://localhost:8080/api/files/x?w=200',
          'http://10.0.2.2:8080',
        ),
        'http://10.0.2.2:8080/api/files/x?w=200',
      );
    });

    test('baseUrl 不合法时原样返回', () {
      expect(
        resolveMediaUrl('http://localhost:8080/api/files/x', ''),
        'http://localhost:8080/api/files/x',
      );
    });
  });
}

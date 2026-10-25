import 'package:flutter_test/flutter_test.dart';

import 'package:airdog_mobile/core/network/api_exception.dart';

void main() {
  group('删除时「已经不存在」的判断', () {
    test('404 当成已删除', () {
      expect(
        isAlreadyGone(ApiException(ApiErrorKind.notFound, '不存在')),
        isTrue,
      );
    });

    test('业务码 9004 也算', () {
      expect(
        isAlreadyGone(
          ApiException(ApiErrorKind.badResponse, '数据不存在', code: 9004),
        ),
        isTrue,
      );
    });

    test('HTTP 404 码也算', () {
      expect(
        isAlreadyGone(ApiException(ApiErrorKind.badResponse, 'x', code: 404)),
        isTrue,
      );
    });

    test('没权限不能当删除成功', () {
      expect(
        isAlreadyGone(ApiException(ApiErrorKind.forbidden, '无权限')),
        isFalse,
      );
    });

    test('网络问题不能当删除成功', () {
      expect(
        isAlreadyGone(ApiException(ApiErrorKind.network, '连不上')),
        isFalse,
      );
    });

    test('版本冲突不能当删除成功', () {
      expect(
        isAlreadyGone(
          ApiException(ApiErrorKind.badResponse, '版本冲突', code: 2003),
        ),
        isFalse,
      );
    });
  });
}

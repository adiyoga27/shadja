import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadja/core/utils/error_reporter.dart';

DioException _dioError(int? status) {
  final request = RequestOptions(
    path: '/orders',
    method: 'POST',
    headers: {'Authorization': 'Bearer rahasia'},
    data: {'customer_phone': '08123456789'},
  );
  return DioException(
    requestOptions: request,
    type: status == null
        ? DioExceptionType.connectionTimeout
        : DioExceptionType.badResponse,
    response: status == null
        ? null
        : Response(requestOptions: request, statusCode: status),
  );
}

void main() {
  late List<String> sent;

  setUp(() {
    sent = [];
    ErrorReporter.resetDedupe();
    ErrorReporter.senderOverride = (text) async => sent.add(text);
  });

  tearDown(() => ErrorReporter.senderOverride = null);

  test('error yang sama hanya dikirim sekali', () async {
    await ErrorReporter.report('boom', null, source: 'async');
    await ErrorReporter.report('boom', null, source: 'async');
    await ErrorReporter.report('lain', null, source: 'async');
    expect(sent, hasLength(2));
  });

  test('pesan dipotong di bawah batas Telegram', () async {
    await ErrorReporter.report('x' * 10000, null, source: 'async');
    expect(sent.single.length, lessThanOrEqualTo(4096));
  });

  test('kegagalan mengirim tidak melempar error', () async {
    ErrorReporter.senderOverride = (_) async => throw Exception('offline');
    await ErrorReporter.report('boom', null, source: 'async');
  });

  test('error API tidak membawa token login atau data pelanggan', () async {
    await ErrorReporter.reportDio(_dioError(500));
    expect(sent.single, contains('POST /orders -> 500'));
    expect(sent.single, isNot(contains('rahasia')));
    expect(sent.single, isNot(contains('08123456789')));
  });

  test('401 dan 422 tidak dilaporkan', () async {
    await ErrorReporter.reportDio(_dioError(401));
    await ErrorReporter.reportDio(_dioError(422));
    expect(sent, isEmpty);
  });

  group('StallDetector', () {
    final start = DateTime(2026);
    DateTime at(int seconds) => start.add(Duration(seconds: seconds));

    test('detak normal tidak melapor', () {
      final detector = StallDetector(start);
      for (var i = 1; i <= 10; i++) {
        expect(detector.onTick(at(i)), isNull);
        expect(detector.onCheck(at(i)), isNull);
      }
    });

    test('macet dilaporkan sekali, lalu pulih dengan durasinya', () {
      final detector = StallDetector(start);
      expect(detector.onCheck(at(1)), isNull);
      expect(detector.onCheck(at(2)), isNull);
      expect(detector.onCheck(at(3)), contains('macet'));
      expect(detector.onCheck(at(4)), isNull);
      expect(detector.onTick(at(7)), 'UI pulih setelah 7 detik');
      expect(detector.onTick(at(8)), isNull);
    });

    test('PC sleep tidak dianggap macet', () {
      final detector = StallDetector(start);
      expect(detector.onCheck(at(3600)), isNull);
      expect(detector.onCheck(at(3601)), isNull);
    });
  });

  test('timeout dilaporkan dengan jenis error', () async {
    await ErrorReporter.reportDio(_dioError(null));
    expect(sent.single, contains('connectionTimeout'));
  });
}

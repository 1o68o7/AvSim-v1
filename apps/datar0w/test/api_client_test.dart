import 'package:datar0w/session/api_client.dart';
import 'package:datar0w/session/model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('base vide → no-op', () async {
    final api = SessionApi(baseOverride: '');
    expect(api.active, isFalse);
    await api.tick(
      id: 's1',
      sample: const SessionSample(t: 1, distM: 0, net: 'wifi'),
    );
  });

  test('create + live parse', () async {
    final client = MockClient((req) async {
      if (req.url.path.endsWith('/datarow/sessions')) {
        return http.Response('{"id":"s1","code":"ABC234"}', 200);
      }
      if (req.url.path.contains('/live')) {
        return http.Response(
          '{"id":"s1","code":"ABC234","sample":{"t":1,"dist_m":3.0,"net":"wifi","sog":2.1}}',
          200,
        );
      }
      return http.Response('no', 404);
    });
    final api = SessionApi(
      client: client,
      baseOverride: 'http://127.0.0.1:8000',
    );
    expect(api.active, isTrue);
    final created = await api.createSession(id: 's1', code: 'ABC234');
    expect(created!.code, 'ABC234');
    final live = await api.fetchLive('s1');
    expect(live!.sample!.sog, 2.1);
  });

  test('HTTP 500 ne jette pas', () async {
    final client = MockClient((req) async => http.Response('x', 500));
    final api = SessionApi(
      client: client,
      baseOverride: 'http://example.invalid',
    );
    expect(await api.lookupByCode('ABCDEF'), isNull);
    await api.note(id: 's1', note: {'t': 1});
  });
}

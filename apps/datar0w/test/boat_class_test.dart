import 'package:datar0w/session/boat_class.dart';
import 'package:datar0w/session/store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('classes 1x–8+ : sièges et cox, pas d’IMU extra', () {
    expect(BoatClassInfo.of('1x').seats, 1);
    expect(BoatClassInfo.of('1x').coxed, isFalse);
    expect(BoatClassInfo.of('2x').seats, 2);
    expect(BoatClassInfo.of('4-').seats, 4);
    expect(BoatClassInfo.of('4+').coxed, isTrue);
    expect(BoatClassInfo.of('8+').seats, 8);
    expect(BoatClassInfo.codes.length, 7);
  });

  test('meta.json class + role + seatIndex', () {
    const m = SessionMeta(
      id: 's1',
      classe: '8+',
      seats: 8,
      cox: true,
      role: 'cox',
      seatIndex: 1,
    );
    final j = m.toJson();
    expect(j['class'], '8+');
    expect(j['seatIndex'], 1);
    final back = SessionMeta.fromJson(j);
    expect(back.classe, '8+');
    expect(back.cox, isTrue);
    expect(back.role, 'cox');
  });
}

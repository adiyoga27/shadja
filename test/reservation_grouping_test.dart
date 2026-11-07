import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shadja/features/reservation/data/reservation_model.dart';
import 'package:shadja/features/reservation/presentation/reservation_list_page.dart';

ReservationModel _at(int id, DateTime time) => ReservationModel(
      id: id,
      restaurantTableId: 1,
      reservationTime: time,
      guestCount: 2,
    );

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  final now = DateTime(2026, 11, 6, 12);

  test('yang akan datang di atas, yang lewat terbaru dulu di akhir', () {
    final groups = groupReservations([
      _at(1, DateTime(2026, 11, 1, 19)),
      _at(2, DateTime(2026, 11, 7, 19)),
      _at(3, DateTime(2026, 11, 6, 20)),
      _at(4, DateTime(2026, 11, 6, 9)),
      _at(5, DateTime(2026, 11, 3, 19)),
      _at(6, DateTime(2026, 11, 10, 19)),
    ], now);

    expect(groups.map((g) => g.label).toList(), [
      'Hari ini',
      'Besok',
      'Selasa, 10 Nov 2026',
      'Sebelumnya',
    ]);
    expect(groups[0].reservations.map((r) => r.id), [4, 3]);
    expect(groups[3].reservations.map((r) => r.id), [5, 1]);
  });

  test('daftar kosong tidak menghasilkan grup', () {
    expect(groupReservations([], now), isEmpty);
  });
}

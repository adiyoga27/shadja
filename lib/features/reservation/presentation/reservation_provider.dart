import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadja/features/reservation/data/reservation_model.dart';
import 'package:shadja/features/reservation/data/reservation_repository.dart';

class ReservationListState {
  const ReservationListState({
    this.reservations = const [],
    this.isLoading = false,
    this.error,
  });

  final List<ReservationModel> reservations;
  final bool isLoading;
  final String? error;
}

class ReservationListNotifier
    extends StateNotifier<ReservationListState> {
  ReservationListNotifier(this._repo)
      : super(const ReservationListState(isLoading: true));

  final ReservationRepository _repo;

  Future<void> load() async {
    state = const ReservationListState(isLoading: true);
    try {
      final list = await _repo.fetchReservations();
      state = ReservationListState(reservations: list);
    } catch (e) {
      state = ReservationListState(error: e.toString());
    }
  }
}

final reservationListProvider = StateNotifierProvider<
    ReservationListNotifier, ReservationListState>(
  (ref) {
    final n = ReservationListNotifier(ref.read(reservationRepositoryProvider));
    n.load();
    return n;
  },
);

final reservationDetailProvider =
    FutureProvider.family<ReservationModel, int>((ref, id) async {
  final repo = ref.read(reservationRepositoryProvider);
  return repo.fetchReservation(id);
});

final tablesProvider =
    FutureProvider<List<RestaurantTableModel>>((ref) async {
  final repo = ref.read(reservationRepositoryProvider);
  return repo.fetchTables();
});

class CreateReservationState {
  const CreateReservationState({this.isLoading = false, this.error});
  final bool isLoading;
  final String? error;
}

class CreateReservationNotifier extends StateNotifier<CreateReservationState> {
  CreateReservationNotifier(this._repo) : super(const CreateReservationState());

  final ReservationRepository _repo;

  Future<ReservationModel?> submit(CreateReservationRequest req) async {
    state = const CreateReservationState(isLoading: true);
    try {
      final res = await _repo.create(req);
      state = const CreateReservationState();
      return res;
    } catch (e) {
      state = CreateReservationState(error: e.toString());
      return null;
    }
  }
}

final createReservationProvider = StateNotifierProvider<
    CreateReservationNotifier, CreateReservationState>(
  (ref) => CreateReservationNotifier(ref.read(reservationRepositoryProvider)),
);
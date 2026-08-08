import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadja/core/constants/app_colors.dart';
import 'package:shadja/core/responsive/responsive_layout.dart';
import 'package:shadja/features/reservation/data/reservation_model.dart';
import 'package:shadja/features/reservation/data/reservation_repository.dart';
import 'package:shadja/features/reservation/presentation/reservation_provider.dart';

class ReservationFormPage extends ConsumerStatefulWidget {
  const ReservationFormPage({super.key});

  @override
  ConsumerState<ReservationFormPage> createState() =>
      _ReservationFormPageState();
}

class _ReservationFormPageState extends ConsumerState<ReservationFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _guestCtrl = TextEditingController(text: '2');
  final _notesCtrl = TextEditingController();
  int? _selectedTableId;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _submitting = false;

  @override
  void dispose() {
    _guestCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedTableId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Pilih meja terlebih dahulu.'),
          backgroundColor: AppColors.danger));
      return;
    }
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Pilih tanggal & jam reservasi.'),
          backgroundColor: AppColors.danger));
      return;
    }

    setState(() => _submitting = true);
    final dt = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );
    final req = CreateReservationRequest(
      restaurantTableId: _selectedTableId!,
      reservationTime: dt,
      guestCount: int.tryParse(_guestCtrl.text) ?? 1,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    );
    final res =
        await ref.read(createReservationProvider.notifier).submit(req);
    setState(() => _submitting = false);
    if (res != null && mounted) {
      ref.invalidate(reservationListProvider);
      context.go('/home/reservations/${res.id}');
    } else if (mounted) {
      final err = ref.read(createReservationProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(err ?? 'Gagal membuat reservasi.'),
            backgroundColor: AppColors.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tablesAsync = ref.watch(tablesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reservasi Baru'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ResponsiveLayout(
        mobile: (_) => _build(tablesAsync),
        tabletLandscape: (_) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: _build(tablesAsync),
          ),
        ),
      ),
    );
  }

  Widget _build(AsyncValue<List<RestaurantTableModel>> tablesAsync) {
    final create = ref.watch(createReservationProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Pilih Meja',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            tablesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Gagal memuat meja: $e'),
              data: (tables) => _TableGrid(
                tables: tables,
                selectedId: _selectedTableId,
                onSelect: (id) => setState(() => _selectedTableId = id),
              ),
            ),
            const SizedBox(height: 20),
            // Date / time
            const Text('Tanggal & Jam',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_month_outlined, size: 18),
                    label: Text(_selectedDate == null
                        ? 'Pilih tanggal'
                        : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickTime,
                    icon: const Icon(Icons.access_time, size: 18),
                    label: Text(_selectedTime == null
                        ? 'Pilih jam'
                        : _selectedTime!.format(context)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _guestCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Jumlah Tamu',
                prefixIcon: Icon(Icons.group_outlined, size: 18),
              ),
              validator: (v) {
                final n = int.tryParse(v ?? '');
                if (n == null || n < 1) return 'Minimal 1 tamu';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Catatan (opsional)',
                prefixIcon: Icon(Icons.note_outlined, size: 18),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: (_submitting || create.isLoading) ? null : _submit,
              icon: (_submitting || create.isLoading)
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check, size: 18),
              label: const Text('Buat Reservasi'),
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16)),
            ),
          ],
        ),
      ),
    );
  }
}

class _TableGrid extends StatelessWidget {
  const _TableGrid({
    required this.tables,
    required this.selectedId,
    required this.onSelect,
  });

  final List<RestaurantTableModel> tables;
  final int? selectedId;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.8,
      ),
      itemCount: tables.length,
      itemBuilder: (context, index) {
        final t = tables[index];
        final selected = selectedId == t.id;
        return GestureDetector(
          onTap: () => onSelect(t.id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: selected ? AppColors.primaryBg : AppColors.surface,
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.border,
                width: selected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  t.tableNumber,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: selected ? AppColors.primary : AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${t.capacity} kursi',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

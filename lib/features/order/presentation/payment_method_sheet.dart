import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadja/core/constants/app_colors.dart';
import 'package:shadja/core/utils/formatters.dart';
import 'package:shadja/features/order/data/order_model.dart';
import 'package:shadja/features/order/presentation/order_provider.dart';

class PaymentResult {
  PaymentResult({required this.success, this.payment});
  final bool success;
  final PaymentModel? payment;
}

class PaymentMethodSheet extends ConsumerStatefulWidget {
  const PaymentMethodSheet({super.key, required this.order});

  final OrderModel order;

  @override
  ConsumerState<PaymentMethodSheet> createState() => _PaymentMethodSheetState();
}

class _PaymentMethodSheetState extends ConsumerState<PaymentMethodSheet> {
  String _method = 'cash';
  bool _processing = false;
  final _cashCtrl = TextEditingController();

  static const _methods = [
    ('cash', 'Tunai', Icons.payments, AppColors.success),
    ('qris', 'QRIS', Icons.qr_code, AppColors.info),
    ('transfer', 'Transfer', Icons.account_balance, AppColors.info),
    ('card', 'Kartu', Icons.credit_card, AppColors.warning),
  ];

  @override
  void dispose() {
    _cashCtrl.dispose();
    super.dispose();
  }

  num get _cashReceived {
    final raw = _cashCtrl.text.trim();
    if (raw.isEmpty) return 0;
    return num.tryParse(raw.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
  }

  num get _change => _cashReceived - widget.order.total;

  String? get _cashError {
    if (_method != 'cash') return null;
    if (_cashReceived < widget.order.total) {
      return 'Uang diterima kurang dari total tagihan';
    }
    return null;
  }

  Future<void> _pay() async {
    if (_method == 'cash' && _cashError != null) {
      setState(() {});
      return;
    }
    setState(() => _processing = true);
    final payment = await ref.read(checkoutProvider.notifier).pay(
          orderId: widget.order.id,
          method: _method,
          amount: widget.order.total,
          cashReceived: _method == 'cash' && _cashReceived > 0
              ? _cashReceived
              : null,
          change: _method == 'cash' && _change > 0 ? _change : null,
        );
    setState(() => _processing = false);
    if (payment != null && mounted) {
      Navigator.of(context).pop(PaymentResult(success: true, payment: payment));
    } else {
      final err = ref.read(checkoutProvider).error;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err ?? 'Pembayaran gagal'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                const Icon(Icons.account_balance_wallet_outlined, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text(
                  'Pilih Metode Pembayaran',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Total tagihan: ${Formatters.rupiah(widget.order.total)}',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 3.2,
              ),
              itemCount: _methods.length,
              itemBuilder: (context, index) {
                final m = _methods[index];
                final selected = _method == m.$1;
                return GestureDetector(
                  onTap: () => setState(() => _method = m.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: selected ? m.$4.withValues(alpha: 0.08) : AppColors.background,
                      border: Border.all(
                        color: selected ? m.$4 : AppColors.border,
                        width: selected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(m.$3, size: 24, color: m.$4),
                        const SizedBox(width: 10),
                        Text(
                          m.$2,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: selected ? m.$4 : AppColors.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        if (selected)
                          const Icon(Icons.check,
                              size: 18, color: AppColors.primary),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            if (_method == 'cash') ...[
              TextFormField(
                controller: _cashCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Uang Diterima',
                  hintText: 'nominal yang dibayar pelanggan',
                  prefixIcon: const Icon(Icons.payments_outlined, size: 18),
                  errorText: _cashError,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              if (_cashReceived > 0)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.successBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Kembalian',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        _change >= 0
                            ? Formatters.rupiah(_change)
                            : '- ${Formatters.rupiah(-_change)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
            ],
            FilledButton.icon(
              onPressed: _processing ? null : _pay,
              icon: _processing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check, size: 18),
              label: Text(_processing ? 'Memproses…' : 'Konfirmasi Pembayaran'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
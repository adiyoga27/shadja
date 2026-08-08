import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:shadja/core/utils/formatters.dart';
import 'package:shadja/features/order/data/order_model.dart';

class ReceiptFormatter {
  ReceiptFormatter._();

  static Future<List<int>> formatBytes({
    required OrderModel order,
    String storeName = 'Shadja Restaurant',
    String storeAddress = 'Jl. Contoh No. 123',
    String storePhone = '08123456789',
    int paperWidth = 80,
  }) async {
    final profile = await CapabilityProfile.load();
    final paper = paperWidth == 58 ? PaperSize.mm58 : PaperSize.mm80;
    final generator = Generator(paper, profile);

    final bytes = _buildReceipt(
      generator: generator,
      order: order,
      storeName: storeName,
      storeAddress: storeAddress,
      storePhone: storePhone,
      paperWidth: paperWidth,
    );

    bytes.addAll(generator.cut());
    return bytes;
  }

  static Future<List<int>> testBytes({
    String storeName = 'Test',
    int paperWidth = 80,
  }) async {
    final profile = await CapabilityProfile.load();
    final paper = paperWidth == 58 ? PaperSize.mm58 : PaperSize.mm80;
    final generator = Generator(paper, profile);

    List<int> bytes = [];
    bytes.addAll(
      generator.text(
        'TEST PRINT - $storeName',
        styles: const PosStyles(bold: true, align: PosAlign.center),
      ),
    );
    bytes.addAll(
      generator.text(
        'Printer terhubung dengan baik.',
        styles: const PosStyles(align: PosAlign.center),
      ),
    );
    bytes.addAll(generator.feed(2));
    bytes.addAll(generator.cut());
    return bytes;
  }

  static List<int> _buildReceipt({
    required Generator generator,
    required OrderModel order,
    String storeName = '',
    String storeAddress = '',
    String storePhone = '',
    int paperWidth = 80,
  }) {
    List<int> bytes = [];
    final is58 = paperWidth == 58;
    final itemFont = is58 ? PosFontType.fontB : PosFontType.fontA;

    void add(List<int> b) => bytes.addAll(b);

    add(generator.text(
      storeName,
      styles: const PosStyles(bold: true, align: PosAlign.center),
    ));
    add(generator.text(
      storeAddress,
      styles: const PosStyles(align: PosAlign.center),
    ));
    add(generator.text(
      'Telp: $storePhone',
      styles: const PosStyles(align: PosAlign.center),
    ));
    add(generator.hr());

    add(generator.text('No: ${order.orderNumber ?? order.id}'));
    add(generator.text(
        'Tgl: ${order.createdAt != null ? _dateStr(order.createdAt!) : '-'}'));
    add(generator.text('Tipe: ${_orderTypeLabel(order.orderType)}'));
    if (order.customerName != null) {
      add(generator.text('Pelanggan: ${order.customerName}'));
    }
    if (order.customerPhone != null) {
      add(generator.text('Telp: ${order.customerPhone}'));
    }
    if (order.deliveryAddress != null) {
      add(generator.text('Alamat: ${order.deliveryAddress}'));
    }
    add(generator.hr());

    for (final item in order.orderItems) {
      if (is58) {
        // 58mm compact layout: two-line format to avoid cutoff
        add(generator.text(
          item.menuItemName,
          styles: PosStyles(fontType: PosFontType.fontA),
        ));
        add(generator.row([
          PosColumn(
              text: '${item.quantity}x${Formatters.rupiah(item.price)}',
              width: 8,
              styles: PosStyles(fontType: itemFont)),
          PosColumn(
              text: Formatters.rupiah(item.subtotal),
              width: 4,
              styles: PosStyles(align: PosAlign.right, fontType: itemFont)),
        ]));
      } else {
        add(generator.row([
          PosColumn(text: item.menuItemName, width: 6),
          PosColumn(
              text: '${item.quantity} x ${Formatters.rupiah(item.price)}',
              width: 3),
          PosColumn(
              text: Formatters.rupiah(item.subtotal),
              width: 3,
              styles: const PosStyles(align: PosAlign.right)),
        ]));
      }
      if (item.notes != null && item.notes!.isNotEmpty) {
        add(generator.text(
          '  ^ ${item.notes}',
          styles: const PosStyles(fontType: PosFontType.fontB),
        ));
      }
    }
    add(generator.hr());

    add(generator.row([
      PosColumn(text: 'Subtotal', width: 6),
      PosColumn(
          text: Formatters.rupiah(order.subtotal),
          width: 6,
          styles: const PosStyles(align: PosAlign.right)),
    ]));
    if (order.discount > 0) {
      add(generator.row([
        PosColumn(text: 'Diskon', width: 6),
        PosColumn(
            text: '- ${Formatters.rupiah(order.discount)}',
            width: 6,
            styles: const PosStyles(align: PosAlign.right)),
      ]));
    }
    if (order.tax > 0) {
      add(generator.row([
        PosColumn(text: 'Pajak', width: 6),
        PosColumn(
            text: Formatters.rupiah(order.tax),
            width: 6,
            styles: const PosStyles(align: PosAlign.right)),
      ]));
    }
    add(generator.hr());
    add(generator.row([
      PosColumn(
          text: 'TOTAL',
          width: 6,
          styles: const PosStyles(bold: true)),
      PosColumn(
          text: Formatters.rupiah(order.total),
          width: 6,
          styles: const PosStyles(
              bold: true,
              align: PosAlign.right)),
    ]));
    add(generator.hr());

    if (order.payments.isNotEmpty) {
      for (final p in order.payments) {
        add(generator.text('${p.method.toUpperCase()}: ${Formatters.rupiah(p.amount)}'));
        if (p.reference != null) add(generator.text('Ref: ${p.reference}'));
      }
      add(generator.hr());
    }
    if (order.notes != null && order.notes!.isNotEmpty) {
      add(generator.text('Catatan: ${order.notes}'));
      add(generator.hr());
    }

    add(generator.text(
      'Terima kasih',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    ));
    add(generator.text(
      'Barokallah',
      styles: const PosStyles(align: PosAlign.center),
    ));
    add(generator.feed(2));

    return bytes;
  }

  // --- Text formatter (debug only) ---
  static const _line80 =
      '----------------------------------------------------------------';
  static const _line58 =
      '------------------------------------------------';

  static String formatText({
    required OrderModel order,
    String storeName = 'Shadja Restaurant',
    String storeAddress = 'Jl. Contoh No. 123',
    String storePhone = '08123456789',
    int paperWidth = 80,
  }) {
    final width = paperWidth == 58 ? 32 : 48;
    final line = paperWidth == 58 ? _line58 : _line80;
    final sb = StringBuffer();

    void center(String s) {
      final pad = ((width - s.length) / 2).floor();
      sb.writeln('${' ' * (pad < 0 ? 0 : pad)}$s');
    }

    sb.writeln(line);
    center(storeName);
    center(storeAddress);
    center('Telp: $storePhone');
    sb.writeln(line);

    sb.writeln('No: ${order.orderNumber ?? order.id}');
    sb.writeln(
        'Tgl: ${order.createdAt != null ? Formatters.dateTime(order.createdAt!) : '-'}');
    sb.writeln('Tipe: ${_orderTypeLabel(order.orderType)}');
    if (order.customerName != null) {
      sb.writeln('Pelanggan: ${order.customerName}');
    }
    if (order.customerPhone != null) {
      sb.writeln('Telp: ${order.customerPhone}');
    }
    if (order.deliveryAddress != null) {
      sb.writeln('Alamat: ${order.deliveryAddress}');
    }
    sb.writeln(line);

    for (final item in order.orderItems) {
      sb.writeln(item.menuItemName);
      final left = '  ${item.quantity} x ${Formatters.rupiah(item.price)}';
      final right = Formatters.rupiah(item.subtotal);
      sb.writeln('$left${' ' * _gap(width, '$left  $right')}$right');
      if (item.notes != null && item.notes!.isNotEmpty) {
        sb.writeln('  ^ ${item.notes}');
      }
    }
    sb.writeln(line);

    sb.writeln(
        '${'Subtotal'.padRight(width - Formatters.rupiah(order.subtotal).length)}${Formatters.rupiah(order.subtotal)}');
    if (order.discount > 0) {
      sb.writeln(
          '${'Diskon'.padRight(width - Formatters.rupiah(order.discount).length)}-${Formatters.rupiah(order.discount)}');
    }
    if (order.tax > 0) {
      sb.writeln(
          '${'Pajak'.padRight(width - Formatters.rupiah(order.tax).length)}${Formatters.rupiah(order.tax)}');
    }
    sb.writeln(line);
    final totalStr = Formatters.rupiah(order.total);
    sb.writeln('TOTAL$totalStr');
    sb.writeln(line);

    if (order.payments.isNotEmpty) {
      for (final p in order.payments) {
        sb.writeln(
            '${p.method.toUpperCase()}: ${Formatters.rupiah(p.amount)}');
        if (p.reference != null) sb.writeln('Ref: ${p.reference}');
      }
      sb.writeln(line);
    }
    if (order.notes != null && order.notes!.isNotEmpty) {
      sb.writeln('Catatan: ${order.notes}');
      sb.writeln(line);
    }

    center('Terima kasih');
    sb.writeln(line);
    sb.writeln();

    return sb.toString();
  }

  static String testPage({String storeName = 'Test', int paperWidth = 80}) {
    final line = paperWidth == 58 ? _line58 : _line80;
    return '$line\n TEST PRINT - $storeName\n$line\n Printer terhubung dengan baik.\n$line\n';
  }

  static int _gap(int width, String content) {
    final g = width - content.length;
    return g < 1 ? 1 : g;
  }

  static String _dateStr(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  static String _orderTypeLabel(String type) {
    switch (type) {
      case 'dine_in':
        return 'Dine-in';
      case 'pickup':
        return 'Pickup';
      case 'delivery':
        return 'Delivery';
      default:
        return type;
    }
  }
}

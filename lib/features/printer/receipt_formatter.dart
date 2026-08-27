import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:shadja/core/utils/formatters.dart';
import 'package:shadja/features/order/data/order_model.dart';

class ReceiptFormatter {
  ReceiptFormatter._();

  // Cash drawer kick: ESC p m t1 t2 (pin 2: m=0x00, pin 5: m=0x01)
  // t1=0x19, t2=0xFA => 50ms on / 500ms off, standar Epson.
  static const _drawerKickPin2 = [0x1B, 0x70, 0x00, 0x19, 0xFA];

  static Future<List<int>> formatBytes({
    required OrderModel order,
    String storeName = 'Shadja Karangasem',
    String storeAddress = 'Jln Tunjung Bang, Bungaya Bebandem Karangasem',
    String storePhone = '082342233213',
    int paperWidth = 80,
  }) async {
    final profile = await CapabilityProfile.load();
    final paper = paperWidth == 58 ? PaperSize.mm58 : PaperSize.mm80;
    final generator = Generator(paper, profile);

    // Buka laci uang (cash drawer) segera saat mulai mencetak.
    final bytes = List<int>.from(_drawerKickPin2);

    bytes.addAll(_buildReceipt(
      generator: generator,
      order: order,
      storeName: storeName,
      storeAddress: storeAddress,
      storePhone: storePhone,
      paperWidth: paperWidth,
    ));

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
    final bodyFont = PosFontType.fontA;

    PosStyles bodyStyle() => PosStyles(fontType: bodyFont);
    PosStyles bodyRight() =>
        PosStyles(fontType: bodyFont, align: PosAlign.right);
    PosStyles centerStyle() =>
        PosStyles(fontType: bodyFont, align: PosAlign.center);
    PosStyles boldStyle() => PosStyles(fontType: bodyFont, bold: true);

    void add(List<int> b) => bytes.addAll(b);

    // Header
    add(generator.text(
      storeName,
      styles: const PosStyles(
        bold: true,
        align: PosAlign.center,
        height: PosTextSize.size2,
      ),
    ));
    if (storeAddress.isNotEmpty) {
      add(generator.text(storeAddress, styles: centerStyle()));
    }
    if (storePhone.isNotEmpty) {
      add(generator.text('Telp: $storePhone', styles: centerStyle()));
    }
    add(generator.hr());

    // Order info
    add(generator.row([
      PosColumn(
          text: 'No: ${order.orderNumber ?? order.id}',
          width: 6,
          styles: bodyStyle()),
      PosColumn(
          text:
              'Tgl: ${order.createdAt != null ? _dateStr(order.createdAt!) : '-'}',
          width: 6,
          styles: bodyRight()),
    ]));
    add(generator.text('Tipe: ${_orderTypeLabel(order.orderType)}',
        styles: bodyStyle()));
    if (order.restaurantTableNumber != null ||
        order.restaurantTableId != null) {
      add(generator.text(
        'Meja: ${order.restaurantTableNumber ?? order.restaurantTableId}',
        styles: bodyStyle(),
      ));
    }
    if (order.customerName != null) {
      add(generator.text('Pelanggan: ${order.customerName}',
          styles: bodyStyle()));
    }
    if (order.customerPhone != null) {
      add(generator.text('Telp: ${order.customerPhone}', styles: bodyStyle()));
    }
    if (order.deliveryAddress != null) {
      add(generator.text('Alamat: ${order.deliveryAddress}',
          styles: bodyStyle()));
    }
    add(generator.hr());

    // Items
    for (final item in order.orderItems) {
      add(generator.text(
        item.menuItemName,
        styles: bodyStyle(),
      ));
      add(generator.row([
        PosColumn(
            text: '${item.quantity}x${Formatters.rupiah(item.price)}',
            width: 7,
            styles: bodyStyle()),
        PosColumn(
            text: Formatters.rupiah(item.subtotal),
            width: 5,
            styles: bodyRight()),
      ]));
      if (item.notes != null && item.notes!.isNotEmpty) {
        add(generator.text(
          '  ^ ${item.notes}',
          styles: bodyStyle(),
        ));
      }
    }
    add(generator.hr());

    // Summary
    add(generator.row([
      PosColumn(text: 'Subtotal', width: 6, styles: bodyStyle()),
      PosColumn(
          text: Formatters.rupiah(order.subtotal),
          width: 6,
          styles: bodyRight()),
    ]));
    if (order.additionalCost > 0) {
      add(generator.row([
        PosColumn(
            text: _costLabel(order),
            width: 6,
            styles: bodyStyle()),
        PosColumn(
            text: '+ ${Formatters.rupiah(order.additionalCost)}',
            width: 6,
            styles: bodyRight()),
      ]));
    }
    if (order.discount > 0) {
      add(generator.row([
        PosColumn(text: 'Diskon', width: 6, styles: bodyStyle()),
        PosColumn(
            text: '- ${Formatters.rupiah(order.discount)}',
            width: 6,
            styles: bodyRight()),
      ]));
    }
    if (order.tax > 0) {
      add(generator.row([
        PosColumn(text: 'Pajak', width: 6, styles: bodyStyle()),
        PosColumn(
            text: '+ ${Formatters.rupiah(order.tax)}',
            width: 6,
            styles: bodyRight()),
      ]));
    }
    add(generator.text('=' * _maxChars(paperWidth),
        styles: boldStyle()));
    add(generator.row([
      PosColumn(
          text: 'TOTAL',
          width: 6,
          styles: PosStyles(fontType: bodyFont, bold: true, height: PosTextSize.size2)),
      PosColumn(
          text: Formatters.rupiah(order.total),
          width: 6,
          styles: PosStyles(
              fontType: bodyFont,
              bold: true,
              align: PosAlign.right,
              height: PosTextSize.size2)),
    ]));
    add(generator.text('=' * _maxChars(paperWidth),
        styles: boldStyle()));

    if (order.payments.isNotEmpty) {
      for (final p in order.payments) {
        add(generator.text(
            '${p.method.toUpperCase()}: ${Formatters.rupiah(p.amount)}',
            styles: bodyStyle()));
        if (p.cashReceived != null) {
          add(generator.text('Tunai diterima: ${Formatters.rupiah(p.cashReceived!)}',
              styles: bodyStyle()));
        }
        if (p.change != null && p.change! > 0) {
          add(generator.text('Kembalian: ${Formatters.rupiah(p.change!)}',
              styles: bodyStyle()));
        }
        if (p.reference != null) {
          add(generator.text('Ref: ${p.reference}', styles: bodyStyle()));
        }
      }
      add(generator.hr());
    }
    if (order.notes != null && order.notes!.isNotEmpty) {
      add(generator.text('Catatan: ${order.notes}', styles: bodyStyle()));
      add(generator.hr());
    }

    // Footer
    add(generator.feed(1));
    add(generator.text(
      'Terima kasih',
      styles: PosStyles(align: PosAlign.center, bold: true, fontType: bodyFont),
    ));
    add(generator.text(
      'Semoga harimu menyenangkan',
      styles: centerStyle(),
    ));
    add(generator.feed(2));

    return bytes;
  }

  static int _maxChars(int paperWidth) => paperWidth == 58 ? 32 : 48;

  static String _costLabel(OrderModel order) {
    final rate = order.additionalCostRate;
    String rateText = '';
    if (rate != null) {
      final d = rate.toDouble();
      rateText =
          d == d.roundToDouble() ? ' ${d.toInt()}%' : ' $d%';
    }
    return '${order.additionalCostName ?? 'Biaya Tambahan'}$rateText';
  }

  // --- Text formatter (debug only) ---
  static const _line80 =
      '----------------------------------------------------------------';
  static const _line58 =
      '------------------------------------------------';

  static String formatText({
    required OrderModel order,
    String storeName = 'Shadja Karangasem',
    String storeAddress = 'Jln Tunjung Bang, Bungaya Bebandem Karangasem',
    String storePhone = '082342233213',
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
        'Tgl: ${order.createdAt != null ? _dateStr(order.createdAt!) : '-'}');
    sb.writeln('Tipe: ${_orderTypeLabel(order.orderType)}');
    if (order.restaurantTableNumber != null ||
        order.restaurantTableId != null) {
      sb.writeln(
          'Meja: ${order.restaurantTableNumber ?? order.restaurantTableId}');
    }
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
    if (order.additionalCost > 0) {
      final label = _costLabel(order);
      final val = '+${Formatters.rupiah(order.additionalCost)}';
      sb.writeln('${label.padRight(width - val.length)}$val');
    }
    if (order.discount > 0) {
      sb.writeln(
          '${'Diskon'.padRight(width - Formatters.rupiah(order.discount).length)}-${Formatters.rupiah(order.discount)}');
    }
    if (order.tax > 0) {
      sb.writeln(
          '${'Pajak'.padRight(width - Formatters.rupiah(order.tax).length)}+${Formatters.rupiah(order.tax)}');
    }
    sb.writeln(line);
    final totalStr = Formatters.rupiah(order.total);
    sb.writeln('TOTAL$totalStr');
    sb.writeln(line);

    if (order.payments.isNotEmpty) {
      for (final p in order.payments) {
        sb.writeln(
            '${p.method.toUpperCase()}: ${Formatters.rupiah(p.amount)}');
        if (p.cashReceived != null) {
          sb.writeln('Tunai diterima: ${Formatters.rupiah(p.cashReceived!)}');
        }
        if (p.change != null && p.change! > 0) {
          sb.writeln('Kembalian: ${Formatters.rupiah(p.change!)}');
        }
        if (p.reference != null) sb.writeln('Ref: ${p.reference}');
      }
      sb.writeln(line);
    }
    if (order.notes != null && order.notes!.isNotEmpty) {
      sb.writeln('Catatan: ${order.notes}');
      sb.writeln(line);
    }

    center('Terima kasih');
    center('Semoga harimu menyenangkan');
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
    // created_at dari server berupa UTC; struk harus tampil di GMT+8.
    final t = dt.toUtc().add(_gmt8Offset);
    return '${t.day.toString().padLeft(2, '0')}/${t.month.toString().padLeft(2, '0')}/${t.year} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  static const _gmt8Offset = Duration(hours: 8);

  static String _orderTypeLabel(String type) {
    switch (type) {
      case 'dine-in':
        return 'Dine-in';
      case 'pickup':
        return 'Take Away';
      case 'delivery':
        return 'Delivery';
      default:
        return type;
    }
  }
}

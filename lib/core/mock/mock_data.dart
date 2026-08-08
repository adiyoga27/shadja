import 'package:shadja/features/menu/data/menu_model.dart';
import 'package:shadja/features/order/data/order_model.dart';
import 'package:shadja/features/reservation/data/reservation_model.dart';

/// Mock data untuk preview UI — dibuat terpisah dari repository
/// supaya gampang diswap ke API asli nanti.
class MockData {
  MockData._();

  static const _img = 'https://images.unsplash.com/photo-'
      '1546069901-ba9599a7e63c?w=400&q=80';

  static List<MenuCategoryModel> menuCategories() => [
        MenuCategoryModel(
          id: 1,
          name: 'Makanan',
          menuItems: [
            MenuItemModel(
                id: 1,
                name: 'Nasi Goreng Spesial',
                price: 25000,
                image: _img,
                description: 'Nasi goreng dengan telur, ayam, dan kerupuk.'),
            MenuItemModel(
                id: 2,
                name: 'Mie Goreng Jawa',
                price: 22000,
                image:
                    'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=400&q=80',
                description: 'Mie goreng ala Jawa, manis pedas.'),
            MenuItemModel(
                id: 3,
                name: 'Ayam Bakar Madu',
                price: 32000,
                image:
                    'https://images.unsplash.com/photo-1604908554007-1a1a9f1d49c4?w=400&q=80',
                description: 'Ayam bakar bumbu madu, juicy dan gurih.'),
            MenuItemModel(
                id: 4,
                name: 'Sate Ayam (10 tusuk)',
                price: 28000,
                image:
                    'https://images.unsplash.com/photo-1567337710282-06c5c0c45855?w=400&q=80',
                description: 'Sate ayam dengan bumbu kacang khas.'),
            MenuItemModel(
                id: 5,
                name: 'Gado-Gado',
                price: 18000,
                image:
                    'https://images.unsplash.com/photo-1565557623262-b51c2513a641?w=400&q=80',
                description: 'Sayuran rebus dengan saus kacang.'),
            MenuItemModel(
                id: 6,
                name: 'Rendang Daging',
                price: 38000,
                image:
                    'https://images.unsplash.com/photo-1601303854342-1a1d1d95c4b3?w=400&q=80',
                description: 'Daging sapi rendang bumbu Padang asli.'),
          ],
        ),
        MenuCategoryModel(
          id: 2,
          name: 'Minuman',
          menuItems: [
            MenuItemModel(
                id: 7,
                name: 'Es Teh Manis',
                price: 8000,
                image:
                    'https://images.unsplash.com/photo-1556679343-c7306c1976bc?w=400&q=80',
                description: 'Teh manis dingin segar.'),
            MenuItemModel(
                id: 8,
                name: 'Es Jeruk Peras',
                price: 12000,
                image:
                    'https://images.unsplash.com/photo-1600271886732-629e0def2cd7?w=400&q=80',
                description: 'Jeruk peras segar dengan es batu.'),
            MenuItemModel(
                id: 9,
                name: 'Kopi Susu',
                price: 15000,
                image:
                    'https://images.unsplash.com/photo-1461023058943-07fcbe9fc1a9?w=400&q=80',
                description: 'Kopi susu gula aren, hot atau ice.'),
            MenuItemModel(
                id: 10,
                name: 'Jus Alpukat',
                price: 18000,
                image:
                    'https://images.unsplash.com/photo-1525335140-842e1d8ecdd1?w=400&q=80',
                description: 'Jus alpukat dengan susu coklat.'),
          ],
        ),
        MenuCategoryModel(
          id: 3,
          name: 'Cemilan',
          menuItems: [
            MenuItemModel(
                id: 11,
                name: 'Pisang Goreng Keju',
                price: 15000,
                image:
                    'https://images.unsplash.com/photo-1581938165093-050aeb5ef218?w=400&q=80',
                description: 'Pisang goreng taburan keju dan coklat.'),
            MenuItemModel(
                id: 12,
                name: 'Kentang Goreng',
                price: 17000,
                image:
                    'https://images.unsplash.com/photo-1639024471283-0350ae8cdec2?w=400&q=80',
                description: 'French fries dengan saus tomat & mayones.'),
            MenuItemModel(
                id: 13,
                name: 'Roti Bakar',
                price: 14000,
                image:
                    'https://images.unsplash.com/photo-1509440159596-0c7531d80685?w=400&q=80',
                description: 'Roti bakar coklat keju.'),
            MenuItemModel(
                id: 14,
                name: 'Tahu Crispy',
                price: 12000,
                image:
                    'https://images.unsplash.com/photo-1565309033-8b16b95d04c3?w=400&q=80',
                description: 'Tahu crispy tepung, 8 pcs.'),
          ],
        ),
        MenuCategoryModel(
          id: 4,
          name: 'Paket Hemat',
          menuItems: [
            MenuItemModel(
                id: 15,
                name: 'Paket Nasi + Ayam + Es Teh',
                price: 35000,
                image:
                    'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=400&q=80',
                description: 'Nasi putih, ayam bakar, es teh manis.'),
            MenuItemModel(
                id: 16,
                name: 'Paket Sate + Lontong + Es Jeruk',
                price: 38000,
                image:
                    'https://images.unsplash.com/photo-1555939594-58e0e6c1e9d4?w=400&q=80',
                description: 'Sate ayam 10 tusuk, lontong, es jeruk.'),
            MenuItemModel(
                id: 17,
                name: 'Paket Rendang + Nasi + Teh',
                price: 42000,
                image:
                    'https://images.unsplash.com/photo-1540189549336-e6e99c4c3f6b?w=400&q=80',
                description: 'Rendang daging, nasi putih, es teh.'),
          ],
        ),
      ];

  static final List<OrderModel> _orders = [
    OrderModel(
      id: 1001,
      orderNumber: 'ORD-1001',
      orderType: 'dine-in',
      orderStatus: 'selesai',
      subtotal: 82000,
      discount: 5000,
      tax: 0,
      total: 77000,
      customerName: 'Budi Santoso',
      customerPhone: '08123456789',
      notes: 'Pedas banget ya',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      orderItems: [
        OrderItemModel(
            id: 1,
            menuItemId: 1,
            menuItemName: 'Nasi Goreng Spesial',
            price: 25000,
            quantity: 2,
            subtotal: 50000,
            notes: 'pedas'),
        OrderItemModel(
            id: 2,
            menuItemId: 9,
            menuItemName: 'Kopi Susu',
            price: 15000,
            quantity: 2,
            subtotal: 30000),
        OrderItemModel(
            id: 3,
            menuItemId: 15,
            menuItemName: 'Paket Nasi + Ayam + Es Teh',
            price: 35000,
            quantity: 1,
            subtotal: 35000),
      ],
      payments: [
        PaymentModel(
            id: 201,
            orderId: 1001,
            method: 'qris',
            amount: 77000,
            status: 'paid',
            reference: 'QRIS-7X9K')
      ],
    ),
    OrderModel(
      id: 1002,
      orderNumber: 'ORD-1002',
      orderType: 'delivery',
      orderStatus: 'diproses',
      subtotal: 64000,
      discount: 0,
      tax: 0,
      total: 64000,
      customerName: 'Siti Rahma',
      customerPhone: '08129876543',
      deliveryAddress: 'Jl. Melati No. 5, Bekasi',
      createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
      orderItems: [
        OrderItemModel(
            id: 4,
            menuItemId: 6,
            menuItemName: 'Rendang Daging',
            price: 38000,
            quantity: 1,
            subtotal: 38000),
        OrderItemModel(
            id: 5,
            menuItemId: 10,
            menuItemName: 'Jus Alpukat',
            price: 18000,
            quantity: 1,
            subtotal: 18000),
        OrderItemModel(
            id: 6,
            menuItemId: 2,
            menuItemName: 'Mie Goreng Jawa',
            price: 22000,
            quantity: 1,
            subtotal: 22000),
      ],
      payments: [
        PaymentModel(
            id: 202,
            orderId: 1002,
            method: 'cash',
            amount: 64000,
            status: 'paid')
      ],
    ),
    OrderModel(
      id: 1003,
      orderNumber: 'ORD-1003',
      orderType: 'pickup',
      orderStatus: 'baru',
      subtotal: 38000,
      discount: 0,
      tax: 0,
      total: 38000,
      customerName: 'Andi Wijaya',
      customerPhone: '08131111222',
      createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
      orderItems: [
        OrderItemModel(
            id: 7,
            menuItemId: 16,
            menuItemName: 'Paket Sate + Lontong + Es Jeruk',
            price: 38000,
            quantity: 1,
            subtotal: 38000),
      ],
      payments: [],
    ),
  ];

  static List<OrderModel> orders() => List.from(_orders);

  static List<RestaurantTableModel> tables() => [
        RestaurantTableModel(id: 1, tableNumber: 'A1', capacity: 4),
        RestaurantTableModel(id: 2, tableNumber: 'A2', capacity: 2),
        RestaurantTableModel(id: 3, tableNumber: 'A3', capacity: 4),
        RestaurantTableModel(id: 4, tableNumber: 'B1', capacity: 6),
        RestaurantTableModel(id: 5, tableNumber: 'B2', capacity: 8),
        RestaurantTableModel(id: 6, tableNumber: 'VIP-1', capacity: 10),
      ];

  static List<ReservationModel> reservations() => [
        ReservationModel(
          id: 1,
          restaurantTableId: 1,
          reservationTime: DateTime.now().add(const Duration(hours: 2)),
          guestCount: 4,
          status: 'confirmed',
          notes: 'Ulang tahun',
          restaurantTable: tables()[0],
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
        ReservationModel(
          id: 2,
          restaurantTableId: 5,
          reservationTime: DateTime.now().add(const Duration(days: 1, hours: 3)),
          guestCount: 7,
          status: 'pending',
          notes: 'Meeting keluarga',
          restaurantTable: tables()[4],
          createdAt: DateTime.now().subtract(const Duration(hours: 5)),
        ),
        ReservationModel(
          id: 3,
          restaurantTableId: 6,
          reservationTime:
              DateTime.now().subtract(const Duration(hours: 10)),
          guestCount: 10,
          status: 'selesai',
          notes: '',
          restaurantTable: tables()[5],
          createdAt: DateTime.now().subtract(const Duration(days: 2)),
        ),
      ];
}
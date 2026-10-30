import 'package:flutter/material.dart';

enum OrderStatus {
  requested('requested', 'Solicitado'),
  preparing('preparing', 'En preparación'),
  ready('ready', 'Listo'),
  delivered('delivered', 'Entregado'),
  rejected('rejected', 'Rechazado');

  const OrderStatus(this.id, this.label);

  /// Value stored in the database.
  final String id;

  /// Spanish display label.
  final String label;

  static OrderStatus fromId(String id) {
    for (final OrderStatus status in values) {
      if (status.id == id) return status;
    }
    return OrderStatus.requested;
  }

  /// Filled-chip background. Fixed semantic palette (not theme colors)
  /// so a status can never blend with buttons or brand elements:
  /// amber = new, blue = in progress, green = ready, slate = closed,
  /// red = rejected.
  Color color(ColorScheme scheme) {
    switch (this) {
      case OrderStatus.requested:
        return const Color(0xFFF59E0B);
      case OrderStatus.preparing:
        return const Color(0xFF2563EB);
      case OrderStatus.ready:
        return const Color(0xFF16A34A);
      case OrderStatus.delivered:
        return const Color(0xFF64748B);
      case OrderStatus.rejected:
        return const Color(0xFFDC2626);
    }
  }

  /// Text color that stays readable on top of [color].
  Color onColor(ColorScheme scheme) => color(scheme).computeLuminance() > 0.45
      ? const Color(0xFF1A1A1A)
      : Colors.white;

  /// Statuses this order may move to.
  List<OrderStatus> get nextOptions {
    switch (this) {
      case OrderStatus.requested:
        return const <OrderStatus>[
          OrderStatus.preparing,
          OrderStatus.ready,
          OrderStatus.rejected,
        ];
      case OrderStatus.preparing:
        return const <OrderStatus>[OrderStatus.ready, OrderStatus.rejected];
      case OrderStatus.ready:
        return const <OrderStatus>[OrderStatus.delivered, OrderStatus.rejected];
      case OrderStatus.delivered:
      case OrderStatus.rejected:
        return const <OrderStatus>[];
    }
  }

  bool get isFinal =>
      this == OrderStatus.delivered || this == OrderStatus.rejected;
}

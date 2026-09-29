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

  Color color(ColorScheme scheme) {
    switch (this) {
      case OrderStatus.requested:
        return scheme.primary;
      case OrderStatus.preparing:
        return scheme.tertiary;
      case OrderStatus.ready:
        return const Color(0xFF2E7D32);
      case OrderStatus.delivered:
        return scheme.onSurfaceVariant;
      case OrderStatus.rejected:
        return scheme.error;
    }
  }

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
        return const <OrderStatus>[
          OrderStatus.ready,
          OrderStatus.rejected,
        ];
      case OrderStatus.ready:
        return const <OrderStatus>[
          OrderStatus.delivered,
          OrderStatus.rejected,
        ];
      case OrderStatus.delivered:
      case OrderStatus.rejected:
        return const <OrderStatus>[];
    }
  }

  bool get isFinal =>
      this == OrderStatus.delivered || this == OrderStatus.rejected;
}

import 'dart:typed_data';

import 'package:all_commerce/core/utils/formatters.dart';
import 'package:all_commerce/features/orders/data/models/order_item_model.dart';
import 'package:all_commerce/features/orders/data/models/order_model.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Builds a shareable A4 PDF ticket for an order (owner side).
/// Uses the built-in Helvetica font: Spanish accents and '$' are in
/// Latin-1 so no font asset is needed.
Future<Uint8List> buildOrderTicketPdf({
  required OrderModel order,
  required List<OrderItemModel> items,
  required String tenantName,
  String? primaryColorHex,
}) async {
  final PdfColor brand =
      _parseHex(primaryColorHex) ?? const PdfColor.fromInt(0xFF0052FF);
  final double luminance =
      0.299 * brand.red + 0.587 * brand.green + 0.114 * brand.blue;
  final PdfColor onBrand = luminance > 0.6 ? _ink : PdfColors.white;
  final PdfColor brandSoft = _mix(brand, PdfColors.white, 0.92);
  const PdfColor muted = PdfColor.fromInt(0xFF6B7280);
  const PdfColor line = PdfColor.fromInt(0xFFE5E7EB);
  const PdfColor success = PdfColor.fromInt(0xFF16A34A);

  final pw.Document doc = pw.Document();
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: <pw.Widget>[
            // ── Header band: tenant brand color ──────────────────────
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 18,
              ),
              decoration: pw.BoxDecoration(
                color: brand,
                borderRadius: pw.BorderRadius.circular(14),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: <pw.Widget>[
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: <pw.Widget>[
                        pw.Text(
                          tenantName.isEmpty ? 'AllCommerce' : tenantName,
                          style: pw.TextStyle(
                            fontSize: 21,
                            fontWeight: pw.FontWeight.bold,
                            color: onBrand,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Comprobante de pedido',
                          style: pw.TextStyle(
                            fontSize: 10.5,
                            color: _mix(onBrand, brand, 0.25),
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: <pw.Widget>[
                      pw.Text(
                        'PEDIDO #${order.orderNumber}',
                        style: pw.TextStyle(
                          fontSize: 15,
                          fontWeight: pw.FontWeight.bold,
                          color: onBrand,
                        ),
                      ),
                      pw.Text(
                        Formatters.dateTime(order.createdAt),
                        style: pw.TextStyle(
                          fontSize: 9.5,
                          color: _mix(onBrand, brand, 0.25),
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: pw.BoxDecoration(
                          color: onBrand,
                          borderRadius: pw.BorderRadius.circular(999),
                        ),
                        child: pw.Text(
                          order.status.label.toUpperCase(),
                          style: pw.TextStyle(
                            fontSize: 8.5,
                            fontWeight: pw.FontWeight.bold,
                            color: brand,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),
            // ── Cliente ─────────────────────────────────────────────
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: line),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: <pw.Widget>[
                  _sectionTitle('CLIENTE', brand),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    order.customerNameSnapshot,
                    style: const pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                      color: _ink,
                    ),
                  ),
                  pw.Text(
                    order.customerPhoneSnapshot,
                    style: const pw.TextStyle(fontSize: 11, color: muted),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),
            // ── Ítems ───────────────────────────────────────────────
            pw.Table(
              columnWidths: const <int, pw.TableColumnWidth>{
                0: pw.FixedColumnWidth(44),
                1: pw.FlexColumnWidth(),
                2: pw.FixedColumnWidth(80),
                3: pw.FixedColumnWidth(80),
              },
              children: <pw.TableRow>[
                pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: brandSoft,
                    borderRadius: const pw.BorderRadius.vertical(
                      top: pw.Radius.circular(6),
                    ),
                  ),
                  children: <pw.Widget>[
                    _cellHeader('Cant.', brand),
                    _cellHeader('Ítem', brand),
                    _cellHeader('Precio', brand, alignEnd: true),
                    _cellHeader('Total', brand, alignEnd: true),
                  ],
                ),
                for (final OrderItemModel item in items)
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(bottom: pw.BorderSide(color: line)),
                    ),
                    children: <pw.Widget>[
                      _cell(Formatters.qtyLabel(item.quantity, item.unit)),
                      _cell(
                        item.variant == null
                            ? item.titleSnapshot
                            : '${item.titleSnapshot} (${item.variant})',
                      ),
                      _cell(Formatters.price(item.unitPrice), alignEnd: true),
                      _cell(Formatters.price(item.lineTotal), alignEnd: true),
                    ],
                  ),
              ],
            ),
            pw.SizedBox(height: 14),
            // ── Resumen ─────────────────────────────────────────────
            pw.Row(
              children: <pw.Widget>[
                pw.Expanded(child: pw.SizedBox()),
                pw.SizedBox(
                  width: 250,
                  child: pw.Column(
                    children: <pw.Widget>[
                      _summaryRow('Subtotal', Formatters.price(order.subtotal)),
                      for (final (String label, double amount)
                          in _discountEntries(order))
                        _summaryRow(
                          label,
                          '-${Formatters.price(amount)}',
                          valueColor: success,
                        ),
                      if (order.deliveryCost > 0)
                        _summaryRow(
                          'Envío',
                          Formatters.price(order.deliveryCost),
                        ),
                      pw.SizedBox(height: 6),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        decoration: pw.BoxDecoration(
                          color: brandSoft,
                          borderRadius: pw.BorderRadius.circular(8),
                        ),
                        child: pw.Row(
                          children: <pw.Widget>[
                            pw.Expanded(
                              child: pw.Text(
                                'Total',
                                style: const pw.TextStyle(
                                  fontSize: 15,
                                  fontWeight: pw.FontWeight.bold,
                                  color: _ink,
                                ),
                              ),
                            ),
                            pw.Text(
                              Formatters.price(order.total),
                              style: pw.TextStyle(
                                fontSize: 15,
                                fontWeight: pw.FontWeight.bold,
                                color: brand,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 16),
            // ── Entrega y pago ──────────────────────────────────────
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: const PdfColor.fromInt(0xFFF9FAFB),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: <pw.Widget>[
                  _sectionTitle('ENTREGA Y PAGO', brand),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    'Entrega: ${order.deliveryMethod.label}'
                    '${order.deliveryAddress != null && order.deliveryAddress!.trim().isNotEmpty ? ' · ${order.deliveryAddress!.trim()}' : ''}',
                    style: const pw.TextStyle(fontSize: 11, color: _ink),
                  ),
                  pw.Text(
                    'Pago: ${order.paymentMethod.label}',
                    style: const pw.TextStyle(fontSize: 11, color: _ink),
                  ),
                  if (order.paymentNotes != null &&
                      order.paymentNotes!.trim().isNotEmpty)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 4),
                      child: pw.Text(
                        order.paymentNotes!,
                        style: const pw.TextStyle(fontSize: 10, color: muted),
                      ),
                    ),
                  if (order.notes != null && order.notes!.trim().isNotEmpty)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 4),
                      child: pw.Text(
                        'Notas: ${order.notes!}',
                        style: const pw.TextStyle(fontSize: 10, color: muted),
                      ),
                    ),
                ],
              ),
            ),
            pw.Spacer(),
            pw.Center(
              child: pw.Text(
                'Generado con AllCommerce',
                style: const pw.TextStyle(fontSize: 9, color: muted),
              ),
            ),
          ],
        );
      },
    ),
  );
  return doc.save();
}

const PdfColor _ink = PdfColor.fromInt(0xFF111827);

/// Discount lines, same labels as [OrderCostRows] in the app.
List<(String, double)> _discountEntries(OrderModel order) {
  final List<(String, double)> entries = <(String, double)>[
    if (order.couponDiscount > 0)
      (
        order.couponCode == null ? 'Cupón' : 'Cupón (${order.couponCode})',
        order.couponDiscount,
      ),
    if (order.bulkDiscount > 0)
      (
        'Descuento por volumen (${order.bulkDiscountPct.round()}%)',
        order.bulkDiscount,
      ),
    if (order.paymentDiscount > 0)
      (
        'Descuento por pago (${order.paymentMethod.label} · '
            '${order.paymentDiscountPct.round()}%)',
        order.paymentDiscount,
      ),
  ];
  if (entries.isEmpty && order.discount > 0) {
    entries.add(('Descuento', order.discount));
  }
  return entries;
}

PdfColor? _parseHex(String? hex) {
  if (hex == null) return null;
  final String h = hex.replaceFirst('#', '');
  final int? v = int.tryParse(h, radix: 16);
  if (v == null || h.length != 6) return null;
  return PdfColor.fromInt(0xFF000000 | v);
}

PdfColor _mix(PdfColor a, PdfColor b, double t) {
  return PdfColor(
    a.red * (1 - t) + b.red * t,
    a.green * (1 - t) + b.green * t,
    a.blue * (1 - t) + b.blue * t,
  );
}

pw.Widget _sectionTitle(String text, PdfColor brand) {
  return pw.Text(
    text,
    style: pw.TextStyle(
      fontSize: 9,
      fontWeight: pw.FontWeight.bold,
      color: brand,
      letterSpacing: 1,
    ),
  );
}

pw.Widget _cellHeader(String text, PdfColor brand, {bool alignEnd = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
    child: pw.Align(
      alignment: alignEnd ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
          color: brand,
          letterSpacing: 0.5,
        ),
      ),
    ),
  );
}

pw.Widget _cell(String text, {bool alignEnd = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
    child: pw.Align(
      alignment: alignEnd ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
      child: pw.Text(
        text,
        style: const pw.TextStyle(fontSize: 11, color: _ink),
      ),
    ),
  );
}

pw.Widget _summaryRow(String label, String value, {PdfColor? valueColor}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Row(
      children: <pw.Widget>[
        pw.Expanded(
          child: pw.Text(
            label,
            style: const pw.TextStyle(
              fontSize: 10,
              color: PdfColor.fromInt(0xFF6B7280),
            ),
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 10, color: valueColor ?? _ink),
        ),
      ],
    ),
  );
}

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
}) async {
  const PdfColor brand = PdfColor.fromInt(0xFF0052FF);
  const PdfColor muted = PdfColor.fromInt(0xFF6B7280);
  const PdfColor line = PdfColor.fromInt(0xFFE5E7EB);

  final pw.Document doc = pw.Document();
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: <pw.Widget>[
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: <pw.Widget>[
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: <pw.Widget>[
                      pw.Text(
                        tenantName.isEmpty ? 'AllCommerce' : tenantName,
                        style: const pw.TextStyle(
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                          color: brand,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Comprobante de pedido',
                        style: const pw.TextStyle(
                          fontSize: 11,
                          color: muted,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: <pw.Widget>[
                    pw.Text(
                      'Pedido #${order.orderNumber}',
                      style: const pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      Formatters.dateTime(order.createdAt),
                      style: const pw.TextStyle(fontSize: 11, color: muted),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      order.status.label.toUpperCase(),
                      style: const pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: muted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 18),
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
                  pw.Text(
                    'CLIENTE',
                    style: const pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: muted,
                      letterSpacing: 1,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    order.customerNameSnapshot,
                    style: const pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    order.customerPhoneSnapshot,
                    style: const pw.TextStyle(fontSize: 11, color: muted),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 18),
            pw.Table(
              columnWidths: const <int, pw.TableColumnWidth>{
                0: pw.FixedColumnWidth(44),
                1: pw.FlexColumnWidth(),
                2: pw.FixedColumnWidth(80),
                3: pw.FixedColumnWidth(80),
              },
              children: <pw.TableRow>[
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: line)),
                  ),
                  children: <pw.Widget>[
                    _cellHeader('Cant.'),
                    _cellHeader('Ítem'),
                    _cellHeader('Precio', alignEnd: true),
                    _cellHeader('Total', alignEnd: true),
                  ],
                ),
                for (final OrderItemModel item in items)
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(bottom: pw.BorderSide(color: line)),
                    ),
                    children: <pw.Widget>[
                      _cell('${item.quantity}x'),
                      _cell(item.titleSnapshot),
                      _cell(
                        Formatters.price(item.unitPrice),
                        alignEnd: true,
                      ),
                      _cell(
                        Formatters.price(item.lineTotal),
                        alignEnd: true,
                      ),
                    ],
                  ),
              ],
            ),
            pw.SizedBox(height: 14),
            pw.Row(
              children: <pw.Widget>[
                pw.Expanded(child: pw.SizedBox()),
                pw.SizedBox(
                  width: 240,
                  child: pw.Column(
                    children: <pw.Widget>[
                      _summaryRow('Subtotal', Formatters.price(order.subtotal)),
                      if (order.discount > 0)
                        _summaryRow(
                          'Descuento',
                          '-${Formatters.price(order.discount)}',
                        ),
                      if (order.deliveryCost > 0)
                        _summaryRow(
                          'Envío',
                          Formatters.price(order.deliveryCost),
                        ),
                      pw.SizedBox(height: 4),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(vertical: 8),
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(
                            top: pw.BorderSide(color: brand, width: 1.5),
                          ),
                        ),
                        child: pw.Row(
                          children: <pw.Widget>[
                            pw.Expanded(
                              child: pw.Text(
                                'Total',
                                style: const pw.TextStyle(
                                  fontSize: 14,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ),
                            pw.Text(
                              Formatters.price(order.total),
                              style: const pw.TextStyle(
                                fontSize: 14,
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
                  pw.Text(
                    'ENTREGA Y PAGO',
                    style: const pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: muted,
                      letterSpacing: 1,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    'Entrega: ${order.deliveryMethod.label}'
                    '${order.deliveryAddress != null && order.deliveryAddress!.trim().isNotEmpty ? ' · ${order.deliveryAddress!.trim()}' : ''}',
                    style: const pw.TextStyle(fontSize: 11),
                  ),
                  pw.Text(
                    'Pago: ${order.paymentMethod.label}',
                    style: const pw.TextStyle(fontSize: 11),
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
                  if (order.notes != null &&
                      order.notes!.trim().isNotEmpty)
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

pw.Widget _cellHeader(String text, {bool alignEnd = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 6),
    child: pw.Align(
      alignment: alignEnd ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
      child: pw.Text(
        text,
        style: const pw.TextStyle(
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
          color: PdfColor.fromInt(0xFF6B7280),
          letterSpacing: 0.5,
        ),
      ),
    ),
  );
}

pw.Widget _cell(String text, {bool alignEnd = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 6),
    child: pw.Align(
      alignment: alignEnd ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 11)),
    ),
  );
}

pw.Widget _summaryRow(String label, String value) {
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
        pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
      ],
    ),
  );
}

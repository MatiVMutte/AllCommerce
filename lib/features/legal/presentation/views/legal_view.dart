import 'package:all_commerce/core/theme/app_tokens.dart';
import 'package:all_commerce/core/widgets/app_back_button.dart';
import 'package:flutter/material.dart';

class TermsView extends StatelessWidget {
  const TermsView({super.key});

  @override
  Widget build(BuildContext context) {
    return const _LegalDocumentScaffold(
      title: 'Términos y condiciones',
      updatedAt: 'Octubre 2026',
      sections: <_LegalSection>[
        _LegalSection(
          heading: '1. Qué es AllCommerce',
          body:
              'AllCommerce es una plataforma tecnológica que permite a comercios '
              'mayoristas y minoristas publicar su catálogo digital con asistencia '
              'de inteligencia artificial y recibir pedidos de clientes a través '
              'de la aplicación y WhatsApp.',
        ),
        _LegalSection(
          heading: '2. Rol de la plataforma',
          body:
              'AllCommerce actúa exclusivamente como herramienta tecnológica de '
              'catálogo y canalización de pedidos. Cada comercio es el único '
              'responsable por la veracidad de los productos publicados, precios, '
              'stock, facturación, cobro, entrega y atención posventa. '
              'AllCommerce no procesa pagos entre compradores y comercios ni '
              'interviene en la entrega de mercadería.',
        ),
        _LegalSection(
          heading: '3. Cuentas de usuario y comercios',
          body:
              'Para realizar pedidos o administrar un comercio debés registrarte '
              'con datos reales y mantener la confidencialidad de tu contraseña. '
              'Queda prohibido publicar productos ilegales, falsificados o que '
              'infrinjan derechos de terceros. AllCommerce podrá suspender o '
              'dar de baja locales que incumplan estas reglas.',
        ),
        _LegalSection(
          heading: '4. Planes y uso de inteligencia artificial',
          body:
              'AllCommerce ofrece un plan gratuito con límite de productos y '
              'planes pagos con mayor capacidad de catálogo y análisis por IA. '
              'Las sugerencias generadas por IA (título, descripción, categoría) '
              'son orientativas y deben ser revisadas por el titular del comercio '
              'antes de su publicación.',
        ),
        _LegalSection(
          heading: '5. Baja de cuenta',
          body:
              'Podés eliminar tu cuenta en cualquier momento desde la sección '
              'Perfil → Eliminar mi cuenta. Si sos titular de un comercio, '
              'la baja eliminará también tu catálogo y productos publicados.',
        ),
      ],
    );
  }
}

class PrivacyView extends StatelessWidget {
  const PrivacyView({super.key});

  @override
  Widget build(BuildContext context) {
    return const _LegalDocumentScaffold(
      title: 'Política de privacidad',
      updatedAt: 'Octubre 2026',
      sections: <_LegalSection>[
        _LegalSection(
          heading: '1. Datos que recopilamos',
          body:
              'Recopilamos únicamente los datos necesarios para operar la '
              'plataforma: email, nombre, número de WhatsApp/teléfono, datos '
              'públicos del comercio (nombre, dirección, horarios, fotos de '
              'productos) y el detalle de los pedidos realizados.',
        ),
        _LegalSection(
          heading: '2. Para qué usamos tus datos',
          body:
              'Usamos tus datos para: (a) autenticarte en la aplicación, '
              '(b) compartir tu nombre, teléfono y dirección de entrega con el '
              'comercio al que le hacés un pedido, (c) enviar notificaciones '
              'push sobre el estado de tus pedidos o nuevos pedidos recibidos, '
              'y (d) analizar imágenes de productos mediante Google Gemini '
              'cuando el comercio utiliza la carga asistida por IA.',
        ),
        _LegalSection(
          heading: '3. Almacenamiento y seguridad',
          body:
              'Los datos se almacenan en servidores seguros provistos por '
              'Supabase con control de acceso por fila (Row-Level Security) y '
              'conexiones cifradas (HTTPS/TLS). No vendemos ni alquilamos tus '
              'datos personales a terceros.',
        ),
        _LegalSection(
          heading: '4. Conservación y eliminación de datos',
          body:
              'Podés eliminar tu cuenta y tus datos personales directamente '
              'desde Perfil → Eliminar mi cuenta dentro de la aplicación, sin '
              'necesidad de trámites externos.',
        ),
      ],
    );
  }
}

class _LegalSection {
  const _LegalSection({required this.heading, required this.body});

  final String heading;
  final String body;
}

class _LegalDocumentScaffold extends StatelessWidget {
  const _LegalDocumentScaffold({
    required this.title,
    required this.updatedAt,
    required this.sections,
  });

  final String title;
  final String updatedAt;
  final List<_LegalSection> sections;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallback: '/profile'),
        title: Text(title),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
              children: <Widget>[
                Text(
                  'Última actualización: $updatedAt',
                  style: TextStyle(fontSize: 13, color: tokens.textTertiary),
                ),
                const SizedBox(height: 16),
                for (final _LegalSection section in sections) ...<Widget>[
                  Text(
                    section.heading,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: tokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    section.body,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: tokens.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

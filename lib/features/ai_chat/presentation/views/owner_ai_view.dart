import 'dart:typed_data';

import 'package:all_commerce/core/theme/app_brand.dart';
import 'package:all_commerce/core/theme/app_tokens.dart';
import 'package:all_commerce/core/utils/app_haptics.dart';
import 'package:all_commerce/core/widgets/adaptive_nav_shell.dart';
import 'package:all_commerce/core/widgets/app_card.dart';
import 'package:all_commerce/core/widgets/app_snackbar.dart';
import 'package:all_commerce/features/ai_chat/data/models/ai_chat_message.dart';
import 'package:all_commerce/features/ai_chat/presentation/view_models/ai_chat_controller.dart';
import 'package:all_commerce/features/auth/data/models/user_model.dart';
import 'package:all_commerce/features/auth/presentation/view_models/auth_providers.dart';
import 'package:all_commerce/features/product_upload/data/services/image_service.dart';
import 'package:all_commerce/features/product_upload/presentation/view_models/product_upload_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// Owner tab: chat with the store's AI. The model reads everything, writes
/// nothing — write intents arrive as proposal cards the owner confirms.
class OwnerAiView extends ConsumerStatefulWidget {
  const OwnerAiView({super.key});

  @override
  ConsumerState<OwnerAiView> createState() => _OwnerAiViewState();
}

class _OwnerAiViewState extends ConsumerState<OwnerAiView> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  Uint8List? _attachedImage;
  bool _attaching = false;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _attach() async {
    setState(() => _attaching = true);
    try {
      final PickedImage? picked = await ref
          .read(imageServiceProvider)
          .pick(ImageSource.gallery);
      if (picked == null) return;
      final Uint8List jpeg = await ref
          .read(imageServiceProvider)
          .compress(picked.bytes);
      if (mounted) setState(() => _attachedImage = jpeg);
    } finally {
      if (mounted) setState(() => _attaching = false);
    }
  }

  Future<void> _send() async {
    final String text = _input.text;
    final Uint8List? image = _attachedImage;
    if (text.trim().isEmpty && image == null) return;
    _input.clear();
    setState(() => _attachedImage = null);
    AppHaptics.light();
    await ref
        .read(aiChatControllerProvider.notifier)
        .send(text, imageBytes: image);
    _jumpToBottom();
  }

  void _jumpToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final AiChatState state = ref.watch(aiChatControllerProvider);
    final String? tenantId = ref.watch(currentProfileProvider).value?.tenantId;
    final bool wide = AdaptiveNavShell.isWide(context);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780),
            child: Column(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: tokens.border)),
                  ),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          gradient: AppBrand.gradient(scheme.primary),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.auto_awesome,
                          size: 20,
                          color: scheme.onPrimary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Asistente IA',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              'Propone cambios · vos confirmás antes de publicar',
                              style: TextStyle(
                                fontSize: 12,
                                color: tokens.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (state.quota?.limit != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: tokens.surfaceMuted,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${state.quota!.used}/${state.quota!.limit} usos',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: tokens.textSecondary,
                            ),
                          ),
                        ),
                      if (state.messages.isNotEmpty) ...<Widget>[
                        const SizedBox(width: 4),
                        IconButton(
                          tooltip: 'Nueva conversación',
                          icon: const Icon(Icons.refresh_rounded, size: 20),
                          onPressed: () => ref
                              .read(aiChatControllerProvider.notifier)
                              .clear(),
                        ),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: state.messages.isEmpty
                      ? _EmptyState(
                          onAttachPhoto: _attaching ? null : _attach,
                          onPrompt: (String p) {
                            _input.text = p;
                            _send();
                          },
                        )
                      : ListView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                          itemCount:
                              state.messages.length + (state.sending ? 1 : 0),
                          itemBuilder: (BuildContext context, int i) {
                            if (i == state.messages.length) {
                              return const _TypingBubble();
                            }
                            final AiChatMessage m = state.messages[i];
                            return _Bubble(
                              message: m,
                              tenantId: tenantId,
                              onConfirm: (AiAction a) => _confirm(m, a),
                              onDismiss: (AiAction a) => ref
                                  .read(aiChatControllerProvider.notifier)
                                  .dismiss(a),
                            );
                          },
                        ),
                ),
                if (_attachedImage != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Stack(
                        children: <Widget>[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(
                              _attachedImage!,
                              width: 68,
                              height: 68,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 3,
                            right: 3,
                            child: InkWell(
                              onTap: () =>
                                  setState(() => _attachedImage = null),
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(3),
                                child: const Icon(
                                  Icons.close,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    6,
                    16,
                    // Scaffold already injects the FloatingNavBar height into
                    // padding.bottom — only add a small gap on top of it.
                    wide ? 16 : MediaQuery.of(context).padding.bottom + 10,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: tokens.surface,
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: tokens.border),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                          color: Colors.black.withValues(alpha: 0.04),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        IconButton(
                          tooltip: 'Adjuntar foto de producto',
                          onPressed: _attaching || state.sending
                              ? null
                              : _attach,
                          icon: _attaching
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  Icons.add_photo_alternate_outlined,
                                  color: tokens.textSecondary,
                                ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _input,
                            minLines: 1,
                            maxLines: 4,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _send(),
                            decoration: const InputDecoration(
                              hintText: 'Mandá una foto o pedime un cambio…',
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              filled: false,
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 10,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2, right: 2),
                          child: IconButton.filled(
                            tooltip: 'Enviar',
                            style: IconButton.styleFrom(
                              backgroundColor: scheme.primary,
                              foregroundColor: scheme.onPrimary,
                              disabledBackgroundColor: tokens.surfaceMuted,
                              minimumSize: const Size(40, 40),
                            ),
                            onPressed: state.sending ? null : _send,
                            icon: const Icon(
                              Icons.arrow_upward_rounded,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirm(AiChatMessage message, AiAction action) async {
    final UserModel? profile = ref.read(currentProfileProvider).value;
    final String? tenantId = profile?.tenantId;
    if (tenantId == null) return;
    try {
      final String done = await ref
          .read(aiChatControllerProvider.notifier)
          .confirm(message, action, tenantId);
      if (!mounted) return;
      AppHaptics.success();
      showAppSnackBar(context, done, clearNavBar: false);
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        'No se pudo aplicar el cambio',
        isError: true,
        clearNavBar: false,
      );
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onPrompt, this.onAttachPhoto});

  final ValueChanged<String> onPrompt;
  final VoidCallback? onAttachPhoto;

  static const List<(IconData, String, String)> _prompts =
      <(IconData, String, String)>[
        (
          Icons.trending_up_rounded,
          '¿Cómo van las ventas este mes?',
          'Resumen de pedidos y facturación del mes',
        ),
        (
          Icons.inventory_2_outlined,
          '¿Qué productos tengo sin stock?',
          'Revisar faltantes o stock bajo',
        ),
        (
          Icons.percent_rounded,
          'Subí todos los precios un 10%',
          'Ajuste masivo con confirmación previa',
        ),
        (
          Icons.receipt_long_outlined,
          'Mostrame mis últimos pedidos',
          'Listado rápido de actividad reciente',
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      children: <Widget>[
        Center(
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: AppBrand.gradient(scheme.primary),
              borderRadius: BorderRadius.circular(20),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.28),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(Icons.auto_awesome, size: 28, color: scheme.onPrimary),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          '¿En qué te ayudo hoy?',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: tokens.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Mandame la foto de un producto y te lo dejo listo para publicar, '
          'o pedime cambios de stock, precios y ofertas.',
          textAlign: TextAlign.center,
          style: TextStyle(color: tokens.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 18),
        if (onAttachPhoto != null) ...<Widget>[
          AppCard(
            onTap: onAttachPhoto,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.add_a_photo_outlined,
                    size: 20,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Subir producto desde una foto',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: tokens.textPrimary,
                        ),
                      ),
                      Text(
                        'Detecto nombre, descripción, categoría y precio sugerido',
                        style: TextStyle(
                          fontSize: 12,
                          color: tokens.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: tokens.textTertiary),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        for (final (IconData icon, String title, String subtitle) in _prompts)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              onTap: () => onPrompt(title),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(
                children: <Widget>[
                  Icon(icon, size: 20, color: scheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: tokens.textPrimary,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: tokens.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.north_west_rounded,
                    size: 16,
                    color: tokens.textTertiary,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.tenantId,
    required this.onConfirm,
    required this.onDismiss,
  });

  final AiChatMessage message;
  final String? tenantId;
  final void Function(AiAction) onConfirm;
  final void Function(AiAction) onDismiss;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool user = message.isUser;
    final Color textColor = message.isError
        ? tokens.danger
        : user
        ? scheme.onPrimary
        : tokens.textPrimary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: user
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          if (!user) ...<Widget>[
            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(right: 8, bottom: 2),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.auto_awesome, size: 15, color: scheme.primary),
            ),
          ],
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: message.isError
                      ? tokens.danger.withValues(alpha: 0.1)
                      : user
                      ? scheme.primary
                      : tokens.surface,
                  border: user || message.isError
                      ? null
                      : Border.all(color: tokens.border),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(user ? 18 : 4),
                    bottomRight: Radius.circular(user ? 4 : 18),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (message.imageBytes != null) ...<Widget>[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.memory(
                          message.imageBytes!,
                          width: 150,
                          height: 150,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (message.text.isNotEmpty)
                      user
                          ? Text(
                              message.text,
                              style: TextStyle(
                                fontSize: 15,
                                height: 1.38,
                                color: textColor,
                              ),
                            )
                          : _FormattedAiText(
                              text: message.text,
                              color: textColor,
                            ),
                    if (message.actions.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 8),
                      for (final AiAction a in message.actions)
                        _ActionCard(
                          action: a,
                          enabled: tenantId != null,
                          onConfirm: () => onConfirm(a),
                          onDismiss: () => onDismiss(a),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Renders light Markdown returned by Gemini (`**bold**`, `*italic*`,
/// `# headings`, and `-`/`*` bullet lines) into clean [RichText] so raw
/// asterisks never leak onto the screen.
class _FormattedAiText extends StatelessWidget {
  const _FormattedAiText({required this.text, required this.color});

  final String text;
  final Color color;

  static final RegExp _headingPrefix = RegExp(r'^#{1,6}\s+');
  static final RegExp _bulletPrefix = RegExp(r'^\s*[-*•]\s+');
  static final RegExp _inlinePattern = RegExp(
    r'\*\*(.+?)\*\*|__(.+?)__|`([^`]+)`|\*([^\s*][^*]*?)\*',
  );

  @override
  Widget build(BuildContext context) {
    final TextStyle base = TextStyle(fontSize: 15, height: 1.42, color: color);
    final List<String> lines = text.split('\n');
    final List<Widget> blocks = <Widget>[];

    for (int i = 0; i < lines.length; i++) {
      final String raw = lines[i];
      if (raw.trim().isEmpty) {
        blocks.add(const SizedBox(height: 6));
        continue;
      }
      if (_headingPrefix.hasMatch(raw.trimLeft())) {
        final String clean = raw.trimLeft().replaceFirst(_headingPrefix, '');
        blocks.add(
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 2),
            child: RichText(
              text: TextSpan(
                style: base.copyWith(fontWeight: FontWeight.w700),
                children: _parseInline(clean, base),
              ),
            ),
          ),
        );
        continue;
      }
      if (_bulletPrefix.hasMatch(raw)) {
        final String clean = raw.replaceFirst(_bulletPrefix, '');
        blocks.add(
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 2, right: 8),
                  child: Text(
                    '•',
                    style: base.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: base,
                      children: _parseInline(clean, base),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }
      blocks.add(
        RichText(
          text: TextSpan(style: base, children: _parseInline(raw, base)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: blocks,
    );
  }

  static List<InlineSpan> _parseInline(String input, TextStyle base) {
    final List<InlineSpan> spans = <InlineSpan>[];
    int cursor = 0;
    for (final RegExpMatch m in _inlinePattern.allMatches(input)) {
      if (m.start > cursor) {
        spans.add(TextSpan(text: input.substring(cursor, m.start)));
      }
      final String? bold = m.group(1) ?? m.group(2);
      final String? code = m.group(3);
      final String? italic = m.group(4);
      if (bold != null) {
        spans.add(
          TextSpan(
            text: bold,
            style: base.copyWith(fontWeight: FontWeight.w700),
          ),
        );
      } else if (code != null) {
        spans.add(
          TextSpan(
            text: code,
            style: base.copyWith(fontWeight: FontWeight.w600),
          ),
        );
      } else if (italic != null) {
        spans.add(
          TextSpan(
            text: italic,
            style: base.copyWith(fontStyle: FontStyle.italic),
          ),
        );
      }
      cursor = m.end;
    }
    if (cursor < input.length) {
      spans.add(TextSpan(text: input.substring(cursor)));
    }
    return spans;
  }
}

/// Confirmation card — the "propone y yo confirmo" contract.
class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.action,
    required this.enabled,
    required this.onConfirm,
    required this.onDismiss,
  });

  final AiAction action;
  final bool enabled;
  final VoidCallback onConfirm;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool pending = action.status == AiActionStatus.pending;
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.auto_awesome, size: 16, color: scheme.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  action.describe(),
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (pending)
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 38),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: enabled ? onConfirm : null,
                    child: const Text('Confirmar y aplicar'),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 38),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      textStyle: const TextStyle(fontSize: 13),
                    ),
                    onPressed: onDismiss,
                    child: Text(
                      'Descartar',
                      style: TextStyle(color: tokens.textTertiary),
                    ),
                  ),
                ),
              ],
            )
          else
            Row(
              children: <Widget>[
                Icon(
                  action.status == AiActionStatus.done
                      ? Icons.check_circle_rounded
                      : Icons.cancel_outlined,
                  size: 16,
                  color: action.status == AiActionStatus.done
                      ? tokens.success
                      : tokens.textTertiary,
                ),
                const SizedBox(width: 6),
                Text(
                  action.status == AiActionStatus.done
                      ? 'Aplicado'
                      : 'Descartado',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: action.status == AiActionStatus.done
                        ? tokens.success
                        : tokens.textTertiary,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10, left: 36),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: tokens.surface,
          border: Border.all(color: tokens.border),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(18),
          ),
        ),
        child: SizedBox(
          width: 44,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List<Widget>.generate(
              3,
              (int i) => Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: tokens.textTertiary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

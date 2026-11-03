import 'dart:typed_data';

import 'package:all_commerce/core/theme/app_tokens.dart';
import 'package:all_commerce/core/utils/app_haptics.dart';
import 'package:all_commerce/core/widgets/app_snackbar.dart';
import 'package:all_commerce/core/widgets/floating_nav_bar.dart';
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
    final AiChatState state = ref.watch(aiChatControllerProvider);
    final String? tenantId = ref.watch(currentProfileProvider).value?.tenantId;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Asistente IA',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
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
                          color: tokens.textTertiary,
                        ),
                      ),
                    ),
                  if (state.messages.isNotEmpty) ...<Widget>[
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: 'Nueva conversación',
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                      onPressed: () =>
                          ref.read(aiChatControllerProvider.notifier).clear(),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: state.messages.isEmpty
                  ? _EmptyState(
                      onPrompt: (String p) {
                        _input.text = p;
                        _send();
                      },
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
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
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Stack(
                    children: <Widget>[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          _attachedImage!,
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: InkWell(
                          onTap: () => setState(() => _attachedImage = null),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(2),
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
                0,
                16,
                12 +
                    MediaQuery.of(context).padding.bottom +
                    FloatingNavBar.height * 0.8,
              ),
              child: Row(
                children: <Widget>[
                  IconButton(
                    tooltip: 'Adjuntar foto de producto',
                    onPressed: _attaching || state.sending ? null : _attach,
                    icon: _attaching
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add_photo_alternate_outlined),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Escribí o mandá una foto…',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Enviar',
                    onPressed: state.sending ? null : _send,
                    icon: Icon(
                      Icons.send_rounded,
                      color: state.sending
                          ? tokens.textTertiary
                          : Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
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
  const _EmptyState({required this.onPrompt});

  final ValueChanged<String> onPrompt;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(24),
          children: <Widget>[
            Icon(
              Icons.auto_awesome,
              size: 44,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'Tu asistente del local',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: tokens.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Mandame una foto de un producto y te lo dejo listo para '
              'publicar, preguntame por tus ventas o pedime cambios de '
              'stock y precios.',
              textAlign: TextAlign.center,
              style: TextStyle(color: tokens.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 20),
            for (final String prompt in <String>[
              '¿Cómo van las ventas este mes?',
              'Qué productos tengo sin stock?',
              'Mostrame mis últimos pedidos',
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ActionChip(
                  label: Text(prompt),
                  onPressed: () => onPrompt(prompt),
                ),
              ),
          ],
        ),
      ),
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
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: message.isError
                ? tokens.danger.withValues(alpha: 0.1)
                : user
                ? scheme.primary
                : tokens.surfaceMuted,
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
                    width: 140,
                    height: 140,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (message.text.isNotEmpty)
                Text(
                  message.text,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.35,
                    color: message.isError
                        ? tokens.danger
                        : user
                        ? scheme.onPrimary
                        : tokens.textPrimary,
                  ),
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
    );
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
        color: tokens.surface,
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
                  child: FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: enabled ? onConfirm : null,
                    child: const Text('Confirmar'),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                  onPressed: onDismiss,
                  child: Text(
                    'Descartar',
                    style: TextStyle(color: tokens.textTertiary),
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
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: tokens.surfaceMuted,
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

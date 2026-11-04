import 'package:all_commerce/core/theme/app_brand.dart';
import 'package:all_commerce/core/theme/app_tokens.dart';
import 'package:all_commerce/core/widgets/app_back_button.dart';
import 'package:all_commerce/core/widgets/brand_logo.dart';
import 'package:flutter/material.dart';

/// Shared frame for account screens: brand mesh background, back button,
/// centered scrollable column. On wide screens the content sits in a
/// raised [AuthCard]; on phones it flows directly over the background.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    required this.child,
    this.backFallback = '/',
    this.showBack = true,
    this.leading,
    this.maxWidth = 460,
    this.useCard = true,
    super.key,
  });

  final Widget child;
  final String backFallback;
  final bool showBack;

  /// Optional override for the app-bar leading widget (e.g. an in-page
  /// back step instead of navigation).
  final Widget? leading;
  final double maxWidth;

  /// Wrap the content in an [AuthCard] on wide screens.
  final bool useCard;

  @override
  Widget build(BuildContext context) {
    final bool wide = MediaQuery.sizeOf(context).width >= 600;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: showBack
          ? AppBar(leading: leading ?? AppBackButton(fallback: backFallback))
          : null,
      body: BrandBackground(
        intensity: 0.8,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(24, wide ? 32 : 24, 24, 32),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: wide && useCard ? AuthCard(child: child) : child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "¿No tenés cuenta? **Creá una**" style footer link.
class AuthSwitchLink extends StatelessWidget {
  const AuthSwitchLink({
    required this.question,
    required this.action,
    required this.onTap,
    super.key,
  });

  final String question;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        Text(
          '$question ',
          style: TextStyle(color: context.tokens.textSecondary),
        ),
        TextButton(
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            minimumSize: const Size(0, 36),
          ),
          onPressed: onTap,
          child: Text(action),
        ),
      ],
    );
  }
}

/// Brand mark + big left-aligned title + secondary subtitle (auth screens).
class AuthHeader extends StatelessWidget {
  const AuthHeader({
    required this.title,
    required this.subtitle,
    this.showLogo = true,
    super.key,
  });

  final String title;
  final String subtitle;
  final bool showLogo;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (showLogo) ...const <Widget>[
          BrandLogo(size: 40, showWordmark: false),
          SizedBox(height: 24),
        ],
        Text(title, style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 10),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 16,
            height: 1.45,
            color: tokens.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// White elevated card that groups a form over the brand background.
class AuthCard extends StatelessWidget {
  const AuthCard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: tokens.border),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x0F0B0F19),
            blurRadius: 40,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// A 13px w600 label above the field (labels outside, hints inside).
class LabeledField extends StatelessWidget {
  const LabeledField({required this.label, required this.child, super.key});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.tokens.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

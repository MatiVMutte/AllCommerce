import 'package:all_commerce/core/theme/app_brand.dart';
import 'package:all_commerce/core/theme/app_tokens.dart';
import 'package:all_commerce/core/widgets/app_back_button.dart';
import 'package:all_commerce/core/widgets/brand_logo.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class WelcomeView extends StatefulWidget {
  const WelcomeView({super.key});

  @override
  State<WelcomeView> createState() => _WelcomeViewState();
}

class _Slide {
  const _Slide(this.icon, this.title, this.text);

  final IconData icon;
  final String title;
  final String text;
}

class _WelcomeViewState extends State<WelcomeView> {
  static const List<_Slide> _slides = <_Slide>[
    _Slide(
      Icons.auto_awesome,
      'Tu catálogo en minutos',
      'Sacá una foto y la IA completa título, descripción y precio.',
    ),
    _Slide(
      Icons.chat_bubble_outline_rounded,
      'Pedidos por WhatsApp',
      'Tus clientes eligen, confirman y te llega el pedido listo.',
    ),
    _Slide(
      Icons.storefront_outlined,
      'Tu local, tu marca',
      'Compartí tu link y recibí pedidos desde cualquier celular.',
    ),
  ];

  final PageController _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final Color primary = Theme.of(context).colorScheme.primary;
    final bool isLast = _page == _slides.length - 1;
    return Scaffold(
      body: BrandBackground(
        child: SafeArea(
          child: Column(
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.only(right: 16),
                child: Row(
                  children: <Widget>[
                    AppBackButton(fallback: '/'),
                    Spacer(),
                    BrandLogo(size: 30),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _slides.length,
                  onPageChanged: (int index) => setState(() => _page = index),
                  itemBuilder: (BuildContext context, int index) {
                    final _Slide slide = _slides[index];
                    return Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: AppBrand.softGradient(
                                  primary,
                                  alpha: 0.08,
                                ),
                              ),
                              child: Container(
                                width: 128,
                                height: 128,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(40),
                                  gradient: AppBrand.gradient(primary),
                                  boxShadow: <BoxShadow>[
                                    BoxShadow(
                                      color: primary.withValues(alpha: 0.3),
                                      blurRadius: 32,
                                      offset: const Offset(0, 14),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  slide.icon,
                                  size: 56,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 40),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 420),
                              child: Column(
                                children: <Widget>[
                                  Text(
                                    slide.title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineLarge,
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    slide.text,
                                    style: TextStyle(
                                      fontSize: 17,
                                      height: 1.5,
                                      color: tokens.textSecondary,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List<Widget>.generate(
                  _slides.length,
                  (int index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    width: index == _page ? 28 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: index == _page
                          ? AppBrand.gradient(primary)
                          : null,
                      color: index == _page ? null : tokens.border,
                    ),
                  ),
                ),
              ),
              Container(
                constraints: const BoxConstraints(maxWidth: 460),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    FilledButton(
                      onPressed: () {
                        if (isLast) {
                          context.push('/register');
                        } else {
                          _controller.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      },
                      child: Text(isLast ? 'Crear cuenta' : 'Siguiente'),
                    ),
                    TextButton(
                      onPressed: () => context.push('/login'),
                      child: const Text('Ya tengo cuenta'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

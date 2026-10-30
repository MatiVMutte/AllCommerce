import 'package:all_commerce/core/theme/app_tokens.dart';
import 'package:all_commerce/core/widgets/app_back_button.dart';
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.center,
            colors: <Color>[
              primary.withValues(alpha: 0.08),
              Theme.of(context).scaffoldBackgroundColor,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: <Widget>[
              const Align(
                alignment: Alignment.centerLeft,
                child: AppBackButton(fallback: '/'),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _slides.length,
                  onPageChanged: (int index) => setState(() => _page = index),
                  itemBuilder: (BuildContext context, int index) {
                    final _Slide slide = _slides[index];
                    return Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: primary.withValues(alpha: 0.1),
                            ),
                            child: Icon(slide.icon, size: 52, color: primary),
                          ),
                          const SizedBox(height: 32),
                          Text(
                            slide.title,
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            slide.text,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(color: tokens.textSecondary),
                            textAlign: TextAlign.center,
                          ),
                        ],
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
                    width: index == _page ? 24 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: index == _page ? primary : tokens.border,
                    ),
                  ),
                ),
              ),
              Padding(
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

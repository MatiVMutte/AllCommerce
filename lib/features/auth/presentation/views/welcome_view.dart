import 'package:all_commerce/core/constants/app_colors.dart';
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
      Icons.chat_bubble_outline,
      'Pedidos por WhatsApp',
      'Tus clientes eligen, confirman y te llega el pedido listo.',
    ),
    _Slide(
      Icons.storefront,
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
    final bool isLast = _page == _slides.length - 1;
    return Scaffold(
      body: SafeArea(
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
                        Icon(
                          slide.icon,
                          size: 96,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 32),
                        Text(
                          slide.title,
                          style: Theme.of(context).textTheme.headlineSmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          slide.text,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(color: AppColors.textSecondary),
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
                (int index) => Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index == _page
                        ? Theme.of(context).colorScheme.primary
                        : AppColors.border,
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
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:newfitness/app/routes/app_routes.dart';
import 'package:newfitness/core/di/injector.dart';
import 'package:newfitness/core/storage/local_prefs.dart';

class _Page {
  const _Page(this.icon, this.title, this.text);

  final IconData icon;
  final String title;
  final String text;
}

const _pages = [
  _Page(
    Icons.fitness_center,
    'Bem-vindo ao NewFitness',
    'Seus treinos, sua evolução e seu personal em um só lugar.',
  ),
  _Page(
    Icons.auto_awesome_outlined,
    'Um treino para você',
    'Comece com um treino pronto. No Premium, há treinos para o seu '
        'esporte e para a sua rotina.',
  ),
  _Page(
    Icons.show_chart,
    'Registre e acompanhe',
    'Anote o peso e as repetições de cada série. Sua semana e seu '
        'histórico ficam salvos para você ver a evolução.',
  ),
  _Page(
    Icons.groups_outlined,
    'Treine com seu personal',
    'Recebeu um código de convite? Vincule sua conta para seguir o plano '
        'que ele montou para você.',
  ),
];

/// Explica o app na primeira vez que ele é aberto neste aparelho.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isLast => _index == _pages.length - 1;

  Future<void> _finish() async {
    await getIt<LocalPrefs>().setOnboardingSeen();
    if (mounted) context.go(AppRoutes.login);
  }

  void _next() {
    if (_isLast) {
      _finish();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Visibility(
                  visible: !_isLast,
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  child: TextButton(
                    onPressed: _finish,
                    child: const Text('Pular'),
                  ),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _pages.length,
                  onPageChanged: (index) => setState(() => _index = index),
                  itemBuilder: (context, index) {
                    final page = _pages[index];
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 56,
                          backgroundColor: colors.primary,
                          child: Icon(
                            page.icon,
                            size: 52,
                            color: const Color(0xFF14171A),
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          page.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          page.text,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (int i = 0; i < _pages.length; i++)
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == _index
                            ? colors.primary
                            : colors.surfaceContainerHighest,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _next,
                  child: Text(_isLast ? 'Começar' : 'Próximo'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

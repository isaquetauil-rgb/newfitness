import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:newfitness/features/auth/logic/auth_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _instructorCodeCtrl = TextEditingController();
  final _nutritionistCodeCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _instructorCodeCtrl.dispose();
    _nutritionistCodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(AuthProvider auth) async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await auth.signUp(
      _nameCtrl.text.trim(),
      _emailCtrl.text,
      _passwordCtrl.text,
      instructorCode: _instructorCodeCtrl.text,
      nutritionistCode: _nutritionistCodeCtrl.text,
    );
    if (ok && mounted) {
      Navigator.of(context).pop();
    } else if (mounted && auth.errorMessage != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(auth.errorMessage!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Criar conta')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nome',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Informe seu nome'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'E-mail',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (v) => (v == null || !v.contains('@'))
                      ? 'E-mail inválido'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Senha',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: (v) => (v == null || v.length < 6)
                      ? 'Mínimo de 6 caracteres'
                      : null,
                ),
                ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _instructorCodeCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Código do instrutor (opcional)',
                      hintText: 'ex: JOAO4F',
                      prefixIcon: Icon(Icons.qr_code),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Se seu instrutor te passou um código, insira aqui para já '
                    'ficar vinculado. Se não tiver, pode deixar em branco e '
                    'vincular depois no seu perfil.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nutritionistCodeCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Código da nutricionista (opcional)',
                      hintText: 'ex: MARIA9K',
                      prefixIcon: Icon(Icons.restaurant_outlined),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Container(
                  key: const ValueKey('professional-signup-note'),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'É personal ou nutricionista? Crie sua conta e '
                          'depois peça a aprovação em Perfil → "Sou '
                          'profissional", informando seu CREF ou CRN.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: auth.isLoading ? null : () => _submit(auth),
                  child: auth.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Criar conta'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

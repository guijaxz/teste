import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/material.dart';
import 'package:tccguilherme/register_screen.dart';
import 'package:tccguilherme/widgets/primary_button.dart';
import 'login_screen.dart';

/// Eu desenhei esta tela para ser a porta de entrada do app.
/// Ela apresenta a marca e o propósito do aplicativo, e oferece ao usuário
/// os dois caminhos principais: fazer login em uma conta existente ou
/// criar uma nova conta.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // METADE DE CIMA: IMAGEM
          SizedBox(
            height: screenHeight * 0.5, // ocupa 50% da tela
            width: double.infinity,
            child: Image.asset('assets/images/dog_hero.png', fit: BoxFit.cover),
          ),

          // METADE DE BAIXO: TEXTO + BOTÕES
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'ENCONTRE SEU PET',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28.0,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  const Text(
                    'Ache seu animal perdido e ajude as pessoas as acharem os delas em um só lugar',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16.0, color: Colors.black54),
                  ),
                  const SizedBox(height: 32.0),

                  // Botão de Login
                  PrimaryButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoginScreen(),
                        ),
                      );
                    },
                    child: const Text('Login'),
                  ),
                  const SizedBox(height: 16.0),

                  // Botão de Criar Conta
                  PrimaryButton(
                    isOutlined: true,
                    onPressed: () async {
                      // Limpa qualquer sessão anterior para garantir um registro limpo
                      await GoogleSignIn().signOut();
                      await FirebaseAuth.instance.signOut();

                      if (!context.mounted) return;

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RegisterScreen(),
                        ),
                      );
                    },
                    child: const Text('Crie uma conta!'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

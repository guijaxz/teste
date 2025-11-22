import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:tccguilherme/widgets/primary_button.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:tccguilherme/register_screen.dart';
import 'package:tccguilherme/main_screen.dart';
import 'package:tccguilherme/services/notification_service.dart';
import 'package:tccguilherme/main.dart';

/// Eu construí esta tela para lidar com todas as formas de login.
/// É um `StatefulWidget` para gerenciar o estado do formulário, o estado de
/// carregamento (`_isLoading`) e a visibilidade da senha. Ela oferece login
/// com e-mail/senha e também com provedores sociais como Google e Facebook.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isPasswordObscured = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Este método executa o login com e-mail e senha.
  /// Eu valido o formulário, inicio o estado de carregamento e chamo o
  /// `signInWithEmailAndPassword` do Firebase. Faço o tratamento de erros
  /// para mostrar mensagens amigáveis e, em caso de sucesso, levo o usuário
  /// para a `MainScreen`.
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (mounted) {
        // Obter e enviar o token FCM após o login
        final notificationService = NotificationService(navigationService);
        final fcmToken = await notificationService.getFcmToken();
        if (fcmToken != null) {
          await notificationService.sendFcmTokenToBackend(fcmToken);
        }

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Login bem-sucedido!')));
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const MainScreen()),
          (Route<dynamic> route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Ocorreu um erro durante o login.';
      if (e.code == 'user-not-found' ||
          e.code == 'wrong-password' ||
          e.code == 'invalid-credential') {
        message = 'E-mail ou senha inválidos. Por favor, tente novamente.';
      } else {
        message = 'Erro: ${e.message}';
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ocorreu um erro inesperado. Tente novamente.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Criei este método para a funcionalidade de "Esqueceu a senha?".
  /// Ele pega o e-mail do `_emailController` e usa o Firebase Auth para
  /// enviar um link de redefinição de senha para o usuário.
  Future<void> _resetPassword() async {
    if (_emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, digite seu e-mail para redefinir a senha.'),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'E-mail de redefinição de senha enviado com sucesso!',
            ),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Erro ao enviar e-mail de redefinição.';
      if (e.code == 'user-not-found') {
        message = 'Nenhuma conta encontrada para este e-mail.';
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ocorreu um erro inesperado.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Eu criei este método genérico para simplificar o login social.
  /// Ele recebe uma função de login (como `_signInWithGoogle`) como argumento,
  /// gerencia o estado de `_isLoading` e cuida da navegação em caso de sucesso,
  /// evitando repetição de código.
  Future<void> _signInWithSocial(Future<void> Function() signInMethod) async {
    setState(() {
      _isLoading = true;
    });
    try {
      await signInMethod();
      if (FirebaseAuth.instance.currentUser != null && mounted) {
        // Obter e enviar o token FCM após o login social
        final notificationService = NotificationService(navigationService);
        final fcmToken = await notificationService.getFcmToken();
        if (fcmToken != null) {
          await notificationService.sendFcmTokenToBackend(fcmToken);
        }

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Login bem-sucedido!')));
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const MainScreen()),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ocorreu um erro no login social: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Lida com o fluxo de autenticação do Google.
  /// Eu uso o plugin `google_sign_in` para obter a conta do usuário e,
  /// em seguida, converto os tokens recebidos em uma `OAuthCredential`
  /// que o Firebase Auth pode usar para autenticar a sessão.
  Future<void> _signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) return;
    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;
    final OAuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    await FirebaseAuth.instance.signInWithCredential(credential);
  }

  /// Lida com o fluxo de autenticação do Facebook.
  /// Similar ao do Google, eu uso o plugin `flutter_facebook_auth` para
  /// iniciar o login e, se for bem-sucedido, crio uma credencial do
  /// Firebase a partir do token de acesso para autenticar o usuário.
  Future<void> _signInWithFacebook() async {
    final LoginResult result = await FacebookAuth.instance.login();
    if (result.status == LoginStatus.success) {
      final OAuthCredential credential = FacebookAuthProvider.credential(
        result.accessToken!.tokenString,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
    } else {
      throw Exception(result.message ?? 'Login com Facebook cancelado.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Login',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Email',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          hintText: 'exemplo@gmail.com',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'O e-mail é obrigatório.';
                          }
                          if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                            return 'Por favor, insira um e-mail válido.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Senha',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _isPasswordObscured,
                        decoration: InputDecoration(
                          hintText: 'sua senha',
                          border: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordObscured
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(() {
                                _isPasswordObscured = !_isPasswordObscured;
                              });
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'A senha é obrigatória.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _isLoading ? null : _resetPassword,
                          child: const Text(
                            'Esqueceu a senha?',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: PrimaryButton(
                          onPressed: _isLoading ? null : _login,
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Text('Login'),
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Row(
                        children: [
                          Expanded(child: Divider()),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8.0),
                            child: Text('Ou login com'),
                          ),
                          Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          PrimaryButton(
                            onPressed: _isLoading
                                ? null
                                : () => _signInWithSocial(_signInWithFacebook),
                            isOutlined: true,
                            child: const FaIcon(
                              FontAwesomeIcons.facebookF,
                              color: Colors.black,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 16),
                          PrimaryButton(
                            onPressed: _isLoading
                                ? null
                                : () => _signInWithSocial(_signInWithGoogle),
                            isOutlined: true,
                            child: const FaIcon(
                              FontAwesomeIcons.google,
                              color: Colors.black,
                              size: 20,
                            ),
                          ),
                          Visibility(
                            visible: false,
                            child: Row(
                              children: [
                                const SizedBox(width: 16),
                                PrimaryButton(
                                  onPressed: () {},
                                  isOutlined: true,
                                  child: const FaIcon(
                                    FontAwesomeIcons.apple,
                                    color: Colors.black,
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Botão de registro fixado na parte inferior
            Padding(
              padding: const EdgeInsets.only(
                top: 16.0,
              ), // Espaço acima do botão
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Não tem uma conta?'),
                  TextButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RegisterScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      'Registre-se',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
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
}

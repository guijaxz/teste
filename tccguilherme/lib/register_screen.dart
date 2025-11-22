import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:tccguilherme/widgets/primary_button.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:tccguilherme/login_screen.dart';
import 'package:tccguilherme/api_client.dart';

/// Eu projetei esta tela para cuidar do registro de novos usuários.
/// É um `StatefulWidget` complexo porque lida com múltiplos cenários:
/// 1. Registro padrão com e-mail e senha.
/// 2. Iniciar o registro com Google/Facebook, que pré-preenche o formulário
///    e depois pede para o usuário completar os dados restantes.
/// Por isso, eu gerencio estados como `_isLoading` e `_isCompletingSocialSignIn`.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _confirmPasswordKey = GlobalKey<FormFieldState<String>>();

  bool _isPasswordObscured = true;
  bool _isConfirmPasswordObscured = true;
  bool _agreeToTerms = false;
  bool _isLoading = false;
  // Flag genérica para login social (Google, Facebook, etc.)
  bool _isCompletingSocialSignIn = false;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_validateConfirmPassword);
  }

  void _validateConfirmPassword() {
    _confirmPasswordKey.currentState?.validate();
  }

  @override
  void dispose() {
    _passwordController.removeListener(_validateConfirmPassword);
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// Este método inicia o fluxo de registro com o Facebook.
  /// Diferente do login, aqui o objetivo é obter os dados básicos do usuário
  /// (nome, e-mail) do provedor social, autenticá-lo no Firebase e, em seguida,
  /// pré-preencher o formulário. Eu ativo a flag `_isCompletingSocialSignIn`
  /// para que o usuário possa completar os campos que faltam (como o telefone)
  /// antes de finalizar o cadastro no nosso backend.
  Future<void> _signInWithFacebook() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await FacebookAuth.instance.logOut();
      await FirebaseAuth.instance.signOut();

      final LoginResult result = await FacebookAuth.instance.login();

      if (result.status == LoginStatus.success) {
        final OAuthCredential credential = FacebookAuthProvider.credential(
          result.accessToken!.tokenString,
        );
        final UserCredential userCredential = await FirebaseAuth.instance
            .signInWithCredential(credential);
        final User? user = userCredential.user;

        if (user != null) {
          _nameController.text = user.displayName ?? '';
          _emailController.text = user.email ?? '';
          setState(() {
            _isCompletingSocialSignIn = true;
          });
          _formKey.currentState?.validate();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Login com Facebook bem-sucedido! Por favor, complete seu cadastro.',
                ),
                duration: Duration(seconds: 4),
              ),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message ?? 'Login com Facebook cancelado.'),
            ),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Ocorreu um erro no login com Facebook.';
      if (e.code == 'account-exists-with-different-credential') {
        message =
            'Já existe uma conta com este e-mail. Faça login com seu método original para continuar.';
      } else {
        message = 'Erro no login com Facebook: ${e.message}';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ocorreu um erro inesperado: $e')),
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

  /// Este método faz o mesmo que o de Facebook, mas para o Google.
  /// Ele autentica o usuário com o Google via Firebase e usa os dados
  /// para pré-preencher o formulário, facilitando o processo de cadastro
  /// para o usuário, que só precisa preencher os campos restantes.
  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await GoogleSignIn().signOut();
      await FirebaseAuth.instance.signOut();

      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      if (googleUser == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        _nameController.text = user.displayName ?? '';
        _emailController.text = user.email ?? '';
        setState(() {
          _isCompletingSocialSignIn = true;
        });
        _formKey.currentState?.validate();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Login com Google bem-sucedido! Por favor, complete seu cadastro.',
              ),
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Ocorreu um erro no login com Google.';
      if (e.code == 'account-exists-with-different-credential') {
        message =
            'Já existe uma conta com este e-mail. Faça login com seu método original para continuar.';
      } else {
        message = 'Erro no login com Google: ${e.message}';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ocorreu um erro inesperado: $e')),
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

  /// Este é o método final que conclui o registro.
  /// Eu projetei ele para lidar com duas situações:
  /// 1. Se for um registro novo (`!_isCompletingSocialSignIn`), ele primeiro cria
  ///    o usuário no Firebase Auth com `createUserWithEmailAndPassword`.
  /// 2. Se for a finalização de um login social, ele simplesmente pega o usuário
  ///    que já está logado no Firebase.
  /// Em ambos os casos, após ter o usuário do Firebase, eu pego o token de ID
  /// e envio os dados do formulário (nome, email, telefone) para a API do meu
  /// backend, que vai criar o perfil do usuário no Firestore.
  Future<void> _finishRegistration() async {
    if (!_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Você precisa aceitar os termos para continuar.'),
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      User? user;

      if (!_isCompletingSocialSignIn) {
        await FirebaseAuth.instance.signOut();
        final credential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
              email: _emailController.text.trim(),
              password: _passwordController.text.trim(),
            );
        user = credential.user;
      } else {
        user = FirebaseAuth.instance.currentUser;
      }

      if (user == null) {
        throw Exception(
          'Ocorreu um erro de autenticação. Nenhum usuário encontrado.',
        );
      }

      final token = await user.getIdToken();

      final response = await http.post(
        Uri.parse('${getBaseUrl()}/api/users/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'fullName': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'phone': _phoneController.text.trim(),
        }),
      );

      if (response.statusCode != 201) {
        final body = jsonDecode(response.body);
        if (response.statusCode == 409 && _isCompletingSocialSignIn) {
          debugPrint("User already exists in backend, proceeding.");
        } else {
          throw Exception(
            'Falha ao salvar perfil no backend: ${body['error'] ?? response.reasonPhrase}',
          );
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registro realizado com sucesso!')),
        );
        Navigator.of(context).pop();
      }
    } on FirebaseAuthException catch (e) {
      String message;
      if (e.code == 'weak-password') {
        message = 'A senha fornecida é muito fraca.';
      } else if (e.code == 'email-already-in-use') {
        message = 'Já existe uma conta para este e-mail.';
      } else {
        message = 'Erro de autenticação: ${e.message}';
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
        debugPrint('Erro no cadastro: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPasswordRequired = !_isCompletingSocialSignIn;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Registrar',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16.0),
            child: Icon(Icons.star_border, color: Colors.black, size: 30),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nome completo',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    hintText: 'Nome e sobrenome',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'O nome é obrigatório.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                const Text(
                  'Email',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailController,
                  readOnly: _isCompletingSocialSignIn,
                  decoration: InputDecoration(
                    hintText: 'exemplo@gmail.com',
                    border: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                    filled: _isCompletingSocialSignIn,
                    fillColor: Colors.grey[200],
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
                  'Telefone',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    hintText: '+55 (ddd) seu telefone',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'O telefone é obrigatório.';
                    }
                    return null;
                  },
                ),
                if (isPasswordRequired) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Crie uma senha',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _isPasswordObscured,
                    decoration: InputDecoration(
                      hintText: 'no mínimo 8 caracteres',
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
                      if (isPasswordRequired &&
                          (value == null || value.isEmpty)) {
                        return 'A senha é obrigatória.';
                      }
                      if (isPasswordRequired && value!.length < 8) {
                        return 'A senha deve ter no mínimo 8 caracteres.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Confirmar senha',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    key: _confirmPasswordKey,
                    controller: _confirmPasswordController,
                    obscureText: _isConfirmPasswordObscured,
                    decoration: InputDecoration(
                      hintText: 'Repita sua senha',
                      border: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isConfirmPasswordObscured
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            _isConfirmPasswordObscured =
                                !_isConfirmPasswordObscured;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (isPasswordRequired &&
                          (value == null || value.isEmpty)) {
                        return 'A confirmação de senha é obrigatória.';
                      }
                      if (isPasswordRequired &&
                          value != _passwordController.text) {
                        return 'As senhas não coincidem.';
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 16),
                CheckboxListTile(
                  value: _agreeToTerms,
                  onChanged: (bool? value) {
                    setState(() {
                      _agreeToTerms = value ?? false;
                    });
                  },
                  title: const Text(
                    'Eu aceito os termos e a política de privacidade',
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  activeColor: Colors.black,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: PrimaryButton(
                    onPressed: _isLoading ? null : _finishRegistration,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text('Registrar'),
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
                      onPressed: _isLoading ? null : _signInWithFacebook,
                      isOutlined: true,
                      child: const FaIcon(
                        FontAwesomeIcons.facebookF,
                        color: Colors.black,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    PrimaryButton(
                      onPressed: _isLoading ? null : _signInWithGoogle,
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
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Já tem uma conta?'),
                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LoginScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        'Log in',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

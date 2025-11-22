import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:tccguilherme/welcome_screen.dart';

/// Eu criei esta tela para ser a área de "Perfil" e "Configurações" do usuário.
/// Ela mostra as informações básicas do usuário logado (foto, nome, e-mail)
/// e apresenta uma lista de opções, como "Ajuda", "Sobre" e, mais importante,
/// a função de "Sair" (logout).
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final User? _user = FirebaseAuth.instance.currentUser;

  /// Este método cuida do processo de logout.
  /// Para evitar saídas acidentais, eu primeiro mostro um diálogo de confirmação.
  /// Se o usuário confirmar, eu chamo o `signOut` do Firebase e redireciono
  /// o usuário de volta para a `WelcomeScreen`, limpando todo o histórico
  /// de navegação anterior.
  Future<void> _signOut() async {
    // Mostra um diálogo de confirmação antes de sair
    final bool? confirmed = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Saída'),
        content: const Text('Você tem certeza que deseja sair?'),
        actions: [
          TextButton(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          TextButton(
            child: const Text('Sair', style: TextStyle(color: Colors.red)),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    // Se o usuário não confirmou, não faz nada
    if (confirmed == null || !confirmed) {
      return;
    }

    try {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      // Após o logout, o usuário será redirecionado para a tela welcomescreen
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const WelcomeScreen()),
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao fazer logout: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        children: [
          const SizedBox(height: 20),
          // --- SEÇÃO DE INFORMAÇÕES DO USUÁRIO ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: [
                const Text(
                  'Meu Perfil',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: _user?.photoURL != null
                      ? NetworkImage(_user!.photoURL!)
                      : null,
                  child: _user?.photoURL == null
                      ? Icon(Icons.person, size: 60, color: Colors.grey[600])
                      : null,
                ),
                const SizedBox(height: 12),
                Text(
                  _user?.displayName ?? 'Nome do Usuário',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _user?.email ?? 'email@exemplo.com',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          const Divider(thickness: 1, height: 1),

          // --- OPÇÕES DO MENU ---
          _buildMenuOption(
            icon: Icons.notifications_outlined,
            title: 'Notificações',
            onTap: () {
              // TODO: Implementar tela de notificações
            },
          ),
          _buildMenuOption(
            icon: Icons.lock_outline,
            title: 'Privacidade e Segurança',
            onTap: () {
              // TODO: Implementar tela de privacidade
            },
          ),
          _buildMenuOption(
            icon: Icons.help_outline,
            title: 'Ajuda',
            onTap: () {
              // TODO: Implementar tela de ajuda
            },
          ),
          _buildMenuOption(
            icon: Icons.info_outline,
            title: 'Sobre',
            onTap: () {
              // TODO: Implementar tela "Sobre"
            },
          ),
          const Divider(thickness: 1, height: 1),
          _buildMenuOption(
            icon: Icons.logout,
            title: 'Sair',
            color: Colors.red,
            onTap: _signOut,
          ),
        ],
      ),
    );
  }

  /// Criei este método auxiliar para construir cada item do menu de opções.
  /// Ele recebe o ícone, título e a função a ser executada ao tocar,
  /// e retorna um `ListTile` estilizado. Isso evita a repetição de código
  /// no método `build` e facilita a manutenção.
  Widget _buildMenuOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color color = Colors.black,
  }) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(color: color, fontSize: 16)),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: Colors.grey[600],
      ),
      onTap: onTap,
    );
  }
}

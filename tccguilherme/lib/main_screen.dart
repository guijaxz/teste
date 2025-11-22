import 'package:flutter/material.dart';
import 'package:tccguilherme/found_screen.dart';
import 'package:tccguilherme/home_screen.dart';
import 'package:tccguilherme/lost_screen.dart';
import 'package:tccguilherme/settings_screen.dart';
import 'package:tccguilherme/widgets/add_pet_panel.dart';

/// Eu construí esta tela para ser a estrutura principal do app após o login.
/// Ela contém a `BottomAppBar` (barra de navegação inferior) e gerencia qual
/// das telas principais (`HomeScreen`, `LostScreen`, etc.) está sendo exibida
/// com base no item que o usuário selecionou, controlado pelo `_selectedIndex`.
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  // Lista de telas que serão exibidas
  static const List<Widget> _widgetOptions = <Widget>[
    HomeScreen(),
    LostScreen(),
    FoundScreen(),
    SettingsScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  /// Este método exibe o painel para adicionar um novo pet.
  /// Eu uso um `showModalBottomSheet` para que o formulário (`AddPetPanel`)
  /// deslize de baixo para cima, uma abordagem de UI comum e elegante.
  void _showAddPetPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return const AddPetPanel();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              _buildNavItem(Icons.home_outlined, 'Home', 0),
              _buildNavItem(Icons.search, 'Perdido', 1),
              const SizedBox(width: 40), // Espaço para o botão flutuante
              _buildNavItem(Icons.visibility_outlined, 'Encontrado', 2),
              _buildNavItem(Icons.person_outline, 'Perfil', 3),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddPetPanel,
        backgroundColor: Colors.black,
        child: const Icon(Icons.add, color: Colors.white, size: 30),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  /// Eu criei este método auxiliar para construir cada item da barra de navegação.
  /// Isso evita repetição de código no `build` e torna o layout mais limpo.
  /// Ele recebe o ícone, o texto e o índice do item, e o estiliza de forma
  /// diferente se ele estiver selecionado (`isSelected`).
  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _selectedIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => _onItemTapped(index),
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment:
              MainAxisAlignment.center, // Center the content vertically
          children: [
            Icon(icon, color: isSelected ? Colors.black : Colors.grey),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.grey,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// Esta tela foi projetada para mostrar os detalhes de uma correspondência
/// encontrada pela IA. Quando o usuário recebe uma notificação de "match",
/// ele é direcionado para cá. A tela recebe o `petId` do animal
/// correspondente para que eu possa buscar e exibir os detalhes.
class MatchDetailsScreen extends StatelessWidget {
  final String petId;

  const MatchDetailsScreen({super.key, required this.petId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detalhes do Match')),
      body: Center(child: Text('Detalhes do match para o pet com ID: $petId')),
    );
  }
}

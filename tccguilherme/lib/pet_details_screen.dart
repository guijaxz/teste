import 'package:flutter/material.dart';

/// Eu criei esta tela para ser a página de detalhes de um pet específico.
/// A ideia é que ela receba um `petId` e use esse ID para buscar e exibir
/// todas as informações daquele pet. Atualmente, ela é um placeholder,
/// mas está pronta para ser desenvolvida.
class PetDetailsScreen extends StatelessWidget {
  final String petId;

  const PetDetailsScreen({super.key, required this.petId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detalhes do Pet')),
      body: Center(child: Text('Detalhes do pet com ID: $petId')),
    );
  }
}

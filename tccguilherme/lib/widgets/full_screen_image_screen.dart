import 'package:flutter/material.dart';

/// Eu criei esta tela para exibir uma imagem em tela cheia.
/// Ela recebe a URL da imagem e uma `heroTag` para criar uma animação suave
/// de transição. Eu uso o `InteractiveViewer` para que o usuário possa dar zoom
/// e mover a imagem. Um toque em qualquer lugar da tela fecha a visualização.
class FullScreenImageScreen extends StatelessWidget {
  final String imageUrl;
  final String heroTag;

  const FullScreenImageScreen({
    super.key,
    required this.imageUrl,
    required this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.8),
      body: GestureDetector(
        onTap: () {
          Navigator.of(context).pop();
        },
        child: Center(
          child: Hero(
            tag: heroTag,
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 1.0,
              maxScale: 4.0,
              child: Image.network(imageUrl, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }
}

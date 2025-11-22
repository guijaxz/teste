import 'package:flutter/material.dart';

/// Eu criei este `PrimaryButton` para ter um estilo de botão consistente em todo o app.
/// Ele pode ser sólido (padrão) ou apenas contornado (`isOutlined = true`),
/// o que me dá flexibilidade na UI. Centralizar o estilo aqui significa que, se eu
/// precisar mudar o design dos botões, só preciso editar este arquivo.
class PrimaryButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget? child;
  final bool isOutlined;

  const PrimaryButton({
    super.key,
    required this.onPressed,
    this.child,
    this.isOutlined = false,
  }) : assert(child != null, 'A child must be provided.');

  @override
  Widget build(BuildContext context) {
    final ButtonStyle solidStyle = ElevatedButton.styleFrom(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );

    final ButtonStyle outlinedStyle = OutlinedButton.styleFrom(
      foregroundColor: Colors.black,
      side: BorderSide(color: Colors.grey.shade300, width: 1.5),
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );

    if (isOutlined) {
      return OutlinedButton(
        onPressed: onPressed,
        style: outlinedStyle,
        child: child!,
      );
    }

    return ElevatedButton(
      onPressed: onPressed,
      style: solidStyle,
      child: child!,
    );
  }
}

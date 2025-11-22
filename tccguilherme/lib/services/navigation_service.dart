import 'package:flutter/material.dart';

/// Eu criei este serviço para gerenciar a navegação de forma global.
/// Com uma `GlobalKey`, eu consigo controlar o `Navigator` de qualquer lugar
/// do app, o que é essencial para, por exemplo, abrir uma tela a partir de uma
/// notificação push, onde não tenho um `BuildContext` disponível.
class NavigationService {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Este método expõe uma forma simples de navegar para uma rota nomeada.
  /// Ele usa a `navigatorKey` para acessar o `NavigatorState` e realizar a navegação.
  Future<dynamic> navigateTo(String routeName, {Object? arguments}) {
    return navigatorKey.currentState!.pushNamed(
      routeName,
      arguments: arguments,
    );
  }
}

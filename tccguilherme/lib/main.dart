import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:tccguilherme/match_details_screen.dart';
import 'package:tccguilherme/pet_details_screen.dart';
import 'package:tccguilherme/services/navigation_service.dart';
import 'package:tccguilherme/services/notification_service.dart';
import 'firebase_options.dart';
import 'welcome_screen.dart';

final NavigationService navigationService = NavigationService();

/// Eu configurei esta função `main` como o ponto de entrada de toda a aplicação.
/// Garanto a inicialização do Flutter, depois do Firebase e, por fim, do nosso
/// serviço de notificações antes de rodar o widget principal `MyApp`.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService(navigationService).init();
  runApp(const MyApp());
}

/// Este é o widget raiz da minha aplicação.
/// Eu o configurei para usar o `MaterialApp`, definindo o título, o tema principal,
/// a chave de navegação global, a tela inicial (`WelcomeScreen`) e as rotas nomeadas
/// para navegação a partir de notificações.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Encontre Seu Pet',
      theme: ThemeData(primarySwatch: Colors.blue),
      navigatorKey: navigationService.navigatorKey,
      home: const WelcomeScreen(),
      routes: {
        '/match-details': (context) => MatchDetailsScreen(
          petId: ModalRoute.of(context)!.settings.arguments as String,
        ),
        '/pet-details': (context) => PetDetailsScreen(
          petId: ModalRoute.of(context)!.settings.arguments as String,
        ),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

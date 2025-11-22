import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:tccguilherme/api_client.dart';
import 'package:tccguilherme/services/navigation_service.dart';

/// Eu centralizei toda a lógica de notificações push nesta classe.
/// Ela é responsável por pedir permissão ao usuário, obter o token FCM,
/// configurar como as notificações aparecem no app (em primeiro plano) e
/// o que acontece quando o usuário clica em uma notificação (navegação).
class NotificationService {
  final NavigationService _navigationService;
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  NotificationService(this._navigationService);

  /// Este é o método de inicialização do serviço, que eu chamo na `main`.
  /// Ele orquestra todo o setup: pede permissão, pega o token FCM e o envia
  /// para o meu backend, e configura os `listeners` para tratar o recebimento
  /// de mensagens com o app aberto ou quando o usuário clica na notificação.
  Future<void> init() async {
    // Solicitar permissão para iOS e web
    await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    // Obter o token FCM
    final fcmToken = await _firebaseMessaging.getToken();
    print('Token FCM: $fcmToken');

    // Enviar o token para o backend
    if (fcmToken != null) {
      await sendFcmTokenToBackend(fcmToken);
    }

    // Configurar o canal de notificação para Android
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel', // id
      'Notificações de Alta Importância', // title
      description:
          'Este canal é usado para notificações importantes.', // description
      importance: Importance.max,
    );

    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    // Inicializar o plugin de notificações locais
    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        );
    await _flutterLocalNotificationsPlugin.initialize(initializationSettings);

    // Lidar com mensagens em primeiro plano
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      if (notification != null && android != null) {
        _flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              channel.id,
              channel.name,
              channelDescription: channel.description,
              icon: android.smallIcon,
            ),
          ),
        );
      }
    });

    // Lidar com a abertura do app a partir de uma notificação
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      final screen = message.data['screen'];
      final petId = message.data['petId'];

      if (screen != null && petId != null) {
        _navigationService.navigateTo(screen, arguments: petId);
      }
    });
  }

  /// Criei este método para obter o token de registro do Firebase (FCM token).
  /// Este token é o endereço único do dispositivo para receber notificações push.
  Future<String?> getFcmToken() async {
    return await _firebaseMessaging.getToken();
  }

  /// Este método envia o token FCM para o meu backend.
  /// Eu o chamo sempre que um novo token é gerado, para que o servidor
  /// saiba para qual dispositivo deve enviar as notificações de um determinado usuário.
  /// A requisição é autenticada com o token de ID do usuário do Firebase.
  Future<void> sendFcmTokenToBackend(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('Usuário não logado. Não é possível enviar o token FCM.');
      return;
    }

    final url = Uri.parse('${getBaseUrl()}/api/users/profile');
    try {
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await user.getIdToken()}',
        },
        body: jsonEncode({'fcmToken': token}),
      );

      if (response.statusCode == 200) {
        print('Token FCM enviado para o backend com sucesso.');
      } else {
        print(
          'Falha ao enviar token FCM para o backend. Código de status: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Erro ao enviar token FCM para o backend: $e');
    }
  }
}

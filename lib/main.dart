import 'package:control_emap/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'firebase_options.dart';
import 'features/auth/screens/auth_gate.dart';

// 👈 IMPORTAMOS NUESTRO SERVICIO INMORTAL
// (Asegúrate de que la ruta coincida con donde guardaste el archivo)
import 'core/services/gps_inmortal_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // ==========================================================
  // 🔔 CREAR EL CANAL DE ANDROID CON SONIDO PERSONALIZADO
  // ==========================================================
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'canal_emap_misiones', // 🔥 EL MISMO ID QUE PUSIMOS EN LA NUBE
    'Alertas EMAP',
    description: 'Notificaciones para solicitudes de salida',
    importance: Importance.max,
    playSound: true,
    sound: RawResourceAndroidNotificationSound('notificacion'),
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);
  // ==========================================================

  // 👻 INICIALIZAMOS EL FANTASMA INMORTAL
  await inicializarGpsInmortal();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Control EMAP',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const AuthGate(),
    );
  }
}

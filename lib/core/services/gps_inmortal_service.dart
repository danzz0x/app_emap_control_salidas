import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/misiones/models/mision_model.dart';
import '../../features/misiones/services/mision_service.dart';

// ==========================================================
// ⚙️ 1. CONFIGURACIÓN DEL SERVICIO SILENCIOSO
// ==========================================================
Future<void> inicializarGpsInmortal() async {
  final service = FlutterBackgroundService();

  // 🔥 Canal silencioso de baja importancia (cero vibración, cero sonido)
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'canal_fantasma_silencioso',
    'GPS EMAP (Rastreo Silencioso)',
    description: 'Mantiene el rastreo de tu misión activo en segundo plano',
    importance: Importance.low,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStartGPS,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: 'canal_fantasma_silencioso', // 🔥 DEBE COINCIDIR
      initialNotificationTitle: '📍 Misión EMAP Activa',
      initialNotificationContent: 'Calculando distancia...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStartGPS,
    ),
  );
}

// ==========================================================
// 👻 2. EL UNIVERSO PARALELO (HEADLESS ISOLATE) BLINDADO
// ==========================================================
@pragma('vm:entry-point')
void onStartGPS(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  try {
    // 🔥 1. INICIALIZAR FIREBASE CORRECTAMENTE
    await Firebase.initializeApp();

    // 🔥 2. CURAR LA AMNESIA DE LA MEMORIA
    final prefs = await SharedPreferences.getInstance();
    await prefs
        .reload(); // <- CRÍTICO: Obliga a leer el disco físico, no el caché
    final String? misionId = prefs.getString('mision_activa_id');

    if (service is AndroidServiceInstance) {
      service
          .on('setAsForeground')
          .listen((event) => service.setAsForegroundService());
      service
          .on('setAsBackground')
          .listen((event) => service.setAsBackgroundService());
    }

    // 🛑 Orden manual de apagado desde la pantalla
    service.on('stopService').listen((event) async {
      debugPrint("💀 Fantasma GPS: Apagando motores por orden del usuario.");
      await service.stopSelf();
    });

    if (misionId == null) {
      debugPrint(
        "❌ Fantasma GPS: AMNESIA. El ID de la misión es null. Me apago.",
      );
      service.stopSelf();
      return;
    }

    // ========================================================
    // 🧠 AQUÍ INICIA LA LÓGICA MATEMÁTICA Y LA MEMORIA DEL FANTASMA
    // ========================================================
    bool salioDeLaBase = false;
    final double emapLatitud = -19.572332699484406;
    final double emapLongitud = -65.75202927545779;

    // 🔥 Instanciamos TU servicio para usar la Arquitectura Limpia
    final MisionService misionService = MisionService();

    final LocationSettings locationSettings = AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 40, // Se actualiza cada 10 metros
    );

    debugPrint("Fantasma GPS: Iniciando rastreo REAL para la misión $misionId");

    // 🛡️ EL BLINDAJE ESTÁ EN EL ON ERROR AL FINAL DEL STREAM
    Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (Position position) async {
        // ⏰ REGLA 1: CORTE DE HORARIO (19:00 hrs)
        if (DateTime.now().hour >= 19) {
          await _autoFinalizarMision(
            service,
            misionId,
            misionService,
            "Hora límite (19:00) alcanzada.",
          );
          return;
        }

        // 📏 REGLA 2: DISTANCIA A LA BASE
        double distanciaEmap = Geolocator.distanceBetween(
          emapLatitud,
          emapLongitud,
          position.latitude,
          position.longitude,
        );

        if (!salioDeLaBase && distanciaEmap > 150) {
          salioDeLaBase = true;
          debugPrint("Fantasma GPS: El trabajador salió de la base (>150m).");
        } else if (salioDeLaBase && distanciaEmap < 50) {
          debugPrint("Fantasma GPS: El trabajador regresó a la base (<23m).");
          await _autoFinalizarMision(
            service,
            misionId,
            misionService,
            "Regreso a la base de EMAP detectado.",
          );
          return;
        }

        // 📍 SI PASA LAS REGLAS, ACTUALIZAMOS LA NOTIFICACIÓN
        if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(
            title: '📍 Misión en curso',
            content: 'Distancia a base: ${distanciaEmap.toInt()} metros',
          );
        }

        // ☁️ ARQUITECTURA LIMPIA: Usamos TU función que ya tiene el arrayUnion
        try {
          await misionService.actualizarUbicacion(
            misionId,
            position.latitude,
            position.longitude,
          );
        } catch (e) {
          debugPrint("Error al usar MisionService desde el Fantasma: $e");
        }
      },
      // 🔥 EL CASCO PROTECTOR CONTRA APAGONES DE GPS
      onError: (error) {
        debugPrint(
          "💥 Fantasma GPS: Error de señal o antena apagada -> $error",
        );
        if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(
            title: '⚠️ Señal GPS Perdida',
            content: 'Por favor, enciende tu ubicación.',
          );
        }
      },
    );
  } catch (fatalError) {
    // 🔥 EL DIAGNÓSTICO FINAL: SI EL FANTASMA MUERE, ESTO NOS DIRÁ POR QUÉ
    debugPrint("🚨 CRASHEO FATAL EN EL FANTASMA: $fatalError");
  }
}

// ==========================================================
// 🗡️ 3. FUNCIÓN DE AUTO-DESTRUCCIÓN INTELIGENTE
// ==========================================================
Future<void> _autoFinalizarMision(
  ServiceInstance service,
  String misionId,
  MisionService misionService,
  String razonDelCierre,
) async {
  debugPrint("🏁 Auto-Finalizando misión desde el Fantasma: $razonDelCierre");

  try {
    // 1. Cerramos la misión en Firebase usando tu servicio
    await misionService.actualizarEstadoMision(
      misionId,
      EstadoMision.completada,
    );

    // 2. Le ponemos la hora de fin y un comentario automático de por qué se cerró
    // (Esto se queda directo con Firestore porque es un dato de auditoría interna del sistema)
    await FirebaseFirestore.instance
        .collection('misiones')
        .doc(misionId)
        .update({
          'hora_fin': FieldValue.serverTimestamp(),
          'nota_cierre_sistema': razonDelCierre,
        });
  } catch (e) {
    debugPrint("Error cerrando misión en Firebase: $e");
  }

  // 3. Limpiamos la memoria del disco
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('mision_activa_id');

  // 4. Cambiamos la notificación visible para avisarle al trabajador
  if (service is AndroidServiceInstance) {
    service.setForegroundNotificationInfo(
      title: '✅ Misión Completada',
      content: razonDelCierre,
    );
  }

  // 5. El Fantasma se apaga a sí mismo
  service.stopSelf();
}

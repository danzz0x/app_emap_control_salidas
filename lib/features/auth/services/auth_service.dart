import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; // 👈 NUEVO IMPORT
import '../../../core/services/session.dart';

class AuthService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;
  static final _messaging =
      FirebaseMessaging.instance; // 👈 INSTANCIA DE MESSAGING

  static Future<void> login({
    required String email,
    required String password,
  }) async {
    try {
      // 1. Login en Authentication
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = cred.user!.uid;

      // 2. Traer datos del usuario desde Firestore
      final docRef = _firestore.collection('usuarios').doc(uid);
      final doc = await docRef.get();

      if (!doc.exists) {
        await _auth.signOut();
        throw Exception("Usuario no registrado en la base de datos de EMAP.");
      }

      final data = doc.data()!;

      // Verificamos si el usuario fue dado de baja
      if (data['activo'] == false) {
        await _auth.signOut();
        throw Exception("Esta cuenta ha sido dada de baja por administración.");
      }

      final rol = data['rol'];

      // 3. 🔔 GESTIÓN DEL TOKEN DE NOTIFICACIONES (NUEVO)
      // Pedimos permiso (Importante para Android 13+ e iOS)
      await _messaging.requestPermission();

      // Obtenemos la "matrícula" única de este celular
      final fcmToken = await _messaging.getToken();

      if (fcmToken != null) {
        // Actualizamos el documento del usuario en Firestore con su nuevo token
        await docRef.update({
          'fcm_token': fcmToken,
          'ultimo_acceso': FieldValue.serverTimestamp(),
        });
      }

      // 4. Guardar en la sesión global para usar en la app
      Session.rol = rol;
      Session.uid = uid;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' ||
          e.code == 'wrong-password' ||
          e.code == 'invalid-credential') {
        throw Exception("Correo o contraseña incorrectos.");
      } else if (e.code == 'invalid-email') {
        throw Exception("El formato del correo es inválido.");
      } else if (e.code == 'user-disabled') {
        throw Exception("Esta cuenta ha sido deshabilitada en el sistema.");
      } else {
        throw Exception("Error al iniciar sesión: ${e.message}");
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  static Future<void> logout() async {
    final uid = _auth.currentUser?.uid;

    if (uid != null) {
      // 🔔 BORRAR EL TOKEN (NUEVO)
      // Borramos el token para no seguir recibiendo notificaciones en este aparato
      await _firestore.collection('usuarios').doc(uid).update({
        'fcm_token': FieldValue.delete(),
      });
    }

    await _auth.signOut();
    Session.rol = null;
    Session.uid = null;
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String nombre;
  final String ci;
  final String email;
  final String cargo;
  final String rol;
  final bool activo;
  final String? fcmToken;
  final DateTime? ultimoAcceso;

  UserModel({
    required this.uid,
    required this.nombre,
    required this.ci,
    required this.email,
    required this.cargo,
    required this.rol,
    required this.activo,
    this.fcmToken,
    this.ultimoAcceso,
  });

  factory UserModel.fromMap(String id, Map<String, dynamic> data) {
    return UserModel(
      uid: id,
      nombre: data['nombre'] ?? 'Sin nombre',
      ci: data['ci'] ?? 'Sin CI',
      email: data['email'] ?? 'Sin correo',
      cargo: data['cargo'] ?? 'Sin cargo',
      rol: data['rol'] ?? 'trabajador',
      activo: data['activo'] ?? true,
      fcmToken: data['fcm_token'],
      ultimoAcceso: (data['ultimo_acceso'] as Timestamp?)?.toDate(),
    );
  }
}

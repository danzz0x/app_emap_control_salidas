import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/user_model.dart';

class UserService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'southamerica-east1',
  );

  // 📡 LECTURA: Directo a Firestore
  Stream<List<UserModel>> obtenerUsuarios() {
    return _db.collection('usuarios').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => UserModel.fromMap(doc.id, doc.data()))
          .toList();
    });
  }

  // 🔐 CREAR: Cloud Function
  Future<void> crearUsuario({
    required String email,
    required String password,
    required String nombre,
    required String cargo,
    required String rolNuevo,
    required String ci,
  }) async {
    try {
      await _functions.httpsCallable('crearUsuario').call({
        'email': email,
        'password': password,
        'nombre': nombre,
        'ci': ci,
        'cargo': cargo,
        'rolNuevo': rolNuevo,
      });
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'Error al comunicarse con el servidor');
    } catch (e) {
      throw Exception('Error inesperado: $e');
    }
  }

  // 🔐 EDITAR: Cloud Function
  Future<void> editarUsuario({
    required String uid,
    required String nombre,
    required String ci,
    required String cargo,
    required String rolNuevo,
  }) async {
    try {
      await _functions.httpsCallable('editarUsuario').call({
        'uid': uid,
        'nombre': nombre,
        'ci': ci,
        'cargo': cargo,
        'rolNuevo': rolNuevo,
      });
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'Error al actualizar usuario');
    }
  }

  // 🔐 DAR DE BAJA / ACTIVAR: Cloud Function
  Future<void> cambiarEstadoUsuario(String uid, bool nuevoEstado) async {
    try {
      await _functions.httpsCallable('cambiarEstadoUsuario').call({
        'uid': uid,
        'activo': nuevoEstado,
      });
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'Error al cambiar el estado del usuario');
    }
  }
}

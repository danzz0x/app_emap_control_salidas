import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/session.dart';
import '../models/mision_model.dart';

class MisionService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 🚀 FUNCIÓN 1: Solicitar una nueva salida (Para el Trabajador)
  Future<void> solicitarMision({
    required String motivo,
    required String destino,
    required String nombreTrabajador,
  }) async {
    try {
      // 1️⃣ VALIDACIÓN DE SEGURIDAD LOCAL
      // Nos aseguramos de que el usuario realmente esté logueado en la app
      if (Session.uid == null) {
        throw Exception(
          "Sesión inválida. Por favor, cierra sesión y vuelve a entrar.",
        );
      }

      // 2️⃣ EMPAQUETAR LOS DATOS (Usando nuestro Modelo)
      // Convertimos los textos sueltos en un objeto de Dart seguro.
      final nuevaMision = MisionModel(
        trabajadorId: Session.uid!, // Usamos el UID global de la sesión
        nombreTrabajador: nombreTrabajador,
        motivo: motivo,
        destino: destino,
        estado:
            EstadoMision.pendiente, // 🔥 Nace como pendiente OBLIGATORIAMENTE
      );

      // 3️⃣ DISPARAR A FIREBASE
      // Usamos toFirestore() para traducir el objeto Dart a un formato que Firebase entienda.
      await _db.collection('misiones').add(nuevaMision.toFirestore());
    } catch (e) {
      // Si algo falla (ej. base de datos caída), atrapamos el error y lo devolvemos limpio
      throw Exception("Error al solicitar la misión: $e");
    }
  }

  // ... tu función solicitarMision anterior ...

  // 🚀 FUNCIÓN 2: Escuchar misiones pendientes en tiempo real (Para el Jefe)
  Stream<List<MisionModel>> obtenerMisionesPendientes() {
    return _db
        .collection('misiones')
        .where('estado', isEqualTo: EstadoMision.pendiente.toMapValue)
        // Pedimos a Firebase que nos avise cada vez que llegue una nueva
        .snapshots()
        .map((snapshot) {
          final lista = snapshot.docs
              .map((doc) => MisionModel.fromFirestore(doc.id, doc.data()))
              .toList();

          // Ordenamos localmente para que las más recientes salgan arriba
          // (Lo hacemos localmente para evitar pedirte que configures índices complejos en Firebase)
          lista.sort((a, b) {
            final fechaA = a.horaSolicitud ?? DateTime.now();
            final fechaB = b.horaSolicitud ?? DateTime.now();
            return fechaB.compareTo(fechaA);
          });

          return lista;
        });
  }

  // 🚀 FUNCIÓN 3: Aprobar o Rechazar (Para el Jefe)
  // 🚀 FUNCIÓN 3: Aprobar o Rechazar con DOBLE FIRMA (Para el Jefe)
  Future<void> responderMision(
    String misionId,
    EstadoMision nuevoEstado, {
    String?
    motivoRechazo, // 👈 NUEVO: Parámetro opcional para recibir el motivo
  }) async {
    final misionRef = _db.collection('misiones').doc(misionId);
    final miUid = Session.uid!;

    try {
      // Usamos runTransaction para evitar choques si dos jefes aprueban al mismo tiempo
      await _db.runTransaction((transaction) async {
        // 1. Leemos la misión actual
        final misionSnapshot = await transaction.get(misionRef);
        if (!misionSnapshot.exists) throw Exception("La misión ya no existe.");

        // 2. Leemos el nombre del jefe actual (para que quede registrado quién firmó)
        final jefeSnapshot = await transaction.get(
          _db.collection('usuarios').doc(miUid),
        );
        final nombreJefe = jefeSnapshot.data()?['nombre'] ?? 'Jefe Desconocido';

        // --- CASO A: EL JEFE RECHAZA ---
        if (nuevoEstado == EstadoMision.rechazado) {
          // Preparamos los datos básicos del rechazo
          Map<String, dynamic> datosRechazo = {
            'estado': EstadoMision.rechazado.toMapValue,
            'rechazado_por': nombreJefe, // Guardamos al "malo" de la película
          };

          // 🔥 Si el jefe escribió un motivo, lo inyectamos en la base de datos
          if (motivoRechazo != null && motivoRechazo.isNotEmpty) {
            datosRechazo['motivo_rechazo'] = motivoRechazo;
          }

          transaction.update(misionRef, datosRechazo);
          return; // Terminamos aquí
        }

        // --- CASO B: EL JEFE APRUEBA ---
        List<dynamic> firmasActuales = misionSnapshot.data()?['firmas'] ?? [];

        // Validación: ¿Este jefe ya firmó?
        bool yaFirmo = firmasActuales.any((firma) => firma['jefe_id'] == miUid);
        if (yaFirmo) throw Exception("Ya has firmado esta solicitud.");

        // Agregamos la nueva firma
        firmasActuales.add({
          'jefe_id': miUid,
          'nombre_jefe': nombreJefe,
          'fecha': Timestamp.now(),
        });

        // LÓGICA DE NEGOCIO: ¿Ya llegamos a 2 firmas?
        String estadoFinal = (firmasActuales.length >= 2)
            ? EstadoMision.aprobado.toMapValue
            : EstadoMision
                  .pendiente
                  .toMapValue; // Si solo va 1, sigue pendiente

        // Guardamos todo de golpe
        transaction.update(misionRef, {
          'firmas': firmasActuales,
          'estado': estadoFinal,
        });
      });
    } catch (e) {
      throw Exception("Error al procesar: $e");
    }
  } // 🚀 FUNCIÓN 4: Escuchar la misión activa del trabajador (Para la Pantalla Inteligente)

  // ==========================================================
  // 📡 OBTENER MISIÓN ACTIVA DEL TRABAJADOR
  // ==========================================================
  Stream<MisionModel?> obtenerMisionActivaTrabajador() {
    return _db
        .collection('misiones')
        // Buscamos solo las misiones de este trabajador específico
        .where('trabajador_id', isEqualTo: Session.uid)
        // 🔥 Buscamos misiones pendientes, aprobadas, en misión y RECHAZADAS (para el feedback)
        .where(
          'estado',
          whereIn: [
            EstadoMision.pendiente.toMapValue,
            EstadoMision.aprobado.toMapValue,
            EstadoMision.enMision.toMapValue,
            EstadoMision
                .rechazado
                .toMapValue, // 👈 ¡EL FANTASMA HA SIDO ATRAPADO!
          ],
        )
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty)
            return null; // No hay misiones activas (Mostrará el formulario)

          // Si hay una, la devolvemos (Mostrará la tarjeta de estado o de rechazo)
          final doc = snapshot.docs.first;
          return MisionModel.fromFirestore(doc.id, doc.data());
        });
  }

  // 🚀 FUNCIÓN 5: Cambiar el estado de la misión (Ej: de 'aprobado' a 'en_mision')
  Future<void> actualizarEstadoMision(
    String misionId,
    EstadoMision nuevoEstado,
  ) async {
    await _db.collection('misiones').doc(misionId).update({
      'estado': nuevoEstado.toMapValue,
    });
  }

  // 🚀 FUNCIÓN 6: Guardar la coordenada GPS en tiempo real
  Future<void> actualizarUbicacion(
    String misionId,
    double lat,
    double lng,
  ) async {
    await _db.collection('misiones').doc(misionId).update({
      // 1. Guardamos la ubicación actual para el mapa en vivo
      'ubicacion_actual': GeoPoint(lat, lng),
      // 2. Guardamos el historial de la ruta agregando el punto a una lista
      'ruta': FieldValue.arrayUnion([GeoPoint(lat, lng)]),
    });
  }

  // ==========================================================
  // ⏱️ AUTO-APROBAR MISIÓN (Desencadenado por el trabajador)
  // ==========================================================
  Future<void> autoAprobarMision(String misionId) async {
    final misionRef = _db.collection('misiones').doc(misionId);

    try {
      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(misionRef);
        if (!snapshot.exists) throw Exception("La misión no existe.");

        List<dynamic> firmasActuales = snapshot.data()?['firmas'] ?? [];

        // Validamos por seguridad que tenga exactamente 1 firma
        if (firmasActuales.length == 1) {
          // Agregamos la segunda firma a nombre del Sistema
          firmasActuales.add({
            'jefe_id': 'sistema_auto',
            'nombre_jefe': 'Sistema (Por Tiempo)',
            'fecha': Timestamp.now(),
          });

          // Guardamos todo y pasamos a aprobado
          transaction.update(misionRef, {
            'firmas': firmasActuales,
            'estado': EstadoMision.aprobado.toMapValue,
            'nota_sistema': 'Auto-aprobado tras 3 minutos de espera.',
          });
        }
      });
    } catch (e) {
      throw Exception("Error al auto-aprobar: $e");
    }
  }
}

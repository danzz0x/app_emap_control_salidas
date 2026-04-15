import 'package:cloud_firestore/cloud_firestore.dart';

enum EstadoMision { pendiente, aprobado, rechazado, enMision, completada }

extension EstadoMisionExtension on EstadoMision {
  String get toMapValue {
    switch (this) {
      case EstadoMision.pendiente:
        return 'pendiente';
      case EstadoMision.aprobado:
        return 'aprobado';
      case EstadoMision.rechazado:
        return 'rechazado';
      case EstadoMision.enMision:
        return 'en_mision';
      case EstadoMision.completada:
        return 'completada';
    }
  }

  static EstadoMision fromString(String value) {
    return EstadoMision.values.firstWhere(
      (e) => e.toMapValue == value,
      orElse: () => EstadoMision.pendiente,
    );
  }
}

class MisionModel {
  final String? id;
  final String trabajadorId;
  final String nombreTrabajador;
  final String motivo;
  final String destino;
  final EstadoMision estado;
  final DateTime? horaSolicitud;

  // 🔥 NUEVOS CAMPOS PARA EL DOBLE CHECK
  final List<Map<String, dynamic>>
  firmas; // Guardará: {jefe_id, nombre_jefe, fecha}
  final String? rechazadoPor; // Guarda el nombre del jefe que dijo "NO"

  final String? motivoRechazo; // En las propiedades

  MisionModel({
    this.id,
    required this.trabajadorId,
    required this.nombreTrabajador,
    required this.motivo,
    required this.destino,
    required this.estado,
    this.horaSolicitud,
    this.firmas = const [], // Inicia vacía por defecto
    this.rechazadoPor,
    this.motivoRechazo,
  });

  factory MisionModel.fromFirestore(String docId, Map<String, dynamic> data) {
    return MisionModel(
      id: docId,
      trabajadorId: data['trabajador_id'] ?? '',
      nombreTrabajador: data['nombre_trabajador'] ?? 'Desconocido',
      motivo: data['motivo'] ?? '',
      destino: data['destino'] ?? '',
      estado: EstadoMisionExtension.fromString(data['estado'] ?? 'pendiente'),
      horaSolicitud: (data['hora_solicitud'] as Timestamp?)?.toDate(),

      // Mapeamos la lista de firmas asegurándonos de que sea una lista válida
      firmas: List<Map<String, dynamic>>.from(data['firmas'] ?? []),
      rechazadoPor: data['rechazado_por'],
      motivoRechazo: data['motivo_rechazo'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'trabajador_id': trabajadorId,
      'nombre_trabajador': nombreTrabajador,
      'motivo': motivo,
      'destino': destino,
      'estado': estado.toMapValue,
      'hora_solicitud': horaSolicitud != null
          ? Timestamp.fromDate(horaSolicitud!)
          : FieldValue.serverTimestamp(),
      'firmas': firmas,
      'rechazado_por': rechazadoPor,
      'motivo_rechazo': motivoRechazo,
    };
  }
}

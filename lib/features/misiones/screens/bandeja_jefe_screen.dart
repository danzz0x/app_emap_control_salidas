import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/session.dart';
import '../models/mision_model.dart';
import '../services/mision_service.dart';

class BandejaJefeScreen extends StatefulWidget {
  const BandejaJefeScreen({super.key});

  @override
  State<BandejaJefeScreen> createState() => _BandejaJefeScreenState();
}

class _BandejaJefeScreenState extends State<BandejaJefeScreen> {
  final _misionService = MisionService();

  // ==========================================================
  // ⚙️ FUNCIÓN ACTUALIZADA: PROCESAR SOLICITUD CON FEEDBACK
  // ==========================================================
  Future<void> _procesarSolicitud(
    MisionModel mision,
    EstadoMision nuevoEstado,
  ) async {
    final esAprobacion = nuevoEstado == EstadoMision.aprobado;
    final accion = esAprobacion ? 'APROBAR' : 'RECHAZAR';
    final motivoRechazoCtrl = TextEditingController();

    // El diálogo ahora espera recibir un String de vuelta
    final resultado = await showDialog<String>(
      context: context,
      builder: (context) {
        // StatefulBuilder nos permite actualizar la vista solo de este cuadrito
        // (útil para habilitar/deshabilitar el botón mientras el jefe escribe)
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text("¿$accion Misión?"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Trabajador: ${mision.nombreTrabajador}\nDestino: ${mision.destino}",
                  ),

                  // 🔥 Si está rechazando, mostramos el input del motivo
                  if (!esAprobacion) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: motivoRechazoCtrl,
                      decoration: InputDecoration(
                        labelText: "Motivo del rechazo (Obligatorio)",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      maxLines: 2,
                      // Cada vez que teclea, refrescamos el estado del botón
                      onChanged: (val) => setStateDialog(() {}),
                    ),
                  ],
                ],
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text(
                    "Cancelar",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: esAprobacion
                        ? AppTheme.primaryGreen
                        : Colors.red,
                  ),
                  // LÓGICA DE BLOQUEO: Si es rechazo y está vacío, desactivamos el botón (null)
                  onPressed:
                      (!esAprobacion && motivoRechazoCtrl.text.trim().isEmpty)
                      ? null
                      : () {
                          // Devolvemos 'APROBADO' o el texto del motivo
                          Navigator.pop(
                            context,
                            esAprobacion
                                ? 'APROBADO'
                                : motivoRechazoCtrl.text.trim(),
                          );
                        },
                  child: Text(
                    "Sí, $accion",
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    // Si el usuario cerró el cuadro o canceló, abortamos
    if (resultado == null) return;

    // Mostramos un circulito de carga para bloquear la pantalla mientras guarda
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryGreen),
      ),
    );

    try {
      // Determinamos si hay un motivo de rechazo que enviar a Firebase
      String? motivo = resultado == 'APROBADO' ? null : resultado;

      // Llamamos al servicio (¡Asegúrate de que tu servicio acepte el motivoRechazo!)
      await _misionService.responderMision(
        mision.id!,
        nuevoEstado,
        motivoRechazo: motivo,
      );

      if (!mounted) return;
      Navigator.pop(context); // Cierra el circulito de carga

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            esAprobacion
                ? "Firma registrada correctamente."
                : "Misión rechazada y notificada.",
          ),
          backgroundColor: esAprobacion ? AppTheme.primaryGreen : Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Cierra el circulito de carga
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Helper para mostrar la hora bonita (ej. 14:30)
  String _formatearHora(DateTime? fecha) {
    if (fecha == null) return "Hora desconocida";
    final hora = fecha.hour.toString().padLeft(2, '0');
    final min = fecha.minute.toString().padLeft(2, '0');
    return "$hora:$min";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<MisionModel>>(
        stream: _misionService.obtenerMisionesPendientes(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryGreen),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                "Error: ${snapshot.error}",
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          final misiones = snapshot.data ?? [];

          if (misiones.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: 80,
                    color: Colors.grey.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Bandeja limpia",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const Text(
                    "No hay solicitudes pendientes.",
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: misiones.length,
            itemBuilder: (context, index) {
              final mision = misiones[index];

              // Validamos si el jefe actual YA firmó esta misión
              final miUid = Session.uid;
              final yaFirmo = mision.firmas.any(
                (firma) => firma['jefe_id'] == miUid,
              );

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Cabecera: Nombre y Hora
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const CircleAvatar(
                                backgroundColor: AppTheme.institutionalPurple,
                                radius: 16,
                                child: Icon(
                                  Icons.person,
                                  size: 18,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                mision.nombreTrabajador,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            _formatearHora(mision.horaSolicitud),
                            style: const TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),

                      // Cuerpo: Destino y Motivo
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            color: Colors.redAccent,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              mision.destino,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.work_outline,
                            color: Colors.grey,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              mision.motivo,
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 🔥 ZONA DE FEEDBACK: Mostrar cuántas firmas van
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.orange.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.draw,
                              color: Colors.orange,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                mision.firmas.isEmpty
                                    ? "Esperando firmas (0/2)"
                                    : "Firmas (1/2): Aprobado por ${mision.firmas.first['nombre_jefe']}",
                                style: const TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 🔥 ZONA DE BOTONES (Solo se muestran si NO ha firmado aún)
                      if (yaFirmo)
                        const Center(
                          child: Text(
                            "Ya aprobaste esta solicitud.\nEsperando al segundo supervisor.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(color: Colors.red),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                icon: const Icon(Icons.close),
                                label: const Text("Rechazar"),
                                onPressed: () => _procesarSolicitud(
                                  mision,
                                  EstadoMision.rechazado,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryGreen,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                icon: const Icon(Icons.check),
                                label: const Text("Aprobar"),
                                onPressed: () => _procesarSolicitud(
                                  mision,
                                  EstadoMision.aprobado,
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

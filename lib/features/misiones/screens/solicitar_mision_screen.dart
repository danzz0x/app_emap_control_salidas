import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/services/session.dart';
import '../models/mision_model.dart';
import '../services/mision_service.dart';

class SolicitarMisionScreen extends StatefulWidget {
  const SolicitarMisionScreen({super.key});

  @override
  State<SolicitarMisionScreen> createState() => _SolicitarMisionScreenState();
}

class _SolicitarMisionScreenState extends State<SolicitarMisionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _motivoCtrl = TextEditingController();
  final _destinoOtroCtrl = TextEditingController();
  bool _isLoading = false;
  final _misionService = MisionService();

  final List<String> _opcionesDestino = [
    'ALCALDÍA',
    'BANCO',
    'INSTITUCIÓN',
    'SSUP',
    'COTIZACIONES',
    'CONTRALORÍA',
    'OTRO',
  ];

  String? _destinoSeleccionado;

  @override
  void dispose() {
    _motivoCtrl.dispose();
    _destinoOtroCtrl.dispose();
    super.dispose();
  }

  Future<void> _iniciarMision(String misionId) async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Por favor, ENCIENDE EL GPS para poder salir.'),
          backgroundColor: Colors.orange,
        ),
      );
      await Geolocator.openLocationSettings();
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '❌ Necesitamos acceso al GPS para iniciar la misión.',
            ),
          ),
        );
        return;
      }
    }

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('mision_activa_id', misionId);

    await _misionService.actualizarEstadoMision(
      misionId,
      EstadoMision.enMision,
    );
    await FirebaseFirestore.instance
        .collection('misiones')
        .doc(misionId)
        .update({'hora_inicio': FieldValue.serverTimestamp()});

    final service = FlutterBackgroundService();
    await service.startService();
  }

  Future<void> _finalizarMision(String misionId) async {
    final service = FlutterBackgroundService();
    service.invoke("stopService");

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('mision_activa_id');

    await _misionService.actualizarEstadoMision(
      misionId,
      EstadoMision.completada,
    );
    await FirebaseFirestore.instance
        .collection('misiones')
        .doc(misionId)
        .update({'hora_fin': FieldValue.serverTimestamp()});

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("🏁 Misión finalizada con éxito."),
        backgroundColor: AppTheme.primaryGreen,
      ),
    );
  }

  Future<void> _mostrarDialogoCancelacion(String misionId) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
              SizedBox(width: 8),
              Text(
                "Cancelar Misión",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: const Text(
            "¿Estás seguro de que deseas cancelar tu solicitud de salida?\n\nEsta acción eliminará el registro actual y tendrás que pedir permiso nuevamente.",
            style: TextStyle(fontSize: 15),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text(
                "NO, MANTENER",
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                "SÍ, CANCELAR",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                _cancelarSolicitud(misionId);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _cancelarSolicitud(String misionId) async {
    try {
      await FirebaseFirestore.instance
          .collection('misiones')
          .doc(misionId)
          .delete();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("🚫 Solicitud cancelada exitosamente."),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      debugPrint("Error cancelando misión: $e");
    }
  }

  Future<void> _enviarSolicitud() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(Session.uid)
          .get();
      final nombreTrabajador = userDoc.data()?['nombre'] ?? 'Desconocido';
      final destinoFinal = (_destinoSeleccionado == 'OTRO')
          ? _destinoOtroCtrl.text.trim()
          : _destinoSeleccionado!;

      await _misionService.solicitarMision(
        motivo: _motivoCtrl.text.trim(),
        destino: destinoFinal,
        nombreTrabajador: nombreTrabajador,
      );

      if (!mounted) return;
      _motivoCtrl.clear();
      _destinoOtroCtrl.clear();
      setState(() => _destinoSeleccionado = null);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<MisionModel?>(
        stream: _misionService.obtenerMisionActivaTrabajador(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                "Error al cargar la misión: ${snapshot.error}",
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            );
          }

          final misionActiva = snapshot.data;

          if (misionActiva == null) return _buildFormulario();

          if (misionActiva.firmas.length == 1 &&
              misionActiva.estado != EstadoMision.aprobado &&
              misionActiva.estado != EstadoMision.rechazado) {
            return StreamBuilder(
              stream: Stream.periodic(const Duration(seconds: 1)),
              builder: (context, _) {
                return _buildPantallaSeguimiento(misionActiva);
              },
            );
          }

          return _buildPantallaSeguimiento(misionActiva);
        },
      ),
    );
  }

  Widget _buildPantallaSeguimiento(MisionModel mision) {
    Color colorEstado = Colors.orange;
    IconData iconoEstado = Icons.hourglass_empty;
    String tituloEstado = "Esperando Revisión";
    String subtitulo = "Ningún admin ha revisado tu solicitud aún.";
    Widget? botonAccion;

    if (mision.estado == EstadoMision.rechazado) {
      colorEstado = Colors.red;
      iconoEstado = Icons.cancel;
      tituloEstado = "Misión Rechazada";
      subtitulo =
          'Motivo: ${mision.motivoRechazo ?? "No se especificó un motivo."}';

      botonAccion = ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey.shade800,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: const Icon(Icons.delete_sweep),
        label: const Text(
          "ENTENDIDO (NUEVA SOLICITUD)",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        onPressed: () => _cancelarSolicitud(mision.id!),
      );
    } else if (mision.estado == EstadoMision.enMision) {
      colorEstado = Colors.blue;
      iconoEstado = Icons.satellite_alt;
      tituloEstado = "Transmitiendo GPS...";
      subtitulo = "Tus superiores están monitoreando tu ubicación en vivo.";

      botonAccion = ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 50),
        ),
        icon: const Icon(Icons.stop_circle),
        label: const Text(
          "FINALIZAR MISIÓN",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        onPressed: () => _finalizarMision(mision.id!),
      );
    } else if (mision.estado == EstadoMision.aprobado) {
      colorEstado = AppTheme.primaryGreen;
      iconoEstado = Icons.check_circle_outline;
      tituloEstado = "¡Misión Aprobada!";
      subtitulo = "Ya tienes permiso para salir. Inicia el recorrido.";

      botonAccion = Column(
        children: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
            ),
            icon: const Icon(Icons.play_arrow),
            label: const Text(
              "INICIAR RECORRIDO",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            onPressed: () => _iniciarMision(mision.id!),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => _mostrarDialogoCancelacion(mision.id!),
            icon: const Icon(Icons.cancel, color: Colors.red),
            label: const Text(
              "Cancelar Salida",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      );
    } else if (mision.firmas.length == 1) {
      colorEstado = Colors.teal;
      iconoEstado = Icons.timer;

      DateTime fechaFirma = (mision.firmas.first['fecha'] as Timestamp)
          .toDate();
      Duration tiempoPasado = DateTime.now().difference(fechaFirma);
      int segundosRestantesTotales = 360 - tiempoPasado.inSeconds;

      if (segundosRestantesTotales <= 0) {
        tituloEstado = "Tiempo de espera finalizado";
        subtitulo =
            "El segundo admin no respondió a tiempo. El sistema te permite salir o puedes cancelar el viaje.";

        botonAccion = Column(
          children: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
              icon: const Icon(Icons.sensor_door_outlined),
              label: const Text(
                "AUTO-APROBAR SALIDA",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              onPressed: () async {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Auto-aprobando misión..."),
                    duration: Duration(seconds: 1),
                  ),
                );
                await _misionService.autoAprobarMision(mision.id!);
              },
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                minimumSize: const Size(double.infinity, 50),
              ),
              icon: const Icon(Icons.cancel_presentation),
              label: const Text(
                "CANCELAR SOLICITUD",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () => _mostrarDialogoCancelacion(mision.id!),
            ),
          ],
        );
      } else {
        int minutos = segundosRestantesTotales ~/ 60;
        int segundos = segundosRestantesTotales % 60;
        String tiempoFormateado =
            "${minutos.toString().padLeft(2, '0')}:${segundos.toString().padLeft(2, '0')}";

        tituloEstado = "Firma 1 de 2 lista";
        subtitulo =
            "Aprobado por ${mision.firmas.first['nombre_jefe']}.\n\nPodrás forzar tu salida en:\n⏳ $tiempoFormateado";

        botonAccion = TextButton.icon(
          onPressed: () => _mostrarDialogoCancelacion(mision.id!),
          icon: const Icon(Icons.cancel, color: Colors.grey),
          label: const Text(
            "Cancelar solicitud ahora",
            style: TextStyle(color: Colors.grey),
          ),
        );
      }
    } else {
      botonAccion = TextButton.icon(
        onPressed: () => _mostrarDialogoCancelacion(mision.id!),
        icon: const Icon(Icons.cancel, color: Colors.grey),
        label: const Text(
          "Cancelar solicitud",
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: colorEstado.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: colorEstado.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: Column(
              children: [
                Icon(iconoEstado, size: 80, color: colorEstado),
                const SizedBox(height: 16),
                Text(
                  tituloEstado,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: colorEstado,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  subtitulo,
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          if (botonAccion != null) botonAccion,
          const SizedBox(height: 24),
          Card(
            elevation: 0,
            color: Colors.grey.shade100,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Destino: ${mision.destino}",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                  Row(
                    children: [
                      const Icon(Icons.work_outline, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          mision.motivo,
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormulario() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Detalles de la Misión",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.institutionalPurple,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Llena este formulario para solicitar autorización de salida.",
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _motivoCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: "Motivo de la salida",
                prefixIcon: const Icon(Icons.work_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? "Obligatorio" : null,
            ),
            const SizedBox(height: 24),
            const Text(
              "Destino",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            FormField<String>(
              validator: (value) =>
                  _destinoSeleccionado == null ? 'Selecciona un destino' : null,
              builder: (state) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 10.0,
                    runSpacing: 10.0,
                    children: _opcionesDestino.map((destino) {
                      final isSelected = _destinoSeleccionado == destino;
                      return InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          setState(() {
                            _destinoSeleccionado = destino;
                            state.didChange(destino);
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.primaryGreen
                                : Colors.white,
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.primaryGreen
                                  : Colors.grey.shade300,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            destino,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.black87,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  if (state.hasError)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        state.errorText!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
            if (_destinoSeleccionado == 'OTRO') ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _destinoOtroCtrl,
                decoration: InputDecoration(
                  labelText: "Especifique",
                  prefixIcon: const Icon(Icons.location_on_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? "Especifique el destino"
                    : null,
              ),
            ],
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isLoading ? null : _enviarSolicitud,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "ENVIAR SOLICITUD",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

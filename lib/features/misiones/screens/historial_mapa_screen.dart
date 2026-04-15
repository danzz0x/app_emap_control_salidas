import 'dart:async';
import 'package:control_emap/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // 👈 IMPORTANTE: Necesitas esta librería para formatear la hora (ej: 14:30 PM)

class HistorialMapaScreen extends StatefulWidget {
  final String misionId;
  final String nombreTrabajador;

  const HistorialMapaScreen({
    super.key,
    required this.misionId,
    required this.nombreTrabajador,
  });

  @override
  State<HistorialMapaScreen> createState() => _HistorialMapaScreenState();
}

class _HistorialMapaScreenState extends State<HistorialMapaScreen> {
  final Completer<GoogleMapController> _controller =
      Completer<GoogleMapController>();

  // Función genérica para formatear las horas
  String _formatearHora(dynamic timestampFirebase) {
    if (timestampFirebase == null) return "--:--";
    DateTime fecha = (timestampFirebase as Timestamp).toDate();
    return DateFormat('HH:mm a').format(
      fecha,
    ); // Te dará "14:30 PM" (Requiere agregar 'intl' al pubspec.yaml si no lo tienes)
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Ruta de ${widget.nombreTrabajador}"),
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('misiones')
            .doc(widget.misionId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError ||
              !snapshot.hasData ||
              !snapshot.data!.exists) {
            return const Center(child: Text("Error al cargar la ruta."));
          }

          var data = snapshot.data!.data() as Map<String, dynamic>;
          List<dynamic>? rutaDinamica = data['ruta'];

          if (rutaDinamica == null || rutaDinamica.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.route_outlined,
                    size: 80,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "No se registró movimiento GPS en esta misión.",
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          List<LatLng> puntosRuta = rutaDinamica.map((punto) {
            GeoPoint geoPoint = punto as GeoPoint;
            return LatLng(geoPoint.latitude, geoPoint.longitude);
          }).toList();

          Set<Marker> marcadores = {
            Marker(
              markerId: const MarkerId('inicio'),
              position: puntosRuta.first,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueGreen,
              ),
              infoWindow: const InfoWindow(title: 'Inicio del recorrido'),
            ),
            Marker(
              markerId: const MarkerId('fin'),
              position: puntosRuta.last,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueRed,
              ),
              infoWindow: const InfoWindow(title: 'Fin del recorrido'),
            ),
          };

          Set<Polyline> polylines = {
            Polyline(
              polylineId: const PolylineId('ruta_historica'),
              points: puntosRuta,
              color: Colors.blue.shade700,
              width: 6,
              jointType: JointType.round,
              startCap: Cap.roundCap,
              endCap: Cap.roundCap,
            ),
          };

          // ==========================================
          // 🕒 LÓGICA DEL TIEMPO
          // (Si no tienes estos campos, usa las firmas o la hora de la solicitud como fallback)
          // ==========================================
          String horaSalida = "--:--";
          String horaRegreso = "--:--";

          // CASO IDEAL: Si guardaste la hora de inicio y fin cuando se presionaron los botones
          if (data['hora_inicio'] != null) {
            horaSalida = _formatearHora(data['hora_inicio']);
          } else if (data['firmas'] != null &&
              (data['firmas'] as List).length == 2) {
            // FALLBACK: Si no tienes 'hora_inicio', usamos la hora en que el 2do jefe firmó
            horaSalida = _formatearHora(data['firmas'][1]['fecha']);
          }

          if (data['hora_fin'] != null) {
            horaRegreso = _formatearHora(data['hora_fin']);
          }

          return Stack(
            children: [
              // 1. EL MAPA DE FONDO
              GoogleMap(
                mapType: MapType.normal,
                initialCameraPosition: CameraPosition(
                  target: puntosRuta.first,
                  zoom: 15,
                ),
                markers: marcadores,
                polylines: polylines,
                onMapCreated: (GoogleMapController controller) {
                  _controller.complete(controller);
                  _ajustarCamaraParaVerTodaLaRuta(controller, puntosRuta);
                },
              ),

              // 2. 🕒 EL PANEL FLOTANTE CON LAS HORAS
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(
                      alpha: 0.95,
                    ), // Efecto cristal suave
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      // BLOQUE DE SALIDA
                      Column(
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.directions_walk,
                                size: 16,
                                color: Colors.green,
                              ),
                              SizedBox(width: 4),
                              Text(
                                "SALIDA",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            horaSalida,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),

                      // DIVISOR
                      Container(
                        width: 1,
                        height: 30,
                        color: Colors.grey.shade300,
                      ),

                      // BLOQUE DE REGRESO
                      Column(
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.flag, size: 16, color: Colors.red),
                              SizedBox(width: 4),
                              Text(
                                "REGRESO",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            horaRegreso,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _ajustarCamaraParaVerTodaLaRuta(
    GoogleMapController controller,
    List<LatLng> puntos,
  ) {
    if (puntos.isEmpty) return;

    double? sur, norte, este, oeste;

    for (var punto in puntos) {
      if (sur == null || punto.latitude < sur) sur = punto.latitude;
      if (norte == null || punto.latitude > norte) norte = punto.latitude;
      if (oeste == null || punto.longitude < oeste) oeste = punto.longitude;
      if (este == null || punto.longitude > este) este = punto.longitude;
    }

    LatLngBounds limites = LatLngBounds(
      southwest: LatLng(sur!, oeste!),
      northeast: LatLng(norte!, este!),
    );

    Future.delayed(const Duration(milliseconds: 500), () {
      controller.animateCamera(CameraUpdate.newLatLngBounds(limites, 50));
    });
  }
}

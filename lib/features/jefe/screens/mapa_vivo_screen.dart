import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MapaVivoScreen extends StatefulWidget {
  final String misionId;
  final String nombreTrabajador;

  const MapaVivoScreen({
    super.key,
    required this.misionId,
    required this.nombreTrabajador,
  });

  @override
  State<MapaVivoScreen> createState() => _MapaVivoScreenState();
}

class _MapaVivoScreenState extends State<MapaVivoScreen> {
  final Completer<GoogleMapController> _controller =
      Completer<GoogleMapController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Rastreando a ${widget.nombreTrabajador}"),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
      ),
      // Escuchamos UN SOLO documento en tiempo real
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('misiones')
            .doc(widget.misionId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          var data = snapshot.data!.data() as Map<String, dynamic>?;

          // Si el GPS del trabajador aún no manda la primera señal
          if (data == null || data['ubicacion_actual'] == null) {
            return const Center(
              child: Text(
                "Esperando señal de GPS del trabajador...",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            );
          }

          // Extraemos el GeoPoint y lo convertimos a LatLng para Google Maps
          GeoPoint geoPoint = data['ubicacion_actual'];
          LatLng posicionActual = LatLng(geoPoint.latitude, geoPoint.longitude);

          // Movemos la cámara suavemente a la nueva posición cada vez que se actualiza
          _moverCamara(posicionActual);

          return GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: CameraPosition(
              target: posicionActual,
              zoom: 16.5,
            ),
            markers: {
              Marker(
                markerId: const MarkerId('marcador_trabajador'),
                position: posicionActual,
                infoWindow: InfoWindow(
                  title: widget.nombreTrabajador,
                  snippet: "Destino: ${data['destino']}",
                ),
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueBlue,
                ),
              ),
            },
            onMapCreated: (GoogleMapController controller) {
              if (!_controller.isCompleted) {
                _controller.complete(controller);
              }
            },
          );
        },
      ),
    );
  }

  // Función para animar la cámara y seguir al trabajador
  Future<void> _moverCamara(LatLng pos) async {
    if (_controller.isCompleted) {
      final GoogleMapController controller = await _controller.future;
      controller.animateCamera(CameraUpdate.newLatLng(pos));
    }
  }
}

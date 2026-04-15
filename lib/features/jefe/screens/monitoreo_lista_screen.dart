import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart'; // 👈 IMPORTANTE para CupertinoIcons
import 'package:cloud_firestore/cloud_firestore.dart';
import 'mapa_vivo_screen.dart';
import '../../../core/services/session.dart';
import '../../../core/theme/app_theme.dart'; // Asegúrate de que esta ruta sea correcta

class MonitoreoListaScreen extends StatelessWidget {
  const MonitoreoListaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // ==========================================================
    // 🧠 CONSULTA INTELIGENTE (EVITA EL PERMISSION_DENIED)
    // ==========================================================
    Query query = FirebaseFirestore.instance
        .collection('misiones')
        .where('estado', isEqualTo: 'en_mision');

    if (Session.rol == 'trabajador') {
      query = query.where('trabajador_id', isEqualTo: Session.uid);
    }
    // ==========================================================

    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    CupertinoIcons.location_slash,
                    size: 80,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "No hay trabajadores en la calle ahora mismo.",
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final misiones = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: misiones.length,
            itemBuilder: (context, index) {
              var mision = misiones[index].data() as Map<String, dynamic>;
              String misionId = misiones[index].id;

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(
                    11,
                  ), // Para que el splash no se salga del borde
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MapaVivoScreen(
                          misionId: misionId,
                          nombreTrabajador:
                              mision['nombre_trabajador'] ?? 'Trabajador',
                        ),
                      ),
                    );
                  },
                  child: Column(
                    children: [
                      // --- CABECERA (ESTILO DASHBOARD) ---
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: const BoxDecoration(
                          color: AppTheme.primaryGreen,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(11),
                            topRight: Radius.circular(11),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              CupertinoIcons.person_fill,
                              size: 16,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              mision['nombre_trabajador'] ?? 'Sin asignar',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const Spacer(),
                            const Icon(
                              CupertinoIcons.antenna_radiowaves_left_right,
                              size: 16,
                              color: AppTheme.accentYellow,
                            ),
                          ],
                        ),
                      ),

                      // --- CUERPO DE LA TARJETA ---
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            // Icono circular representativo
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryGreen.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                CupertinoIcons.map_pin_ellipse,
                                color: AppTheme.primaryGreen,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),

                            // Información de la Misión
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "HACIA DESTINO",
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.grey,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    mision['destino'] ?? 'No especificado',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(
                                        CupertinoIcons.doc_text,
                                        size: 12,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          "Motivo: ${mision['motivo']}",
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade700,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              CupertinoIcons.chevron_forward,
                              size: 14,
                              color: Colors.black26,
                            ),
                          ],
                        ),
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

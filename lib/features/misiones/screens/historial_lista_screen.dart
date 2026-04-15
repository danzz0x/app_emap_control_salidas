import 'package:control_emap/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../core/services/session.dart';
import 'historial_mapa_screen.dart';
import 'package:flutter/cupertino.dart';

class HistorialListaScreen extends StatefulWidget {
  const HistorialListaScreen({super.key});

  @override
  State<HistorialListaScreen> createState() => _HistorialListaScreenState();
}

class _HistorialListaScreenState extends State<HistorialListaScreen> {
  // ==========================================
  // ⚙️ VARIABLES DE CONTROL DE PAGINACIÓN
  // ==========================================
  final List<Map<String, dynamic>> _misiones = [];
  DocumentSnapshot? _ultimoDocumento;
  bool _estaCargando = false;
  bool _hayMasDatos = true;
  final ScrollController _scrollController = ScrollController();

  // ==========================================
  // 🔍 VARIABLES DE BÚSQUEDA Y FILTROS
  // ==========================================
  String _filtroTexto = "";
  DateTime? _fechaFiltroInicio;
  DateTime? _fechaFiltroFin;
  TimeOfDay? _horaFiltroInicio;
  TimeOfDay? _horaFiltroFin;

  @override
  void initState() {
    super.initState();
    _cargarMisiones();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _cargarMisiones();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ==========================================
  // 🕒 FUNCIÓN PARA FORMATEAR LAS HORAS
  // ==========================================
  String _formatearHora(dynamic timestampFirebase) {
    if (timestampFirebase == null) return "--:--";
    DateTime fecha = (timestampFirebase as Timestamp).toDate();
    return DateFormat('HH:mm').format(fecha);
  }

  // ==========================================
  // 🧹 FUNCIÓN PARA REINICIAR LA LISTA (Al Filtrar)
  // ==========================================
  void _aplicarFiltros() {
    FocusScope.of(context).unfocus();

    setState(() {
      _misiones.clear();
      _ultimoDocumento = null;
      _hayMasDatos = true;
    });
    _cargarMisiones();
  }

  // ==========================================
  // 🔄 FUNCIÓN PARA EL PULL-TO-REFRESH
  // ==========================================
  Future<void> _refrescarLista() async {
    setState(() {
      _misiones.clear();
      _ultimoDocumento = null;
      _hayMasDatos = true;
    });
    await _cargarMisiones();
  }

  // ==========================================
  // 📅 FLUJO PARA SELECCIONAR FECHA Y HORA
  // ==========================================
  Future<void> _seleccionarFechaYHora() async {
    DateTimeRange? rangoFechas = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primaryGreen,
            ),
          ),
          child: child!,
        );
      },
    );

    if (rangoFechas == null || !mounted) return;

    TimeOfDay? horaInicio = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
      helpText: "HORA INICIO DEL TURNO",
    );
    if (horaInicio == null || !mounted) return;

    TimeOfDay? horaFin = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 12, minute: 0),
      helpText: "HORA FIN DEL TURNO",
    );
    if (horaFin == null) return;

    setState(() {
      _fechaFiltroInicio = rangoFechas.start;
      _fechaFiltroFin = DateTime(
        rangoFechas.end.year,
        rangoFechas.end.month,
        rangoFechas.end.day,
        23,
        59,
        59,
      );
      _horaFiltroInicio = horaInicio;
      _horaFiltroFin = horaFin;
    });

    _aplicarFiltros();
  }

  // ==========================================
  // 🚀 FUNCIÓN PARA DESCARGAR Y FILTRAR DATOS
  // ==========================================
  Future<void> _cargarMisiones() async {
    if (_estaCargando || !_hayMasDatos) return;

    setState(() => _estaCargando = true);

    try {
      Query query = FirebaseFirestore.instance
          .collection('misiones')
          .where('estado', isEqualTo: 'completada');

      if (Session.rol == 'trabajador') {
        query = query.where('trabajador_id', isEqualTo: Session.uid);
      }

      // 🔍 2. BÚSQUEDA EXACTA SÓLO POR CI (Y solo si NO es trabajador)
      if (_filtroTexto.isNotEmpty && Session.rol != 'trabajador') {
        String textoLimpio = _filtroTexto.trim();
        query = query.where('ci', isEqualTo: textoLimpio);
      }

      // 📅 3. FILTRO EN LA NUBE
      if (_fechaFiltroInicio != null && _fechaFiltroFin != null) {
        query = query
            .where('hora_solicitud', isGreaterThanOrEqualTo: _fechaFiltroInicio)
            .where('hora_solicitud', isLessThanOrEqualTo: _fechaFiltroFin);
      }

      query = query.orderBy('hora_solicitud', descending: true).limit(15);

      if (_ultimoDocumento != null) {
        query = query.startAfterDocument(_ultimoDocumento!);
      }

      final snapshot = await query.get();

      if (snapshot.docs.length < 15) {
        _hayMasDatos = false;
      }

      if (snapshot.docs.isNotEmpty) {
        _ultimoDocumento = snapshot.docs.last;

        setState(() {
          for (var doc in snapshot.docs) {
            final data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;

            // 🛑 4. FILTRO LOCAL DE HORAS
            bool pasaFiltroDeHora = true;

            if (_horaFiltroInicio != null && _horaFiltroFin != null) {
              DateTime? horaSalidaReal;
              DateTime? horaRegresoReal;

              if (data['hora_inicio'] != null) {
                horaSalidaReal = (data['hora_inicio'] as Timestamp).toDate();
              } else if (data['firmas'] != null &&
                  (data['firmas'] as List).length == 2) {
                horaSalidaReal = (data['firmas'][1]['fecha'] as Timestamp)
                    .toDate();
              }

              if (data['hora_fin'] != null) {
                horaRegresoReal = (data['hora_fin'] as Timestamp).toDate();
              }

              if (horaSalidaReal != null) {
                int minutosSalida =
                    horaSalidaReal.hour * 60 + horaSalidaReal.minute;
                int minutosLlegada = horaRegresoReal != null
                    ? (horaRegresoReal.hour * 60 + horaRegresoReal.minute)
                    : minutosSalida;

                int minutosFiltroInicio =
                    _horaFiltroInicio!.hour * 60 + _horaFiltroInicio!.minute;
                int minutosFiltroFin =
                    _horaFiltroFin!.hour * 60 + _horaFiltroFin!.minute;

                if (minutosSalida < minutosFiltroInicio ||
                    minutosLlegada > minutosFiltroFin) {
                  pasaFiltroDeHora = false;
                }
              }
            }

            if (pasaFiltroDeHora) {
              _misiones.add(data);
            }
          }
        });
      }
    } catch (e) {
      debugPrint("Error cargando historial con filtros: $e");
    } finally {
      if (mounted) setState(() => _estaCargando = false);
    }
  }

  // ==========================================
  // 🎨 RENDERIZADO VISUAL
  // ==========================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          // =========================================================
          // 🔍 PANEL SUPERIOR: BARRA DE BÚSQUEDA Y BOTONES
          // =========================================================
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // 🛑 LÓGICA CONDICIONAL DE ROLES
                if (Session.rol != 'trabajador') ...[
                  // Si es Jefe o Admin, le mostramos el buscador de CI
                  Expanded(
                    child: TextField(
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: "Buscar por CI exacto...",
                        hintStyle: const TextStyle(fontSize: 14),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: AppTheme.primaryGreen),
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.grey,
                        ),
                      ),
                      onChanged: (texto) => _filtroTexto = texto,
                      onSubmitted: (_) => _aplicarFiltros(),
                    ),
                  ),
                ] else ...[
                  // Si es Trabajador, le mostramos un texto amigable en su lugar
                  const Expanded(
                    child: Text(
                      "Filtra tus misiones por fecha 📅",
                      style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],

                const SizedBox(width: 8),

                // 2. Botón de Calendario y Hora (Para TODOS)
                Container(
                  decoration: BoxDecoration(
                    color: _fechaFiltroInicio != null
                        ? AppTheme.primaryGreen.withValues(alpha: 0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.calendar_month,
                      color: _fechaFiltroInicio != null
                          ? AppTheme.primaryGreen
                          : Colors.grey.shade700,
                    ),
                    tooltip: "Filtrar por Fecha y Hora",
                    onPressed: _seleccionarFechaYHora,
                  ),
                ),

                // 3. Botón para Limpiar Filtros
                if (_filtroTexto.isNotEmpty || _fechaFiltroInicio != null) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(
                      Icons.filter_alt_off,
                      color: Colors.redAccent,
                    ),
                    tooltip: "Limpiar filtros",
                    onPressed: () {
                      _filtroTexto = "";
                      _fechaFiltroInicio = null;
                      _fechaFiltroFin = null;
                      _horaFiltroInicio = null;
                      _horaFiltroFin = null;
                      _aplicarFiltros();
                    },
                  ),
                ],
              ],
            ),
          ),

          // =========================================================
          // 📜 ÁREA DE LA LISTA (CON REFRESH INDICATOR)
          // =========================================================
          Expanded(
            child: _misiones.isEmpty && _estaCargando
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryGreen,
                    ),
                  )
                : _misiones.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.history_toggle_off,
                          size: 80,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "No se encontraron resultados.",
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                // 🔥 NUEVO: REFRESH INDICATOR AQUÍ
                : RefreshIndicator(
                    color: AppTheme.primaryGreen,
                    onRefresh: _refrescarLista,
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      physics:
                          const AlwaysScrollableScrollPhysics(), // Obliga al scroll aunque haya pocos items
                      itemCount: _misiones.length + 1,
                      itemBuilder: (context, index) {
                        if (index == _misiones.length) {
                          return _hayMasDatos
                              ? const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 32.0),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      color: AppTheme.primaryGreen,
                                    ),
                                  ),
                                )
                              : const SizedBox(height: 32);
                        }

                        var mision = _misiones[index];
                        String misionId = mision['id'];

                        // Extraer Fecha Principal
                        String fechaFormateada = "Sin fecha";
                        if (mision['hora_solicitud'] != null) {
                          DateTime dt = (mision['hora_solicitud'] as Timestamp)
                              .toDate();
                          fechaFormateada =
                              "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}";
                        }

                        // EXTRAER HORAS
                        String horaSalida = "--:--";
                        String horaRegreso = "--:--";

                        if (mision['hora_inicio'] != null) {
                          horaSalida = _formatearHora(mision['hora_inicio']);
                        } else if (mision['firmas'] != null &&
                            (mision['firmas'] as List).length == 2) {
                          horaSalida = _formatearHora(
                            mision['firmas'][1]['fecha'],
                          );
                        }

                        if (mision['hora_fin'] != null) {
                          horaRegreso = _formatearHora(mision['hora_fin']);
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.grey.shade200,
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.01),
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
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => HistorialMapaScreen(
                                    misionId: misionId,
                                    nombreTrabajador:
                                        mision['nombre_trabajador'] ??
                                        'Trabajador',
                                  ),
                                ),
                              );
                            },
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
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
                                        Icons.person,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          mision['nombre_trabajador'] ??
                                              'Sin asignar',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text(
                                        fechaFormateada,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(
                                        Icons.map_rounded,
                                        size: 16,
                                        color: AppTheme.accentYellow,
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: const BoxDecoration(
                                          color: AppTheme.primaryGreen,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          CupertinoIcons.map_pin_ellipse,
                                          color: AppTheme.accentYellow,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              "DESTINO",
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey,
                                              ),
                                            ),
                                            Text(
                                              mision['destino'] ??
                                                  'No especificado',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black87,
                                              ),
                                            ),
                                            const SizedBox(height: 6),

                                            // 🕒 DIBUJAMOS EL INTERVALO DE HORAS
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.schedule,
                                                  size: 14,
                                                  color: AppTheme.primaryGreen,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  "$horaSalida  |  $horaRegreso",
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                    color:
                                                        AppTheme.primaryGreen,
                                                  ),
                                                ),
                                              ],
                                            ),

                                            const SizedBox(height: 6),
                                            Text(
                                              "Motivo: ${mision['motivo']}",
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey.shade700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(
                                        Icons.arrow_forward_ios,
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
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/session.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';
import '../widgets/create_user_dialog.dart';
import '../widgets/edit_user_dialog.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final _userService = UserService();

  void _mostrarDialogoCrear() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const CreateUserDialog(),
    );
  }

  // 🔥 Diálogo para confirmar la activación/desactivación
  Future<void> _cambiarEstado(UserModel user) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              user.activo
                  ? Icons.warning_amber_rounded
                  : Icons.check_circle_outline,
              color: user.activo ? Colors.red : AppTheme.primaryGreen,
              size: 28,
            ),
            const SizedBox(width: 8),
            Text(user.activo ? "Dar de baja" : "Activar usuario"),
          ],
        ),
        content: Text(
          user.activo
              ? "¿Estás seguro de que deseas desactivar a ${user.nombre}? No podrá iniciar sesión en la app."
              : "¿Deseas volver a habilitar el acceso a ${user.nombre}?",
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              "Cancelar",
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: user.activo ? Colors.red : AppTheme.primaryGreen,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              user.activo ? "SÍ, DESACTIVAR" : "SÍ, ACTIVAR",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await _userService.cambiarEstadoUsuario(user.uid, !user.activo);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              user.activo
                  ? "Usuario desactivado."
                  : "Usuario activado con éxito.",
            ),
            backgroundColor: user.activo
                ? Colors.orange
                : AppTheme.primaryGreen,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 🎨 Función para extraer las iniciales (Ej: Juan Perez -> JP)
  String _getInitials(String name) {
    List<String> nameParts = name.trim().split(' ');
    if (nameParts.isEmpty) return "?";
    if (nameParts.length == 1) return nameParts[0][0].toUpperCase();
    return "${nameParts[0][0]}${nameParts[1][0]}".toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      floatingActionButton: Session.rol == 'admin'
          ? FloatingActionButton(
              backgroundColor: AppTheme.accentYellow,
              elevation: 4,
              onPressed: _mostrarDialogoCrear,
              child: const Icon(Icons.person_add, color: AppTheme.primaryGreen),
            )
          : null,

      // STREAMBUILDER: Escucha la colección en tiempo real
      body: StreamBuilder<List<UserModel>>(
        stream: _userService.obtenerUsuarios(),
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

          final usuarios = snapshot.data ?? [];

          // 🎨 ESTADO VACÍO ELEGANTE
          if (usuarios.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.group_off_outlined,
                    size: 80,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "No hay usuarios registrados.",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(
              top: 16,
              left: 16,
              right: 16,
              bottom: 80,
            ), // Padding inferior para el FAB
            itemCount: usuarios.length,
            itemBuilder: (context, index) {
              final user = usuarios[index];
              final colorRol = _getColorByRol(user.rol);

              return AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: user.activo
                    ? 1.0
                    : 0.6, // Efecto fantasma si está inactivo
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: user.activo
                          ? Colors.grey.shade200
                          : Colors.red.shade200,
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // 🟢 AVATAR CON INICIALES
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: colorRol.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              _getInitials(user.nombre),
                              style: TextStyle(
                                color: colorRol,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),

                        // 📝 INFORMACIÓN DEL USUARIO
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      user.nombre,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.black87,
                                        decoration: user.activo
                                            ? TextDecoration.none
                                            : TextDecoration.lineThrough,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  // Etiqueta roja de INACTIVO (Si aplica)
                                  if (!user.activo)
                                    Container(
                                      margin: const EdgeInsets.only(left: 8),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: Colors.red.withValues(
                                            alpha: 0.5,
                                          ),
                                        ),
                                      ),
                                      child: const Text(
                                        "INACTIVO",
                                        style: TextStyle(
                                          color: Colors.red,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                user.cargo,
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(
                                    Icons.email_outlined,
                                    size: 14,
                                    color: Colors.grey.shade500,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      user.email,
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 12,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // ⚙️ ROL Y MENÚ DE ACCIONES
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Etiqueta del Rol
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: colorRol,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                user.rol.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Menú del Admin
                            if (Session.rol == 'admin')
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: PopupMenuButton<String>(
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(
                                    Icons.more_vert,
                                    color: Colors.grey,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  onSelected: (value) {
                                    if (value == 'editar') {
                                      showDialog(
                                        context: context,
                                        barrierDismissible: false,
                                        builder: (context) =>
                                            EditUserDialog(usuario: user),
                                      );
                                    } else if (value == 'estado') {
                                      _cambiarEstado(user);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'editar',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.edit_outlined,
                                            size: 20,
                                            color: Colors.black54,
                                          ),
                                          SizedBox(width: 12),
                                          Text("Editar"),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'estado',
                                      child: Row(
                                        children: [
                                          Icon(
                                            user.activo
                                                ? Icons.block
                                                : Icons.check_circle_outline,
                                            size: 20,
                                            color: user.activo
                                                ? Colors.red
                                                : Colors.green,
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            user.activo
                                                ? "Dar de baja"
                                                : "Activar acceso",
                                            style: TextStyle(
                                              color: user.activo
                                                  ? Colors.red
                                                  : Colors.green,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // Función para darle color según el rol
  Color _getColorByRol(String rol) {
    switch (rol.toLowerCase()) {
      case 'admin':
        return Colors.red.shade400;
      case 'jefe':
        return AppTheme.institutionalPurple;
      default:
        return AppTheme.primaryGreen;
    }
  }
}

import 'package:flutter/material.dart';
import '../../features/auth/services/auth_service.dart';
import '../../features/auth/screens/login_screen.dart';
import '../theme/app_theme.dart';

// Implements PreferredSizeWidget es obligatorio para que Flutter
// nos deje usar este widget dentro de la propiedad "appBar" del Scaffold.
class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;

  const CustomAppBar({super.key, required this.title});

  // Función que muestra la alerta de confirmación
  Future<void> _mostrarConfirmacion(BuildContext context) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          "Cerrar Sesión",
          style: TextStyle(
            color: AppTheme.institutionalPurple,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          "¿Estás seguro de que deseas salir del sistema EMAP?",
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), // Devuelve "false"
            child: const Text("Cancelar", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true), // Devuelve "true"
            child: const Text(
              "Sí, salir",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    // Si el usuario presionó "Sí, salir", ejecutamos el logout
    if (confirmar == true) {
      if (!context.mounted) return;

      // Opcional: Mostrar un indicador de carga mientras borra el token
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      await AuthService.logout();

      if (!context.mounted) return;

      // Destruimos todas las pantallas y volvemos al Login
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      // 🔥 TOQUES MODERNOS
      centerTitle: true, // Centra el texto en Android y iOS
      elevation: 0, // Le quita la sombra al menú
      backgroundColor: Colors.transparent, // Se funde con el fondo de la app

      title: Text(
        title.toUpperCase(), // Mayúsculas pequeñas le dan un toque muy limpio
        style: const TextStyle(
          color: AppTheme.primaryGreen, // Color gris suave para el texto
          fontSize: 13, // Texto más pequeño y sutil
          fontWeight: FontWeight.w800, // Letra gordita
          letterSpacing: 1.5, // Letras un poco separadas (muy moderno)
        ),
      ),

      iconTheme: const IconThemeData(color: AppTheme.primaryGreen),

      actions: [
        // Le puse un poco de padding para que no esté tan pegado al borde derecho
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: IconButton(
            icon: const Icon(Icons.logout_rounded, size: 22), // Ícono más suave
            tooltip: 'Cerrar Sesión',
            onPressed: () => _mostrarConfirmacion(context),
          ),
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

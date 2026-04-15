import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/session.dart';
import '../../../core/theme/app_theme.dart';
import '../../../layout/main_layout.dart';
import 'login_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    // ⏳ Le damos medio segundo a Flutter para que termine de construir la pantalla
    // de forma segura antes de intentar navegar a otro lado.
    Future.delayed(const Duration(milliseconds: 500), () {
      _verificarSesion();
    });
  }

  Future<void> _verificarSesion() async {
    // 1. Preguntamos al disco duro del celular si hay una sesión de Firebase guardada
    final user = FirebaseAuth.instance.currentUser;

    // Si no hay sesión, lo mandamos al Login de inmediato
    if (user == null) {
      _irAlLogin();
      return;
    }

    try {
      // 2. Si hay sesión, nuestra RAM está vacía. Vamos a Firestore a recuperar el Rol.
      final doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .get();

      // Validación extra: Si el usuario fue borrado de Firestore o dado de baja (activo: false)
      // mientras la app estaba cerrada, le matamos la sesión por seguridad.
      if (!doc.exists || doc.data()?['activo'] == false) {
        await FirebaseAuth.instance.signOut();
        _irAlLogin();
        return;
      }

      // 3. Restauramos nuestra clase estática Session
      Session.uid = user.uid;
      Session.rol = doc.data()?['rol'];

      // 4. Lo dejamos pasar al sistema principal sin pedir contraseña
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainLayout()),
        );
      }
    } catch (e) {
      // Si el celular no tiene internet para validar el rol, o pasa algo raro,
      // por seguridad lo mandamos al login para que lo intente manualmente.
      _irAlLogin();
    }
  }

  void _irAlLogin() {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Mientras hace la verificación (que dura menos de 1 segundo),
    // mostramos una pantalla limpia con el color de la institución.
    return const Scaffold(
      backgroundColor: AppTheme.institutionalPurple,
      body: Center(child: CircularProgressIndicator(color: Colors.white)),
    );
  }
}

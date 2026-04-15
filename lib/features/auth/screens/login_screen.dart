import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // 🔥 Importación necesaria para resetear contraseña
import '../../../layout/main_layout.dart';
import '../../../core/theme/app_theme.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword =
      true; // 🔥 Variable para controlar si se ve la contraseña

  // ==========================================================
  // 🚀 LÓGICA DE INICIO DE SESIÓN
  // ==========================================================
  Future<void> _handleLogin() async {
    // Evitar múltiples clics mientras carga
    if (_isLoading) return;

    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      _showError("Por favor, llena todos los campos");
      return;
    }

    setState(() => _isLoading = true);

    try {
      await AuthService.login(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Si el widget ya no está en el árbol (ej. el usuario cerró la app mientras cargaba), abortamos.
      if (!mounted) return;

      // 🚀 Navegar al layout principal
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainLayout()),
      );
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ==========================================================
  // 🔑 LÓGICA DE RECUPERACIÓN DE CONTRASEÑA
  // ==========================================================
  Future<void> _recuperarContrasenia() async {
    final emailRecuperacionCtrl = TextEditingController(
      text: _emailController.text.trim(),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.lock_reset, color: AppTheme.primaryGreen),
            SizedBox(width: 8),
            Text("Recuperar Acceso", style: TextStyle(fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Ingresa tu correo electrónico y te enviaremos un enlace seguro para crear una nueva contraseña.",
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailRecuperacionCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: "Correo electrónico",
                prefixIcon: const Icon(Icons.email_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () async {
              if (emailRecuperacionCtrl.text.trim().isEmpty) return;

              Navigator.pop(
                context,
              ); // Cerramos el modal rápido para dar feedback visual

              try {
                // 🔥 Magia de Firebase para enviar el correo
                await FirebaseAuth.instance.sendPasswordResetEmail(
                  email: emailRecuperacionCtrl.text.trim(),
                );

                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      "✅ Correo enviado. Revisa tu bandeja de entrada o SPAM.",
                    ),
                    backgroundColor: AppTheme.primaryGreen,
                    duration: Duration(seconds: 4),
                  ),
                );
              } on FirebaseAuthException catch (e) {
                // 🕵️‍♂️ AQUÍ ATRAPAMOS EL ERROR REAL DE FIREBASE
                if (!mounted) return;
                _showError("CÓDIGO FIREBASE: ${e.code}\n${e.message}");
              } catch (e) {
                // 🕵️‍♂️ CUALQUIER OTRO ERROR (Ej. Sin internet)
                if (!mounted) return;
                _showError("ERROR DESCONOCIDO: $e");
              }
            },
            child: const Text(
              "ENVIAR ENLACE",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.red.shade700,
        content: Text(message, style: const TextStyle(color: Colors.white)),
        behavior: SnackBarBehavior.floating, // Le da un toque más moderno
        duration: const Duration(
          seconds: 6,
        ), // 🔥 Le di más tiempo para que alcances a leer el error
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ==========================================================
  // 🎨 DISEÑO DE LA PANTALLA
  // ==========================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.institutionalPurple, AppTheme.primaryGreen],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            // Añadido para evitar error de píxeles al abrir el teclado
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              margin: const EdgeInsets.symmetric(horizontal: 24),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icono arriba del texto (opcional, pero se ve muy pro)
                    const Icon(
                      Icons.maps_home_work_rounded,
                      size: 50,
                      color: AppTheme.primaryGreen,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Iniciar Sesión",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.institutionalPurple,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 📧 CAMPO CORREO
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: "Correo",
                        prefixIcon: Icon(Icons.email),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 🔒 CAMPO CONTRASEÑA (Ahora con el ojito)
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: "Contraseña",
                        prefixIcon: const Icon(Icons.lock),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                      ),
                    ),

                    // 🆘 BOTÓN "OLVIDÉ MI CONTRASEÑA"
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _recuperarContrasenia,
                        child: const Text(
                          "¿Olvidaste tu contraseña?",
                          style: TextStyle(
                            color: AppTheme.primaryGreen,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 🚀 BOTÓN INGRESAR
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryGreen,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: _handleLogin,
                              child: const Text(
                                "INGRESAR",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

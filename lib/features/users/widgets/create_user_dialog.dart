import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../services/user_service.dart';

class CreateUserDialog extends StatefulWidget {
  const CreateUserDialog({super.key});

  @override
  State<CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends State<CreateUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _cargoCtrl = TextEditingController();
  final _ciCtrl = TextEditingController();

  String _rolSeleccionado = 'trabajador';
  bool _isLoading = false;

  final _userService = UserService();

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await _userService.crearUsuario(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
        nombre: _nombreCtrl.text.trim(),
        ci: _ciCtrl.text.trim(),
        cargo: _cargoCtrl.text.trim(),
        rolNuevo: _rolSeleccionado,
      );

      if (!mounted) return;
      Navigator.pop(context); // Cierra el modal si fue exitoso

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Usuario creado exitosamente"),
          backgroundColor: AppTheme.primaryGreen,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _cargoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        "Nuevo Usuario",
        style: TextStyle(
          color: AppTheme.institutionalPurple,
          fontWeight: FontWeight.bold,
        ),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nombreCtrl,
                decoration: const InputDecoration(labelText: "Nombre completo"),
                validator: (val) => val!.isEmpty ? "Campo requerido" : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _ciCtrl,
                decoration: const InputDecoration(labelText: "CI"),
                validator: (val) => val!.isEmpty ? "Campo requerido" : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: "Correo electrónico",
                ),
                validator: (val) =>
                    val!.contains('@') ? null : "Correo inválido",
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _passCtrl,
                decoration: const InputDecoration(labelText: "Contraseña"),
                validator: (val) =>
                    val!.length < 6 ? "Mínimo 6 caracteres" : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _cargoCtrl,
                decoration: const InputDecoration(
                  labelText: "Cargo (Ej. Técnico)",
                ),
                validator: (val) => val!.isEmpty ? "Campo requerido" : null,
              ),
              const SizedBox(height: 15),
              DropdownButtonFormField<String>(
                value: _rolSeleccionado,
                decoration: const InputDecoration(labelText: "Rol del sistema"),
                items: const [
                  DropdownMenuItem(
                    value: "admin",
                    child: Text("Administrador"),
                  ),
                  DropdownMenuItem(
                    value: "trabajador",
                    child: Text("Trabajador"),
                  ),
                ],
                onChanged: (val) => setState(() => _rolSeleccionado = val!),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text("Cancelar", style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submitForm,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryGreen,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text("Crear", style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

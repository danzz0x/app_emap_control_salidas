import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';

class EditUserDialog extends StatefulWidget {
  final UserModel usuario; // Recibimos el usuario a editar

  const EditUserDialog({super.key, required this.usuario});

  @override
  State<EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends State<EditUserDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nombreCtrl;
  late TextEditingController _cargoCtrl;
  late TextEditingController _ciCtrl;

  late String _rolSeleccionado;
  bool _isLoading = false;

  final _userService = UserService();

  @override
  void initState() {
    super.initState();
    // Inicializamos los controladores con los datos actuales del usuario
    _nombreCtrl = TextEditingController(text: widget.usuario.nombre);
    _cargoCtrl = TextEditingController(text: widget.usuario.cargo);
    _ciCtrl = TextEditingController(text: widget.usuario.ci);
    _rolSeleccionado = widget.usuario.rol;
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await _userService.editarUsuario(
        uid: widget.usuario.uid,
        nombre: _nombreCtrl.text.trim(),
        ci: _ciCtrl.text.trim(),
        cargo: _cargoCtrl.text.trim(),
        rolNuevo: _rolSeleccionado,
      );

      if (!mounted) return;
      Navigator.pop(context); // Cierra el modal

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Usuario actualizado exitosamente"),
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
    _cargoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        "Editar Usuario",
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
              // El correo se muestra pero no se edita
              TextFormField(
                initialValue: widget.usuario.email,
                enabled: false, // Solo lectura
                decoration: const InputDecoration(
                  labelText: "Correo electrónico (No editable)",
                  prefixIcon: Icon(Icons.lock_outline, size: 20),
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _nombreCtrl,
                decoration: const InputDecoration(labelText: "Nombre completo"),
                validator: (val) => val!.isEmpty ? "Campo requerido" : null,
              ),
              TextFormField(
                controller: _ciCtrl,
                decoration: const InputDecoration(labelText: "CI"),
                validator: (val) => val!.isEmpty ? "Campo requerido" : null,
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
                  DropdownMenuItem(value: "jefe", child: Text("Jefe")),
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
              : const Text("Guardar", style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'diseno.dart';

class RecuperarContrasena extends StatefulWidget {
  final String? oobCode; // Código del enlace de restablecimiento

  const RecuperarContrasena({super.key, this.oobCode});

  @override
  State<RecuperarContrasena> createState() => _RecuperarContrasenaState();
}

class _RecuperarContrasenaState extends State<RecuperarContrasena> {
  final _formKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _isSuccess = false;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.confirmPasswordReset(
        code: widget.oobCode!,
        newPassword: _newPasswordController.text.trim(),
      );
      
      setState(() => _isSuccess = true);
    } on FirebaseAuthException catch (e) {
      String mensaje;
      switch (e.code) {
        case 'expired-action-code':
          mensaje = 'El enlace de restablecimiento ha expirado. Solicita uno nuevo.';
          break;
        case 'invalid-action-code':
          mensaje = 'El enlace de restablecimiento no es válido. Solicita uno nuevo.';
          break;
        case 'weak-password':
          mensaje = 'La contraseña es demasiado débil. Usa al menos 6 caracteres.';
          break;
        default:
          mensaje = e.message ?? 'Error al restablecer la contraseña';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensaje),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isSuccess) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Contraseña restablecida'),
          backgroundColor: AppColores.primario,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle, size: 80, color: Colors.green),
                const SizedBox(height: 24),
                const Text(
                  '¡Contraseña restablecida exitosamente!',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Ya puedes iniciar sesión con tu nueva contraseña.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/',
                    (route) => false,
                  ),
                  style: EstilosApp.botonPrimario(context),
                  child: const Text('Ir al inicio de sesión'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Restablecer contraseña'),
        backgroundColor: AppColores.primario,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              const Text(
                'Ingresa tu nueva contraseña',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 30),
              TextFormField(
                controller: _newPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Nueva contraseña',
                  prefixIcon: Icon(Icons.lock_outline),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Ingresa tu nueva contraseña';
                  }
                  if (value.length < 6) {
                    return 'La contraseña debe tener al menos 6 caracteres';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirmar nueva contraseña',
                  prefixIcon: Icon(Icons.lock_outline),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Confirma tu nueva contraseña';
                  }
                  if (value != _newPasswordController.text) {
                    return 'Las contraseñas no coinciden';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _resetPassword,
                style: EstilosApp.botonPrimario(context),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Restablecer contraseña'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
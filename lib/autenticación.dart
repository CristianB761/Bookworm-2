import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'diseño.dart';
import '../servicio/servicio_firestore.dart'; 
import '../modelos/datos_usuario.dart'; 

class Autenticacion extends StatefulWidget {
  const Autenticacion({super.key});

  @override
  State<Autenticacion> createState() => _EstadoPantallaAuth();
}

class _EstadoPantallaAuth extends State<Autenticacion> {
  final _controladorEmail = TextEditingController();
  final _controladorPassword = TextEditingController();
  final _controladorConfirmarPassword = TextEditingController();
  final _controladorNombre = TextEditingController();
  
  bool _esLogin = true;
  bool _passwordOculta = true;
  bool _confirmarPasswordOculta = true;
  bool _estaCargando = false;
  
  final _auth = FirebaseAuth.instance;
  
  @override
  void dispose() {
    _controladorEmail.dispose();
    _controladorPassword.dispose();
    _controladorConfirmarPassword.dispose();
    _controladorNombre.dispose();
    super.dispose();
  }

  void _alternarModoAuth() {
    setState(() {
      _esLogin = !_esLogin;
      _controladorConfirmarPassword.clear();
      _controladorNombre.clear();
      ScaffoldMessenger.of(context).clearSnackBars();
    });
  }

  Future<void> _enviarFormulario() async {
    if (!_validarFormulario()) return;
    setState(() => _estaCargando = true);

    try {
      _esLogin ? await _iniciarSesionUsuario() : await _registrarUsuario();
    } on FirebaseAuthException catch (e) {
      _manejarErrorFirebase(e);
    } catch (e) {
      _mostrarSnackBar('Error inesperado: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _estaCargando = false);
    }
  }

  bool _validarFormulario() {
    final email = _controladorEmail.text.trim();
    if (email.isEmpty) {
      _mostrarSnackBar('Ingresa tu correo electrónico', Colors.red);
      return false;
    }
    
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!emailRegex.hasMatch(email)) {
      _mostrarSnackBar('Ingresa un correo electrónico válido', Colors.red);
      return false;
    }
    
    if (_controladorPassword.text.isEmpty) {
      _mostrarSnackBar('Ingresa tu contraseña', Colors.red);
      return false;
    }
    
    if (_controladorPassword.text.length < 6) {
      _mostrarSnackBar('La contraseña debe tener al menos 6 caracteres', Colors.red);
      return false;
    }
    
    if (!_esLogin) {
      if (_controladorNombre.text.trim().isEmpty) {
        _mostrarSnackBar('Ingresa tu nombre', Colors.red);
        return false;
      }
      
      if (_controladorPassword.text != _controladorConfirmarPassword.text) {
        _mostrarSnackBar('Las contraseñas no coinciden', Colors.red);
        return false;
      }
    }
    
    return true;
  }

  Future<void> _iniciarSesionUsuario() async {
    final credencialUsuario = await _auth.signInWithEmailAndPassword(
      email: _controladorEmail.text.trim(),
      password: _controladorPassword.text,
    );
    if (credencialUsuario.user != null) {
      _mostrarSnackBar('¡Bienvenido de vuelta!', Colors.green);
      _navegarAInicio();
    }
  }

  Future<void> _registrarUsuario() async {
    final credencialUsuario = await _auth.createUserWithEmailAndPassword(
      email: _controladorEmail.text.trim(),
      password: _controladorPassword.text,
    );

    if (credencialUsuario.user != null) {
      final datosUsuario = DatosUsuario(
        uid: credencialUsuario.user!.uid,
        nombre: _controladorNombre.text.trim(),
        correo: _controladorEmail.text.trim(),
        fechaCreacion: DateTime.now(),
        urlImagenPerfil: null,
        biografia: '',
        preferencias: {
          'generos': [],
          'formatos': ['fisico', 'audio'],
          'notificaciones': true,
          'recordatorios': false,
          'libros_por_mes': 1,
          'hora_inicio': {'hora': 9, 'minuto': 0},
          'hora_fin': {'hora': 22, 'minuto': 0},
        },
        estadisticas: {
          'librosLeidos': 0,
          'tiempoLectura': 0, 
          'rachaActual': 0, 
          'paginasTotales': 0,
        },
        generosFavoritos: [],
      );

      try {
        final servicioFirestore = ServicioFirestore();
        await servicioFirestore.crearUsuario(datosUsuario);
        _mostrarSnackBar('¡Cuenta creada exitosamente!', Colors.green);
        _navegarAInicio();
      } catch (e) {
        await credencialUsuario.user!.delete();
        _mostrarSnackBar('Error al guardar datos: $e', Colors.red);
        rethrow;
      }
    }
  }

  void _manejarErrorFirebase(FirebaseAuthException e) {
    final mensajesError = {
      'user-not-found': 'No existe una cuenta con este email',
      'wrong-password': 'Contraseña incorrecta',
      'email-already-in-use': 'Ya existe una cuenta con este email',
      'weak-password': 'La contraseña es demasiado débil',
      'invalid-email': 'El formato del email no es válido',
      'network-request-failed': 'Error de conexión a internet. Verifica tu conexión',
      'too-many-requests': 'Demasiados intentos fallidos. Intenta más tarde',
      'user-disabled': 'Esta cuenta ha sido deshabilitada',
      'operation-not-allowed': 'Este método de inicio de sesión no está habilitado',
    };
    
    _mostrarSnackBar(mensajesError[e.code] ?? 'Error: ${e.message}', Colors.red);
  }

  void _mostrarSnackBar(String mensaje, Color color) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje, style: const TextStyle(color: Colors.white)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: color == Colors.green ? 3 : 5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _navegarAInicio() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    });
  }

  Widget _construirCampoTexto(TextEditingController controlador, String etiqueta, IconData icono, 
  {bool textoOculto = false, VoidCallback? alAlternarVisibilidad, TextInputType? tipoTeclado}) {
    return TextFormField(
      controller: controlador,
      decoration: InputDecoration(
        labelText: etiqueta,
        labelStyle: const TextStyle(color: Colors.grey),
        prefixIcon: Icon(icono, color: AppColores.primario),
        suffixIcon: alAlternarVisibilidad != null ? IconButton(
          icon: Icon(textoOculto ? Icons.visibility_off : Icons.visibility, 
                     color: AppColores.primario.withOpacity(0.7)),
          onPressed: alAlternarVisibilidad,
        ) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColores.primario, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.grey),
        ),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
      ),
      obscureText: textoOculto,
      enabled: !_estaCargando,
      keyboardType: tipoTeclado,
      style: const TextStyle(fontSize: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColores.primario, AppColores.secundario],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: [0.0, 1.0],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 400,
                  constraints: const BoxConstraints(maxWidth: 400),
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 20,
                        spreadRadius: 2,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: AppColores.primario.withOpacity(0.1),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColores.primario, width: 3),
                        ),
                        child: const Icon(
                          Icons.menu_book_rounded,
                          size: 50,
                          color: AppColores.primario,
                        ),
                      ),
                      
                      const SizedBox(height: 25),
                      
                      Text(
                        _esLogin ? 'Iniciar Sesión' : 'Crear Cuenta',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      
                      const SizedBox(height: 10),
                      
                      Text(
                        _esLogin 
                            ? 'Bienvenido de vuelta a tu biblioteca personal'
                            : 'Únete a nuestra comunidad de lectores',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      
                      const SizedBox(height: 30),
                      
                      if (!_esLogin) ...[
                        _construirCampoTexto(
                          _controladorNombre, 
                          'Nombre completo', 
                          Icons.person_outline,
                          tipoTeclado: TextInputType.name,
                        ),
                        const SizedBox(height: 20),
                      ],
                      
                      _construirCampoTexto(
                        _controladorEmail, 
                        'Correo electrónico', 
                        Icons.email_outlined,
                        tipoTeclado: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 20),
                      
                      _construirCampoTexto(
                        _controladorPassword, 
                        'Contraseña', 
                        Icons.lock_outline,
                        textoOculto: _passwordOculta,
                        alAlternarVisibilidad: _estaCargando ? null : () => setState(() => _passwordOculta = !_passwordOculta),
                      ),
                      const SizedBox(height: 20),
                      
                      if (!_esLogin) ...[
                        _construirCampoTexto(
                          _controladorConfirmarPassword, 
                          'Confirmar contraseña', 
                          Icons.lock_reset,
                          textoOculto: _confirmarPasswordOculta,
                          alAlternarVisibilidad: _estaCargando ? null : () => setState(() => _confirmarPasswordOculta = !_confirmarPasswordOculta),
                        ),
                        const SizedBox(height: 20),
                      ],
                      
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: _estaCargando
                            ? const Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(AppColores.primario),
                                  strokeWidth: 3,
                                ),
                              )
                            : ElevatedButton(
                                onPressed: _enviarFormulario,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColores.primario,
                                  foregroundColor: Colors.white,
                                  elevation: 5,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 15),
                                ),
                                child: Text(
                                  _esLogin ? 'Iniciar Sesión' : 'Crear Cuenta',
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                      ),
                      
                      const SizedBox(height: 25),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _esLogin ? '¿No tienes cuenta?' : '¿Ya tienes cuenta?',
                            style: const TextStyle(
                              fontSize: 15,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _alternarModoAuth,
                            child: Text(
                              _esLogin ? 'Regístrate aquí' : 'Inicia sesión aquí',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColores.primario,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
                
                const SizedBox(height: 30),
                
                Text(
                  'Al continuar, aceptas nuestros Términos de Servicio y Política de Privacidad',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.9),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'diseno.dart';
import 'servicio/servicio_firestore.dart';
import 'modelos/datos_usuario.dart';
import 'theme_provider.dart';

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
  GoogleSignIn? _googleSignIn;

  final Map<String, bool> _hoverInputs = {
    'email': false,
    'password': false,
    'confirmar': false,
    'nombre': false,
  };

  bool _hoverBotonLogin = false;
  bool _hoverBotonGoogle = false;
  bool _hoverRegistro = false;
  bool _hoverIconoPass = false;
  bool _hoverIconoConfirm = false;

  @override
  void initState() {
    super.initState();
    _inicializarGoogleSignIn();
  }

  void _inicializarGoogleSignIn() {
    try {
      const webClientId = '993471989568-t5gumicvfvdt3fagka0f2lg7uf6v23br.apps.googleusercontent.com';
      
      _googleSignIn = GoogleSignIn(
        clientId: webClientId,
        scopes: ['email', 'profile'],
      );
    } catch (e) {
      _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
    }
  }

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
      _esLogin ? await _iniciarSesionEmail() : await _registrarEmail();
    } on FirebaseAuthException catch (e) {
      if (mounted) _manejarErrorFirebase(e);
    } catch (e) {
      if (mounted) _mostrarSnackBar('Error inesperado: $e', const Color(0xFFb22222));
    } finally {
      if (mounted) setState(() => _estaCargando = false);
    }
  }

  Future<void> _iniciarSesionConGoogle() async {
    if (_googleSignIn == null) {
      _mostrarSnackBar('Google Sign-In no está disponible', const Color(0xFFb22222));
      return;
    }

    setState(() => _estaCargando = true);

    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn!.signIn();
      
      if (googleUser == null) {
        if (mounted) setState(() => _estaCargando = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final usuario = userCredential.user;

      if (usuario != null) {
        await _crearUsuarioSiNoExiste(usuario, googleUser.displayName, googleUser.email);
        
        if (mounted) {
          _mostrarSnackBar('¡Bienvenido ${usuario.displayName ?? googleUser.displayName}!', const Color(0xFF32cd32));
        }
      }
    } catch (e) {
      if (mounted) {
        _mostrarSnackBar('Error con Google: $e', const Color(0xFFb22222));
      }
    } finally {
      if (mounted) setState(() => _estaCargando = false);
    }
  }

  Future<void> _crearUsuarioSiNoExiste(User usuario, String? displayName, String? email) async {
    final userDoc = await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(usuario.uid)
        .get();

    if (!userDoc.exists) {
      final datosUsuario = DatosUsuario(
        uid: usuario.uid,
        nombre: usuario.displayName ?? displayName ?? 'Usuario',
        correo: usuario.email ?? email ?? '',
        fechaCreacion: DateTime.now(),
        urlImagenPerfil: usuario.photoURL,
        biografia: '',
        preferencias: {
          'generos': [],
          'formatos': ['fisico', 'audio'],
          'notificaciones': true,
          'recordatorios': false,
          'libros_por_mes': 1,
          'hora_inicio': {'hora': 9, 'minuto': 0},
          'hora_fin': {'hora': 22, 'minuto': 0},
          'minutos_lectura_diaria': 30,
          'perfil_publico': true,
          'actividad_publica': true,
        },
        estadisticas: {
          'librosLeidos': 0,
          'tiempoLectura': 0,
          'rachaActual': 0,
          'paginasTotales': 0,
        },
        generosFavoritos: [],
      );

      final servicioFirestore = ServicioFirestore();
      await servicioFirestore.crearUsuario(datosUsuario);
    }
  }

  bool _validarFormulario() {
    final email = _controladorEmail.text.trim();
    if (email.isEmpty) {
      _mostrarSnackBar('Ingresa tu correo electrónico', const Color(0xFFb22222));
      return false;
    }

    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!emailRegex.hasMatch(email)) {
      _mostrarSnackBar('Ingresa un correo electrónico válido', const Color(0xFFb22222));
      return false;
    }

    if (_controladorPassword.text.isEmpty) {
      _mostrarSnackBar('Ingresa tu contraseña', const Color(0xFFb22222));
      return false;
    }

    if (_controladorPassword.text.length < 6) {
      _mostrarSnackBar('La contraseña debe tener al menos 6 caracteres', const Color(0xFFb22222));
      return false;
    }

    if (!_esLogin) {
      if (_controladorNombre.text.trim().isEmpty) {
        _mostrarSnackBar('Ingresa tu nombre', const Color(0xFFb22222));
        return false;
      }

      if (_controladorPassword.text != _controladorConfirmarPassword.text) {
        _mostrarSnackBar('Las contraseñas no coinciden', const Color(0xFFb22222));
        return false;
      }
    }

    return true;
  }

  Future<void> _iniciarSesionEmail() async {
    final credencialUsuario = await _auth.signInWithEmailAndPassword(
      email: _controladorEmail.text.trim(),
      password: _controladorPassword.text,
    );
    if (credencialUsuario.user != null && mounted) {
      _mostrarSnackBar('¡Bienvenido de vuelta!', const Color(0xFF32cd32));
    }
  }

  Future<void> _registrarEmail() async {
    final credencialUsuario = await _auth.createUserWithEmailAndPassword(
      email: _controladorEmail.text.trim(),
      password: _controladorPassword.text,
    );

    if (credencialUsuario.user != null) {
      await credencialUsuario.user!.updateDisplayName(_controladorNombre.text.trim());

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
          'minutos_lectura_diaria': 30,
          'perfil_publico': true,
          'actividad_publica': true,
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
      } catch (e) {
        await credencialUsuario.user!.delete();
        if (mounted) {
          _mostrarSnackBar('Error al guardar datos: $e', const Color(0xFFb22222));
        }
        rethrow;
      }

      if (mounted) {
        _mostrarSnackBar('¡Cuenta creada exitosamente!', const Color(0xFF32cd32));
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
      'network-request-failed': 'Error de conexión a internet',
      'too-many-requests': 'Demasiados intentos fallidos',
      'user-disabled': 'Esta cuenta ha sido deshabilitada',
      'operation-not-allowed': 'Método de inicio no habilitado',
    };

    _mostrarSnackBar(mensajesError[e.code] ?? 'Error: ${e.message}', const Color(0xFFb22222));
  }

  void _mostrarDialogoRecuperarContrasena() {
    final emailController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recuperar contraseña'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Te enviaremos un enlace a tu correo para restablecer tu contraseña.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Correo electrónico',
                hintText: 'tu@email.com',
                prefixIcon: Icon(Icons.email_outlined),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = emailController.text.trim();
              if (email.isEmpty) {
                _mostrarSnackBar('Ingresa tu correo electrónico', const Color(0xFFb22222));
                return;
              }
              
              Navigator.pop(context);
              await _enviarRecuperacionContrasena(email);
            },
            style: EstilosApp.botonPrimario(context),
            child: const Text('Enviar enlace'),
          ),
        ],
      ),
    );
  }

  Future<void> _enviarRecuperacionContrasena(String email) async {
    setState(() => _estaCargando = true);
    
    try {
      await _auth.sendPasswordResetEmail(email: email);
      if (mounted) {
        _mostrarSnackBar(
          'Se ha enviado un enlace de recuperación a $email. Revisa tu bandeja de entrada.',
          const Color(0xFF32cd32),
        );
      }
    } on FirebaseAuthException catch (e) {
      String mensaje;
      switch (e.code) {
        case 'user-not-found':
          mensaje = 'No existe una cuenta con este correo electrónico';
          break;
        case 'invalid-email':
          mensaje = 'El formato del correo electrónico no es válido';
          break;
        default:
          mensaje = 'Error al enviar el correo de recuperación: ${e.message}';
      }
      if (mounted) {
        _mostrarSnackBar(mensaje, const Color(0xFFb22222));
      }
    } catch (e) {
      if (mounted) {
        _mostrarSnackBar('Error inesperado: $e', const Color(0xFFb22222));
      }
    } finally {
      if (mounted) setState(() => _estaCargando = false);
    }
  }

  void _mostrarSnackBar(String mensaje, Color color) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje, style: const TextStyle(color: Color(0xFFfffafa))),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: color == const Color(0xFF32cd32) ? 3 : 5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _construirCampoTexto(
    TextEditingController controlador,
    String etiqueta,
    IconData icono, {
    bool textoOculta = false,
    VoidCallback? alAlternarVisibilidad,
    TextInputType? tipoTeclado,
    required String hoverKey,
    required bool isHovered,
    required ValueChanged<bool> onHover,
    required Color fillColorNormal,
    required Color fillColorHover,
    required Color borderColor,
    required Color inputTextColor,
  }) {
    return MouseRegion(
      onEnter: (_) => onHover(true),
      onExit: (_) => onHover(false),
      child: TextFormField(
        controller: controlador,
        decoration: InputDecoration(
          labelText: etiqueta,
          labelStyle: const TextStyle(
            color: Color(0xFF696969),
            fontWeight: FontWeight.normal,
          ),
          floatingLabelStyle: const TextStyle(
            color: Color(0xFF696969),
            fontWeight: FontWeight.bold,
          ),
          prefixIcon: Icon(icono, color: AppColores.primario),
          suffixIcon: alAlternarVisibilidad != null
              ? MouseRegion(
                  onEnter: (_) => setState(() {
                    if (hoverKey == 'password') _hoverIconoPass = true;
                    if (hoverKey == 'confirmar') _hoverIconoConfirm = true;
                  }),
                  onExit: (_) => setState(() {
                    if (hoverKey == 'password') _hoverIconoPass = false;
                    if (hoverKey == 'confirmar') _hoverIconoConfirm = false;
                  }),
                  child: IconButton(
                    icon: Icon(
                      textoOculta ? Icons.visibility_off : Icons.visibility,
                      color: (hoverKey == 'password' && _hoverIconoPass) || (hoverKey == 'confirmar' && _hoverIconoConfirm)
                          ? const Color(0xFF008080)
                          : AppColores.primario,
                    ),
                    onPressed: alAlternarVisibilidad,
                    splashRadius: 0.1,
                    style: ButtonStyle(
                      overlayColor: MaterialStateProperty.all(Colors.transparent),
                    ),
                  ),
                )
              : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColores.primario, width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
            borderSide: BorderSide(color: borderColor),
          ),
          filled: true,
          fillColor: isHovered ? fillColorHover : fillColorNormal,
          contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
        ),
        obscureText: textoOculta,
        enabled: !_estaCargando,
        keyboardType: tipoTeclado,
        style: TextStyle(fontSize: 16, color: inputTextColor),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final esModoOscuro = themeProvider.esModoOscuro;

    final Color inputFillNormal = esModoOscuro ? const Color(0xFF1e1e1e) : const Color(0xFFf5f5f5);
    final Color inputFillHover = esModoOscuro ? const Color(0xFF2c2c2c) : const Color(0xFFdcdcdc);
    final Color inputBorderColor = esModoOscuro ? const Color(0xFF2c2c2c) : const Color(0xFFdcdcdc);
    final Color inputTextColor = esModoOscuro ? const Color(0xFFfffafa) : const Color(0xFF121212);
    final Color formularioTextoColor = esModoOscuro ? const Color(0xFFfffafa) : const Color(0xFF121212);
    final Color piePaginaColor = esModoOscuro ? const Color(0xFFfffafa) : const Color(0xFFf8f8ff);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColores.primario, AppColores.secundario],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
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
                    color: esModoOscuro ? const Color(0xFF121212) : const Color(0xFFfffafa),
                    borderRadius: const BorderRadius.all(Radius.circular(20)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: AppColores.primario.withValues(alpha: 0.1),
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
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: formularioTextoColor,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _esLogin
                            ? 'Bienvenido de vuelta a tu biblioteca personal'
                            : 'Únete a nuestra comunidad de lectores',
                        style: TextStyle(
                          fontSize: 16,
                          color: formularioTextoColor,
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
                          hoverKey: 'nombre',
                          isHovered: _hoverInputs['nombre']!,
                          onHover: (v) => setState(() => _hoverInputs['nombre'] = v),
                          fillColorNormal: inputFillNormal,
                          fillColorHover: inputFillHover,
                          borderColor: inputBorderColor,
                          inputTextColor: inputTextColor,
                        ),
                        const SizedBox(height: 20),
                      ],
                      _construirCampoTexto(
                        _controladorEmail,
                        'Correo electrónico',
                        Icons.email_outlined,
                        tipoTeclado: TextInputType.emailAddress,
                        hoverKey: 'email',
                        isHovered: _hoverInputs['email']!,
                        onHover: (v) => setState(() => _hoverInputs['email'] = v),
                        fillColorNormal: inputFillNormal,
                        fillColorHover: inputFillHover,
                        borderColor: inputBorderColor,
                        inputTextColor: inputTextColor,
                      ),
                      const SizedBox(height: 20),
                      _construirCampoTexto(
                        _controladorPassword,
                        'Contraseña',
                        Icons.lock_outline,
                        textoOculta: _passwordOculta,
                        alAlternarVisibilidad: _estaCargando
                            ? null
                            : () => setState(() => _passwordOculta = !_passwordOculta),
                        hoverKey: 'password',
                        isHovered: _hoverInputs['password']!,
                        onHover: (v) => setState(() => _hoverInputs['password'] = v),
                        fillColorNormal: inputFillNormal,
                        fillColorHover: inputFillHover,
                        borderColor: inputBorderColor,
                        inputTextColor: inputTextColor,
                      ),
                      const SizedBox(height: 20),
                      if (_esLogin) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: _mostrarDialogoRecuperarContrasena,
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(50, 30),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                '¿Olvidaste tu contraseña?',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColores.primario,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (!_esLogin) ...[
                        _construirCampoTexto(
                          _controladorConfirmarPassword,
                          'Confirmar contraseña',
                          Icons.lock_reset,
                          textoOculta: _confirmarPasswordOculta,
                          alAlternarVisibilidad: _estaCargando
                              ? null
                              : () => setState(() => _confirmarPasswordOculta = !_confirmarPasswordOculta),
                          hoverKey: 'confirmar',
                          isHovered: _hoverInputs['confirmar']!,
                          onHover: (v) => setState(() => _hoverInputs['confirmar'] = v),
                          fillColorNormal: inputFillNormal,
                          fillColorHover: inputFillHover,
                          borderColor: inputBorderColor,
                          inputTextColor: inputTextColor,
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
                            : MouseRegion(
                                onEnter: (_) => setState(() => _hoverBotonLogin = true),
                                onExit: (_) => setState(() => _hoverBotonLogin = false),
                                child: ElevatedButton(
                                  onPressed: _enviarFormulario,
                                  style: ButtonStyle(
                                    backgroundColor: MaterialStateProperty.resolveWith((states) {
                                      if (_hoverBotonLogin) return const Color(0xFF20b2aa);
                                      return const Color(0xFF008080);
                                    }),
                                    foregroundColor: MaterialStateProperty.resolveWith((states) {
                                      if (_hoverBotonLogin) return const Color(0xFFfffafa);
                                      return const Color(0xFFdcdcdc);
                                    }),
                                    elevation: MaterialStateProperty.all(0),
                                    shape: MaterialStateProperty.all(
                                      RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    padding: MaterialStateProperty.all(const EdgeInsets.symmetric(vertical: 15)),
                                  ),
                                  child: Text(
                                    _esLogin ? 'Iniciar Sesión' : 'Crear Cuenta',
                                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                                  ),
                                ),
                              ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: Divider(
                              color: formularioTextoColor.withOpacity(0.3),
                              thickness: 1,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'O continúa con',
                              style: TextStyle(
                                fontSize: 13,
                                color: formularioTextoColor.withOpacity(0.6),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              color: formularioTextoColor.withOpacity(0.3),
                              thickness: 1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: MouseRegion(
                          onEnter: (_) => setState(() => _hoverBotonGoogle = true),
                          onExit: (_) => setState(() => _hoverBotonGoogle = false),
                          child: OutlinedButton(
                            onPressed: _estaCargando ? null : _iniciarSesionConGoogle,
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: _hoverBotonGoogle ? AppColores.primario : Colors.grey,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              backgroundColor: _hoverBotonGoogle 
                                  ? AppColores.primario.withOpacity(0.05)
                                  : Colors.transparent,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: const BoxDecoration(
                                    image: DecorationImage(
                                      image: AssetImage('assets/googleLogo.png'),
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  _esLogin ? 'Iniciar con Google' : 'Registrarse con Google',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: _hoverBotonGoogle ? AppColores.primario : formularioTextoColor,
                                  ),
                                ),
                              ],
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
                            style: TextStyle(fontSize: 15, color: formularioTextoColor),
                          ),
                          const SizedBox(width: 8),
                          MouseRegion(
                            onEnter: (_) => setState(() => _hoverRegistro = true),
                            onExit: (_) => setState(() => _hoverRegistro = false),
                            child: GestureDetector(
                              onTap: _alternarModoAuth,
                              child: Text(
                                _esLogin ? 'Regístrate aquí' : 'Inicia sesión aquí',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: _hoverRegistro ? const Color(0xFF008080) : const Color(0xFF20b2aa),
                                ),
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
                  style: TextStyle(fontSize: 13, color: piePaginaColor),
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
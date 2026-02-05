import 'package:flutter/material.dart';

class AppColores {
  static const Color primario = Color(0xFF4A6FA5); 
  static const Color secundario = Color(0xFF6B8EAC); 
  static const Color acento = Color(0xFFF5A623); 
  static const Color fondo = Color(0xFFF8F9FA); 
  static const Color texto = Color(0xFF333333); 
  static const Color textoClaro = Color(0xFF666666); 
  static const Color error = Color(0xFFE74C3C); 
  static const Color exito = Color(0xFF2ECC71); 
  static const Color advertencia = Color(0xFFF39C12);
  static const Color borde = Color(0xFFDDDDDD); 
  static const Color deshabilitado = Color(0xFFB0B0B0); 
}

class EstilosApp {
  static const TextStyle tituloGrande = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: Colors.white,
    letterSpacing: -0.5,
  );

  static const TextStyle tituloMedio = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: AppColores.texto,
  );

  static const TextStyle tituloPequeno = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColores.texto,
  );

  static const TextStyle subtitulo = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColores.textoClaro,
  );

  static const TextStyle cuerpoGrande = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.normal,
    color: AppColores.texto,
    height: 1.5,
  );

  static const TextStyle cuerpoMedio = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: AppColores.texto,
    height: 1.4,
  );

  static const TextStyle cuerpoPequeno = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColores.textoClaro,
    height: 1.3,
  );

  static const TextStyle etiqueta = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColores.texto,
    letterSpacing: 0.5,
  );

  static const TextStyle boton = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Colors.white,
    letterSpacing: 0.5,
  );

  static ButtonStyle botonPrimario = ElevatedButton.styleFrom(
    backgroundColor: AppColores.primario,
    foregroundColor: Colors.white,
    elevation: 4,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
  );

  static ButtonStyle botonSecundario = OutlinedButton.styleFrom(
    side: const BorderSide(color: AppColores.primario, width: 2),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
  );

  static ButtonStyle botonDeshabilitado = ElevatedButton.styleFrom(
    backgroundColor: AppColores.deshabilitado,
    foregroundColor: Colors.white,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
  );

  static BoxDecoration tarjeta = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: Color.fromRGBO(0, 0, 0, 0.1),
        blurRadius: 20,
        spreadRadius: 1,
        offset: const Offset(0, 5),
      ),
    ],
  );

  static InputDecoration entradaTexto = InputDecoration(
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColores.borde),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColores.primario, width: 2),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColores.borde),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColores.error, width: 2),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColores.error, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
    hintStyle: const TextStyle(color: AppColores.textoClaro),
  );

  static InputDecoration entradaTextoConIcono(IconData icono) {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      prefixIcon: Icon(icono, color: AppColores.primario),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColores.borde),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColores.primario, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColores.borde),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColores.error, width: 2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColores.error, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      hintStyle: const TextStyle(color: AppColores.textoClaro),
    );
  }

  static BoxDecoration tarjetaPlana = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    boxShadow: [
      BoxShadow(
        color: Color.fromRGBO(0, 0, 0, 0.05),
        blurRadius: 8,
        spreadRadius: 1,
        offset: const Offset(0, 2),
      ),
    ],
  );

  static BoxDecoration decoracionGradiente = BoxDecoration(
    gradient: const LinearGradient(
      colors: [AppColores.primario, AppColores.secundario],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(16),
  );

  static Color rojo = AppColores.error; // Para sincronizacion_offline.dart
}

class DatosApp {
  static final List<String> generos = [
    'Todos los géneros',
    'Ficción',
    'Ciencia Ficción',
    'Fantasía',
    'Romance',
    'Misterio',
    'Terror',
    'No Ficción',
    'Biografía',
    'Historia',
    'Poesía',
    'Drama',
    'Aventura',
    'Infantil',
    'Juvenil',
    'Autoayuda',
  ];

  static final List<Map<String, dynamic>> accionesRapidas = [
    {'etiqueta': 'Buscar', 'icono': Icons.search},
    {'etiqueta': 'Favoritos', 'icono': Icons.favorite},
    {'etiqueta': 'Historial', 'icono': Icons.history},
    {'etiqueta': 'Recomendados', 'icono': Icons.star},
    {'etiqueta': 'Clubs', 'icono': Icons.group},
    {'etiqueta': 'Desafíos', 'icono': Icons.emoji_events},
    {'etiqueta': 'Configuración', 'icono': Icons.settings},
    {'etiqueta': 'Ayuda', 'icono': Icons.help},
  ];

  static final List<Map<String, dynamic>> seccionesPerfil = [
    {'texto': 'Información', 'icono': Icons.person},
    {'texto': 'Progreso', 'icono': Icons.trending_up},
    {'texto': 'Estadísticas', 'icono': Icons.bar_chart},
    {'texto': 'Preferencias', 'icono': Icons.tune},
    {'texto': 'Configuración', 'icono': Icons.settings},
  ];
}

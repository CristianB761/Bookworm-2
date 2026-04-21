import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme_provider.dart';

class AppColores {
  static const Color primario = Color(0xFF20B2AA);
  static const Color secundario = Color(0xFF20B2AA);
  static const Color acento = Color(0xFFFFD700);
  static const Color error = Color(0xFFB22222);
  static const Color exito = Color(0xFF32CD32);
  static const Color advertencia = Color(0xFFFF8C00);

  static Color get fondo => _getColor(const Color(0xFFF8F9FA), const Color(0xFF121212));
  static Color get texto => _getColor(const Color(0xFF333333), const Color(0xFFF5F5F5));
  static Color get textoClaro => _getColor(const Color(0xFF666666), const Color(0xFFAAAAAA));
  static Color get borde => _getColor(const Color(0xFFDDDDDD), const Color(0xFF444444));
  static Color get deshabilitado => _getColor(const Color(0xFFB0B0B0), const Color(0xFF666666));
  static Color get blancoONegro => _getColor(Colors.white, Colors.black);
  static Color get negroOBlanco => _getColor(Colors.black, Colors.white);

  static Color _getColor(Color light, Color dark) {
    final brightness = WidgetsBinding.instance.window.platformBrightness;
    return brightness == Brightness.light ? light : dark;
  }

  static Color getColorForTheme(BuildContext context, Color light, Color dark) {
    try {
      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
      return themeProvider.esModoOscuro ? dark : light;
    } catch (e) {
      final brightness = MediaQuery.platformBrightnessOf(context);
      return brightness == Brightness.light ? light : dark;
    }
  }
}

class EstilosApp {
  static TextStyle tituloGrande(BuildContext context) {
    return const TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.bold,
      color: Colors.white,
      letterSpacing: -0.5,
    );
  }

  static TextStyle tituloMedio(BuildContext context) {
    return TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      color: Theme.of(context).textTheme.bodyLarge?.color,
    );
  }

  static TextStyle tituloPequeno(BuildContext context) {
    return TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: Theme.of(context).textTheme.bodyLarge?.color,
    );
  }

  static TextStyle subtitulo(BuildContext context) {
    return TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
    );
  }

  static TextStyle cuerpoGrande(BuildContext context) {
    return TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.normal,
      color: Theme.of(context).textTheme.bodyLarge?.color,
      height: 1.5,
    );
  }

  static TextStyle cuerpoMedio(BuildContext context) {
    return TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.normal,
      color: Theme.of(context).textTheme.bodyMedium?.color,
      height: 1.4,
    );
  }

  static TextStyle cuerpoPequeno(BuildContext context) {
    return TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.normal,
      color: Theme.of(context).textTheme.bodySmall?.color,
      height: 1.3,
    );
  }

  static TextStyle etiqueta(BuildContext context) {
    return TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: Theme.of(context).textTheme.bodyMedium?.color,
      letterSpacing: 0.5,
    );
  }

  static TextStyle boton(BuildContext context) {
    return const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: Colors.white,
      letterSpacing: 0.5,
    );
  }

  static ButtonStyle botonPrimario(BuildContext context) {
    return ElevatedButton.styleFrom(
      backgroundColor: AppColores.primario,
      foregroundColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    );
  }

  static ButtonStyle botonSecundario(BuildContext context) {
    return OutlinedButton.styleFrom(
      side: const BorderSide(color: AppColores.primario, width: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      foregroundColor: AppColores.primario,
    );
  }

  static ButtonStyle botonDeshabilitado(BuildContext context) {
    return ElevatedButton.styleFrom(
      backgroundColor: AppColores.deshabilitado,
      foregroundColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    );
  }

  static BoxDecoration tarjeta(BuildContext context) {
    return BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(16),
    );
  }

  static BoxDecoration tarjetaPlana(BuildContext context) {
    final esModoOscuro = Theme.of(context).brightness == Brightness.dark;
    final colorFondo = esModoOscuro ? const Color(0xFF2C2C2C) : const Color(0xFFF5F5F5);

    return BoxDecoration(
      color: colorFondo,
      borderRadius: BorderRadius.circular(12),
    );
  }

  static BoxDecoration decoracionGradiente(BuildContext context) {
    return BoxDecoration(
      gradient: LinearGradient(
        colors: [AppColores.primario, AppColores.secundario],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(16),
    );
  }

  static Color rojo = AppColores.error;
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
    {'etiqueta': 'Recomendaciones', 'icono': Icons.recommend},
    {'etiqueta': 'Desafíos', 'icono': Icons.emoji_events},
    {'etiqueta': 'Clubs', 'icono': Icons.group},
    {'etiqueta': 'Historial', 'icono': Icons.history},
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
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'diseno.dart';
import 'API/modelos.dart';
import 'theme_provider.dart';
import 'servicio/servicio_notificaciones.dart';

class BotonesBarraApp extends StatelessWidget {
  final String rutaActual;

  const BotonesBarraApp({super.key, required this.rutaActual});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.esModoOscuro;

    final rutas = {
      'Inicio': {'ruta': '/home', 'icono': Icons.home},
      'Buscar': {'ruta': '/search', 'icono': Icons.search},
      'Clubs': {'ruta': '/clubs', 'icono': Icons.group},
      'Perfil': {'ruta': '/perfil', 'icono': Icons.person},
    };

    return Row(
      children: rutas.entries.map((e) => _construirBotonBarraApp(
        context,
        e.key,
        e.value['ruta'] as String,
        e.value['icono'] as IconData,
        isDark,
      )).toList(),
    );
  }

  Widget _construirBotonBarraApp(BuildContext context, String texto, String ruta, IconData icono, bool isDark) {
    final estaActivo = rutaActual == ruta;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: TextButton(
        onPressed: () {
          if (ModalRoute.of(context)?.settings.name != ruta) {
            Navigator.pushReplacementNamed(context, ruta);
          }
        },
        style: ButtonStyle(
          foregroundColor: MaterialStateProperty.resolveWith((states) {
            if (estaActivo) return const Color(0xFFdcdcdc);
            if (states.contains(MaterialState.hovered) && !estaActivo) return const Color(0xFFdcdcdc);
            return const Color(0xFFfffafa);
          }),
          backgroundColor: MaterialStateProperty.resolveWith((states) {
            if (estaActivo) return const Color(0xFF008080);
            if (states.contains(MaterialState.hovered) && !estaActivo) return const Color(0xFF008080);
            return const Color(0xFF20b2aa);
          }),
          shape: MaterialStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          padding: MaterialStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 18),
            const SizedBox(width: 6),
            Text(
              texto,
              style: TextStyle(
                fontSize: 14,
                fontWeight: estaActivo ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BotonSeccion extends StatelessWidget {
  final String texto;
  final bool estaSeleccionado;
  final IconData icono;
  final VoidCallback alPresionar;

  const BotonSeccion({
    super.key,
    required this.texto,
    required this.estaSeleccionado,
    required this.icono,
    required this.alPresionar,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: alPresionar,
      style: ElevatedButton.styleFrom(
        backgroundColor: estaSeleccionado ? AppColores.primario : Colors.transparent,
        foregroundColor: estaSeleccionado ? Color(0xFFfffafa) : AppColores.primario,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: estaSeleccionado ? AppColores.primario : Theme.of(context).dividerColor,
          ),
        ),
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icono, size: 18),
          const SizedBox(width: 8),
          Text(texto, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class EstadoVacio extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String descripcion;

  const EstadoVacio({
    super.key,
    required this.icono,
    required this.titulo,
    required this.descripcion,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hintColor = isDark ? const Color(0xFF888888) : const Color(0xFF696969);
    final textColor = isDark ? const Color(0xFFfffafa) : const Color(0xFF121212);

    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(icono, size: 48, color: hintColor),
            const SizedBox(height: 16),
            Text(
              titulo,
              style: EstilosApp.cuerpoPequeno(context).copyWith(
                color: textColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              descripcion,
              style: EstilosApp.cuerpoPequeno(context).copyWith(color: hintColor),
            ),
          ],
        ),
      ),
    );
  }
}

class BarraBusquedaPersonalizada extends StatelessWidget {
  final TextEditingController controlador;
  final String textoHint;
  final VoidCallback alBuscar;

  const BarraBusquedaPersonalizada({
    super.key,
    required this.controlador,
    required this.textoHint,
    required this.alBuscar,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorFondo = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFf5f5f5);
    final colorBorde = isDark ? const Color(0xFF444444) : const Color(0xFFdcdcdc);
    final colorLupa = isDark ? AppColores.primario : const Color(0xFF20b2aa);
    final colorTexto = isDark ? const Color(0xFFfffafa) : const Color(0xFF121212);
    final colorHint = isDark ? const Color(0xFF888888) : const Color(0xFF696969);

    return Row(
      children: [
        Expanded(
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: colorFondo,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorBorde),
            ),
            child: TextField(
              controller: controlador,
              decoration: InputDecoration(
                hintText: textoHint,
                hintStyle: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.normal,
                  color: colorHint,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                prefixIcon: Icon(Icons.search, color: colorLupa),
              ),
              style: TextStyle(
                fontSize: 16,
                color: colorTexto,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: alBuscar,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF20b2aa),
              foregroundColor: const Color(0xFFfffafa),
              elevation: 0,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ).copyWith(
              backgroundColor: MaterialStateProperty.resolveWith((states) {
                if (states.contains(MaterialState.hovered)) {
                  return const Color(0xFF008080);
                }
                return const Color(0xFF20b2aa);
              }),
              foregroundColor: MaterialStateProperty.resolveWith((states) {
                if (states.contains(MaterialState.hovered)) {
                  return const Color(0xFFdcdcdc);
                }
                return const Color(0xFFfffafa);
              }),
            ),
            child: const Text('Buscar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}

class FiltroDesplegable extends StatelessWidget {
  final String? valor;
  final List<String> items;
  final String hint;
  final ValueChanged<String?> alCambiar;

  const FiltroDesplegable({
    super.key,
    required this.valor,
    required this.items,
    required this.hint,
    required this.alCambiar,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorFondo = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFf5f5f5);
    final colorTexto = isDark ? const Color(0xFFfffafa) : const Color(0xFF121212);
    final colorHint = isDark ? const Color(0xFF888888) : const Color(0xFF696969);
    final colorBorde = isDark ? const Color(0xFF444444) : const Color(0xFFdcdcdc);
    final colorFlecha = isDark ? AppColores.primario : const Color(0xFF20b2aa);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: colorFondo,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorBorde),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: valor,
          isExpanded: true,
          hint: Text(
            hint,
            style: TextStyle(
              color: colorHint,
              fontSize: 16,
            ),
          ),
          dropdownColor: colorFondo,
          style: TextStyle(
            color: colorTexto,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          icon: Icon(Icons.arrow_drop_down, color: colorFlecha),
          items: items.map((valor) => DropdownMenuItem<String>(
            value: valor,
            child: Text(valor, style: TextStyle(color: colorTexto)),
          )).toList(),
          onChanged: alCambiar,
        ),
      ),
    );
  }
}

class TarjetaLibro extends StatelessWidget {
  final Libro libro;
  final VoidCallback? alPresionar;

  const TarjetaLibro({
    super.key,
    required this.libro,
    this.alPresionar,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: alPresionar,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: EstilosApp.tarjetaPlana(context),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _construirPortadaLibro(),
            const SizedBox(width: 16),
            Expanded(child: _construirInfoLibro(context)),
          ],
        ),
      ),
    );
  }

  Widget _construirPortadaLibro() {
    return Container(
      width: 80,
      height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: const Color(0xFFEEEEEE),
      ),
      child: libro.urlMiniatura != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                libro.urlMiniatura!,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progresoCarga) {
                  if (progresoCarga == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: progresoCarga.expectedTotalBytes != null
                          ? progresoCarga.cumulativeBytesLoaded / progresoCarga.expectedTotalBytes!
                          : null,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.book, size: 40, color: Color(0xFF9E9E9E));
                },
              ),
            )
          : const Icon(Icons.book, size: 40, color: Color(0xFF9E9E9E)),
    );
  }

  Widget _construirInfoLibro(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          libro.titulo,
          style: EstilosApp.tituloPequeno(context),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),

        if (libro.autores.isNotEmpty)
          Text(
            'Por ${libro.autores.join(', ')}',
            style: EstilosApp.cuerpoMedio(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

        if (libro.fechaPublicacion != null) ...[
          const SizedBox(height: 4),
          Text(
            'Publicado: ${libro.fechaPublicacion}',
            style: EstilosApp.cuerpoPequeno(context),
          ),
        ],

        if (libro.calificacionPromedio != null) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.star, size: 16, color: Color(0xFFff8c00)),
              const SizedBox(width: 4),
              Text(
                '${libro.calificacionPromedio!.toStringAsFixed(1)} (${libro.numeroCalificaciones ?? 0})',
                style: EstilosApp.cuerpoPequeno(context),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class ElementoConfiguracion extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final IconData icono;
  final bool tieneSwitch;
  final bool valorSwitch;
  final ValueChanged<bool>? alCambiarSwitch;
  final VoidCallback? alPresionar;

  const ElementoConfiguracion({
    super.key,
    required this.titulo,
    required this.subtitulo,
    required this.icono,
    this.tieneSwitch = false,
    this.valorSwitch = false,
    this.alCambiarSwitch,
    this.alPresionar,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColores.primario.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icono, size: 20, color: AppColores.primario),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: EstilosApp.cuerpoGrande(context)),
                const SizedBox(height: 4),
                Text(subtitulo, style: EstilosApp.cuerpoMedio(context)),
              ],
            ),
          ),
          if (tieneSwitch)
            Switch(
              value: valorSwitch,
              onChanged: alCambiarSwitch,
              activeColor: AppColores.primario,
            )
          else
            Icon(Icons.chevron_right, color: Theme.of(context).hintColor),
        ],
      ),
    );

    if (alPresionar != null) {
      return InkWell(
        onTap: alPresionar,
        child: content,
      );
    }

    return content;
  }
}

class IndicadorCarga extends StatelessWidget {
  final String mensaje;

  const IndicadorCarga({
    super.key,
    this.mensaje = 'Cargando...',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppColores.primario)),
          const SizedBox(height: 16),
          Text(mensaje, style: EstilosApp.cuerpoMedio(context)),
        ],
      ),
    );
  }
}

class BotonAccionRapida extends StatelessWidget {
  final String texto;
  final IconData icono;
  final VoidCallback alPresionar;

  const BotonAccionRapida({
    super.key,
    required this.texto,
    required this.icono,
    required this.alPresionar,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: alPresionar,
      style: ButtonStyle(
        foregroundColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.hovered)) return const Color(0xFFfffafa);
          return const Color(0xFFdcdcdc);
        }),
        backgroundColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.hovered)) return const Color(0xFF20b2aa);
          return const Color(0xFF008080);
        }),
        shape: MaterialStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
        padding: MaterialStateProperty.all(const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 16),
          const SizedBox(width: 6),
          Text(
            texto,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class TextoConLinks extends StatelessWidget {
  final String texto;
  final TextStyle? estilo;
  final int? maxLineas;
  final TextOverflow? desbordamiento;

  const TextoConLinks({
    super.key,
    required this.texto,
    this.estilo,
    this.maxLineas,
    this.desbordamiento,
  });

  List<_Segmento> _analizarTexto(String texto) {
    final List<_Segmento> segmentos = [];

    final patrones = [
      RegExp(r'https?://[^\s]+'),
      RegExp(r'www\.[^\s]+'),
      RegExp(r'(?:instagram|tiktok|twitter|facebook|youtube|linkedin|twitch|discord)\.[^\s]*(?:\.com)?|@[a-zA-Z0-9_.]+'),
    ];

    int ultimaPosicion = 0;
    final partesEncontradas = <_Match>[];

    for (final patron in patrones) {
      for (final coincidencia in patron.allMatches(texto)) {
        partesEncontradas.add(_Match(
          inicio: coincidencia.start,
          fin: coincidencia.end,
          texto: coincidencia.group(0)!,
          esLink: true,
        ));
      }
    }

    partesEncontradas.sort((a, b) => a.inicio.compareTo(b.inicio));

    for (final parte in partesEncontradas) {
      if (ultimaPosicion < parte.inicio) {
        segmentos.add(_Segmento(
          texto: texto.substring(ultimaPosicion, parte.inicio),
          esLink: false,
          url: null,
        ));
      }

      final url = _prepararUrl(parte.texto);
      segmentos.add(_Segmento(
        texto: parte.texto,
        esLink: true,
        url: url,
      ));

      ultimaPosicion = parte.fin;
    }

    if (ultimaPosicion < texto.length) {
      segmentos.add(_Segmento(
        texto: texto.substring(ultimaPosicion),
        esLink: false,
        url: null,
      ));
    }

    if (segmentos.isEmpty) {
      segmentos.add(_Segmento(
        texto: texto,
        esLink: false,
        url: null,
      ));
    }

    return segmentos;
  }

  String _prepararUrl(String texto) {
    String url = texto.trim();

    if (url.startsWith('@')) {
      return 'https://instagram.com/${url.substring(1)}';
    }

    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      if (url.contains('instagram')) return 'https://$url';
      if (url.contains('tiktok')) return 'https://$url';
      if (url.contains('twitter')) return 'https://$url';
      if (url.contains('facebook')) return 'https://$url';
      if (url.contains('youtube')) return 'https://$url';
      if (url.contains('linkedin')) return 'https://$url';
      if (url.contains('twitch')) return 'https://$url';
      if (url.contains('discord')) return 'https://$url';
      if (url.startsWith('www.')) return 'https://$url';
    }

    return url;
  }

  void _abrirUrl(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
      }
    } catch (e) {
    }
  }

  @override
  Widget build(BuildContext context) {
    final segmentos = _analizarTexto(texto);
    final colorLink = AppColores.primario;

    return RichText(
      maxLines: maxLineas,
      overflow: desbordamiento ?? TextOverflow.clip,
      text: TextSpan(
        children: segmentos.map((segmento) {
          if (segmento.esLink && segmento.url != null) {
            return TextSpan(
              text: segmento.texto,
              style: (estilo ?? const TextStyle()).copyWith(
                color: colorLink,
                decoration: TextDecoration.underline,
                decorationColor: colorLink,
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = () => _abrirUrl(segmento.url!),
            );
          } else {
            return TextSpan(
              text: segmento.texto,
              style: estilo,
            );
          }
        }).toList(),
      ),
    );
  }
}

class _Segmento {
  final String texto;
  final bool esLink;
  final String? url;

  _Segmento({
    required this.texto,
    required this.esLink,
    this.url,
  });
}

class _Match {
  final int inicio;
  final int fin;
  final String texto;
  final bool esLink;

  _Match({
    required this.inicio,
    required this.fin,
    required this.texto,
    required this.esLink,
  });
}

class BotonNotificaciones extends StatefulWidget {
  const BotonNotificaciones({super.key});

  @override
  State<BotonNotificaciones> createState() => _BotonNotificacionesState();
}

class _BotonNotificacionesState extends State<BotonNotificaciones> {
  late OverlayEntry _overlayEntry;
  bool _mostrarDropdown = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<ServicioNotificaciones>(
      builder: (context, servicio, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications),
                tooltip: 'Notificaciones',
                onPressed: () {
                  setState(() {
                    _mostrarDropdown = !_mostrarDropdown;
                  });
                  if (_mostrarDropdown) {
                    _mostrarMenuNotificaciones(context, servicio);
                  } else {
                    _ocultarMenuNotificaciones();
                  }
                },
              ),
              if (servicio.contadorNoLeidosTotal > 0)
                Positioned(
                  right: 4,
                  top: 4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      servicio.contadorNoLeidosTotal > 99
                          ? '99+'
                          : servicio.contadorNoLeidosTotal.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _mostrarMenuNotificaciones(
    BuildContext context,
    ServicioNotificaciones servicio,
  ) {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Positioned(
          right: MediaQuery.of(context).size.width - (offset.dx + size.width),
          top: offset.dy + size.height + 8,
          width: 320,
          child: CompositedTransformFollower(
            link: LayerLink(),
            showWhenUnlinked: true,
            offset: const Offset(0, 8),
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF1E1E1E)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).dividerColor,
                  ),
                ),
                child: servicio.notificaciones.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.notifications_none,
                                size: 32,
                                color: Theme.of(context).hintColor,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'No hay notificaciones',
                                style: TextStyle(
                                  color: Theme.of(context).hintColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 400),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: servicio.notificaciones.length,
                          itemBuilder: (context, index) {
                            final notificacion = servicio.notificaciones[index];
                            return _construirItemNotificacion(
                              context,
                              notificacion,
                              servicio,
                            );
                          },
                        ),
                      ),
              ),
            ),
          ),
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry);
  }

  void _ocultarMenuNotificaciones() {
    if (_overlayEntry.mounted) {
      _overlayEntry.remove();
    }
  }

  Widget _construirItemNotificacion(
    BuildContext context,
    Notificacion notificacion,
    ServicioNotificaciones servicio,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          _ocultarMenuNotificaciones();
          setState(() {
            _mostrarDropdown = false;
          });
          
          Navigator.pushNamed(
            context,
            '/chat_club',
            arguments: {
              'clubId': notificacion.clubId,
              'clubNombre': notificacion.clubNombre,
            },
          );
          
          servicio.marcarComoLeido(notificacion.clubId, notificacion.id);
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF5F5F5),
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      notificacion.clubNombre,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.circle,
                    size: 8,
                    color: AppColores.primario,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${notificacion.usuarioNombre}: ${notificacion.mensaje}',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                _formatearTiempoTranscurrido(notificacion.timestamp),
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatearTiempoTranscurrido(DateTime fechaNotificacion) {
    final ahora = DateTime.now();
    final diferencia = ahora.difference(fechaNotificacion);

    if (diferencia.inSeconds < 60) {
      return 'Hace unos segundos';
    } else if (diferencia.inMinutes < 60) {
      return 'Hace ${diferencia.inMinutes} min';
    } else if (diferencia.inHours < 24) {
      return 'Hace ${diferencia.inHours} h';
    } else if (diferencia.inDays == 1) {
      return 'Ayer';
    } else if (diferencia.inDays < 7) {
      return 'Hace ${diferencia.inDays} días';
    } else {
      return 'Hace ${(diferencia.inDays / 7).floor()} semanas';
    }
  }
}
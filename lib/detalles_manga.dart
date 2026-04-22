import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'diseno.dart';
import 'API/modelos.dart';

class DetallesManga extends StatefulWidget {
  final Manga mangaObjeto;
  const DetallesManga({super.key, required this.mangaObjeto});

  @override
  State<DetallesManga> createState() => _DetallesMangaState();
}

class _DetallesMangaState extends State<DetallesManga> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _esFavorito = false;
  bool _estaGuardado = false;

  @override
  void initState() {
    super.initState();
    _verificarEstadoManga();
  }

  Future<void> _verificarEstadoManga() async {
    try {
      final usuario = _auth.currentUser;
      if (usuario == null) return;

      final mangaDoc = await _firestore
          .collection('usuarios')
          .doc(usuario.uid)
          .collection('mangas_guardados')
          .doc(widget.mangaObjeto.id)
          .get();

      if (mangaDoc.exists) {
        final data = mangaDoc.data();
        if (data != null) {
          setState(() {
            _esFavorito = data['favorito'] == true;
            _estaGuardado = true;
          });
        }
      }
    } catch (e) {
    }
  }

  Future<void> _toggleFavorito() async {
    try {
      final usuario = _auth.currentUser;
      if (usuario == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Debes iniciar sesión primero')),
        );
        return;
      }

      final nuevoEstado = !_esFavorito;
      await _firestore
          .collection('usuarios')
          .doc(usuario.uid)
          .collection('mangas_guardados')
          .doc(widget.mangaObjeto.id)
          .set({
            'id': widget.mangaObjeto.id,
            'titulo': widget.mangaObjeto.titulo,
            'urlPortada': widget.mangaObjeto.urlPortada,
            'autores': widget.mangaObjeto.autores,
            'favorito': nuevoEstado,
            'fechaGuardado': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      setState(() {
        _esFavorito = nuevoEstado;
        _estaGuardado = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nuevoEstado ? '¡Añadido a favoritos!' : 'Removido de favoritos',
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _abrirURL(String url) async {
    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir el enlace: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: CustomScrollView(
        slivers: [
          // AppBar con portada
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: const Color(0xFF121212),
            flexibleSpace: FlexibleSpaceBar(
              background: widget.mangaObjeto.urlPortada != null
                  ? Image.network(
                      widget.mangaObjeto.urlPortada!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: const Color(0xFF1e1e1e),
                        child: const Icon(Icons.broken_image, size: 100),
                      ),
                    )
                  : Container(
                      color: const Color(0xFF1e1e1e),
                      child: const Icon(Icons.image, size: 100),
                    ),
            ),
          ),

          // Contenido
          SliverList(
            delegate: SliverChildListDelegate([
              Container(
                padding: const EdgeInsets.all(20),
                color: const Color(0xFF121212),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Título
                    Text(
                      widget.mangaObjeto.titulo,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Autores
                    Text(
                      widget.mangaObjeto.autores.join(', '),
                      style: TextStyle(
                        fontSize: 16,
                        color: const Color(0xFFAAAAAA),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Calificaciones
                    Row(
                      children: [
                        if (widget.mangaObjeto.calificacionAniList != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1e1e1e),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'AniList',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: const Color(0xFFAAAAAA),
                                  ),
                                ),
                                Text(
                                  '${(widget.mangaObjeto.calificacionAniList! / 10).toStringAsFixed(1)}/10',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColores.acento,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        if (widget.mangaObjeto.calificacionMangaDex != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1e1e1e),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'MangaDex',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: const Color(0xFFAAAAAA),
                                  ),
                                ),
                                Text(
                                  '${widget.mangaObjeto.calificacionMangaDex!.toStringAsFixed(1)}/10',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColores.acento,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Estado
                    if (widget.mangaObjeto.estado != null) ...[
                      Chip(
                        label: Text(widget.mangaObjeto.estado!),
                        backgroundColor: const Color(0xFF1e1e1e),
                        labelStyle: TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Sinopsis
                    if (widget.mangaObjeto.sinopsis != null &&
                        widget.mangaObjeto.sinopsis!.isNotEmpty) ...[
                      Text(
                        'Sinopsis',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.mangaObjeto.sinopsis!,
                        style: TextStyle(
                          fontSize: 14,
                          color: const Color(0xFFAAAAAA),
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Géneros
                    if (widget.mangaObjeto.generos.isNotEmpty) ...[
                      Text(
                        'Géneros',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: widget.mangaObjeto.generos.map((genero) {
                          return Chip(
                            label: Text(genero),
                            backgroundColor: const Color(0xFF1e1e1e),
                            labelStyle: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Temas
                    if (widget.mangaObjeto.temas.isNotEmpty) ...[
                      Text(
                        'Temas',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: widget.mangaObjeto.temas.map((tema) {
                          return Chip(
                            label: Text(tema),
                            backgroundColor: AppColores.acento.withAlpha(50),
                            labelStyle: TextStyle(
                              color: AppColores.acento,
                              fontSize: 12,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Adaptación anime
                    if (widget.mangaObjeto.adaptacionAnime != null) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1e1e1e),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColores.acento),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.tv, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Adaptación anime',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFFAAAAAA),
                                    ),
                                  ),
                                  Text(
                                    widget.mangaObjeto.adaptacionAnime!,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Botones de acción
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _toggleFavorito,
                            icon: Icon(
                              _esFavorito ? Icons.favorite : Icons.favorite_border,
                            ),
                            label: Text(
                              _esFavorito ? 'En favoritos' : 'Añadir a favoritos',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _esFavorito
                                  ? AppColores.acento
                                  : const Color(0xFF1e1e1e),
                              foregroundColor: _esFavorito
                                  ? Colors.white
                                  : const Color(0xFFAAAAAA),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (widget.mangaObjeto.urlMangaDex != null)
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () =>
                                  _abrirURL(widget.mangaObjeto.urlMangaDex!),
                              icon: const Icon(Icons.open_in_new),
                              label: const Text('MangaDex'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1e1e1e),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (widget.mangaObjeto.urlAniList != null)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              _abrirURL(widget.mangaObjeto.urlAniList!),
                          icon: const Icon(Icons.open_in_new),
                          label: const Text('Ver en AniList'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1e1e1e),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

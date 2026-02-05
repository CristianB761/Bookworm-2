import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';
import 'diseno.dart';
import 'componentes.dart';

class Desafios extends StatefulWidget {
  const Desafios({super.key});

  @override
  State<Desafios> createState() => _DesafiosState();
}

class _DesafiosState extends State<Desafios> {
  final TextEditingController _notaController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void dispose() {
    _notaController.dispose();
    super.dispose();
  }

  Future<void> _agregarNota() async {
    if (_notaController.text.trim().isEmpty) return;

    final usuario = _auth.currentUser;
    if (usuario == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes iniciar sesión')),
      );
      return;
    }

    final colores = [
      0xFFFFF59D, 
      0xFFFFCCBC, 
      0xFFB3E5FC, 
      0xFFC8E6C9, 
      0xFFE1BEE7, 
      0xFFFFCDD2, 
    ];
    
    final colorRandom = colores[Random().nextInt(colores.length)];

    try {
      await _firestore
          .collection('usuarios')
          .doc(usuario.uid)
          .collection('notas_desafios')
          .add({
        'texto': _notaController.text.trim(),
        'fecha': FieldValue.serverTimestamp(),
        'color': colorRandom,
      });

      _notaController.clear();
      if (mounted) {
        FocusScope.of(context).unfocus();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _eliminarNota(String id) async {
    final usuario = _auth.currentUser;
    if (usuario == null) return;

    await _firestore
        .collection('usuarios')
        .doc(usuario.uid)
        .collection('notas_desafios')
        .doc(id)
        .delete();
  }

  @override
  Widget build(BuildContext context) {
    final usuario = _auth.currentUser;

    return Scaffold(
      backgroundColor: AppColores.fondo,
      appBar: AppBar(
        title: const Text('Mis Desafíos', style: EstilosApp.tituloGrande),
        backgroundColor: AppColores.primario,
        foregroundColor: Colors.white,
        actions: const [BotonesBarraApp(rutaActual: '/desafios')],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _notaController,
                    decoration: InputDecoration(
                      hintText: 'Escribe una meta, idea o frase...',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                    maxLines: 1,
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: (_) => _agregarNota(),
                  ),
                ),
                const SizedBox(width: 12),
                FloatingActionButton.small(
                  onPressed: _agregarNota,
                  backgroundColor: AppColores.primario,
                  elevation: 2,
                  child: const Icon(Icons.add, color: Colors.white),
                ),
              ],
            ),
          ),
          Expanded(
            child: usuario == null 
                ? const Center(child: Text('Inicia sesión para ver tus notas'))
                : StreamBuilder<QuerySnapshot>(
                    stream: _firestore
                        .collection('usuarios')
                        .doc(usuario.uid)
                        .collection('notas_desafios')
                        .orderBy('fecha', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) return const Center(child: Text('Error al cargar notas'));
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final docs = snapshot.data?.docs ?? [];

                      if (docs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.note_alt_outlined, size: 64, color: Colors.grey[300]),
                              const SizedBox(height: 16),
                              Text(
                                'Tus notas aparecerán aquí',
                                style: TextStyle(color: Colors.grey[500], fontSize: 16),
                              ),
                            ],
                          ),
                        );
                      }

                      return GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 1.0,
                        ),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final data = docs[index].data() as Map<String, dynamic>;
                          final id = docs[index].id;
                          final colorValue = data['color'] ?? 0xFFFFF59D;
                          final color = Color(colorValue);
                          
                          return _construirPostIt(id, data['texto'] ?? '', color);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _construirPostIt(String id, String texto, Color color) {
    return Stack(
      children: [
        Transform.rotate(
          angle: (id.hashCode % 10 - 5) * 0.01,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            padding: const EdgeInsets.fromLTRB(8, 20, 8, 8),
            decoration: BoxDecoration(
              color: color,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 8,
                  offset: const Offset(3, 3),
                ),
              ],
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(2),
                bottomRight: Radius.circular(15),
                topLeft: Radius.circular(2),
                topRight: Radius.circular(2),
              ),
            ),
            child: Center(
              child: SingleChildScrollView(
                child: Text(
                  texto,
                  style: const TextStyle(
                    fontSize: 22,
                    color: Color(0xFF333333),
                    height: 1.3,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () => _eliminarNota(id),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 14, color: Colors.black54),
            ),
          ),
        ),
        Positioned(
          top: -8,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.red[400],
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 2,
                    offset: const Offset(1, 1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
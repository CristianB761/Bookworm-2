import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'diseno.dart';
import 'componentes.dart';
import 'API/modelos.dart';
import 'theme_provider.dart';

class Historial extends StatelessWidget {
  const Historial({super.key});

  Future<void> _eliminarDelHistorial(BuildContext context, String docId) async {
    final usuario = FirebaseAuth.instance.currentUser;
    if (usuario == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(usuario.uid)
          .collection('historial')
          .doc(docId)
          .delete();
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Libro eliminado del historial'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
    }
  }

  Future<void> _borrarTodoElHistorial(BuildContext context) async {
    final usuario = FirebaseAuth.instance.currentUser;
    if (usuario == null) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Borrar historial'),
        content: const Text('¿Estás seguro de que quieres borrar todo el historial?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Borrar todo'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      final batch = FirebaseFirestore.instance.batch();
      final snapshot = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(usuario.uid)
          .collection('historial')
          .get();

      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Historial borrado completamente'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final usuario = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Búsqueda'),
        backgroundColor: AppColores.primario,
        foregroundColor: Colors.white,
        actions: [
          if (usuario != null)
            Tooltip(
              message: 'Borrar todo',
              child: TextButton(
                onPressed: () => _borrarTodoElHistorial(context),
                style: ButtonStyle(
                  foregroundColor: MaterialStateProperty.resolveWith((states) {
                    if (states.contains(MaterialState.hovered)) return const Color(0xFFDCDCDC);
                    return const Color(0xFFFAFAFA);
                  }),
                  backgroundColor: MaterialStateProperty.resolveWith((states) {
                    if (states.contains(MaterialState.hovered)) return const Color(0xFF008080);
                    return const Color(0xFF20B2AA);
                  }),
                  shape: MaterialStateProperty.all(
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  padding: MaterialStateProperty.all(
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                child: const Icon(Icons.delete_sweep, size: 18),
              ),
            ),
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, _) {
              return TextButton(
                onPressed: () => themeProvider.alternarTema(),
                style: ButtonStyle(
                  foregroundColor: MaterialStateProperty.resolveWith((states) {
                    if (states.contains(MaterialState.hovered)) return const Color(0xFFDCDCDC);
                    return const Color(0xFFFAFAFA);
                  }),
                  backgroundColor: MaterialStateProperty.resolveWith((states) {
                    if (states.contains(MaterialState.hovered)) return const Color(0xFF008080);
                    return const Color(0xFF20B2AA);
                  }),
                  shape: MaterialStateProperty.all(
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  padding: MaterialStateProperty.all(
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                child: Icon(
                  themeProvider.esModoOscuro ? Icons.light_mode : Icons.dark_mode,
                  size: 18,
                ),
              );
            },
          ),
          const BotonesBarraApp(rutaActual: '/historial'),
        ],
      ),
      body: usuario == null
          ? const Center(child: Text('Inicia sesión para ver tu historial'))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('usuarios')
                  .doc(usuario.uid)
                  .collection('historial')
                  .orderBy('fechaVisto', descending: true)
                  .limit(50)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: EstadoVacio(
                      icono: Icons.history,
                      titulo: 'Historial vacío',
                      descripcion: 'Los libros que veas aparecerán aquí',
                    ),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 14,
                    childAspectRatio: 0.7,
                  ),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    data['id'] = doc.id;
                    
                    final libro = Libro.fromMap(data);

                    return GestureDetector(
                      onLongPress: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Eliminar del historial'),
                            content: const Text('¿Deseas eliminar este libro del historial?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancelar'),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _eliminarDelHistorial(context, doc.id);
                                },
                                child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                      },
                      child: TarjetaLibro(
                        libro: libro,
                        alPresionar: () {
                          Navigator.pushNamed(
                            context,
                            '/detalles_libro',
                            arguments: libro,
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
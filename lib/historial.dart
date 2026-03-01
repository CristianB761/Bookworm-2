import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'diseno.dart';
import 'componentes.dart';
import 'API/modelos.dart';

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
        automaticallyImplyLeading: false,
        actions: [
          if (usuario != null)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: 'Borrar todo',
              onPressed: () => _borrarTodoElHistorial(context),
            ),
          const BotonesBarraApp(rutaActual: '/historial')
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

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    data['id'] = doc.id;
                    
                    final libro = Libro.fromMap(data);

                    return Dismissible(
                      key: Key(doc.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.centerRight,
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (direction) => _eliminarDelHistorial(context, doc.id),
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
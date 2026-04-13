import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_messages_screen.dart';

class ListaChats extends StatelessWidget {
  const ListaChats({super.key});

  @override
  Widget build(BuildContext context) {
    String uidActual = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mensajes'),
        backgroundColor: const Color(0xFF20B2AA),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chats')
            .where('participantes', arrayContains: uidActual)
            .orderBy('ultimaActividad', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Error al cargar chats'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No tienes conversaciones', style: TextStyle(color: Colors.grey)),
                  SizedBox(height: 8),
                  Text('Visita un perfil y envía un mensaje', style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final chatDoc = snapshot.data!.docs[index];
              final data = chatDoc.data() as Map<String, dynamic>;
              final participantes = List<String>.from(data['participantes']);
              final otroUsuarioId = participantes.firstWhere((id) => id != uidActual);
              final ultimoMensaje = data['ultimoMensaje'] ?? '';
              final ultimaActividad = (data['ultimaActividad'] as Timestamp).toDate();

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('usuarios').doc(otroUsuarioId).get(),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData) {
                    return const ListTile(
                      leading: CircleAvatar(child: Icon(Icons.person)),
                      title: Text('Cargando...'),
                    );
                  }

                  final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                  final nombre = userData['nombre'] ?? 'Usuario';
                  final fotoUrl = userData['urlImagenPerfil'];

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF20B2AA).withOpacity(0.1),
                      backgroundImage: fotoUrl != null ? NetworkImage(fotoUrl) : null,
                      child: fotoUrl == null ? const Icon(Icons.person, color: Color(0xFF20B2AA)) : null,
                    ),
                    title: Text(nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      ultimoMensaje,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                    trailing: Text(
                      _formatTime(ultimaActividad),
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatMessagesScreen(
                            otroUsuarioId: otroUsuarioId,
                            otroUsuarioNombre: nombre,
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  String _formatTime(DateTime time) {
    DateTime now = DateTime.now();
    if (time.day == now.day && time.month == now.month && time.year == now.year) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else if (time.year == now.year && time.month == now.month && now.day - time.day == 1) {
      return 'Ayer';
    } else if (time.year == now.year) {
      return '${time.day}/${time.month}';
    } else {
      return '${time.day}/${time.month}/${time.year}';
    }
  }
}
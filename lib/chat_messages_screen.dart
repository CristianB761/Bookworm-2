import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatMessagesScreen extends StatefulWidget {
  final String otroUsuarioId;
  final String otroUsuarioNombre;

  const ChatMessagesScreen({
    super.key,
    required this.otroUsuarioId,
    required this.otroUsuarioNombre,
  });

  @override
  State<ChatMessagesScreen> createState() => _ChatMessagesScreenState();
}

class _ChatMessagesScreenState extends State<ChatMessagesScreen> {
  final TextEditingController _mensajeController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ScrollController _scrollController = ScrollController();

  String get _chatId {
    String uidActual = _auth.currentUser!.uid;
    List<String> ids = [uidActual, widget.otroUsuarioId];
    ids.sort();
    return 'chat_${ids.join('_')}';
  }

  @override
  void initState() {
    super.initState();
    _marcarMensajesComoLeidos();
  }

  @override
  void dispose() {
    _mensajeController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _marcarMensajesComoLeidos() async {
    String uidActual = _auth.currentUser!.uid;
    
    QuerySnapshot mensajesNoLeidos = await _firestore
        .collection('chats')
        .doc(_chatId)
        .collection('mensajes')
        .where('leido', isEqualTo: false)
        .where('emisorId', isNotEqualTo: uidActual)
        .get();

    for (var doc in mensajesNoLeidos.docs) {
      await doc.reference.update({'leido': true});
    }
  }

  Future<void> _enviarMensaje() async {
    if (_mensajeController.text.trim().isEmpty) return;

    String uidActual = _auth.currentUser!.uid;
    String mensaje = _mensajeController.text.trim();
    _mensajeController.clear();

    await _firestore.collection('chats').doc(_chatId).set({
      'participantes': [uidActual, widget.otroUsuarioId],
      'ultimoMensaje': mensaje,
      'ultimaActividad': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _firestore
        .collection('chats')
        .doc(_chatId)
        .collection('mensajes')
        .add({
      'emisorId': uidActual,
      'receptorId': widget.otroUsuarioId,
      'mensaje': mensaje,
      'timestamp': FieldValue.serverTimestamp(),
      'leido': false,
    });

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.otroUsuarioNombre),
        backgroundColor: const Color(0xFF20B2AA),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('chats')
                  .doc(_chatId)
                  .collection('mensajes')
                  .orderBy('timestamp', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Error al cargar mensajes'));
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
                        Text('No hay mensajes aún', style: TextStyle(color: Colors.grey)),
                        SizedBox(height: 8),
                        Text('Envía el primer mensaje', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  );
                }

                String uidActual = _auth.currentUser!.uid;
                final mensajes = snapshot.data!.docs;

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: mensajes.length,
                  itemBuilder: (context, index) {
                    final data = mensajes[index].data() as Map<String, dynamic>;
                    bool esMio = data['emisorId'] == uidActual;
                    String mensaje = data['mensaje'] ?? '';
                    DateTime timestamp = (data['timestamp'] as Timestamp).toDate();
                    bool leido = data['leido'] ?? false;

                    return _buildMessageBubble(
                      mensaje: mensaje,
                      esMio: esMio,
                      timestamp: timestamp,
                      leido: leido,
                    );
                  },
                );
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble({
    required String mensaje,
    required bool esMio,
    required DateTime timestamp,
    required bool leido,
  }) {
    return Align(
      alignment: esMio ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment: esMio ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: esMio ? const Color(0xFF20B2AA) : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                mensaje,
                style: TextStyle(
                  color: esMio ? Colors.white : Colors.black87,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(timestamp),
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
                if (esMio) ...[
                  const SizedBox(width: 4),
                  Icon(
                    leido ? Icons.done_all : Icons.done,
                    size: 12,
                    color: leido ? const Color(0xFF20B2AA) : Colors.grey,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _mensajeController,
              decoration: InputDecoration(
                hintText: 'Escribe un mensaje...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onSubmitted: (_) => _enviarMensaje(),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _enviarMensaje,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF20B2AA),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    DateTime now = DateTime.now();
    if (time.day == now.day && time.month == now.month && time.year == now.year) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else {
      return '${time.day}/${time.month} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
  }
}
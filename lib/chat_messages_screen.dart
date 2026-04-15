import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../diseno.dart';

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
  
  bool _enviando = false;
  String? _fotoUrlOtroUsuario;

  String get _chatId {
    String uidActual = _auth.currentUser!.uid;
    List<String> ids = [uidActual, widget.otroUsuarioId];
    ids.sort();
    return 'chat_${ids.join('_')}';
  }

  @override
  void initState() {
    super.initState();
    _cargarFotoUsuario();
    _marcarMensajesComoLeidos();
  }

  @override
  void dispose() {
    _mensajeController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _cargarFotoUsuario() async {
    try {
      final userDoc = await _firestore
          .collection('usuarios')
          .doc(widget.otroUsuarioId)
          .get();
      
      if (userDoc.exists) {
        setState(() {
          _fotoUrlOtroUsuario = userDoc.data()?['urlImagenPerfil'];
        });
      }
    } catch (e) {
      print('Error cargando foto: $e');
    }
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
    if (_mensajeController.text.trim().isEmpty || _enviando) return;

    String uidActual = _auth.currentUser!.uid;
    String mensaje = _mensajeController.text.trim();
    _mensajeController.clear();
    
    setState(() => _enviando = true);

    try {
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
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al enviar mensaje: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _enviando = false);
    }
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

  Future<void> _verPerfil() async {
    Navigator.pushNamed(
      context,
      '/perfil',
      arguments: {'userId': widget.otroUsuarioId},
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: _verPerfil,
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColores.primario.withOpacity(0.1),
                backgroundImage: _fotoUrlOtroUsuario != null && _fotoUrlOtroUsuario!.isNotEmpty
                    ? NetworkImage(_fotoUrlOtroUsuario!)
                    : null,
                child: _fotoUrlOtroUsuario == null || _fotoUrlOtroUsuario!.isEmpty
                    ? const Icon(Icons.person, size: 18, color: AppColores.primario)
                    : null,
              ),
              const SizedBox(width: 12),
              Text(
                widget.otroUsuarioNombre,
                style: const TextStyle(fontSize: 18),
              ),
            ],
          ),
        ),
        backgroundColor: AppColores.primario,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: _verPerfil,
            tooltip: 'Ver perfil',
          ),
        ],
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
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('Error al cargar mensajes: ${snapshot.error}'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {});
                          },
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'No hay mensajes aún',
                          style: EstilosApp.tituloPequeno(context),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Envía el primer mensaje a ${widget.otroUsuarioNombre}',
                          style: EstilosApp.cuerpoPequeno(context),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                String uidActual = _auth.currentUser!.uid;
                final mensajes = snapshot.data!.docs;

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients && mounted) {
                    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
                  }
                });

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
          _buildMessageInput(isDark),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: esMio ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!esMio)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: AppColores.primario.withOpacity(0.1),
                backgroundImage: _fotoUrlOtroUsuario != null && _fotoUrlOtroUsuario!.isNotEmpty
                    ? NetworkImage(_fotoUrlOtroUsuario!)
                    : null,
                child: _fotoUrlOtroUsuario == null || _fotoUrlOtroUsuario!.isEmpty
                    ? const Icon(Icons.person, size: 14, color: AppColores.primario)
                    : null,
              ),
            ),
          Flexible(
            child: Column(
              crossAxisAlignment: esMio ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: esMio 
                        ? AppColores.primario 
                        : (isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    mensaje,
                    style: TextStyle(
                      color: esMio ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                      fontSize: 15,
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
                        color: leido ? AppColores.primario : Colors.grey,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(color: isDark ? const Color(0xFF444444) : Colors.grey.shade300),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(30),
              ),
              child: TextField(
                controller: _mensajeController,
                decoration: const InputDecoration(
                  hintText: 'Escribe un mensaje...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
                onSubmitted: (_) => _enviarMensaje(),
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _enviarMensaje,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColores.primario,
                shape: BoxShape.circle,
              ),
              child: _enviando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send, color: Colors.white, size: 20),
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
    } else if (time.year == now.year) {
      return '${time.day}/${time.month} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else {
      return '${time.day}/${time.month}/${time.year}';
    }
  }
}
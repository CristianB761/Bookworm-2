import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../diseno.dart';
import '../componentes.dart';
import '../servicio/servicio_firestore.dart';
import '../modelos/datos_usuario.dart';
import 'chat_messages_screen.dart';

class MensajesDirectos extends StatefulWidget {
  const MensajesDirectos({super.key});

  @override
  State<MensajesDirectos> createState() => _MensajesDirectosState();
}

class _MensajesDirectosState extends State<MensajesDirectos> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ServicioFirestore _servicioFirestore = ServicioFirestore();
  
  List<Map<String, dynamic>> _chatsRecientes = [];
  bool _cargando = true;
  bool _mostrarListaUsuarios = false;
  String _busqueda = '';
  String? _uidActual;

  @override
  void initState() {
    super.initState();
    _uidActual = _auth.currentUser?.uid;
    if (_uidActual != null) {
      _escucharChats();
    }
  }

  void _escucharChats() {
    if (_uidActual == null) return;

    _firestore
        .collection('chats')
        .where('participantes', arrayContains: _uidActual)
        .orderBy('ultimaActividad', descending: true)
        .snapshots()
        .listen((snapshot) async {
      List<Map<String, dynamic>> chats = [];
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final participantes = List<String>.from(data['participantes']);
        final otroUsuarioId = participantes.firstWhere((id) => id != _uidActual);
        
        final otroUsuario = await _servicioFirestore.obtenerDatosUsuario(otroUsuarioId);
        
        if (otroUsuario != null) {
          final noLeidos = await _contarNoLeidos(doc.id, _uidActual!);
          
          chats.add({
            'chatId': doc.id,
            'otroUsuario': otroUsuario,
            'ultimoMensaje': data['ultimoMensaje'] ?? '',
            'ultimaActividad': (data['ultimaActividad'] as Timestamp).toDate(),
            'noLeidos': noLeidos,
          });
        }
      }
      
      if (mounted) {
        setState(() {
          _chatsRecientes = chats;
          _cargando = false;
        });
      }
    }, onError: (error) {
      print('Error escuchando chats: $error');
      if (mounted) {
        setState(() => _cargando = false);
      }
    });
  }

  Future<int> _contarNoLeidos(String chatId, String uidActual) async {
    try {
      final mensajesNoLeidos = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('mensajes')
          .where('leido', isEqualTo: false)
          .where('emisorId', isNotEqualTo: uidActual)
          .get();
      
      return mensajesNoLeidos.docs.length;
    } catch (e) {
      return 0;
    }
  }

  void _iniciarConversacion(DatosUsuario usuario) async {
    if (_uidActual == null) return;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatMessagesScreen(
          otroUsuarioId: usuario.uid,
          otroUsuarioNombre: usuario.nombre,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Mensajes Directos'),
        backgroundColor: AppColores.primario,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(
              _mostrarListaUsuarios ? Icons.chat : Icons.person_add,
            ),
            onPressed: () {
              setState(() {
                _mostrarListaUsuarios = !_mostrarListaUsuarios;
                _busqueda = '';
              });
            },
            tooltip: _mostrarListaUsuarios ? 'Ver conversaciones' : 'Nuevo mensaje',
          ),
          const BotonesBarraApp(rutaActual: '/mensajes_directos'),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _mostrarListaUsuarios
              ? _construirListaUsuarios()
              : _construirListaChats(),
    );
  }
  
  Widget _construirListaUsuarios() {
    return FutureBuilder<List<DatosUsuario>>(
      future: _servicioFirestore.obtenerSiguiendo(_uidActual ?? ''),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final usuariosQueSigo = snapshot.data ?? [];
        
        if (usuariosQueSigo.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  'No sigues a nadie aún',
                  style: EstilosApp.tituloPequeno(context),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sigue a otros usuarios para enviarles mensajes',
                  style: EstilosApp.cuerpoPequeno(context),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/search');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColores.primario,
                  ),
                  child: const Text('Buscar usuarios'),
                ),
              ],
            ),
          );
        }
        
        final usuariosFiltrados = _busqueda.isEmpty
            ? usuariosQueSigo
            : usuariosQueSigo.where((u) =>
                u.nombre.toLowerCase().contains(_busqueda.toLowerCase())
            ).toList();
        
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Buscar usuarios...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF2C2C2C)
                      : const Color(0xFFF5F5F5),
                ),
                onChanged: (value) {
                  setState(() {
                    _busqueda = value;
                  });
                },
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: usuariosFiltrados.length,
                itemBuilder: (context, index) {
                  final usuario = usuariosFiltrados[index];
                  return _construirItemUsuario(usuario);
                },
              ),
            ),
          ],
        );
      },
    );
  }
  
  Widget _construirItemUsuario(DatosUsuario usuario) {
    return ListTile(
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: AppColores.primario.withOpacity(0.1),
        backgroundImage: usuario.urlImagenPerfil != null && usuario.urlImagenPerfil!.isNotEmpty
            ? NetworkImage(usuario.urlImagenPerfil!)
            : null,
        child: usuario.urlImagenPerfil == null || usuario.urlImagenPerfil!.isEmpty
            ? const Icon(Icons.person, size: 24, color: AppColores.primario)
            : null,
      ),
      title: Text(
        usuario.nombre,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        usuario.biografia?.isNotEmpty == true
            ? usuario.biografia!
            : 'Sin biografía',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: ElevatedButton(
        onPressed: () => _iniciarConversacion(usuario),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColores.primario,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: const Text('Mensaje'),
      ),
    );
  }
  
  Widget _construirListaChats() {
    if (_chatsRecientes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No tienes conversaciones',
              style: EstilosApp.tituloPequeno(context),
            ),
            const SizedBox(height: 8),
            Text(
              'Cuando alguien te envíe un mensaje, aparecerá aquí',
              style: EstilosApp.cuerpoPequeno(context),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _mostrarListaUsuarios = true;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColores.primario,
              ),
              child: const Text('Nuevo mensaje'),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      itemCount: _chatsRecientes.length,
      itemBuilder: (context, index) {
        final chat = _chatsRecientes[index];
        final usuario = chat['otroUsuario'] as DatosUsuario;
        final ultimoMensaje = chat['ultimoMensaje'] as String;
        final ultimaActividad = chat['ultimaActividad'] as DateTime;
        final noLeidos = chat['noLeidos'] as int;
        
        return _construirItemChat(
          usuario: usuario,
          ultimoMensaje: ultimoMensaje,
          ultimaActividad: ultimaActividad,
          noLeidos: noLeidos,
        );
      },
    );
  }
  
  Widget _construirItemChat({
    required DatosUsuario usuario,
    required String ultimoMensaje,
    required DateTime ultimaActividad,
    required int noLeidos,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: noLeidos > 0 
            ? (isDark ? const Color(0xFF1E3A5F).withOpacity(0.3) : AppColores.primario.withOpacity(0.05))
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppColores.primario.withOpacity(0.1),
              backgroundImage: usuario.urlImagenPerfil != null && usuario.urlImagenPerfil!.isNotEmpty
                  ? NetworkImage(usuario.urlImagenPerfil!)
                  : null,
              child: usuario.urlImagenPerfil == null || usuario.urlImagenPerfil!.isEmpty
                  ? const Icon(Icons.person, size: 28, color: AppColores.primario)
                  : null,
            ),
            if (noLeidos > 0)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      noLeidos > 99 ? '99+' : '$noLeidos',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          usuario.nombre,
          style: TextStyle(
            fontWeight: noLeidos > 0 ? FontWeight.bold : FontWeight.normal,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        subtitle: Text(
          ultimoMensaje.isNotEmpty ? ultimoMensaje : 'Sin mensajes',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: noLeidos > 0 ? AppColores.primario : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
            fontWeight: noLeidos > 0 ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _formatearFecha(ultimaActividad),
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 4),
            if (noLeidos > 0)
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColores.primario,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatMessagesScreen(
                otroUsuarioId: usuario.uid,
                otroUsuarioNombre: usuario.nombre,
              ),
            ),
          );
        },
      ),
    );
  }
  
  String _formatearFecha(DateTime fecha) {
    final ahora = DateTime.now();
    final diferencia = ahora.difference(fecha);
    
    if (diferencia.inDays > 7) {
      return '${fecha.day}/${fecha.month}';
    } else if (diferencia.inDays > 0) {
      return 'Hace ${diferencia.inDays}d';
    } else if (diferencia.inHours > 0) {
      return 'Hace ${diferencia.inHours}h';
    } else if (diferencia.inMinutes > 0) {
      return 'Hace ${diferencia.inMinutes}m';
    } else {
      return 'Ahora';
    }
  }
}
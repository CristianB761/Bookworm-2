import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'diseño.dart';
import 'componentes.dart';
import '../servicio/servicio_firestore.dart'; 

class ChatClub extends StatefulWidget {
  final String clubId;
  final String clubNombre;
  final String? rolUsuario; 

  const ChatClub({
    super.key,
    required this.clubId,
    required this.clubNombre,
    this.rolUsuario = 'miembro',
  });

  @override
  State<ChatClub> createState() => _ChatClubState();
}

class _ChatClubState extends State<ChatClub> {
  final TextEditingController _controladorMensaje = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ServicioFirestore _servicioFirestore = ServicioFirestore(); 
  final ScrollController _scrollController = ScrollController();
  
  String? _rolUsuario;
  Map<String, dynamic>? _infoClub;

  @override
  void initState() {
    super.initState();
    _cargarInfoClub();
  }

  @override
  void dispose() {
    _controladorMensaje.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _cargarInfoClub() async {
    try {
      final clubDoc = await _firestore.collection('clubs').doc(widget.clubId).get();
      if (clubDoc.exists) {
        setState(() {
          _infoClub = clubDoc.data();
        });
      }

      final usuario = _auth.currentUser;
      if (usuario != null) {
        final miClubDoc = await _firestore
            .collection('usuarios')
            .doc(usuario.uid)
            .collection('mis_clubs')
            .doc(widget.clubId)
            .get();
        
        if (miClubDoc.exists) {
          setState(() {
            _rolUsuario = miClubDoc.data()?['rol'] ?? 'miembro';
          });
        }
      }
    } catch (e) {
      print('Error cargando info del club: $e');
    }
  }

  void _mostrarDialogoEditarClub() {
    final controladorNombre = TextEditingController(text: _infoClub?['nombre'] ?? '');
    final controladorDescripcion = TextEditingController(text: _infoClub?['descripcion'] ?? '');
    String? generoSeleccionado = _infoClub?['genero'] ?? 'Todos los géneros';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar información del club', style: EstilosApp.tituloMedio),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: controladorNombre,
                decoration: const InputDecoration(
                  labelText: 'Nombre del club',
                  border: OutlineInputBorder(),
                ),
                maxLength: 50,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: controladorDescripcion,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                maxLength: 200,
              ),
              const SizedBox(height: 16),
              const Text('Género favorito', style: EstilosApp.cuerpoGrande),
              const SizedBox(height: 8),
              FiltroDesplegable(
                valor: generoSeleccionado,
                items: DatosApp.generos,
                hint: 'Selecciona un género',
                alCambiar: (valor) {
                  if (valor != null) {
                    generoSeleccionado = valor;
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controladorNombre.text.isEmpty || generoSeleccionado == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Nombre y género son obligatorios'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              try {
                await _servicioFirestore.actualizarInfoClub(
                  clubId: widget.clubId,
                  nombre: controladorNombre.text,
                  descripcion: controladorDescripcion.text,
                  genero: generoSeleccionado!,
                );

                setState(() {
                  _infoClub = {
                    ...?_infoClub,
                    'nombre': controladorNombre.text,
                    'descripcion': controladorDescripcion.text,
                    'genero': generoSeleccionado,
                  };
                });

                Navigator.pop(context);
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Información del club actualizada'),
                    backgroundColor: AppColores.secundario,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error actualizando: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: EstilosApp.botonPrimario,
            child: const Text('Guardar cambios'),
          ),
        ],
      ),
    );
  }

  Future<void> _enviarMensaje() async {
    if (_controladorMensaje.text.trim().isEmpty) return;

    final usuario = _auth.currentUser;
    if (usuario == null) return;

    try {
      await _firestore.collection('clubs').doc(widget.clubId).collection('mensajes').add({
        'texto': _controladorMensaje.text.trim(),
        'usuarioId': usuario.uid,
        'usuarioNombre': usuario.displayName ?? 'Usuario',
        'timestamp': FieldValue.serverTimestamp(),
        'leidoPor': [usuario.uid],
      });

      await _firestore.collection('clubs').doc(widget.clubId).update({
        'ultimaActividad': FieldValue.serverTimestamp(),
      });

      _controladorMensaje.clear();
      _scrollAlFinal();
    } catch (e) {
      print('Error enviando mensaje: $e');
    }
  }

  void _scrollAlFinal() {
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

  Widget _construirMensaje(DocumentSnapshot mensaje) {
    final datos = mensaje.data() as Map<String, dynamic>;
    final esMio = datos['usuarioId'] == _auth.currentUser?.uid;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        mainAxisAlignment: esMio ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!esMio)
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColores.primario.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  datos['usuarioNombre'].toString().substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColores.primario,
                  ),
                ),
              ),
            ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: esMio ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!esMio)
                  Text(
                    datos['usuarioNombre'],
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.black54,
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: esMio ? AppColores.primario : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    datos['texto'],
                    style: TextStyle(
                      fontSize: 14,
                      color: esMio ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                if (datos['timestamp'] != null)
                  Text(
                    _formatearFecha(datos['timestamp'].toDate()),
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.grey,
                    ),
                  ),
              ],
            ),
          ),
          if (esMio) const SizedBox(width: 8),
        ],
      ),
    );
  }

  String _formatearFecha(DateTime fecha) {
    final ahora = DateTime.now();
    final diferencia = ahora.difference(fecha);

    if (diferencia.inDays > 0) {
      return '${diferencia.inDays}d';
    } else if (diferencia.inHours > 0) {
      return '${diferencia.inHours}h';
    } else if (diferencia.inMinutes > 0) {
      return '${diferencia.inMinutes}m';
    } else {
      return 'Ahora';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _infoClub?['nombre'] ?? widget.clubNombre,
              style: const TextStyle(fontSize: 18),
            ),
            if (_infoClub?['genero'] != null)
              Text(
                _infoClub?['genero'] ?? '',
                style: const TextStyle(fontSize: 12),
              ),
          ],
        ),
        backgroundColor: AppColores.primario,
        actions: [
          if (_rolUsuario == 'creador')
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _mostrarDialogoEditarClub,
              tooltip: 'Editar información del club',
            ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              _mostrarInfoClub();
            },
            tooltip: 'Información del club',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('clubs')
                  .doc(widget.clubId)
                  .collection('mensajes')
                  .orderBy('timestamp', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text('Error cargando mensajes'),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const IndicadorCarga(mensaje: 'Cargando mensajes...');
                }

                final mensajes = snapshot.data?.docs ?? [];

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(8),
                  itemCount: mensajes.length,
                  itemBuilder: (context, index) {
                    return _construirMensaje(mensajes[index]);
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColores.fondo,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _controladorMensaje,
                      decoration: const InputDecoration(
                        hintText: 'Escribe un mensaje...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onSubmitted: (_) => _enviarMensaje(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _enviarMensaje,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColores.primario,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.send,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarInfoClub() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Información del club', style: EstilosApp.tituloMedio),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_infoClub?['nombre'] != null) ...[
                const Text('Nombre:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(_infoClub!['nombre']),
                const SizedBox(height: 12),
              ],
              if (_infoClub?['descripcion'] != null && _infoClub!['descripcion'].toString().isNotEmpty) ...[
                const Text('Descripción:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(_infoClub!['descripcion']),
                const SizedBox(height: 12),
              ],
              if (_infoClub?['genero'] != null) ...[
                const Text('Género favorito:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(_infoClub!['genero']),
                const SizedBox(height: 12),
              ],
              if (_infoClub?['creadorNombre'] != null) ...[
                const Text('Creado por:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(_infoClub!['creadorNombre']),
                const SizedBox(height: 12),
              ],
              if (_infoClub?['miembrosCount'] != null) ...[
                const Text('Miembros:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('${_infoClub!['miembrosCount']} miembros'),
              ],
            ],
          ),
        ),
        actions: [
          if (_rolUsuario == 'creador')
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _mostrarDialogoEditarClub();
              },
              child: const Text('Editar'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}

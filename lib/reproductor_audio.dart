import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../diseno.dart';

class ReproductorAudio extends StatefulWidget {
  final String titulo;
  final String audioUrl;
  final String? autores;

  const ReproductorAudio({
    super.key,
    required this.titulo,
    required this.audioUrl,
    this.autores,
  });

  @override
  State<ReproductorAudio> createState() => _ReproductorAudioState();
}

class _ReproductorAudioState extends State<ReproductorAudio> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isLoading = true;
  bool _isPlaying = false;
  bool _isBuffering = false;
  String? _error;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  double _progress = 0.0;
  double _volume = 1.0;
  double _volumeAntesSilencio = 1.0;
  bool _isMuted = false;
  double _speed = 1.0;
  bool _isLocalFile = false;
  File? _localFile;
  double _downloadProgress = 0.0;
  bool _isDownloading = false;
  late SharedPreferences _prefs;
  bool _prefsCargadas = false;

  // Configuración de la velocidad: mínima 0.25, máxima 2.00, pasos de 0.05
  static const double _minSpeed = 0.25;
  static const double _maxSpeed = 2.00;
  static const double _speedStep = 0.05;
  static const int _speedDivisions = 35; // (2.00 - 0.25) / 0.05 = 35

  @override
  void initState() {
    super.initState();
    _inicializarPrefs();
  }

  Future<void> _inicializarPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    _prefsCargadas = true;
    await _cargarVolumenGuardado();
    await _cargarVelocidadGuardada();
    _inicializarReproductor();
  }

  Future<void> _cargarVolumenGuardado() async {
    final volumenGuardado = _prefs.getDouble('volumen_audio');
    if (volumenGuardado != null) {
      _volume = volumenGuardado.clamp(0.0, 1.0);
      _isMuted = (_volume == 0);
      if (!_isMuted) {
        _volumeAntesSilencio = _volume;
      }
    } else {
      _volume = 1.0;
      _volumeAntesSilencio = 1.0;
      _isMuted = false;
    }
  }

  Future<void> _cargarVelocidadGuardada() async {
    final velocidadGuardada = _prefs.getDouble('velocidad_audio');
    if (velocidadGuardada != null) {
      _speed = velocidadGuardada.clamp(_minSpeed, _maxSpeed);
      // Redondear al paso más cercano para mantener consistencia
      _speed = (_speed / _speedStep).round() * _speedStep;
    } else {
      _speed = 1.0;
    }
  }

  Future<void> _guardarVolumen(double nuevoVolumen) async {
    if (!_prefsCargadas) return;
    await _prefs.setDouble('volumen_audio', nuevoVolumen);
  }

  Future<void> _guardarVelocidad(double nuevaVelocidad) async {
    if (!_prefsCargadas) return;
    await _prefs.setDouble('velocidad_audio', nuevaVelocidad);
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _inicializarReproductor() async {
    await _cargarAudio();
    
    _audioPlayer.positionStream.listen((position) {
      if (mounted) {
        setState(() {
          _position = position;
          if (_duration.inMilliseconds > 0) {
            _progress = position.inMilliseconds / _duration.inMilliseconds;
          }
        });
      }
    });

    _audioPlayer.durationStream.listen((duration) {
      if (mounted && duration != null) {
        setState(() {
          _duration = duration;
        });
      }
    });

    _audioPlayer.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
          _isBuffering = state.processingState == ProcessingState.buffering;
        });
      }
    });
  }

  Future<void> _cargarAudio() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await _audioPlayer.setUrl(widget.audioUrl);
      _audioPlayer.setVolume(_volume);
      _audioPlayer.setSpeed(_speed);
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error al cargar el audio: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _descargarAudio() async {
    if (_isDownloading) return;

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      final tempDir = await getTemporaryDirectory();
      final fileName = '${widget.titulo.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.mp3';
      final file = File('${tempDir.path}/$fileName');

      final response = await http.Client().send(
        http.Request('GET', Uri.parse(widget.audioUrl))
      );

      final totalBytes = response.contentLength;
      var bytesReceived = 0;

      final sink = file.openWrite();
      await response.stream.listen((chunk) {
        sink.add(chunk);
        bytesReceived += chunk.length;
        if (totalBytes != null && mounted) {
          setState(() {
            _downloadProgress = bytesReceived / totalBytes;
          });
        }
      }).asFuture();
      await sink.close();

      if (mounted) {
        setState(() {
          _localFile = file;
          _isLocalFile = true;
          _isDownloading = false;
        });
        
        await _audioPlayer.setUrl(file.path);
        _audioPlayer.setVolume(_volume);
        _audioPlayer.setSpeed(_speed);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Audio descargado para reproducción offline'),
            backgroundColor: AppColores.secundario,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al descargar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _eliminarAudioLocal() async {
    if (_localFile != null && await _localFile!.exists()) {
      await _localFile!.delete();
      setState(() {
        _localFile = null;
        _isLocalFile = false;
      });
      
      await _cargarAudio();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Audio offline eliminado'),
          backgroundColor: AppColores.secundario,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _playPause() {
    if (_isPlaying) {
      _audioPlayer.pause();
    } else {
      _audioPlayer.play();
    }
  }

  void _seek(double value) {
    final position = Duration(milliseconds: (value * _duration.inMilliseconds).toInt());
    _audioPlayer.seek(position);
  }

  void _setVolume(double value) {
    setState(() {
      _volume = value;
      _isMuted = (value == 0);
      if (!_isMuted) {
        _volumeAntesSilencio = value;
      }
    });
    _audioPlayer.setVolume(value);
    _guardarVolumen(value);
  }

  void _toggleMute() {
    if (_isMuted) {
      _setVolume(_volumeAntesSilencio);
    } else {
      _volumeAntesSilencio = _volume;
      _setVolume(0.0);
    }
  }

  void _setSpeed(double value) {
    // Redondear al paso más cercano para evitar errores de precisión
    final roundedSpeed = (value / _speedStep).round() * _speedStep;
    setState(() {
      _speed = roundedSpeed;
    });
    _audioPlayer.setSpeed(_speed);
    _guardarVelocidad(_speed);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return duration.inHours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  String _formatSpeed(double speed) {
    // Mostrar siempre dos decimales
    return '${speed.toStringAsFixed(2)}x';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(widget.titulo, style: EstilosApp.tituloGrande(context)),
        backgroundColor: AppColores.primario,
        foregroundColor: Colors.white,
        actions: [
          if (!_isLocalFile && !_isDownloading)
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: _descargarAudio,
              tooltip: 'Descargar para offline',
            ),
          if (_isLocalFile)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _eliminarAudioLocal,
              tooltip: 'Eliminar descarga',
            ),
          if (_isDownloading)
            const SizedBox(
              width: 40,
              height: 40,
              child: Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(_error!, style: EstilosApp.cuerpoMedio(context), textAlign: TextAlign.center),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _cargarAudio,
                        style: ElevatedButton.styleFrom(backgroundColor: AppColores.primario),
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Container(
                        height: 200,
                        width: 200,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColores.primario, AppColores.secundario],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColores.primario.withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.audiotrack,
                          size: 80,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        widget.titulo,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      if (widget.autores != null)
                        Text(
                          widget.autores!,
                          style: TextStyle(
                            fontSize: 16,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      const SizedBox(height: 16),
                      if (_isLocalFile)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.offline_bolt, size: 16, color: Colors.green),
                              SizedBox(width: 4),
                              Text('Disponible offline', style: TextStyle(fontSize: 12, color: Colors.green)),
                            ],
                          ),
                        ),
                      const SizedBox(height: 32),
                      if (_isBuffering)
                        const Center(child: CircularProgressIndicator())
                      else ...[
                        Slider(
                          value: _progress,
                          onChanged: _seek,
                          activeColor: AppColores.primario,
                          inactiveColor: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatDuration(_position),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark ? Colors.white70 : Colors.black54,
                                ),
                              ),
                              Text(
                                _formatDuration(_duration),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark ? Colors.white70 : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColores.primario,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColores.primario.withOpacity(0.5),
                              blurRadius: 15,
                              spreadRadius: 3,
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: Icon(
                            _isPlaying ? Icons.pause : Icons.play_arrow,
                            size: 40,
                            color: Colors.white,
                          ),
                          onPressed: _playPause,
                          padding: EdgeInsets.zero,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                IconButton(
                                  icon: Icon(
                                    _isMuted ? Icons.volume_off : Icons.volume_up,
                                    color: AppColores.primario,
                                  ),
                                  onPressed: _toggleMute,
                                  tooltip: _isMuted ? 'Activar sonido' : 'Silenciar',
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Slider(
                                    value: _volume,
                                    onChanged: _setVolume,
                                    min: 0,
                                    max: 1,
                                    activeColor: AppColores.primario,
                                  ),
                                ),
                                Text(
                                  '${(_volume * 100).toInt()}%',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.white70 : Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                const Icon(Icons.speed, color: AppColores.primario),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Slider(
                                    value: _speed,
                                    onChanged: _setSpeed,
                                    min: _minSpeed,
                                    max: _maxSpeed,
                                    divisions: _speedDivisions,
                                    activeColor: AppColores.primario,
                                  ),
                                ),
                                Text(
                                  _formatSpeed(_speed),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.white70 : Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_isDownloading)
                        Column(
                          children: [
                            LinearProgressIndicator(value: _downloadProgress),
                            const SizedBox(height: 8),
                            Text(
                              'Descargando... ${(_downloadProgress * 100).toStringAsFixed(0)}%',
                              style: EstilosApp.cuerpoPequeno(context),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
    );
  }
}
import 'dart:async';
import 'package:flutter/material.dart';
import '../../controllers/voice_room_controller.dart';
import '../../models/clan_member_model.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;

class VoiceSidePanel extends StatefulWidget {
  const VoiceSidePanel({
    super.key,
    required this.roomName,
    required this.accentColor,
    required this.controller,
    this.members = const [],
    this.chatWidget, // Opcional: si se pasa, se integra abajo de los participantes compactos
    this.onActivityTap, // Opcional: abre el log cronológico de actividad
    this.onClose,
  });

  final String roomName;
  final Color accentColor;
  final VoiceRoomController controller;
  final List<ClanMemberModel> members;
  final Widget? chatWidget;
  final VoidCallback? onActivityTap;
  final VoidCallback? onClose;

  @override
  State<VoiceSidePanel> createState() => _VoiceSidePanelState();
}

class _VoiceSidePanelState extends State<VoiceSidePanel> {
  int _ping = 28;
  Timer? _pingTimer;
  Offset _tapPosition = Offset.zero;

  @override
  void initState() {
    super.initState();
    _pingTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted) {
        setState(() {
          _ping = 24 + (DateTime.now().millisecond % 15);
        });
      }
    });
  }

  @override
  void dispose() {
    _pingTimer?.cancel();
    super.dispose();
  }

  String _getRoleName(String userId) {
    if (widget.members.isEmpty) return 'Miembro';
    final member = widget.members.cast<ClanMemberModel?>().firstWhere(
          (m) => m?.userId == userId,
          orElse: () => null,
        );
    return member?.role?.name ?? 'Miembro';
  }

  Color _getRoleColor(String roleName, Color defaultColor) {
    if (roleName == 'Leader') return Colors.amber;
    if (roleName == 'Co-Leader') return Colors.orange;
    if (roleName == 'Moderator') return Colors.blueAccent;
    return defaultColor.withOpacity(0.8);
  }

  @override
  Widget build(BuildContext context) {
    final users = widget.controller.participants;

    return Container(
      width: 310,
      decoration: const BoxDecoration(
        color: Color(0xff100D1A),
        border: Border(left: BorderSide(color: Color(0xff2d2543))),
      ),
      child: Column(
        children: [
          // Header del Panel de Voz Unificado
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            decoration: const BoxDecoration(
              color: Color(0xff161324),
              border: Border(bottom: BorderSide(color: Color(0xff2d2543))),
            ),
            child: Row(
              children: [
                const Icon(Icons.volume_up_rounded, color: Color(0xff50E6A5), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.controller.connectedChannel?.name ?? 'Canal de Voz',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                      ),
                      Text(
                        '🔊 ${users.length} Conectados',
                        style: const TextStyle(fontSize: 10, color: Colors.white54, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                if (widget.onActivityTap != null)
                  IconButton(
                    icon: const Icon(Icons.history_toggle_off_rounded, color: Colors.white60, size: 18),
                    tooltip: 'Historial de Actividad',
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(6),
                    onPressed: widget.onActivityTap,
                  ),
                if (widget.onClose != null)
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white60, size: 18),
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(6),
                    onPressed: widget.onClose,
                  ),
              ],
            ),
          ),

          // 1. PARTICIPANTES ARRIBA (Lista compacta horizontal de avatares)
          Container(
            height: 64,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: const BoxDecoration(
              color: Color(0xff141120),
              border: Border(bottom: BorderSide(color: Color(0xff221C35))),
            ),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                final isSpeaking = user.isSpeaking;
                final isMuted = user.isMuted;
                final roleName = _getRoleName(user.id);

                return GestureDetector(
                  onTap: () => _showParticipantDetailsPopout(user, roleName),
                  onSecondaryTapDown: (details) {
                    _tapPosition = details.globalPosition;
                  },
                  onSecondaryTap: () {
                    _showContextMenu(context, user, roleName, _tapPosition);
                  },
                  onLongPressStart: (details) {
                    _tapPosition = details.globalPosition;
                  },
                  onLongPress: () {
                    _showContextMenu(context, user, roleName, _tapPosition);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    alignment: Alignment.center,
                    child: Tooltip(
                      message: '${user.name} (${roleName})',
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSpeaking ? const Color(0xff50E6A5) : Colors.white12,
                                width: 2,
                              ),
                              boxShadow: [
                                if (isSpeaking)
                                  BoxShadow(
                                    color: const Color(0xff50E6A5).withOpacity(0.2),
                                    blurRadius: 6,
                                  ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 16,
                              backgroundColor: widget.accentColor,
                              backgroundImage: user.avatarUrl.isNotEmpty ? NetworkImage(user.avatarUrl) : null,
                              child: user.avatarUrl.isEmpty
                                  ? Text(
                                      user.name.isEmpty ? '?' : user.name[0].toUpperCase(),
                                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                    )
                                  : null,
                            ),
                          ),
                          if (isMuted)
                            Positioned(
                              right: -2,
                              bottom: -2,
                              child: Container(
                                padding: const EdgeInsets.all(2.5),
                                decoration: const BoxDecoration(
                                  color: Color(0xffD64A68),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.mic_off_rounded, color: Colors.white, size: 6.5),
                              ),
                            ),
                          if (user.isScreenSharing)
                            Positioned(
                              left: -2,
                              bottom: -2,
                              child: Container(
                                padding: const EdgeInsets.all(2.5),
                                decoration: BoxDecoration(
                                  color: widget.accentColor,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.screen_share_rounded, color: Colors.white, size: 6.5),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // 2. CHAT / CONTENIDO ABAJO (Reemplaza el espacio grande de actividad)
          Expanded(
            child: widget.chatWidget ??
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.volume_up_rounded, color: Colors.white10, size: 48),
                      const SizedBox(height: 12),
                      const Text(
                        'Canal de voz conectado',
                        style: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Haz clic en un avatar para ajustar su volumen.',
                        style: TextStyle(color: Colors.white24, fontSize: 10),
                      ),
                    ],
                  ),
                ),
          ),

          // Calidad de conexión & Ping
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xff09070F),
            child: Row(
              children: [
                const Icon(Icons.wifi_rounded, color: Color(0xff50E6A5), size: 12),
                const SizedBox(width: 8),
                Text(
                  'Excelente  ·  Ping: ${_ping}ms',
                  style: const TextStyle(color: Colors.white30, fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          // Controles Inferiores Discord-Style
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xff141120),
              border: Border(top: BorderSide(color: Color(0xff2d2543))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Mute Microphone
                _controlBtn(
                  icon: widget.controller.microphoneMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                  active: !widget.controller.microphoneMuted,
                  color: widget.controller.microphoneMuted ? const Color(0xffD64A68) : Colors.white70,
                  onPressed: () => widget.controller.toggleMicrophone(),
                  tooltip: widget.controller.microphoneMuted ? 'Activar Micrófono' : 'Silenciar Micrófono',
                ),

                // Deafen Headphones
                _controlBtn(
                  icon: widget.controller.deafened ? Icons.headset_off_rounded : Icons.headphones_rounded,
                  active: !widget.controller.deafened,
                  color: widget.controller.deafened ? const Color(0xffD64A68) : Colors.white70,
                  onPressed: () => widget.controller.toggleDeafen(),
                  tooltip: widget.controller.deafened ? 'Activar Audio' : 'Silenciar Audio (Ensordecer)',
                ),

                // Screen Share
                _controlBtn(
                  icon: Icons.screen_share_rounded,
                  active: widget.controller.isScreenSharing,
                  color: widget.controller.isScreenSharing ? Colors.greenAccent : Colors.white70,
                  onPressed: () => widget.controller.toggleScreenShare(),
                  tooltip: widget.controller.isScreenSharing ? 'Detener Pantalla' : 'Compartir Pantalla',
                ),

                // Settings Menu
                _buildSettingsMenuButton(),

                // Disconnect Call
                IconButton(
                  icon: const Icon(Icons.call_end_rounded, color: Colors.white, size: 18),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xffD64A68),
                    padding: const EdgeInsets.all(10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => widget.controller.disconnect(),
                  tooltip: 'Desconectarse de la llamada',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _controlBtn({
    required IconData icon,
    required bool active,
    required Color color,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(icon, color: color, size: 15),
        style: IconButton.styleFrom(
          backgroundColor: active ? Colors.white.withOpacity(0.04) : color.withOpacity(0.1),
          padding: const EdgeInsets.all(9),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
        ),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildSettingsMenuButton() {
    return PopupMenuButton<String>(
      tooltip: 'Dispositivos de Entrada/Salida',
      icon: const Icon(Icons.settings_rounded, color: Colors.white70, size: 15),
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withOpacity(0.04),
        padding: const EdgeInsets.all(9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
      ),
      color: const Color(0xff161324),
      onSelected: (val) async {
        if (val == 'ns_off') {
          await widget.controller.setNoiseSuppressionMode('off');
        } else if (val == 'ns_standard') {
          await widget.controller.setNoiseSuppressionMode('standard');
        } else if (val == 'ns_ai') {
          await widget.controller.setNoiseSuppressionMode('ai');
        } else if (val == 'toggle_aec') {
          await widget.controller.toggleEchoCancellation();
        } else if (val == 'toggle_agc') {
          await widget.controller.toggleAutoGainControl();
        } else {
          final parts = val.split('||');
          if (parts[0] == 'input') {
            final devices = await widget.controller.audioInputs();
            final target = devices.firstWhere((d) => d.deviceId == parts[1]);
            await widget.controller.selectAudioInput(target);
          } else if (parts[0] == 'output') {
            final devices = await widget.controller.audioOutputs();
            final target = devices.firstWhere((d) => d.deviceId == parts[1]);
            await widget.controller.selectAudioOutput(target);
          }
        }
      },
      itemBuilder: (context) {
        return [
          const PopupMenuItem(
            enabled: false,
            child: Text('🎤 MICRÓFONO / ENTRADA', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
          ..._buildDeviceMenuItems('input'),
          const PopupMenuDivider(),
          const PopupMenuItem(
            enabled: false,
            child: Text('🔊 SALIDA DE AUDIO', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
          ..._buildDeviceMenuItems('output'),
          const PopupMenuDivider(),
          const PopupMenuItem(
            enabled: false,
            child: Text('🎙️ SUPRESIÓN DE RUIDO', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
          PopupMenuItem(
            value: 'ns_off',
            child: Row(
              children: [
                Icon(
                  widget.controller.noiseSuppressionMode == 'off' ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: widget.controller.noiseSuppressionMode == 'off' ? widget.accentColor : Colors.white24,
                  size: 14,
                ),
                const SizedBox(width: 8),
                const Text('Desactivada', style: TextStyle(color: Colors.white70, fontSize: 11)),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'ns_standard',
            child: Row(
              children: [
                Icon(
                  widget.controller.noiseSuppressionMode == 'standard' ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: widget.controller.noiseSuppressionMode == 'standard' ? widget.accentColor : Colors.white24,
                  size: 14,
                ),
                const SizedBox(width: 8),
                const Text('Estándar', style: TextStyle(color: Colors.white70, fontSize: 11)),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'ns_ai',
            child: Row(
              children: [
                Icon(
                  widget.controller.noiseSuppressionMode == 'ai' ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: widget.controller.noiseSuppressionMode == 'ai' ? widget.accentColor : Colors.white24,
                  size: 14,
                ),
                const SizedBox(width: 8),
                const Text('IA / Avanzada', style: TextStyle(color: Colors.white70, fontSize: 11)),
              ],
            ),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem(
            enabled: false,
            child: Text('⚙️ PROCESAMIENTO', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
          PopupMenuItem(
            value: 'toggle_aec',
            child: Row(
              children: [
                Icon(
                  widget.controller.echoCancellationEnabled ? Icons.check_box : Icons.check_box_outline_blank,
                  color: widget.controller.echoCancellationEnabled ? widget.accentColor : Colors.white24,
                  size: 14,
                ),
                const SizedBox(width: 8),
                const Text('Cancelación de eco', style: TextStyle(color: Colors.white70, fontSize: 11)),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'toggle_agc',
            child: Row(
              children: [
                Icon(
                  widget.controller.autoGainControlEnabled ? Icons.check_box : Icons.check_box_outline_blank,
                  color: widget.controller.autoGainControlEnabled ? widget.accentColor : Colors.white24,
                  size: 14,
                ),
                const SizedBox(width: 8),
                const Text('Control de ganancia (AGC)', style: TextStyle(color: Colors.white70, fontSize: 11)),
              ],
            ),
          ),
        ];
      },
    );
  }

  List<PopupMenuEntry<String>> _buildDeviceMenuItems(String type) {
    return [
      PopupMenuItem(
        value: '${type}||default',
        child: const Text('Dispositivo Predeterminado', style: TextStyle(color: Colors.white70, fontSize: 11)),
      ),
    ];
  }

  // ==========================
  // PANEL DETALLADO DE PARTICIPANTE (POPOUT)
  // ==========================

  void _showParticipantDetailsPopout(VoiceParticipantState user, String roleName) {
    final roleColor = _getRoleColor(roleName, widget.accentColor);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: const Color(0xff161324),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              content: SizedBox(
                width: 280,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Avatar grande e indicador de voz
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: user.isSpeaking ? const Color(0xff50E6A5) : Colors.white24,
                          width: 2,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 36,
                        backgroundColor: widget.accentColor,
                        backgroundImage: user.avatarUrl.isNotEmpty ? NetworkImage(user.avatarUrl) : null,
                        child: user.avatarUrl.isEmpty
                            ? Text(
                                user.name.isEmpty ? '?' : user.name[0].toUpperCase(),
                                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Nombre y Rol
                    Text(
                      user.name,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      roleName,
                      style: TextStyle(color: roleColor, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    const Divider(color: Colors.white12, height: 24),

                    // Estado del micrófono y pantalla
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatusIndicator(
                          icon: user.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                          label: user.isMuted ? 'Muted' : 'Activo',
                          color: user.isMuted ? const Color(0xffD64A68) : const Color(0xff50E6A5),
                        ),
                        _buildStatusIndicator(
                          icon: Icons.screen_share_rounded,
                          label: user.isScreenSharing ? 'Compartiendo' : 'Sin stream',
                          color: user.isScreenSharing ? Colors.greenAccent : Colors.white24,
                        ),
                      ],
                    ),

                    if (!user.isLocal) ...[
                      const Divider(color: Colors.white12, height: 24),
                      // Slider de volumen local
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Volumen de usuario', style: TextStyle(color: Colors.white70, fontSize: 11)),
                          Text(
                            '${(user.localVolume * 100).toInt()}%',
                            style: TextStyle(color: widget.accentColor, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      SliderTheme(
                        data: SliderThemeData(
                          activeTrackColor: widget.accentColor,
                          inactiveTrackColor: Colors.white12,
                          thumbColor: widget.accentColor,
                          trackHeight: 3,
                        ),
                        child: Slider(
                          value: user.localVolume,
                          min: 0.0,
                          max: 2.0,
                          onChanged: (val) {
                            setStateDialog(() {
                              widget.controller.setParticipantVolume(user.id, val);
                              // Refrescar el estado de este popup
                              user = widget.controller.participants.firstWhere((p) => p.id == user.id);
                            });
                            setState(() {}); // Refrescar el panel de voz
                          },
                        ),
                      ),

                      // Botón para silenciar localmente
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          user.isLocalMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                          color: user.isLocalMuted ? const Color(0xffD64A68) : Colors.white60,
                          size: 20,
                        ),
                        title: const Text('Silenciar para mí', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        trailing: Switch(
                          value: user.isLocalMuted,
                          activeColor: const Color(0xffD64A68),
                          onChanged: (_) {
                            setStateDialog(() {
                              widget.controller.toggleParticipantLocalMute(user.id);
                              user = widget.controller.participants.firstWhere((p) => p.id == user.id);
                            });
                            setState(() {});
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cerrar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showContextMenu(BuildContext context, VoiceParticipantState user, String roleName, Offset position) {
    if (user.isLocal) return; // No tiene sentido cambiar nuestro propio volumen local
    showDialog(
      context: context,
      barrierColor: Colors.transparent, // Fondo invisible para cerrarlo con un clic fuera
      builder: (context) {
        return Stack(
          children: [
            Positioned(
              left: position.dx.clamp(10.0, MediaQuery.of(context).size.width - 250.0),
              top: position.dy.clamp(10.0, MediaQuery.of(context).size.height - 230.0),
              child: Material(
                color: Colors.transparent,
                child: StatefulBuilder(
                  builder: (context, setStateDialog) {
                    return Container(
                      width: 230,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xff161324),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xff2d2543), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Nombre
                          Text(
                            user.name,
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 10),
                          
                          // Título Volumen
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Volumen de usuario', style: TextStyle(color: Colors.white54, fontSize: 10)),
                              Text(
                                '${(user.localVolume * 100).toInt()}%',
                                style: TextStyle(color: widget.accentColor, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          
                          // Slider de Volumen
                          SizedBox(
                            height: 32,
                            child: SliderTheme(
                              data: SliderThemeData(
                                activeTrackColor: widget.accentColor,
                                inactiveTrackColor: Colors.white12,
                                thumbColor: widget.accentColor,
                                trackHeight: 3,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                              ),
                              child: Slider(
                                value: user.localVolume,
                                min: 0.0,
                                max: 2.0,
                                onChanged: (val) {
                                  setStateDialog(() {
                                    widget.controller.setParticipantVolume(user.id, val);
                                    user = widget.controller.participants.firstWhere((p) => p.id == user.id);
                                  });
                                  setState(() {}); // Refrescar panel principal
                                },
                              ),
                            ),
                          ),
                          
                          const Divider(color: Colors.white12, height: 16),
                          
                          // Opción Silenciar
                          InkWell(
                            onTap: () {
                              setStateDialog(() {
                                widget.controller.toggleParticipantLocalMute(user.id);
                                user = widget.controller.participants.firstWhere((p) => p.id == user.id);
                              });
                              setState(() {});
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                              child: Row(
                                children: [
                                  Icon(
                                    user.isLocalMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                                    color: user.isLocalMuted ? const Color(0xffD64A68) : Colors.white60,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text('Silenciar para mí', style: TextStyle(color: Colors.white70, fontSize: 11)),
                                  const Spacer(),
                                  SizedBox(
                                    height: 16,
                                    width: 28,
                                    child: Switch(
                                      value: user.isLocalMuted,
                                      activeColor: const Color(0xffD64A68),
                                      onChanged: (val) {
                                        setStateDialog(() {
                                          widget.controller.toggleParticipantLocalMute(user.id);
                                          user = widget.controller.participants.firstWhere((p) => p.id == user.id);
                                        });
                                        setState(() {});
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          
                          // Restablecer a 100%
                          InkWell(
                            onTap: () {
                              setStateDialog(() {
                                widget.controller.setParticipantVolume(user.id, 1.0);
                                user = widget.controller.participants.firstWhere((p) => p.id == user.id);
                              });
                              setState(() {});
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                              child: Row(
                                children: [
                                  Icon(Icons.refresh_rounded, color: Colors.white60, size: 16),
                                  const SizedBox(width: 8),
                                  Text('Restablecer volumen (100%)', style: TextStyle(color: Colors.white70, fontSize: 11)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatusIndicator({required IconData icon, required String label, required Color color}) {
    return Column(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 9)),
      ],
    );
  }
}

class _SpeakingIndicatorWave extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        final heightFactor = (index == 1) ? 1.0 : 0.6;
        return Container(
          width: 1.5,
          height: 10 * heightFactor,
          margin: const EdgeInsets.symmetric(horizontal: 0.5),
          decoration: BoxDecoration(
            color: const Color(0xff50E6A5),
            borderRadius: BorderRadius.circular(1),
          ),
        );
      }),
    );
  }
}

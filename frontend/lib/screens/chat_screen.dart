import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import '../models.dart';
import '../providers/chat_provider.dart';
import '../services/audio_service.dart';
import '../widgets/talking_head_widget.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _recorder = AudioRecorder();
  bool _isRecording = false;
  bool _audioUnlocked = false;

  /// Unlock audio playback on mobile browsers (must happen inside a user gesture).
  void _ensureAudioUnlocked() {
    if (!_audioUnlocked) {
      _audioUnlocked = true;
      AudioService.unlockAudio();
    }
  }

  void _send() {
    _ensureAudioUnlocked();
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    context.read<ChatProvider>().sendText(text);
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

  Future<void> _toggleRecording() async {
    _ensureAudioUnlocked();
    if (_isRecording) {
      // Stop recording — returns a blob URL on web
      final path = await _recorder.stop();
      setState(() => _isRecording = false);

      if (path != null && path.isNotEmpty) {
        try {
          // On web, path is a blob: URL; fetch it to get raw bytes
          final resp = await http.get(Uri.parse(path));
          final audioBytes = resp.bodyBytes;
          if (audioBytes.isNotEmpty) {
            context.read<ChatProvider>().sendVoice(audioBytes);
          }
        } catch (e) {
          debugPrint('Failed to read recording: $e');
        }
      }
    } else {
      // Request permission and start recording
      if (await _recorder.hasPermission()) {
        await _recorder.start(
          const RecordConfig(
            encoder: AudioEncoder.opus,
            numChannels: 1,
            sampleRate: 16000,
          ),
          path: '',
        );
        setState(() => _isRecording = true);
      }
    }
  }

  @override
  void dispose() {
    _recorder.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      appBar: AppBar(
        title: const Text(
          'TalkingHeadAI',
          style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.3),
        ),
        backgroundColor: const Color(0xFF09090B),
        foregroundColor: const Color(0xFFFAFAFA),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => Navigator.pushNamed(context, '/admin'),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.admin_panel_settings,
                      size: 22,
                      color: Color(0xFFA1A1AA),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Admin',
                      style: TextStyle(
                        color: Color(0xFFA1A1AA),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: Consumer<ChatProvider>(
        builder: (context, chat, _) {
          _scrollToBottom();
          return Column(
            children: [
              // Talking head avatar
              Container(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: TalkingHeadWidget(
                    isSpeaking: chat.isSpeaking,
                    size: 200,
                  ),
                ),
              ),

              // Status indicator with stop button
              if (chat.isSpeaking)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GestureDetector(
                    onTap: () => chat.stopSpeaking(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF22C55E).withValues(alpha: 0.5),
                          width: 1,
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.stop_circle,
                            color: Color(0xFF22C55E),
                            size: 20,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Stop Speaking',
                            style: TextStyle(
                              color: Color(0xFF22C55E),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              const Divider(color: Color(0xFF27272A), height: 1),

              // Messages list
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: chat.messages.length,
                  itemBuilder: (context, i) =>
                      _MessageBubble(message: chat.messages[i]),
                ),
              ),

              // Loading indicator
              if (chat.isLoading)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF3B82F6),
                        ),
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Thinking...',
                        style: TextStyle(color: Color(0xFF71717A)),
                      ),
                    ],
                  ),
                )
              else if (chat.isStreaming)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white24,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Streaming...',
                        style: TextStyle(
                          color: Color(0xFF52525B),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

              // Input area
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Color(0xFF18181B),
                  border: Border(top: BorderSide(color: Color(0xFF27272A))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        style: const TextStyle(color: Color(0xFFFAFAFA)),
                        decoration: InputDecoration(
                          hintText: 'Ask a question...',
                          hintStyle: const TextStyle(color: Color(0xFF52525B)),
                          filled: true,
                          fillColor: const Color(0xFF27272A),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      backgroundColor: _isRecording
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF27272A),
                      child: IconButton(
                        icon: Icon(
                          _isRecording ? Icons.stop : Icons.mic,
                          color: Colors.white,
                        ),
                        onPressed: _toggleRecording,
                      ),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      backgroundColor: const Color(0xFF3B82F6),
                      child: IconButton(
                        icon: const Icon(Icons.send, color: Colors.white),
                        onPressed: _send,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF3B82F6) : const Color(0xFF18181B),
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: isUser ? const Radius.circular(4) : null,
            bottomLeft: !isUser ? const Radius.circular(4) : null,
          ),
          border: isUser ? null : Border.all(color: const Color(0xFF27272A)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser && message.answerType != null)
              Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _tagColor(message.answerType!).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _tagLabel(message.answerType!, message.timesAsked),
                  style: TextStyle(
                    color: _tagColor(message.answerType!),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            Text(
              message.text,
              style: TextStyle(
                color: isUser
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.9),
                fontSize: 14,
              ),
            ),
            if (message.text.isNotEmpty)
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: message.text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Copied to clipboard'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Icon(
                      Icons.copy,
                      size: 14,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _tagLabel(String answerType, int? timesAsked) {
    switch (answerType) {
      case 'new':
        return '✨ New Question';
      case 'known':
        final count = timesAsked != null ? ' · Asked $timesAsked times' : '';
        return '📚 Known Answer$count';
      default:
        return answerType;
    }
  }

  static Color _tagColor(String answerType) {
    switch (answerType) {
      case 'new':
        return const Color(0xFFF59E0B);
      case 'known':
        return const Color(0xFF38BDF8);
      default:
        return const Color(0xFF71717A);
    }
  }
}

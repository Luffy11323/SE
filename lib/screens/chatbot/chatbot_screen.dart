// lib/screens/chatbot/chatbot_screen.dart

import 'package:flutter/material.dart';
import 'package:self_evaluator/screens/self_eval/mcq_session_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vibration/vibration.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:self_evaluator/constants/colors.dart';
import 'package:self_evaluator/constants/strings.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ChatMessage {
  final bool isBot;
  final String content;
  final DateTime timestamp;

  ChatMessage({
    required this.isBot,
    required this.content,
    required this.timestamp,
  });
}

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> with TickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;
  bool _isInitialized = false;

  // Journey tracking
  String? _journeySummary;
  String? _progressNote;
  int? _pendingCount;
  bool _isResetting = false;

  // Voice input (STT)
  final SpeechToText _speech = SpeechToText();
  bool _speechInitialized = false;
  bool _isListening = false;
  String _liveTranscription = '';

  // Voice output (TTS)
  final FlutterTts _tts = FlutterTts();
  bool _isSpeaking = false;
  String _ttsStatus = '';
  String _currentVoice = 'en-US';
  final List<String> _availableVoices = ['en-US', 'ur-PK'];

  // Realtime
  late RealtimeChannel _channel;
  final supabase = Supabase.instance.client;
  late final String _userId = supabase.auth.currentUser?.id ?? 'anonymous';

  late AnimationController _waveController;
  late Animation<double> _waveAnimation;

  @override
  void initState() {
    super.initState();
    _initControllers();
    _initSpeechAndTts();
    _loadInitialHistory();
    _setupRealtime();
    _scrollController.addListener(_scrollListener);
  }

  void _initControllers() {
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _waveAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _waveController, curve: Curves.easeInOut),
    );
  }

  Future<void> _initSpeechAndTts() async {
    try {
      _speechInitialized = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            _stopListening();
          }
        },
        onError: (error) {
          setState(() {
            _isListening = false;
            _liveTranscription = "Didn't catch that, insha'Allah. Try again?";
          });
        },
      );

      await _tts.setLanguage(_currentVoice);
      await _tts.setSpeechRate(0.6);
      await _tts.setPitch(1.1);
      await _tts.setVolume(1.0);

      _tts.setCompletionHandler(() {
        setState(() {
          _isSpeaking = false;
          _ttsStatus = '';
        });
      });

      setState(() => _isInitialized = true);
    } catch (e) {
      debugPrint('Init error: $e');
    }
  }

  Future<void> _loadInitialHistory() async {
    try {
      final response = await supabase
          .from('chat_history')
          .select()
          .eq('user_id', _userId)
          .order('happened_at', ascending: true)
          .limit(50);

      if (mounted) {
        setState(() {
          _messages.addAll(response.map((e) => ChatMessage(
                isBot: e['message_type'] == 'bot',
                content: e['content'] as String,
                timestamp: DateTime.parse(e['happened_at']),
              )));
          _scrollToBottom();
        });
      }
    } catch (e) {
      debugPrint('History load error: $e');
    }
  }

  void _setupRealtime() {
    _channel = supabase.channel('chat_history').onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'chat_history',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: _userId,
      ),
      callback: (payload) {
        if (!mounted) return;

        final newRecord = payload.newRecord;
        if (newRecord['user_id'] != _userId) return;

        final isInsertOrUpdate = payload.eventType == PostgresChangeEvent.insert ||
            payload.eventType == PostgresChangeEvent.update;

        if (isInsertOrUpdate) {
          setState(() {
            _isTyping = false;
            
            // Extract journey metadata if present
            if (newRecord['cumulative_summary'] != null) {
              _journeySummary = newRecord['cumulative_summary'] as String;
            }
            if (newRecord['progress_note'] != null) {
              _progressNote = newRecord['progress_note'] as String;
            }
            if (newRecord['pending_count'] != null) {
              _pendingCount = newRecord['pending_count'] as int;
            }
            
            _messages.add(ChatMessage(
              isBot: newRecord['message_type'] == 'bot',
              content: newRecord['content'] as String,
              timestamp: DateTime.parse(newRecord['happened_at']),
            ));
            _scrollToBottom();
            if (newRecord['message_type'] == 'bot') {
              Vibration.vibrate(duration: 50);
              _speakBotMessage(newRecord['content'] as String);
            }
          });
        }
      },
    ).subscribe();
  }

  Future<void> _resetJourney() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: Text(
          'Reset Journey?',
          style: TextStyle(color: AppColors.textLight),
        ),
        content: Text(
          'This will clear your conversation history and start fresh. Are you sure?',
          style: TextStyle(color: AppColors.textLight.withValues(alpha: 0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: TextStyle(color: AppColors.textLight)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Reset', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isResetting = true);

    try {
      // Get the base URL from your Supabase config
      final supabaseUrl = "https://jjnbusmjsgjyjgomhuij.supabase.co";
      final baseUrl = supabaseUrl.replaceAll('/rest/v1', '');
      
      final response = await http.post(
        Uri.parse('$baseUrl/functions/v1/reset-journey/$_userId'),
        headers: {
          'Authorization': 'Bearer ${supabase.auth.currentSession?.accessToken}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _messages.clear();
          _journeySummary = null;
          _progressNote = null;
          _pendingCount = null;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Journey reset successfully'),
              backgroundColor: AppColors.accentGreen,
            ),
          );
        }
      } else {
        throw Exception('Reset failed: ${response.body}');
      }
    } catch (e) {
      debugPrint('Reset journey error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reset journey: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isResetting = false);
    }
  }

  Future<void> _startListening() async {
    if (_isListening || !_speechInitialized) return;

    setState(() {
      _isListening = true;
      _liveTranscription = '';
      _ttsStatus = 'Listening...';
    });

    Vibration.vibrate(duration: 40);

    await _speech.listen(
      onResult: (result) {
        setState(() => _liveTranscription = result.recognizedWords);

        if (result.finalResult && _isListening) {
          Future.delayed(const Duration(milliseconds: 800), () {
            if (_isListening && _liveTranscription.trim().isNotEmpty) {
              _sendMessage(_liveTranscription, fromVoice: true);
              _stopListening();
            }
          });
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 5),
      localeId: _currentVoice,
    );
  }

  Future<void> _stopListening() async {
    if (!_isListening) return;
    await _speech.stop();
    setState(() {
      _isListening = false;
      _ttsStatus = '';
    });
    Vibration.vibrate(duration: 20);
  }

  Future<void> _speak(String text) async {
    if (_isSpeaking) await _tts.stop();

    setState(() {
      _isSpeaking = true;
      _ttsStatus = 'Speaking...';
    });

    await Future.delayed(const Duration(milliseconds: 300));
    await _tts.speak(text);
  }

  Future<void> _speakBotMessage(String text) async {
    await _speak(text);
  }

  Future<void> _sendMessage(String text, {bool fromVoice = false}) async {
    text = text.trim();
    if (text.isEmpty) return;

    final message = ChatMessage(
      isBot: false,
      content: text,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(message);
      _textController.clear();
      _liveTranscription = '';
      _isTyping = true;
      _scrollToBottom();
    });

    Vibration.vibrate(duration: 10);

    try {
      await supabase.from('chat_history').insert({
        'user_id': _userId,
        'message_type': 'user',
        'content': text,
        'category_context': 'General',
      });

      if (fromVoice) {
        await _speak("Alhamdulillah, got it...");
      }
    } catch (e) {
      debugPrint('Send message error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    }
  }

  void _scrollToBottom({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: animate ? const Duration(milliseconds: 300) : Duration.zero,
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _scrollListener() {
    if (_scrollController.position.pixels > 100) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }

  Widget _buildWaveform() {
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (i) {
            final height = 6 + (_waveAnimation.value * 20 * (i % 3 + 1));
            return AnimatedContainer(
              duration: Duration(milliseconds: 200 + i * 100),
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 6,
              height: _isListening ? height : 6,
              decoration: BoxDecoration(
                color: AppColors.accentGreen.withValues(alpha: _isListening ? 0.8 : 0.3),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildJourneySummaryCard() {
    if (_journeySummary == null && _progressNote == null && _pendingCount == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accentGreen.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.accentGreen.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentGreen.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome,
                color: AppColors.accentGreen,
                size: 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Journey Summary',
                  style: TextStyle(
                    color: AppColors.accentGreen,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (_journeySummary != null)
                IconButton(
                  icon: Icon(Icons.refresh, color: AppColors.accentGreen),
                  onPressed: _isResetting ? null : _resetJourney,
                  tooltip: 'Reset Journey',
                ),
            ],
          ),
          if (_journeySummary != null) ...[
            const SizedBox(height: 12),
            Text(
              _journeySummary!,
              style: TextStyle(
                color: AppColors.textLight.withValues(alpha: 0.9),
                fontSize: 15,
                height: 1.5,
              ),
            ),
          ],
          if (_progressNote != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.cardBackground.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    color: Colors.amber,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _progressNote!,
                      style: TextStyle(
                        color: AppColors.textLight.withValues(alpha: 0.85),
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_pendingCount != null && _pendingCount! > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.orange.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.pending_actions,
                    color: Colors.orange,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$_pendingCount pending question${_pendingCount! > 1 ? 's' : ''}',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    _channel.unsubscribe();
    _textController.dispose();
    _scrollController.dispose();
    _waveController.dispose();
    _tts.stop();
    _speech.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      appBar: AppBar(
        title: Text(AppStrings.chatbotWelcome.split(',')[0]),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.settings_voice, color: AppColors.textLight),
            onSelected: (voice) {
              setState(() {
                _currentVoice = voice;
              });
              _tts.stop();
              _tts.setLanguage(voice);
            },
            itemBuilder: (context) => _availableVoices
                .map((v) => PopupMenuItem(value: v, child: Text(v)))
                .toList(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Journey Summary Card
          _buildJourneySummaryCard(),

          // Status bar
          if (_ttsStatus.isNotEmpty || _isListening)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: AppColors.cardBackground.withValues(alpha: 0.5),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isListening) ...[
                      _buildWaveform(),
                      const SizedBox(width: 12),
                    ],
                    Text(
                      _ttsStatus.isNotEmpty ? _ttsStatus : "Listening...",
                      style: TextStyle(
                        color: AppColors.accentGreen,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Live preview
          if (_liveTranscription.isNotEmpty && _isListening)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                "You said: $_liveTranscription",
                style: TextStyle(
                  color: AppColors.textLight.withValues(alpha: 0.8),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),

          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (index < _messages.length) {
                  final msg = _messages[index];
                  final isBot = msg.isBot;
                  return Align(
                    alignment: isBot ? Alignment.centerLeft : Alignment.centerRight,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: isBot
                            ? AppColors.cardBackground.withValues(alpha: 0.7)
                            : AppColors.accentGreen.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(isBot ? 0 : 20),
                          topRight: Radius.circular(isBot ? 20 : 0),
                          bottomLeft: const Radius.circular(20),
                          bottomRight: const Radius.circular(20),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isBot ? Colors.black26 : AppColors.accentGreen.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        msg.content,
                        style: TextStyle(
                          color: isBot ? AppColors.textLight : AppColors.buttonText,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  );
                }

                // Typing indicator
                return Padding(
                  padding: const EdgeInsets.only(left: 16, top: 8),
                  child: Row(
                    children: List.generate(3, (i) => Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: AppColors.accentGreen.withValues(alpha: 1 - i * 0.35),
                            shape: BoxShape.circle,
                          ),
                        )),
                  ),
                );
              },
            ),
          ),
          if (_journeySummary != null ||
              _progressNote != null ||
              _pendingCount != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                color: AppColors.cardBackground,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Journey Progress",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.accentGreen,
                        ),
                      ),
                      const SizedBox(height: 12),

                      if (_progressNote != null)
                        Text(
                          "Note: $_progressNote",
                          style: TextStyle(color: AppColors.textLight),
                        ),

                      if (_journeySummary != null)
                        Text(
                          "Summary: $_journeySummary",
                          style: TextStyle(color: AppColors.textLight),
                        ),

                      if (_pendingCount != null && _pendingCount! > 0)
                        Text(
                          "${_pendingCount!} questions remaining",
                          style: TextStyle(color: AppColors.accentGreen),
                        ),

                      if (_pendingCount != null && _pendingCount == 0)
                        Text(
                          "Journey complete!",
                          style: TextStyle(color: AppColors.accentGreen),
                        ),

                      const SizedBox(height: 12),

                      if (_pendingCount != null && _pendingCount! > 0)
                        ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => MCQSessionScreen(
                                  category: 'Current',
                                  isNewSession: false,
                                ),
                              ),
                            );
                          },
                          child: const Text("Continue Journey"),
                        ),

                      if (_pendingCount != null)
                        TextButton(
                          onPressed: () async {
                            setState(() => _isResetting = true);

                            await supabase.functions.invoke(
                              'reset-journey',
                              body: {'user_id': _userId},
                            );

                            setState(() {
                              _journeySummary = null;
                              _progressNote = null;
                              _pendingCount = 0;
                              _isResetting = false;
                            });
                          },
                          child: Text(
                            "Reset Journey",
                            style: TextStyle(color: AppColors.errorColor),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

          // Input area
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.cardBackground.withValues(alpha: 0.8),
              border: Border(top: BorderSide(color: AppColors.accentGreen.withValues(alpha: 0.3))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: InputDecoration(
                      hintText: AppStrings.typeMessageHint,
                      hintStyle: TextStyle(color: AppColors.textLight.withValues(alpha: 0.6)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    style: TextStyle(color: AppColors.textLight),
                    maxLines: null,
                    minLines: 1,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(_textController.text),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onLongPressStart: (_) => _startListening(),
                  onLongPressEnd: (_) => _stopListening(),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isListening ? Colors.red.withValues(alpha: 0.8) : AppColors.accentGreen,
                      boxShadow: [
                        BoxShadow(
                          color: _isListening ? Colors.red.withValues(alpha: 0.4) : AppColors.accentGreen.withValues(alpha: 0.4),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.mic, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.send, color: AppColors.accentGreen),
                  onPressed: () => _sendMessage(_textController.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

}
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_state.dart';
import '../core/app_theme.dart';
import '../l10n/language_controller.dart';
import '../models/models.dart';
import '../widgets/common.dart';

class AiScreen extends StatefulWidget {
  const AiScreen({
    super.key,
    this.initialRoomId,
    this.standalone = false,
  });

  final String? initialRoomId;
  final bool standalone;

  @override
  State<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends State<AiScreen> {
  static const int _maxStoredMessages = 100;

  final controller = TextEditingController();
  final scrollController = ScrollController();
  final messages = <ChatMessage>[];

  bool loading = false;
  bool restoringHistory = true;
  String? selectedRoomId;

  String get _historyKey {
    if (widget.standalone) {
      return 'edgespace_ai_chat_room_${widget.initialRoomId ?? 'all'}';
    }
    return 'edgespace_ai_chat_main';
  }

  String _welcomeText(BuildContext context) {
    return context.tr(
      "Hi! I'm the EdgeSpace AI Assistant. Talk to me naturally — you don't "
          "need predefined commands. You can ask me who I am, how the app works, "
          "or ask for help with Buildings, Rooms, ESP32-C3, Analytics, Settings "
          "and your space measurements.\n\n"
          "For example: “How are you?”, “How do I create a new room?” or "
          "“How do I connect an ESP32-C3?”",
      'Γεια! Είμαι ο EdgeSpace AI Assistant. Μίλα μου φυσικά — δεν χρειάζονται '
          'προκαθορισμένες εντολές. Μπορείς να με ρωτήσεις πώς είμαι, ποιος είμαι, '
          'πώς λειτουργεί η εφαρμογή ή να μου ζητήσεις βοήθεια με Buildings, Rooms, '
          'ESP32-C3, Analytics, Settings και τις μετρήσεις των χώρων.\n\n'
          'Για παράδειγμα: «Τι κάνεις;», «Πώς φτιάχνω νέο δωμάτιο;» ή '
          '«Πώς συνδέω ένα ESP32-C3;».',
    );
  }

  bool _isWelcomeMessage(ChatMessage message) {
    if (message.fromUser) return false;

    return message.text.startsWith(
          'Γεια! Είμαι ο EdgeSpace AI Assistant.',
        ) ||
        message.text.startsWith(
          "Hi! I'm the EdgeSpace AI Assistant.",
        );
  }

  @override
  void initState() {
    super.initState();
    selectedRoomId = widget.initialRoomId;
    _restoreConversation();
  }

  void _addWelcomeMessage() {
    messages.add(
      ChatMessage(
        text: _welcomeText(context),
        fromUser: false,
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> _restoreConversation() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historyKey);
    final restored = <ChatMessage>[];

    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is! Map) continue;

            final text = item['text']?.toString().trim() ?? '';
            if (text.isEmpty) continue;

            final fromUser = item['fromUser'] == true;
            final createdAtRaw = item['createdAt']?.toString();
            final createdAt = createdAtRaw == null
                ? DateTime.now()
                : DateTime.tryParse(createdAtRaw) ?? DateTime.now();

            restored.add(
              ChatMessage(
                text: text,
                fromUser: fromUser,
                createdAt: createdAt,
              ),
            );
          }
        }
      } catch (_) {
        // Corrupt/old chat data should never stop the AI screen from opening.
      }
    }

    if (!mounted) return;

    setState(() {
      messages
        ..clear()
        ..addAll(restored);

      if (messages.isEmpty) {
        _addWelcomeMessage();
      }

      restoringHistory = false;
    });

    _scrollDown();
  }

  Future<void> _saveConversation() async {
    final prefs = await SharedPreferences.getInstance();

    final start = messages.length > _maxStoredMessages
        ? messages.length - _maxStoredMessages
        : 0;
    final toStore = messages.sublist(start);

    final payload = toStore
        .map(
          (message) => {
            'text': message.text,
            'fromUser': message.fromUser,
            'createdAt': message.createdAt.toIso8601String(),
          },
        )
        .toList();

    await prefs.setString(_historyKey, jsonEncode(payload));
  }

  @override
  void dispose() {
    controller.dispose();
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    final effectiveSelectedRoomId = selectedRoomId != null &&
            state.rooms.any((room) => room.id == selectedRoomId)
        ? selectedRoomId
        : null;

    final usingRemoteAi = state.useGemini && state.backendOnline;

    final body = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Column(
            children: [
              Row(
                children: [
                  if (!widget.standalone) ...[
                    const BrandMark(size: 38),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Text(
                      context.tr('AI Assistant', 'Βοηθός AI'),
                      style: widget.standalone
                          ? Theme.of(context).textTheme.titleLarge
                          : Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  StatusChip(
                    label: state.aiBadgeLabel,
                    color: usingRemoteAi ? EdgeColors.blue : EdgeColors.green,
                    icon: Icons.auto_awesome_rounded,
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: context.tr('Clear chat', 'Καθαρισμός συνομιλίας'),
                    onPressed: loading ? null : _clearChat,
                    icon: const Icon(
                      Icons.delete_sweep_outlined,
                      size: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: effectiveSelectedRoomId ?? 'all',
                decoration: InputDecoration(
                  labelText: context.tr(
                    'Analysis scope',
                    'Πεδίο ανάλυσης',
                  ),
                  prefixIcon: const Icon(Icons.filter_alt_outlined),
                  isDense: true,
                ),
                items: [
                  DropdownMenuItem(
                    value: 'all',
                    child: Text(
                      context.tr(
                        'All spaces',
                        'Όλοι οι χώροι',
                      ),
                    ),
                  ),
                  ...state.rooms.map(
                    (room) => DropdownMenuItem(
                      value: room.id,
                      child: Text(
                        '${state.buildingOf(room).name} / ${room.name}',
                      ),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    selectedRoomId = value == 'all' ? null : value;
                  });
                },
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _QuickPrompt(
                      text: context.tr(
                        'How do I create a new room?',
                        'Πώς φτιάχνω νέο δωμάτιο;',
                      ),
                      onTap: _sendPreset,
                    ),
                    _QuickPrompt(
                      text: context.tr(
                        'How do I connect an ESP32-C3?',
                        'Πώς συνδέω ESP32-C3;',
                      ),
                      onTap: _sendPreset,
                    ),
                    _QuickPrompt(
                      text: context.tr(
                        'What should I pay attention to today?',
                        'Τι πρέπει να προσέξω σήμερα;',
                      ),
                      onTap: _sendPreset,
                    ),
                    _QuickPrompt(
                      text: context.tr(
                        'What can you do?',
                        'Τι μπορείς να κάνεις;',
                      ),
                      onTap: _sendPreset,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: restoringHistory
              ? const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 22),
                  itemCount: messages.length + (loading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == messages.length && loading) {
                      return const _ThinkingBubble();
                    }
                    final message = messages[index];

                    final displayMessage = _isWelcomeMessage(message)
                        ? ChatMessage(
                            text: _welcomeText(context),
                            fromUser: false,
                            createdAt: message.createdAt,
                          )
                        : message;

                    return _ChatBubble(message: displayMessage);
                  },
                ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: context.tr(
                        'Write to me naturally, like you would to an assistant...',
                        'Γράψε μου όπως θα μιλούσες σε έναν βοηθό...',
                      ),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 48,
                  height: 48,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: loading ? null : _send,
                    child: const Icon(Icons.arrow_upward_rounded),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    if (!widget.standalone) {
      return SafeArea(child: body);
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          context.tr(
            'Room AI',
            'AI Χώρου',
          ),
        ),
      ),
      body: body,
    );
  }

  void _sendPreset(String text) {
    controller.text = text;
    _send();
  }

  Future<void> _clearChat() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);

    if (!mounted) return;

    setState(() {
      messages.clear();
      _addWelcomeMessage();
    });

    await _saveConversation();
    _scrollDown();
  }

  Future<void> _send() async {
    final text = controller.text.trim();
    if (text.isEmpty || loading) {
      return;
    }

    final state = context.read<AppState>();
    final responseLanguageCode = context.isGreek ? 'el' : 'en';
    final priorConversation =
        messages.where((message) => !_isWelcomeMessage(message)).toList();

    setState(() {
      messages.add(
        ChatMessage(
          text: text,
          fromUser: true,
          createdAt: DateTime.now(),
        ),
      );
      controller.clear();
      loading = true;
    });

    await _saveConversation();
    _scrollDown();

    try {
      final safeRoomId = selectedRoomId != null &&
              state.rooms.any((room) => room.id == selectedRoomId)
          ? selectedRoomId
          : null;

      final answer = await state.askAdvisor(
        text,
        roomId: safeRoomId,
        conversation: priorConversation,
        responseLanguageCode: responseLanguageCode,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        loading = false;
        selectedRoomId = safeRoomId;
        messages.add(
          ChatMessage(
            text: answer,
            fromUser: false,
            createdAt: DateTime.now(),
          ),
        );
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        loading = false;
        messages.add(
          ChatMessage(
            text: 'Δεν μπόρεσα να ολοκληρώσω την απάντηση: $e',
            fromUser: false,
            createdAt: DateTime.now(),
          ),
        );
      });
    }

    await _saveConversation();
    _scrollDown();
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scrollController.hasClients) {
        return;
      }

      scrollController.animateTo(
        scrollController.position.maxScrollExtent + 220,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }
}

class _QuickPrompt extends StatelessWidget {
  const _QuickPrompt({
    required this.text,
    required this.onTap,
  });

  final String text;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: ActionChip(
        avatar: const Icon(
          Icons.auto_awesome_rounded,
          size: 15,
          color: EdgeColors.blue,
        ),
        label: Text(
          text,
          style: const TextStyle(fontSize: 10),
        ),
        onPressed: () => onTap(text),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final user = message.fromUser;

    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * .82,
        ),
        margin: const EdgeInsets.only(bottom: 11),
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: user ? EdgeColors.blue : const Color(0xFFF0F4F7),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(user ? 16 : 4),
            bottomRight: Radius.circular(user ? 4 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .08),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: user
            ? Text(
                message.text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  height: 1.48,
                  fontWeight: FontWeight.w600,
                ),
              )
            : MarkdownBody(
                data: message.text,
                selectable: true,
                styleSheet: MarkdownStyleSheet(
                  p: const TextStyle(
                    color: Color(0xFF182A35),
                    fontSize: 12.5,
                    height: 1.48,
                    fontWeight: FontWeight.w500,
                  ),
                  h1: const TextStyle(
                    color: Color(0xFF102A3A),
                    fontSize: 18,
                    height: 1.3,
                    fontWeight: FontWeight.w800,
                  ),
                  h2: const TextStyle(
                    color: Color(0xFF102A3A),
                    fontSize: 16,
                    height: 1.35,
                    fontWeight: FontWeight.w800,
                  ),
                  h3: const TextStyle(
                    color: Color(0xFF102A3A),
                    fontSize: 14,
                    height: 1.4,
                    fontWeight: FontWeight.w800,
                  ),
                  strong: const TextStyle(
                    color: Color(0xFF102A3A),
                    fontWeight: FontWeight.w800,
                  ),
                  em: const TextStyle(
                    color: Color(0xFF29485A),
                    fontStyle: FontStyle.italic,
                  ),
                  code: const TextStyle(
                    color: Color(0xFF0D4F73),
                    backgroundColor: Color(0xFFE1EDF4),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                  listBullet: const TextStyle(
                    color: Color(0xFF1687C9),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                  blockquote: const TextStyle(
                    color: Color(0xFF36505E),
                    fontSize: 12.5,
                    height: 1.45,
                    fontStyle: FontStyle.italic,
                  ),
                  a: const TextStyle(
                    color: Color(0xFF147FC1),
                    decoration: TextDecoration.underline,
                  ),
                  codeblockPadding: const EdgeInsets.all(10),
                  codeblockDecoration: BoxDecoration(
                    color: const Color(0xFFE7F0F5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  blockquotePadding: const EdgeInsets.fromLTRB(10, 4, 8, 4),
                  blockquoteDecoration: const BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        color: Color(0xFF4AA8DA),
                        width: 3,
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _ThinkingBubble extends StatelessWidget {
  const _ThinkingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F4F7),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: EdgeColors.blue,
              ),
            ),
            SizedBox(width: 9),
            Text(
              'Σκέφτομαι...',
              style: TextStyle(
                color: Color(0xFF36505E),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

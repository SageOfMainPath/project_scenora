import 'dart:async';

import 'package:flutter/material.dart';

import '../core/scenora_theme.dart';
import '../models/scenora_models.dart';
import '../widgets/scenora_widgets.dart';

class ShoutboxScreen extends StatefulWidget {
  const ShoutboxScreen({
    super.key,
    required this.isLoggedIn,
    required this.requireAuth,
    required this.loadMessages,
    required this.sendMessage,
  });

  final bool isLoggedIn;
  final Future<bool> Function(String reason) requireAuth;
  final Future<List<ChatMessage>> Function() loadMessages;
  final Future<ChatMessage> Function(String text) sendMessage;

  @override
  State<ShoutboxScreen> createState() => _ShoutboxScreenState();
}

class _ShoutboxScreenState extends State<ShoutboxScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final List<ChatMessage> _messages = [];
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => _refresh());
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final messages = await widget.loadMessages();
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(messages);
      });
    } catch (_) {
      // Keep the current conversation and retry on the next poll.
    }
  }

  Future<void> _send() async {
    final allowed = await widget.requireAuth(
      'Log in to join the live Shoutbox conversation.',
    );
    if (!allowed || !mounted) return;
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    try {
      final message = await widget.sendMessage(text);
      if (!mounted) return;
      setState(() => _messages.add(message));
      _controller.clear();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Shoutbox',
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
          ),
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: Color(0xFF25B487),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                'Live community chat',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.info_outline_rounded),
        ),
      ],
    ),
    body: Column(
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(16, 6, 16, 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: ScenoraTheme.crimson.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.campaign_outlined,
                size: 19,
                color: ScenoraTheme.crimson,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Be respectful and keep spoilers clearly labelled.',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _messages.isEmpty
              ? const Center(
                  child: Text('No messages yet. Start the conversation!'),
                )
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) => _Bubble(message: _messages[i]),
                  ),
                ),
        ),
        if (!widget.isLoggedIn)
          Material(
            color: Theme.of(
              context,
            ).colorScheme.primaryContainer.withValues(alpha: .35),
            child: InkWell(
              onTap: () => widget.requireAuth(
                'Log in to join the live Shoutbox conversation.',
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_outline_rounded, size: 17),
                    SizedBox(width: 7),
                    Text(
                      'Log in to join the conversation',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ),
          ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 7, 12, 10),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => widget.requireAuth(
                    'Log in to share images in the Shoutbox.',
                  ),
                  icon: const Icon(Icons.add_circle_outline_rounded),
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: const InputDecoration(
                      hintText: 'Say something…',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                IconButton.filled(
                  onPressed: _send,
                  icon: const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: message.isMine
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      children: [
        if (!message.isMine) ...[
          UserAvatar(name: message.user, color: message.color, radius: 17),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Column(
            crossAxisAlignment: message.isMine
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              if (!message.isMine)
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 4),
                  child: Text(
                    message.user,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: message.isMine
                      ? ScenoraTheme.crimson
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(17),
                    topRight: const Radius.circular(17),
                    bottomLeft: Radius.circular(message.isMine ? 17 : 4),
                    bottomRight: Radius.circular(message.isMine ? 4 : 17),
                  ),
                ),
                child: Text(
                  message.text,
                  style: TextStyle(
                    color: message.isMine ? Colors.white : null,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                message.time,
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

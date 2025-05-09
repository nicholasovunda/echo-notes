import 'package:echonotes/send_to_groq.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_bubble/chat_bubble.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:html_unescape/html_unescape.dart';

class SendMessage extends StatefulWidget {
  const SendMessage({super.key});

  @override
  State<SendMessage> createState() => _SendMessageState();
}

class _SendMessageState extends State<SendMessage> {
  final TextEditingController _controller = TextEditingController();
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final HtmlUnescape _htmlUnescape = HtmlUnescape();
  final FocusNode _textFieldFocus = FocusNode();

  final groq = GroqService();

  bool _isLoading = false;
  bool _isListening = false;
  bool _isSpeechAvailable = false;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _scrollController.addListener(_handleScroll);
  }

  void _handleScroll() {
    // Auto-scroll only when new message arrives
    if (_scrollController.position.atEdge) {
      if (_scrollController.position.pixels != 0) {
        _scrollToBottom();
      }
    }
  }

  Future<void> _initSpeech() async {
    try {
      _isSpeechAvailable = await _speech.initialize(
        onStatus: (status) {
          if (status == 'notListening' && _isListening) {
            setState(() => _isListening = false);
          }
        },
        onError: (error) => _handleSpeechError(error.toString()),
      );
      setState(() {});
    } catch (e) {
      debugPrint('Speech initialization failed: $e');
    }
  }

  void _handleSpeechError(String error) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Speech error: $error')));
      setState(() => _isListening = false);
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

  Future<void> _toggleListening() async {
    if (!_isSpeechAvailable) return;

    setState(() => _isListening = !_isListening);

    if (_isListening) {
      _controller.clear();
      await _speech.listen(
        onResult: (result) {
          if (result.finalResult) {
            _controller.text = result.recognizedWords;
          }
        },
        listenFor: const Duration(minutes: 1),
        cancelOnError: true,
      );
    } else {
      await _speech.stop();
      _textFieldFocus.requestFocus();
    }
  }

  Future<void> _sendMessage(String message) async {
    final trimmedMessage = message.trim();
    if (trimmedMessage.isEmpty) return;

    setState(() {
      _isLoading = true;
      _messages.add(ChatMessage(text: trimmedMessage, isMe: true));
      _controller.clear();
    });
    _scrollToBottom();

    try {
      final reply = await groq.sendToGroq(trimmedMessage);
      final unescapedReply = _htmlUnescape.convert(reply);

      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(text: unescapedReply, isMe: false));
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('Message sending error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _messages.add(
            ChatMessage(
              text: "Sorry, something went wrong. Please try again.",
              isMe: false,
            ),
          );
        });
        _scrollToBottom();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(8),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final message = _messages[index];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: ChatBubble(
                  clipper: ChatBubbleClipper9(
                    type:
                        message.isMe
                            ? BubbleType.sendBubble
                            : BubbleType.receiverBubble,
                  ),
                  alignment:
                      message.isMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                  backGroundColor:
                      message.isMe
                          ? Theme.of(context).primaryColor
                          : Colors.grey[300],
                  margin: const EdgeInsets.only(top: 4),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    child: Text(
                      message.text,
                      style: TextStyle(
                        color: message.isMe ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: CircularProgressIndicator(),
          ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _textFieldFocus,
                  minLines: 1,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Type your message...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onSubmitted: (text) => _sendMessage(text),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor:
                    _isListening ? Colors.red : Theme.of(context).primaryColor,
                child: IconButton(
                  icon: Icon(
                    _isListening ? Icons.mic_off : Icons.mic,
                    color: Colors.white,
                  ),
                  onPressed: _toggleListening,
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: Theme.of(context).primaryColor,
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white),
                  onPressed: () => _sendMessage(_controller.text),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _speech.stop();
    _textFieldFocus.dispose();
    super.dispose();
  }
}

class ChatMessage {
  final String text;
  final bool isMe;

  ChatMessage({required this.text, required this.isMe});
}

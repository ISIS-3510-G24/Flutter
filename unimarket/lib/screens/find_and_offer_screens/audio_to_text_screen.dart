import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class AudioToTextScreen extends StatefulWidget {
  final Function(String) onTextGenerated;

  const AudioToTextScreen({Key? key, required this.onTextGenerated}) : super(key: key);

  @override
  _AudioToTextScreenState createState() => _AudioToTextScreenState();
}

class _AudioToTextScreenState extends State<AudioToTextScreen> {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _text = "";

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
  }

  void _startListening() async {
    bool available = await _speech.initialize(
      onStatus: (status) => print("Status: $status"),
      onError: (error) => print("Error: $error"),
    );

    if (available) {
      setState(() => _isListening = true);
      _speech.listen(
        onResult: (result) {
          setState(() {
            _text = result.recognizedWords;
          });
        },
      );
    } else {
      print("Speech recognition not available");
    }
  }

  void _stopListening() {
    _speech.stop();
    setState(() => _isListening = false);
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text("Audio to Text"),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () {
            widget.onTextGenerated(_text); // Devuelve el texto generado
            Navigator.pop(context);
          },
          child: const Text("Done"),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Speak now:",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _text.isEmpty ? "Press the mic button and start speaking" : _text,
                style: const TextStyle(fontSize: 16),
              ),
            ),
            const Spacer(),
            Center(
              child: GestureDetector(
                onTap: _isListening ? _stopListening : _startListening,
                child: CircleAvatar(
                  radius: 30,
                  backgroundColor: _isListening ? Colors.red : Colors.blue,
                  child: Icon(
                    _isListening ? Icons.mic_off : Icons.mic,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
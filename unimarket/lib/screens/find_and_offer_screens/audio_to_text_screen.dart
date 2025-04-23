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
    // Detener cualquier reconocimiento anterior para evitar acumulación de texto
    if (_isListening) {
      await _speech.stop();
    }

    setState(() {
      _text = ""; // Limpiar texto antes de empezar a escuchar
      _isListening = true;
    });

    bool available = await _speech.initialize(
      onStatus: (status) => print("Status: $status"),
      onError: (error) => print("Error: $error"),
    );

    if (available) {
      _speech.listen(
        onResult: (result) {
          setState(() {
            _text = result.recognizedWords; // Solo se guarda el nuevo texto
          });
        },
      );
    } else {
      print("Speech recognition not available");
      setState(() {
        _isListening = false;
      });
    }
  }

  void _stopListening() async {
    await _speech.stop();
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Speak now:",
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: CupertinoColors.black,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey6,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: CupertinoColors.systemGrey),
              ),
              child: Center(
                child: Text(
                  _text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    color: CupertinoColors.black,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: _isListening ? _stopListening : _startListening,
              child: CircleAvatar(
                radius: 40,
                backgroundColor: _isListening
                    ? CupertinoColors.systemRed
                    : const Color.fromARGB(255, 144, 198, 255),
                child: Icon(
                  _isListening ? CupertinoIcons.mic_off : CupertinoIcons.mic,
                  color: CupertinoColors.white,
                  size: 30,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _isListening ? "Listening..." : "Tap the mic to start",
              style: const TextStyle(
                fontSize: 16,
                color: CupertinoColors.systemGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

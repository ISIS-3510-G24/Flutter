import 'package:flutter/material.dart';


class QrGenerate extends StatefulWidget {
  const QrGenerate({super.key});

  @override
  State<QrGenerate> createState() => _QrGenerateState();
}

class _QrGenerateState extends State<QrGenerate> {
  String? qrdata;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Generate QR code"),
        actions: [
          IconButton(
            onPressed: (){
              Navigator.popAndPushNamed(context, "/scanQR");
            },
            icon: const Icon(Icons.qr_code_scanner))
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(

        ),
      ),
    );
  }
}
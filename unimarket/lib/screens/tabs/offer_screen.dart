import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class OfferScreen extends StatefulWidget {
  const OfferScreen({super.key});

  @override
  _OfferScreenState createState() => _OfferScreenState();
}

class _OfferScreenState extends State<OfferScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _productName;
  String? _description;
  String? _characteristics;
  String? _price;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Confirm Product'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.back),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // Imagen del producto
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                    ),
                    child: Center(
                      child: Image.asset(
                        "assets/images/Notebooks.png", 
                        height: 150,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  
                  CupertinoButton(
                    onPressed: () {
                      // Lógica para tomar otra imagen
                    },
                    child: const Text('Retake Image'),
                  ),
                  const SizedBox(height: 20),

                  // Nombre del producto
                  const Text(
                    'Name of the product',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  CupertinoTextField(
                    placeholder: 'Enter product name',
                    onChanged: (value) {
                      _productName = value;
                    },
                  ),
                  const SizedBox(height: 10),

                  // Descripción
                  const Text(
                    'Description',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  CupertinoTextField(
                    placeholder: 'Enter description',
                    onChanged: (value) {
                      _description = value;
                    },
                  ),
                  const SizedBox(height: 10),

                  // Características
                  const Text(
                    'Characteristics',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  CupertinoTextField(
                    placeholder: 'Enter characteristics',
                    onChanged: (value) {
                      _characteristics = value;
                    },
                  ),
                  const SizedBox(height: 10),

                  // Precio
                  const Text(
                    'Price',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  CupertinoTextField(
                    placeholder: 'Enter price',
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      _price = value;
                    },
                  ),
                  const SizedBox(height: 20),
                  // Botón Confirmar
                  CupertinoButton.filled(
                    onPressed: () {
                      if (_formKey.currentState?.validate() ?? false) {
                        _formKey.currentState?.save();
                   
                      }
                    },
                    child: const Text('Confirm Product'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
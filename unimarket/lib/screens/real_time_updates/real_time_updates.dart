import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RealTimeUpdatesScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text('Real-time Item Availability'),
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ),
        body: RealTimeUpdatesBody(),
      ),
    );
  }
}

class RealTimeUpdatesBody extends StatefulWidget {
  @override
  _RealTimeUpdatesBodyState createState() => _RealTimeUpdatesBodyState();
}

class _RealTimeUpdatesBodyState extends State<RealTimeUpdatesBody> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('Product').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        final products = snapshot.data!.docs;

        List<Widget> productWidgets = [];
        for (var product in products) {
          final productName = product['description'];
          final productStatus = product['status'];

          if (productStatus == "Not available") {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('Producto no disponible'),
                  content: Text('El producto $productName no está disponible.'),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text('Aceptar'),
                    ),
                  ],
                ),
              );
            });
          }

          final productWidget = ListTile(
            title: Text(productName),
            subtitle: Text('Status: $productStatus'),
          );

          productWidgets.add(productWidget);
        }

        return ListView(
          children: productWidgets,
        );
      },
    );
  }
}
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:unimarket/data/firebase_dao.dart';

class QrGenerate extends StatefulWidget {
  const QrGenerate({super.key});

  @override
  State<QrGenerate> createState() => _QrGenerateState();
}

class _QrGenerateState extends State<QrGenerate> {
  //Aplica el patrón de DAO
  final FirebaseDAO _firebaseDAO = FirebaseDAO(); 
  Map<String, Map<String, dynamic>>? _productsWithHashes;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    try {
      final productsWithHashes = await _firebaseDAO.getProductsForCurrentSELLER();
      setState(() {
        _productsWithHashes = productsWithHashes;
        _isLoading = false;
      });
    } catch (e) {
      print("Error fetching products: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showQrPopup(String hashConfirm) {
  showCupertinoDialog(
    context: context,
    builder: (context) {
      return CupertinoAlertDialog(
        content: Container(
          color: CupertinoColors.white, 
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min, 
            children: [
              
              SizedBox(
                width: 200, 
                height: 200, 
                child: PrettyQrView.data(
                  data: hashConfirm,
                  errorCorrectLevel: QrErrorCorrectLevel.M,
                ),
              ),
              const SizedBox(height: 20),
              CupertinoButton(
                child: const Text('Close'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text("Generate QR code"),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: _isLoading
              ? const Center(child: CupertinoActivityIndicator())
              : _productsWithHashes == null || _productsWithHashes!.isEmpty
                  ? const Center(child: Text("No products found."))
                  : ListView.builder(
                      itemCount: _productsWithHashes!.length,
                      itemBuilder: (context, index) {
                        final productId = _productsWithHashes!.keys.elementAt(index);
                        final productData = _productsWithHashes![productId]!;
                        final product = productData['product'] as Map<String, dynamic>;
                        final hashConfirm = productData['hashConfirm'] as String;

                        final imageUrls = (product['imageURLs'] as List<dynamic>?) ?? [];
                        final imageUrl = imageUrls.isNotEmpty ? imageUrls[0] as String : null;

                        final title = product['title'] as String? ?? 'No Title';
                        final labels = (product['labels'] as List<dynamic>?) ?? [];

                        return CupertinoListTile(
                          leading: imageUrl != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    imageUrl,
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : null,
                          title: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: labels.isNotEmpty
                              ? Wrap(
                                  spacing: 4,
                                  children: labels
                                      .map((label) => Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: CupertinoColors.systemBlue.withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              label,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: CupertinoColors.systemBlue,
                                              ),
                                            ),
                                          ))
                                      .toList(),
                                )
                              : null,
                          onTap: () {
                            _showQrPopup(hashConfirm);
                          },
                        );
                      },
                    ),
        ),
      ),
    );
  }
}
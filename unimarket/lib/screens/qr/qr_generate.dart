import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:unimarket/data/firebase_dao.dart';
import 'package:unimarket/screens/ble_scan/seller_ble_advertiser.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'dart:convert';
import 'dart:typed_data';

class QrGenerate extends StatefulWidget {
  const QrGenerate({super.key});

  @override
  State<QrGenerate> createState() => _QrGenerateState();
}

class _QrGenerateState extends State<QrGenerate> {
  //Aplica el patrón de DAO
  final FirebaseDAO _firebaseDAO = FirebaseDAO(); 
  final SellerBLEAdvertiser _sellerBLEAdvertiser = SellerBLEAdvertiser();
  //Vaina nueva para poder usar el cache
  final cache = DefaultCacheManager();
  
  Map<String, Map<String, dynamic>>? _productsWithHashes;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
  const llaveCache = 'qr_productos';
  try {
    final fileInfo = await cache.getFileFromCache(llaveCache);
    if (fileInfo != null) {
      print("Fetched products successfully from cache!");
      //Como el Cache Manager administra todo como archivos JSON, 
      //Es necesario hacerle transformaciones
      final file = fileInfo.file;
      final jsonStr = await file.readAsString();
      final decoded = json.decode(jsonStr) as Map<String, dynamic>;
      //Paso final, debería funcionar igual
      final cachedMap = decoded.map((key, value) =>
        MapEntry(key, Map<String, dynamic>.from(value as Map)));

      setState(() {
        _productsWithHashes = cachedMap;
        _isLoading = false;
      });

      print("Loaded products from cache");
      return;
    }

    // Si no funciona el cache, ir por la de firebase
    final productsWithHashes = await _firebaseDAO.getProductsForCurrentSELLER();
    final jsonString = json.encode(productsWithHashes);
    final bytes = Uint8List.fromList(utf8.encode(jsonString));
    //Se manda a cache el archivo json creado, debería funcionar ojala
    await cache.putFile(llaveCache, bytes);

    setState(() {
      _productsWithHashes = productsWithHashes;
      _isLoading = false;
    });

    print("Fetched products from firebase, successfully cached them all");
  } catch (e) {
    print("Error fetching products: $e");
    setState(() {
      _isLoading = false;
    });
  }
}

  void _showQrPopup(String hashConfirm) {
    
    _sellerBLEAdvertiser.startAdvertising();

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
                    
                    _sellerBLEAdvertiser.stopAdvertising();
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
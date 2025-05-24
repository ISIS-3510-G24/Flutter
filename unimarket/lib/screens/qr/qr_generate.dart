import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:unimarket/data/firebase_dao.dart';
import 'package:unimarket/screens/ble_scan/seller_ble_advertiser.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:unimarket/theme/app_colors.dart';

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
  bool _isConnected = true;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  void _showNoConnectionPopup() {
  showCupertinoDialog(
    context: context,
    builder: (_) => CupertinoAlertDialog(
      title: const Text("Connection Error"),
      content: const Text("Sorry, there is no active internet connection. Please try again."),
      actions: [
        CupertinoDialogAction(
          child: const Text("OK"),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    ),
  );
}


  Future<void> _fetchProducts() async {
  const cacheKey = 'qr_productos';
  
  try {
    // 1. Primero se intenta hacer el fetch de firebase
    final productsWithHashes = await _firebaseDAO.getProductsForCurrentSELLER();

    // 2. si se obtiene, se transforman las ordenes en un hasmap cacheable
    final cacheableData = _convertFirestoreData(productsWithHashes);

    // 3. Almacenar en cache usando DefaultCacheManager
    await _storeInCache(cacheKey, cacheableData);
    if (mounted) {
      setState(() {
        _productsWithHashes = productsWithHashes;
        _isLoading = false;
        _isConnected = true;
      });
    }

    debugPrint("Successfully fetched products from Firebase");
  } catch (e) {
    debugPrint("Error fetching from Firebase: $e");
    await _handleFetchError(cacheKey);
  }
}

// Transformación de datos de las ordenes a un hashmap cacheable
Map<String, dynamic> _convertFirestoreData(Map<String, dynamic> originalData) {
  return originalData.map((key, value) {
    // Handle nested conversion
    dynamic convertValue(dynamic v) {
      if (v == null) return null;
      if (v is Timestamp) {
        return v.toDate().toIso8601String(); // ISO format for dates
      } else if (v is Map) {
        return v.map((k, v) => MapEntry(k, convertValue(v)));
      } else if (v is List) {
        return v.map((e) => convertValue(e)).toList();
      }
      return v;
    }

    return MapEntry(key, convertValue(value));
  });
}

// Helper method to store data in cache
Future<void> _storeInCache(String key, Map<String, dynamic> data) async {
  try {
    final jsonString = json.encode(data);
    final bytes = Uint8List.fromList(utf8.encode(jsonString));
    await cache.putFile(key, bytes);
  } catch (e) {
    debugPrint("Error storing in cache: $e");
    rethrow; // Re-throw to trigger fallback
  }
}

// Helper method to handle errors and fallback to cache
Future<void> _handleFetchError(String cacheKey) async {
    try {
      debugPrint("Attempting to load from cache...");
      final fileInfo = await cache.getFileFromCache(cacheKey);
      
      if (fileInfo != null) {
        final jsonStr = await fileInfo.file.readAsString();
        final decoded = json.decode(jsonStr) as Map<String, dynamic>;

        if (mounted) {
          setState(() {
            _productsWithHashes = decoded.cast<String, Map<String, dynamic>>();
            _isLoading = false;
            _isConnected = false; 
          });
          _showOfflineSuccessPopup();
        }
        debugPrint("Loaded products from cache");
        return;
      }
    } catch (cacheError) {
      debugPrint("Cache read error: $cacheError");
    }

    if (mounted) {
      setState(() {
        _productsWithHashes = null;
        _isLoading = false;
        _isConnected = false; 
      });
      _showNoConnectionPopup();
    }
  }
  void _showOfflineSuccessPopup() {
  showCupertinoDialog(
    context: context,
    builder: (context) => CupertinoAlertDialog(
      title: const Text("Offline Mode"),
      content: const Text("You are offline. Newer product sales will not be shown until you're back online."),
      actions: [
        CupertinoDialogAction(
          child: const Text("OK"),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    ),
  );
}

   /*Future<void> _onRefresh() async {
    setState(() {
      _isLoading = true;
    });
    await _fetchProducts();
  }*/

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
      navigationBar: const CupertinoNavigationBar(
        middle: Text("Generate QR code to validate your transaction"),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Add the banner here
            if (!_isConnected)
  Container(
    width: double.infinity,
    color: CupertinoColors.systemYellow.withOpacity(0.3),
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
    child: Row(
      children: [
        const Icon(
          CupertinoIcons.exclamationmark_triangle,
          size: 16,
          color: CupertinoColors.systemYellow,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            "You are offline. Shown orders may be outdated.",
            style: GoogleFonts.inter(
              fontSize: 12,
              color: CupertinoColors.systemGrey,
            ),
          ),
        ),
        CupertinoButton(
          padding: EdgeInsets.zero,
          minSize: 0,
          onPressed: () async {
            // Call the same function as the refresh control
            await _fetchProducts();
            // Optional: Show a brief loading indicator
            setState(() {});
          },
          child: Text(
            "Retry",
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.primaryBlue,
            ),
          ),
        ),
      ],
    ),
  ),
Expanded(
  child: _isLoading
      ? const Center(child: CupertinoActivityIndicator())
      : _productsWithHashes == null
          ? const Center(child: Text("Failed to load products"))
          : CustomScrollView(
              slivers: [
                CupertinoSliverRefreshControl(
                  onRefresh: _fetchProducts, // Same function as Retry
                ),
                SliverPadding(
                    padding: const EdgeInsets.all(10),
                    sliver: (_productsWithHashes != null && _productsWithHashes!.isEmpty)
                        ? const SliverFillRemaining(
                            child: Center(child: Text("No products found.")),
                          )
                        : SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
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
                                  onTap: () => _showQrPopup(hashConfirm),
                                );
                              },
                              childCount: _productsWithHashes!.length,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ]
        ),
      ),
    );
  }

}
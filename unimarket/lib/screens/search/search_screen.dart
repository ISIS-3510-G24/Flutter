// lib/screens/search/search_screen.dart
import 'dart:async';

import 'package:unimarket/services/connectivity_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unimarket/models/product_model.dart';
import 'package:unimarket/screens/search/algolia_image_widget.dart';
import 'package:unimarket/services/algolia_service.dart';
import 'package:unimarket/screens/product/product_detail_screen.dart';
import 'package:unimarket/theme/app_colors.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  _SearchScreenState createState() => _SearchScreenState();
}
class _SearchScreenState extends State<SearchScreen> {
  final AlgoliaService _algoliaService = AlgoliaService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final ConnectivityService _connectivityService = ConnectivityService();
  final int _maxSearchLength = 100; // Límite máximo de caracteres
  
  List<ProductModel> _searchResults = [];
  List<String> _searchHistory = [];
  bool _isLoading = false;
  bool _isSearching = false;
  bool _hasNoInternet = false;
  int _currentLength = 0; // Para mostrar el contador
  StreamSubscription? _connectivitySubscription;
  
  @override
  void initState() {
    super.initState();
    _loadSearchHistory();
    
    // Agregar listener para el contador de caracteres
    _searchController.addListener(_updateCharCount);
    
    // Escuchar cambios de conectividad
    _connectivitySubscription = _connectivityService.connectivityStream.listen((hasInternet) {
      setState(() {
        _hasNoInternet = !hasInternet;
      });
    });
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_searchFocus);
    });
  }
  
  void _updateCharCount() {
    setState(() {
      _currentLength = _searchController.text.length;
    });
  }
  
  @override
  void dispose() {
    _searchController.removeListener(_updateCharCount);
    _searchController.dispose();
    _searchFocus.dispose();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadSearchHistory() async {
    final history = await _algoliaService.getSearchHistory();
    setState(() {
      _searchHistory = history;
    });
  }
Future<void> _performSearch(String query) async {
   // Validar longitud antes de procesar
  if (query.length > _maxSearchLength) {
    _showSearchTooLongAlert();
    return;
  }
  
  if (query.trim().isEmpty) {
    setState(() {
      _searchResults = [];
      _isSearching = false;
    });
    return;
  }
  
  
  // Siempre añadir la búsqueda al historial, independientemente del resultado
  await _algoliaService.addSearchToHistory(query);
  
  setState(() {
    _isLoading = true;
    _isSearching = true;
  });
  
  // Añadir un timeout para evitar carga infinita
  Timer loadingTimeout = Timer(Duration(seconds: 8), () {
    if (_isLoading) {
      setState(() {
        _isLoading = false;
        _hasNoInternet = true;
      });
    }
  });
  
  try {
    // Verificar conectividad explícitamente
    bool isConnected = await _connectivityService.checkConnectivity();
    
    if (!isConnected) {
      // No hay conexión a internet
      setState(() {
        _searchResults = [];
        _isLoading = false;
        _hasNoInternet = true;
      });
      _loadSearchHistory(); // Refrescar historial incluso sin conexión
      return;
    }
    
    // Si hay conexión, realizar la búsqueda
    final results = await _algoliaService.searchProducts(query)
        .timeout(Duration(seconds: 5), onTimeout: () {
          throw Exception('Search timed out');
        });
    
    setState(() {
      _searchResults = results;
      _isLoading = false;
      _hasNoInternet = false;
    });
    _loadSearchHistory();
  } catch (e) {
    print("Error en búsqueda: $e");
    
    setState(() {
      _searchResults = [];
      _isLoading = false;
      _hasNoInternet = true;
    });
    _loadSearchHistory(); // Refrescar historial incluso con error
  } finally {
    // Asegurarse de cancelar el timeout
    loadingTimeout.cancel();
  }
}
  String _formatPrice(double price) {
    final whole = price.toInt().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < whole.length; i++) {
      buffer.write(whole[i]);
      final pos = whole.length - 1 - i;
      if (pos % 3 == 0 && i < whole.length - 1) buffer.write('.');
    }
    return '${buffer.toString()} \$';
  }
void _showSearchTooLongAlert() {
  showCupertinoDialog(
    context: context,
    builder: (context) => CupertinoAlertDialog(
      title: Text("Search Too Long"),
      content: Text("Please reduce the length of your search. Searches are limited to 100 characters."),
      actions: [
        CupertinoDialogAction(
          child: Text("OK"),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    ),
  );
}
@override
Widget build(BuildContext context) {
  return CupertinoPageScaffold(
    navigationBar: CupertinoNavigationBar(
      middle: CupertinoSearchTextField(
        controller: _searchController,
        focusNode: _searchFocus,
        placeholder: "Search products...",
        onSubmitted: _performSearch,
        onChanged: (v) {
          if (v.isEmpty) setState(() => _isSearching = false);
          
          // Limitar la longitud del texto
          if (v.length > _maxSearchLength) {
            _searchController.text = v.substring(0, _maxSearchLength);
            _searchController.selection = TextSelection.fromPosition(
              TextPosition(offset: _maxSearchLength)
            );
          }
        },
      ),
      leading: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () => Navigator.pop(context),
        child: const Icon(CupertinoIcons.back, color: AppColors.primaryBlue),
      ),
      // Agregar trailing con el contador
      trailing: Text(
        "$_currentLength/$_maxSearchLength",
        style: GoogleFonts.inter(
          fontSize: 10, 
          color: _currentLength >= _maxSearchLength 
            ? CupertinoColors.systemRed 
            : CupertinoColors.systemGrey
        ),
      ),
    ),
    child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _isSearching
                  ? _buildSearchResults()
                  : _buildSearchHistory(),
            ),
          ],
        ),
      ),
    );
  }

Widget _buildSearchResults() {
  if (_isLoading) {
    return const Center(child: CupertinoActivityIndicator());
  }
  
  if (_hasNoInternet) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(CupertinoIcons.wifi_slash, 
                    size: 50, 
                    color: CupertinoColors.systemGrey),
          const SizedBox(height: 16),
          Text("No internet connection",
              style: GoogleFonts.inter(
                fontSize: 16, 
                color: CupertinoColors.systemGrey)),
          const SizedBox(height: 8),
          Text("Check your connection and try again",
              style: GoogleFonts.inter(
                fontSize: 14, 
                color: CupertinoColors.systemGrey)),
          const SizedBox(height: 16),
          CupertinoButton(
            child: Text("Retry",
                style: GoogleFonts.inter(
                  color: AppColors.primaryBlue,
                  fontWeight: FontWeight.w600)),
            onPressed: () async {
              setState(() => _isLoading = true);
              bool hasInternet = await _connectivityService.checkConnectivity();
              if (hasInternet && _searchController.text.isNotEmpty) {
                _performSearch(_searchController.text);
              } else {
                setState(() {
                  _isLoading = false;
                  _hasNoInternet = !hasInternet;
                });
              }
            },
          ),
        ],
      ),
    );
  }
  
  if (_searchResults.isEmpty) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(CupertinoIcons.search, 
                    size: 50, 
                    color: CupertinoColors.systemGrey),
          const SizedBox(height: 16),
          Text("No products found",
              style: GoogleFonts.inter(
                fontSize: 16, 
                color: CupertinoColors.systemGrey)),
        ],
      ),
    );
  }

    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, childAspectRatio: 0.9, crossAxisSpacing: 10, mainAxisSpacing: 10,
      ),
      itemCount: _searchResults.length,
      itemBuilder: (ctx, i) {
        final p = _searchResults[i];
        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            CupertinoPageRoute(builder: (_) => ProductDetailScreen(product: p)),
          ),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: CupertinoColors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [BoxShadow(color: CupertinoColors.systemGrey4, blurRadius: 5, spreadRadius: 1)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ProductImageWidget(
                    imageUrls: p.imageUrls,
                    borderRadius: BorderRadius.circular(10),
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
                const SizedBox(height: 10),
                Text(p.title,
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(_formatPrice(p.price),
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchHistory() {
    if (_searchHistory.isEmpty) {
      return Center(
        child: Text("No recent searches",
            style: GoogleFonts.inter(fontSize: 16, color: CupertinoColors.systemGrey)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Recent Searches",
                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () async {
                  await _algoliaService.clearSearchHistory();
                  _loadSearchHistory();
                },
                child: Text("Clear",
                    style: GoogleFonts.inter(
                        fontSize: 14, color: AppColors.primaryBlue, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _searchHistory.length,
            itemBuilder: (ctx, i) {
              final q = _searchHistory[i];
              return CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () {
                  _searchController.text = q;
                  _performSearch(q);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: CupertinoColors.systemGrey5, width: 1)),
                  ),
                  child: Row(
                    children: [
                      const Icon(CupertinoIcons.clock, size: 18, color: CupertinoColors.systemGrey),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(q,
                            style: GoogleFonts.inter(fontSize: 16, color: CupertinoColors.black)),
                      ),
                      Icon(CupertinoIcons.forward, size: 18, color: CupertinoColors.systemGrey),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

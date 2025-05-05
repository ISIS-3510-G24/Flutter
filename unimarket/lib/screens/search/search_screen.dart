// lib/screens/search/search_screen.dart

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

  List<ProductModel> _searchResults = [];
  List<String> _searchHistory = [];
  bool _isLoading = false;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadSearchHistory();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_searchFocus);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _loadSearchHistory() async {
    final history = await _algoliaService.getSearchHistory();
    setState(() {
      _searchHistory = history;
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _isSearching = true;
    });
    final results = await _algoliaService.searchProducts(query);
    setState(() {
      _searchResults = results;
      _isLoading = false;
    });
    _loadSearchHistory();
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
          },
        ),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.pop(context),
          child: const Icon(CupertinoIcons.back, color: AppColors.primaryBlue),
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
    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(CupertinoIcons.search, size: 50, color: CupertinoColors.systemGrey),
            const SizedBox(height: 16),
            Text("No products found",
                style: GoogleFonts.inter(fontSize: 16, color: CupertinoColors.systemGrey)),
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

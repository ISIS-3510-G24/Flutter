import 'package:unimarket/widgets/dropdowns/custom_dropdown_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unimarket/screens/upload/confirm_product_screen.dart';
import 'package:unimarket/screens/find_and_offer_screens/find_screen.dart';
import 'package:unimarket/models/find_model.dart';
import 'package:unimarket/models/offer_model.dart';
import 'package:unimarket/services/find_service.dart';

import 'package:unimarket/theme/app_colors.dart';

class FindAndOfferScreen extends StatefulWidget {
  const FindAndOfferScreen({Key? key}) : super(key: key);

  @override
  State<FindAndOfferScreen> createState() => _FindAndOfferScreenState();
}

class _FindAndOfferScreenState extends State<FindAndOfferScreen> {
  String _selectedCategory = "All requests"; 
  final FindService _findService = FindService();
  List<FindModel> _finds = [];
  bool _isLoading = true;
  final List<Map<String, String>> _wishlistItems = [
    {"title": "Wishlist Item 1", "subtitle": "Description 1"},
    {"title": "Wishlist Item 2", "subtitle": "Description 2"},
  ];
  final List<Map<String, String>> _sellingItems = [
    {"title": "Selling Item 1", "subtitle": "Description 1"},
    {"title": "Selling Item 2", "subtitle": "Description 2"},
  ];

  @override
  void initState() {
    super.initState();
    _loadFinds();
  }

  Future<void> _loadFinds() async {
    try {
      final finds = await _findService.getFind();
      setState(() {
        _finds = finds;
        _isLoading = false;
      });
    } catch (e) {
      print("Error fetching finds: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          "Find & Offer",
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            // ---- CONTENIDO PRINCIPAL SCROLLEABLE ----
            Positioned.fill(
              child: _isLoading
                  ? const Center(child: CupertinoActivityIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 80),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTopRow(),
                          // “From your major”
                          _buildSectionHeader(
                            title: "All",
                            onSeeMore: () => debugPrint("See more: All"),
                          ),
                          _buildMajorHorizontalList(),

                          // “Your wishlist”
                          _buildSectionHeader(
                            title: "Your wishlist",
                            onSeeMore: () => debugPrint("See more: Your wishlist"),
                          ),
                          _buildVerticalList(_wishlistItems, showBuyButton: false),

                          // “Selling out”
                          _buildSectionHeader(
                            title: "Selling out",
                            onSeeMore: () => debugPrint("See more: Selling out"),
                          ),
                          _buildVerticalList(_sellingItems, showBuyButton: true),
                        ],
                      ),
                    ),
            ),

            // ---- BOTÓN FLOTANTE ----
            Positioned(
              right: 20,
              bottom: 20,
              child: CupertinoButton(
                color: AppColors.primaryBlue,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                borderRadius: BorderRadius.circular(30),
                child: Text(
                  "New Offer",
                  style: GoogleFonts.inter(
                    color: CupertinoColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    CupertinoPageRoute(
                      builder: (ctx) => const ConfirmProductScreen(
                        postType: "offer",
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// TOP ROW: Botón circular "All requests" e ícono Search
  Widget _buildTopRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          // Botón circular "All requests"
          _buildAllRequestsButton(),
          const SizedBox(width: 12),

          // Ícono de búsqueda
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _showSearchModal,
            child: const Icon(
              CupertinoIcons.search,
              size: 26,
              color: AppColors.primaryBlue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllRequestsButton() {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () {
        // No hacemos nada
        showCustomDropdownPicker(
          context,
          selectedCategory: _selectedCategory,
        );
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.primaryBlue,
        ),
        child: const Icon(
          CupertinoIcons.list_bullet,
          color: CupertinoColors.white,
          size: 20,
        ),
      ),
    );
  }

  /// Header de sección con “See more”
  Widget _buildSectionHeader({
    required String title,
    required VoidCallback onSeeMore,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              )),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: onSeeMore,
            child: Text(
              "See more",
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.primaryBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Lista horizontal (From your major)
  Widget _buildMajorHorizontalList() {
    return SizedBox(
      height: 210,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _finds.isNotEmpty ? _finds.length : 5, // Mostrar 5 tarjetas vacías si no hay datos
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          if (_finds.isNotEmpty) {
            final find = _finds[index];
            return FutureBuilder<List<OfferModel>>(
              future: _findService.getOffersForFind(find.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CupertinoActivityIndicator());
                }
                if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                  return _buildMajorCard(find, null);
                }
                final offer = snapshot.data!.first;
                return _buildMajorCard(find, offer);
              },
            );
          } else {
            return _buildEmptyCard();
          }
        },
      ),
    );
  }

  /// Tarjeta horizontal
  Widget _buildMajorCard(FindModel find, OfferModel? offer) {
    return Container(
      width: 160,
      height: 210,
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ícono por defecto
          Container(
            height: 100,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.lightGreyBackground,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: const Icon(
              CupertinoIcons.photo,
              size: 50,
              color: CupertinoColors.systemGrey,
            ),
          ),
          // Etiqueta de fecha
          if (find.timestamp != null)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  "${find.timestamp.month}/${find.timestamp.day}",
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ),
            ),
          // Título y subtítulo
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              find.id,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              offer?.description ?? find.description,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: CupertinoColors.systemGrey,
              ),
            ),
          ),
          // Botones “Find” y “Offer”
          Padding(
            padding: const EdgeInsets.all(2.0), // Reducir el padding
            child: Row(
              children: [
                Expanded(
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2), // Reducir el padding
                    color: AppColors.primaryBlue,
                    borderRadius: BorderRadius.circular(30),
                    onPressed: () {
                      Navigator.push(
                        context,
                        CupertinoPageRoute(
                          builder: (ctx) => FindsScreen(
                            find: find,
                          ),
                        ),
                      );
                    },
                    child: Text(
                      "Find",
                      style: GoogleFonts.inter(
                        fontSize: 8, // Reducir el tamaño de la fuente
                        color: CupertinoColors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 2), // Reducir el espacio entre los botones
                Expanded(
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2), // Reducir el padding
                    color: AppColors.primaryBlue,
                    borderRadius: BorderRadius.circular(30),
                    onPressed: () {
                      Navigator.push(
                        context,
                        CupertinoPageRoute(
                          builder: (ctx) => const ConfirmProductScreen(
                            postType: "offer",
                          ),
                        ),
                      );
                    },
                    child: Text(
                      "Offer",
                      style: GoogleFonts.inter(
                        fontSize: 8, // Reducir el tamaño de la fuente
                        color: CupertinoColors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Tarjeta vacía
  Widget _buildEmptyCard() {
    return Container(
      width: 160,
      height: 210,
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ícono por defecto
          Container(
            height: 100,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.lightGreyBackground,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: const Icon(
              CupertinoIcons.photo,
              size: 50,
              color: CupertinoColors.systemGrey,
            ),
          ),
          // Etiqueta de fecha
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                "N/A",
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: AppColors.primaryBlue,
                ),
              ),
            ),
          ),
          // Título y subtítulo
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              "N/A",
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              "N/A",
              style: GoogleFonts.inter(
                fontSize: 12,
                color: CupertinoColors.systemGrey,
              ),
            ),
          ),
          // Botones “Find” y “Offer”
          Padding(
            padding: const EdgeInsets.all(2.0), // Reducir el padding
            child: Row(
              children: [
                Expanded(
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2), // Reducir el padding
                    color: AppColors.primaryBlue,
                    borderRadius: BorderRadius.circular(30),
                    onPressed: () {},
                    child: Text(
                      "Find",
                      style: GoogleFonts.inter(
                        fontSize: 8, // Reducir el tamaño de la fuente
                        color: CupertinoColors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 2), // Reducir el espacio entre los botones
                Expanded(
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2), // Reducir el padding
                    color: AppColors.primaryBlue,
                    borderRadius: BorderRadius.circular(30),
                    onPressed: () {},
                    child: Text(
                      "Offer",
                      style: GoogleFonts.inter(
                        fontSize: 8, // Reducir el tamaño de la fuente
                        color: CupertinoColors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Lista vertical (Your wishlist / Selling out)
  Widget _buildVerticalList(
    List<Map<String, String>> items, {
    bool showBuyButton = false,
  }) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      itemBuilder: (ctx, index) {
        final item = items[index];
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: CupertinoColors.systemGrey6,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              // Ícono por defecto
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.transparentGrey,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  CupertinoIcons.photo,
                  color: CupertinoColors.white,
                ),
              ),
              const SizedBox(width: 10),
              // Texto
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item["title"] ?? "",
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      item["subtitle"] ?? "",
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: CupertinoColors.systemGrey,
                      ),
                    ),
                  ],
                ),
              ),
              // Botón “Buy” o flecha
              if (showBuyButton)
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  color: AppColors.primaryBlue,
                  borderRadius: BorderRadius.circular(20),
                  onPressed: () => debugPrint("Buy ${item["title"]}"),
                  child: Text(
                    "Buy",
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: CupertinoColors.white,
                    ),
                  ),
                )
              else ...[
                const SizedBox(width: 8),
                const Icon(
                  CupertinoIcons.chevron_forward,
                  color: CupertinoColors.systemGrey,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // Muestra un modal con un campo de búsqueda
  void _showSearchModal() {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) {
        return Container(
          color: CupertinoColors.systemBackground,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CupertinoSearchTextField(),
            ],
          ),
        );
      },
    );
  }
}
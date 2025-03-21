import 'package:unimarket/widgets/dropdowns/custom_dropdown_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unimarket/screens/upload/confirm_product_screen.dart';
import 'package:unimarket/screens/find_and_offer_screens/find_screen.dart';
import 'package:unimarket/models/find_model.dart';
import 'package:unimarket/models/offer_model.dart';
import 'package:unimarket/services/find_service.dart';
import 'package:unimarket/screens/upload/create_offer_screen.dart';
import 'package:unimarket/theme/app_colors.dart';

class FindAndOfferScreen extends StatefulWidget {
  const FindAndOfferScreen({Key? key}) : super(key: key);

  @override
  State<FindAndOfferScreen> createState() => _FindAndOfferScreenState();
}

// 1. Primero, actualiza la clase _FindAndOfferScreenState para añadir las nuevas variables:

class _FindAndOfferScreenState extends State<FindAndOfferScreen> {
  String _selectedCategory = "All requests"; 
  final FindService _findService = FindService();
  List<FindModel> _finds = [];
  List<FindModel> _majorFinds = []; // Nueva lista para finds por major
  String? _userMajor; // Para almacenar el major del usuario
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
    _loadUserDataAndFinds(); // Nuevo método
  }

  // 2. Nuevo método para cargar el major del usuario y luego los finds
  Future<void> _loadUserDataAndFinds() async {
    try {
      // Primero obtenemos el major del usuario
      final major = await _findService.getCurrentUserMajor();
      setState(() {
        _userMajor = major;
      });
      
      print("User major: $_userMajor");
      
      // Ahora cargamos los finds
      _loadFinds();
    } catch (e) {
      print("Error loading user data: $e");
      // Continuamos cargando los finds incluso si no pudimos obtener el major
      _loadFinds();
    }
  }

  // 3. Modifica el método _loadFinds para que también cargue los finds por major
  Future<void> _loadFinds() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Cargamos todos los finds
      final finds = await _findService.getFind();
      
      // Cargamos los finds por major si el usuario tiene un major asignado
      List<FindModel> majorFinds = [];
      if (_userMajor != null && _userMajor!.isNotEmpty) {
        majorFinds = await _findService.getFindsByMajor(_userMajor!);
        print("Loaded ${majorFinds.length} finds from user's major: $_userMajor");
      }
      
      setState(() {
        _finds = finds;
        _majorFinds = majorFinds;
        _isLoading = false;
      });
      
      print("Loaded ${finds.length} total finds successfully");
      
    } catch (e) {
      print("Error fetching finds: $e");
      
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text("Error"),
            content: const Text("Failed to load data. Please try again later."),
            actions: [
              CupertinoDialogAction(
                child: const Text("OK"),
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
      }
      
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 4. Nuevo método para construir la sección "From your major"
  Widget _buildFromMajorSection() {
    if (_majorFinds.isEmpty) {
      // Si no hay finds del major del usuario, mostramos los items por defecto
      return _buildVerticalList(_wishlistItems, showBuyButton: false);
    }
    
    // Convertimos los finds a un formato similar a los items de _wishlistItems
    final List<Map<String, String>> majorItems = _majorFinds.map((find) {
      return {
        "title": find.title,
        "subtitle": find.description,
        "id": find.id,
        "image": find.image,
      };
    }).toList();
    
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: majorItems.length > 2 ? 2 : majorItems.length, // Mostrar máximo 2 items
      itemBuilder: (ctx, index) {
        final item = majorItems[index];
        final find = _majorFinds[index]; // Obtener el find original
        
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: CupertinoColors.systemGrey6,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              // Imagen o icono por defecto
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.transparentGrey,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: find.image.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          find.image,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            CupertinoIcons.photo,
                            color: CupertinoColors.white,
                          ),
                        ),
                      )
                    : const Icon(
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
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Flecha de navegación
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    CupertinoPageRoute(
                      builder: (ctx) => CreateOfferScreen(findId: find.id)
                      ),
                  );
                },
                child: const Icon(
                  CupertinoIcons.chevron_forward,
                  color: CupertinoColors.systemGrey,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 5. Actualiza el método build para usar _buildFromMajorSection
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
                          // "All" section
                          _buildSectionHeader(
                            title: "All",
                            onSeeMore: () => debugPrint("See more: All"),
                          ),
                          _buildMajorHorizontalList(),

                          // "From your major" section - Actualizada
                          _buildSectionHeader(
                            title: "From your major",
                            onSeeMore: () => debugPrint("See more: From your major"),
                          ),
                          _buildFromMajorSection(), // Usando el nuevo método

                          // "Most popular" section
                          _buildSectionHeader(
                            title: "Most popular",
                            onSeeMore: () => debugPrint("See more: Most popular"),
                          ),
                          _buildMostPopularList(),
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
                  "New Find",
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

// Este widget se mostrará cuando no haya ofertas para un find

Widget _buildNoOffersWidget() {
  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: CupertinoColors.systemGrey6,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: AppColors.primaryBlue.withOpacity(0.3),
        width: 1,
      ),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          CupertinoIcons.info_circle,
          color: AppColors.primaryBlue,
          size: 40,
        ),
        const SizedBox(height: 12),
        Text(
          "No hay ofertas todavía",
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: CupertinoColors.darkBackgroundGray,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Sé el primero en hacer una oferta para este producto.",
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: CupertinoColors.systemGrey,
          ),
        ),
        const SizedBox(height: 16),
        CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          color: AppColors.primaryBlue,
          borderRadius: BorderRadius.circular(20),
          onPressed: () {
            // Navegar a la pantalla de crear oferta
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
            "Hacer una oferta",
            style: GoogleFonts.inter(
              fontSize: 14,
              color: CupertinoColors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _buildMostPopularList() {
  // If finds list is empty, show default items
  if (_finds.isEmpty) {
    return _buildVerticalList(_sellingItems, showBuyButton: true);
  }

  // Sort finds by upvoteCount in descending order
  final sortedFinds = List<FindModel>.from(_finds)
    ..sort((a, b) => b.upvoteCount.compareTo(a.upvoteCount));

  // Take the top 2 items or less if not enough items
  final topItems = sortedFinds.take(2).toList();
  
  // Create a list of items to display
  final List<Map<String, String>> popularItems = topItems.map((find) {
    return {
      "title": find.title,
      "subtitle": find.description,
      "upvotes": find.upvoteCount.toString(),
    };
  }).toList();

  return ListView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: popularItems.length,
    itemBuilder: (ctx, index) {
      final item = popularItems[index];
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: CupertinoColors.systemGrey6,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            // Try to get the find by matching title
            Builder(
              builder: (context) {
                final find = topItems[index];
                return Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.transparentGrey,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: find.image.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            find.image,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => const Icon(
                              CupertinoIcons.photo,
                              color: CupertinoColors.white,
                            ),
                          ),
                        )
                      : const Icon(
                          CupertinoIcons.photo,
                          color: CupertinoColors.white,
                        ),
                );
              }
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    "Upvotes: ${item["upvotes"]}",
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.primaryBlue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            // "Buy" button
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
            ),
          ],
        ),
      );
    },
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

 Widget _buildMajorHorizontalList() {
  return SizedBox(
    height: 200, // Updated height to match card height
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

Widget _buildMajorCard(FindModel find, OfferModel? offer) {
  return Container(
    width: 160,
    height: 200, // Fixed height
    decoration: BoxDecoration(
      color: CupertinoColors.systemGrey6,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Image or default icon
        Container(
          height: 90, // Reduced height
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.lightGreyBackground,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: find.image.isNotEmpty
              ? ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: Image.network(
                    find.image,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      CupertinoIcons.photo,
                      size: 40, // Smaller icon
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                )
              : const Icon(
                  CupertinoIcons.photo,
                  size: 40, // Smaller icon
                  color: CupertinoColors.systemGrey,
                ),
        ),
        
        // Date label
        if (find.timestamp != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 8), // Reduced padding
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), // Smaller padding
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                "${find.timestamp.month}/${find.timestamp.day}",
                style: GoogleFonts.inter(
                  fontSize: 9, // Smaller font
                  color: AppColors.primaryBlue,
                ),
              ),
            ),
          ),
          
        // Title
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), // Reduced padding
          child: Text(
            find.title, // Using title instead of id
            style: GoogleFonts.inter(
              fontSize: 12, // Smaller font
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        
        // Description
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1), // Reduced padding
          child: Text(
            offer?.description ?? find.description,
            style: GoogleFonts.inter(
              fontSize: 10, // Smaller font
              color: CupertinoColors.systemGrey,
            ),
            maxLines: 1, // Reducido a 1 línea para dejar más espacio a los botones
            overflow: TextOverflow.ellipsis,
          ),
        ),
        
        // Spacer to push buttons to bottom
        const Spacer(),
        
        // Buttons "Find" and "Offer" at the bottom of the card
        Padding(
          padding: const EdgeInsets.only(left: 4, right: 4, bottom: 8, top: 2), // Adjust padding
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 30, // Increased height for button
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0), // Minimal padding
                    color: AppColors.primaryBlue,
                    borderRadius: BorderRadius.circular(20),
                    minSize: 20, // Smaller minimum size
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
                        fontSize: 12, // Increased font size (was 8)
                        fontWeight: FontWeight.w600, // Added bold
                        color: CupertinoColors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4), // Slightly wider gap
              Expanded(
                child: SizedBox(
                  height: 30, // Increased height for button
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0), // Minimal padding
                    color: AppColors.primaryBlue,
                    borderRadius: BorderRadius.circular(20),
                    minSize: 20, // Smaller minimum size
                    onPressed: () {
                      Navigator.push(
                        context,
                        CupertinoPageRoute(
                          builder: (ctx) => CreateOfferScreen(findId: find.id)
                        ),
                      );
                    },
                    child: Text(
                      "Offer",
                      style: GoogleFonts.inter(
                        fontSize: 12, // Increased font size (was 8)
                        fontWeight: FontWeight.w600, // Added bold
                        color: CupertinoColors.white,
                      ),
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

 Widget _buildEmptyCard() {
  return Container(
    width: 160,
    height: 200, // Reduced height to match other cards
    decoration: BoxDecoration(
      color: CupertinoColors.systemGrey6,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Ícono por defecto
        Container(
          height: 90, // Reduced height
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.lightGreyBackground,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: const Icon(
            CupertinoIcons.photo,
            size: 40, // Smaller icon
            color: CupertinoColors.systemGrey,
          ),
        ),
        // Etiqueta de fecha
        Padding(
          padding: const EdgeInsets.only(top: 4, left: 8), // Reduced padding
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), // Smaller padding
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              "N/A",
              style: GoogleFonts.inter(
                fontSize: 9, // Smaller font
                color: AppColors.primaryBlue,
              ),
            ),
          ),
        ),
        // Título
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), // Reduced padding
          child: Text(
            "N/A",
            style: GoogleFonts.inter(
              fontSize: 12, // Smaller font
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        // Subtítulo
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1), // Reduced padding
          child: Text(
            "N/A",
            style: GoogleFonts.inter(
              fontSize: 10, // Smaller font
              color: CupertinoColors.systemGrey,
            ),
          ),
        ),
        
        // Spacer to push buttons to bottom
        const Spacer(),
        
        // Botones "Find" y "Offer" at the bottom
        Padding(
          padding: const EdgeInsets.only(left: 4, right: 4, bottom: 8, top: 2), // Adjust padding
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 24, // Fixed height for button
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0), // Minimal padding
                    color: AppColors.primaryBlue,
                    borderRadius: BorderRadius.circular(20),
                    minSize: 20, // Smaller minimum size
                    onPressed: () {},
                    child: Text(
                      "Find",
                      style: GoogleFonts.inter(
                        fontSize: 8, // Small font
                        color: CupertinoColors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Expanded(
                child: SizedBox(
                  height: 24, // Fixed height for button
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0), // Minimal padding
                    color: AppColors.primaryBlue,
                    borderRadius: BorderRadius.circular(20),
                    minSize: 20, // Smaller minimum size
                    onPressed: () {},
                    child: Text(
                      "Offer",
                      style: GoogleFonts.inter(
                        fontSize: 8, // Small font
                        color: CupertinoColors.white,
                      ),
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
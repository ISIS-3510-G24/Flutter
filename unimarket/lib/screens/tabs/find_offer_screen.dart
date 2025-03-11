import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unimarket/screens/tabs/offer_screen.dart';
import 'package:unimarket/theme/app_colors.dart';

class FindAndOfferScreen extends StatefulWidget {
  const FindAndOfferScreen({Key? key}) : super(key: key);

  @override
  State<FindAndOfferScreen> createState() => _FindAndOfferScreenState();
}

class _FindAndOfferScreenState extends State<FindAndOfferScreen> {
  bool isFindSelected = true; // Controla si estamos en modo FIND u OFFER

  // Ejemplo de datos para la sección horizontal (“From your major”)
  final List<Map<String, String>> _majorItems = [
    {
      "title": "Computer",
      "subtitle": "Lenovo",
      "imageUrl": "https://via.placeholder.com/400x300.png?text=Lenovo+Laptop",
      "dateTag": "MAR 05",
    },
    {
      "title": "USB",
      "subtitle": "Type C",
      "imageUrl": "https://via.placeholder.com/400x300.png?text=Type+C+USB",
      "dateTag": "MAR 07",
    },
    {
      "title": "Tablet",
      "subtitle": "iPad Air",
      "imageUrl": "https://via.placeholder.com/400x300.png?text=iPad+Air",
      "dateTag": "MAR 09",
    },
  ];

  // Ejemplo de datos para la sección “Your wishlist”
  final List<Map<String, String>> _wishlistItems = [
    {
      "title": "Set pink rulers",
      "subtitle": "pink reference",
    },
    {
      "title": "Pink scissors",
      "subtitle": "Any reference",
    },
  ];

  // Ejemplo de datos para la sección “Selling out”
  final List<Map<String, String>> _sellingItems = [
    {
      "title": "Smartphone",
      "subtitle": "Samsung Galaxy S21",
    },
    {
      "title": "Headphones",
      "subtitle": "Sony WH-1000XM4",
    },
  ];

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      // Barra de navegación
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 80), 
                // para dejar espacio al botón flotante
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // TOP ROW: boton circular "All requests", toggles FIND/OFFER, icono Search
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Row(
                        children: [
                          // Botón circular "All requests"
                          _buildAllRequestsButton(),
                          const SizedBox(width: 12),
                          
                          // Botones FIND y OFFER
                          Expanded(
                            child: Row(
                              children: [
                                _buildBigToggleButton("FIND", isFind: true),
                                const SizedBox(width: 10),
                                _buildBigToggleButton("OFFER", isFind: false),
                              ],
                            ),
                          ),
                          
                          const SizedBox(width: 12),
                          // Icono de búsqueda
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
                    ),
                    
                    // Sección horizontal “From your major”
                    _buildSectionHeader(
                      title: "From your major",
                      onSeeMore: () => debugPrint("See more: From your major"),
                    ),
                    _buildMajorHorizontalList(),

                    // Sección “Your wishlist”
                    _buildSectionHeader(
                      title: "Your wishlist",
                      onSeeMore: () => debugPrint("See more: Your wishlist"),
                    ),
                    _buildVerticalList(_wishlistItems, showBuyButton: false),

                    // Sección “Selling out”
                    _buildSectionHeader(
                      title: "Selling out",
                      onSeeMore: () => debugPrint("See more: Selling out"),
                    ),
                    _buildVerticalList(_sellingItems, showBuyButton: true),
                  ],
                ),
              ),
            ),

            // ---- BOTÓN FLOTANTE (New Request / New Offer) ----
            Positioned(
              right: 20,
              bottom: 20,
              child: CupertinoButton(
                // Sobrescribimos el color por defecto (que es azul iOS) con tu primaryBlue
                color: AppColors.primaryBlue,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                borderRadius: BorderRadius.circular(30),
                child: Text(
                  isFindSelected ? "New Request" : "New Offer",
                  style: GoogleFonts.inter(
                    color: CupertinoColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: () {
                  if (isFindSelected) {
                    // Lógica para crear un nuevo "Find"
                    debugPrint("Crear nueva solicitud (Find)");
                  } else {
                    // Navegar a la pantalla OfferScreen, por ejemplo
                    Navigator.push(
                      context,
                      CupertinoPageRoute(builder: (ctx) => const OfferScreen()),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // TODO: reemplazar el texto "ALL" con un ícono cuando lo tengas
  Widget _buildAllRequestsButton() {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () {
        debugPrint("All requests button pressed");
        // Aquí podrías mostrar un menú, un picker, etc.
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.primaryBlue,
        ),
        child: Center(
          child: Text(
            "ALL",
            style: GoogleFonts.inter(
              fontSize: 12,
              color: CupertinoColors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  /// Botón grande para FIND u OFFER, ocupa espacio en el row
  Widget _buildBigToggleButton(String label, {required bool isFind}) {
    final bool isSelected =
        (isFindSelected && isFind) || (!isFindSelected && !isFind);
    return Expanded(
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(vertical: 14),
        color: isSelected
            ? AppColors.primaryBlue
            : AppColors.lightGreyBackground,
        borderRadius: BorderRadius.circular(25),
        onPressed: () {
          setState(() {
            isFindSelected = isFind;
          });
        },
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: isSelected ? CupertinoColors.white : CupertinoColors.black,
          ),
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

  /// Lista horizontal (ej: “From your major”) con altura un poco mayor para no overflow
  Widget _buildMajorHorizontalList() {
    return SizedBox(
      height: 210, // Ajustado para que no haga overflow
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _majorItems.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final item = _majorItems[index];
          return _buildMajorCard(item);
        },
      ),
    );
  }

  /// Tarjeta horizontal con imagen, fecha y botón “Buy”
  Widget _buildMajorCard(Map<String, String> item) {
    return Container(
      width: 160,
      height: 290,
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Imagen
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Image.network(
              item["imageUrl"] ?? "",
              height: 100,
              width: double.infinity,
              fit: BoxFit.fill,
              errorBuilder: (ctx, error, stack) => Container(
                height: 90, // TODO
                width: double.infinity,
                color: AppColors.lightGreyBackground,
                child: const Icon(CupertinoIcons.photo),
              ),
            ),
          ),
          // Etiqueta de fecha
          if (item["dateTag"] != null)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item["dateTag"]!,
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
              item["title"] ?? "",
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              item["subtitle"] ?? "",
              style: GoogleFonts.inter(
                fontSize: 12,
                color: CupertinoColors.systemGrey,
              ),
            ),
            ),
            // Botón “Buy”
            // Botón “Buy” más pequeño
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: SizedBox(
            height: 32, // Ajusté la altura del botón
            width: double.infinity, // Ocupar todo el ancho
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              color: AppColors.primaryBlue,
              borderRadius: BorderRadius.circular(20),
              onPressed: () {
                debugPrint("Buy ${item["title"]}");
              },
              child: Text(
                "Buy",
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: CupertinoColors.white,
                ),
              ),
              ),
              ),
            ),
        ],
      ),
    );
  }

  /// Lista vertical (para “Your wishlist” o “Selling out”)
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
              // Imagen placeholder
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.transparentGrey,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(CupertinoIcons.photo, color: CupertinoColors.white),
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

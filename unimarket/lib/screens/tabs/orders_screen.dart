import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unimarket/theme/app_colors.dart';

class OrdersScreen extends StatefulWidget {
    const OrdersScreen({super.key});

    @override
    _OrdersScreenState createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
    int _selectedTab = 1; // Inicia en "Buying"

    // Datos de productos por categoría
    final List<Map<String, String>> historyProducts = [
        {
            "name": "Linoleum Sheets",
            "details": "Black / M",
            "status": "Completed",
            "action": "Help",
            "image": "assets/svgs/ImagePlaceHolder.svg",
        },
    ];

    final List<Map<String, String>> buyingProducts = [
        {
            "name": "Thermoformed Tubes",
            "details": "Blue / 42",
            "status": "Ordered",
            "action": "Complete",
            "image": "assets/svgs/ImagePlaceHolder.svg"
        },
        {
            "name": "Organizer",
            "details": "Gold / L",
            "status": "Ordered",
            "action": "Complete",
            "image": "assets/svgs/ImagePlaceHolder.svg",
        },
        {
            "name": "Beautiful Colorful Folders",
            "details": "Blue, pink, yellow",
            "status": "Ordered",
            "action": "Complete",
            "image": "assets/svgs/ImagePlaceHolder.svg"
        },
    ];

    final List<Map<String, String>> sellingProducts = [
        {
            "name": "MD Board",
            "details": "Black / M",
            "price": "\$88.000",
            "action": "Modify",
            "image": "assets/svgs/ImagePlaceHolder.svg",
        },
    ];

    @override
    Widget build(BuildContext context) {
        return CupertinoPageScaffold(
            navigationBar: CupertinoNavigationBar(
                middle: Text(
                    "Orders",
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                ),
                trailing: const Icon(CupertinoIcons.search, color: AppColors.primaryBlue),
            ),
            child: SafeArea(
                child: Column(
                    children: [
                        const SizedBox(height: 10),
                        _buildTabSelector(),
                        const SizedBox(height: 10),
                        Expanded(
                            child: ListView.separated(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                itemCount: _getCurrentProducts().length,
                                separatorBuilder: (context, index) =>
                                        Container(height: 1, color: AppColors.lightGreyBackground),
                                itemBuilder: (context, index) {
                                    final product = _getCurrentProducts()[index];
                                    return _buildProductItem(product);
                                },
                            ),
                        ),
                    ],
                ),
            ),
        );
    }

    Widget _buildTabSelector() {
        return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Container(
                decoration: BoxDecoration(
                    color: AppColors.transparentGrey, // Fondo más claro
                    borderRadius: BorderRadius.circular(30), // Bordes súper redondeados
                ),
                padding: const EdgeInsets.all(8), // Espaciado interno para suavizar bordes
                child: CupertinoSegmentedControl<int>(
                    groupValue: _selectedTab,
                    onValueChanged: (int newIndex) {
                        setState(() {
                            _selectedTab = newIndex;
                        });
                    },
                    children: {
                        0: _buildTabItem("History", 0),
                        1: _buildTabItem("Buying", 1),
                        2: _buildTabItem("Selling", 2),
                    },
                    selectedColor: AppColors.primaryBlue, // Azul oficial
                    borderColor: CupertinoColors.transparent, // Sin bordes visibles
                    unselectedColor: CupertinoColors.transparent, // Sin color de fondo,
                    pressedColor: CupertinoColors.systemGrey4.withOpacity(0.2),
                    padding: EdgeInsets.zero,
                ),
            ),
        );
    }

    Widget _buildTabItem(String title, int index) {
        final bool isSelected = _selectedTab == index;
        return Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
            child: Text(
                title,
                style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? CupertinoColors.white : CupertinoColors.black.withOpacity(0.7),
                ),
            ),
        );
    }

    // 🔹 Obtiene la lista de productos según la pestaña seleccionada
    List<Map<String, String>> _getCurrentProducts() {
        switch (_selectedTab) {
            case 0:
                return historyProducts;
            case 1:
                return buyingProducts;
            case 2:
                return sellingProducts;
            default:
                return [];
        }
    }

    // 🔹 Widget para cada producto en la lista
    Widget _buildProductItem(Map<String, String> product) {
        return CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () {},
            child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                        // 🔹 Imagen del producto
                        ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SvgPicture.asset(
                                product["image"]!,
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                            ),
                        ),
                        const SizedBox(width: 10),

                        // 🔹 Detalles del producto
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                    Text(
                                        product["name"]!,
                                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
                                    ),
                                    Text(
                                        product["details"]!,
                                        style: GoogleFonts.inter(fontSize: 14, color: CupertinoColors.systemGrey),
                                    ),
                                    if (product.containsKey("price"))
                                        Text(
                                            product["price"]!,
                                            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.primaryBlue),
                                        ),
                                    if (product.containsKey("status"))
                                        Text(
                                            product["status"]!,
                                            style: GoogleFonts.inter(fontSize: 14, color: CupertinoColors.systemGrey),
                                        ),
                                ],
                            ),
                        ),

                        // 🔹 Botón de acción (Help, Complete, Modify)
                        if (_selectedTab != 2) ...[
                            CupertinoButton(
                                padding: EdgeInsets.zero,
                                child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: AppColors.primaryBlue,
                                    ),
                                    child: const Icon(
                                        CupertinoIcons.chat_bubble,
                                        color: CupertinoColors.white,
                                        size: 20,
                                    ),
                                ),
                                onPressed: () {},
                            ),
                        ],

                        const SizedBox(width: 10),

                        Text(
                            product["action"]!,
                            style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryBlue,
                            ),
                        ),

                        if (_selectedTab == 2) ...[
                            const SizedBox(width: 10),
                            CupertinoButton(
                                padding: EdgeInsets.zero,
                                child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: AppColors.lightGreyBackground,
                                    ),
                                    child: const Icon(
                                        CupertinoIcons.clear_circled,
                                        color: CupertinoColors.systemGrey,
                                        size: 20,
                                    ),
                                ),
                                onPressed: () {},
                            ),
                        ]
                    ],
                ),
            ),
        );
    }
}

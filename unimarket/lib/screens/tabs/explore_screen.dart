import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unimarket/widgets/popups/not_implemented.dart';

class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          "Explore",
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildIconButton(context, "assets/icons/Bell.svg"),
            _buildIconButton(context, "assets/icons/check-heart.svg"),
            _buildShoppingBagIcon(context),
          ],
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 200,
                child: PageView(
                  children: [
                    SvgPicture.asset("assets/svgs/ImagePlaceHolder.svg", fit: BoxFit.cover),
                    SvgPicture.asset("assets/svgs/ImagePlaceHolder.svg", fit: BoxFit.cover),
                    SvgPicture.asset("assets/svgs/ImagePlaceHolder.svg", fit: BoxFit.cover),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Perfect for you",
                      style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        Navigator.push(context, CupertinoPageRoute(builder: (context) => const NotImplementedScreen()));
                      },
                      child: Text(
                        "See more",
                        style: GoogleFonts.inter(color: const Color(0xFF66B7F0)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.9,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: 4,
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(context, CupertinoPageRoute(builder: (context) => const NotImplementedScreen()));
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: CupertinoColors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: CupertinoColors.systemGrey4,
                              blurRadius: 5,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: SvgPicture.asset(
                                  "assets/svgs/ImagePlaceHolder.svg",
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text("Product Name", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                            Text("\$45.000", style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton(BuildContext context, String assetPath) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () {
        Navigator.push(context, CupertinoPageRoute(builder: (context) => const NotImplementedScreen()));
      },
      child: SvgPicture.asset(assetPath, width: 24, height: 24),
    );
  }

  Widget _buildShoppingBagIcon(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () {
        Navigator.push(context, CupertinoPageRoute(builder: (context) => const NotImplementedScreen()));
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          SvgPicture.asset(
            "assets/icons/Shopping Bag Outlined.svg",
            width: 22,
            height: 22,
            colorFilter: const ColorFilter.mode(
              Color.fromARGB(255, 31, 31, 31),
              BlendMode.srcIn,
            ),
          ),
          Positioned(
            right: -5,
            top: 8,
            child: Container(
              width: 18,
              height: 18,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF66B7F0),
              ),
              child: const Text(
                "9",
                style: TextStyle(
                  color: CupertinoColors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

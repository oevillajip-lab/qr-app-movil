import 'dart:convert' show utf8;
import 'qr_svg_exporter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr/qr.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:path_provider/path_provider.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:image/image.dart' as img_lib;
import 'package:share_plus/share_plus.dart';
import 'dart:typed_data';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/rendering.dart';

void main() => runApp(
      MaterialApp(
        title: 'QR+Logo',
        home: const SplashScreen(),
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          fontFamily: 'SF Pro Display',
          scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        ),
      ),
    );

// ═══════════════════════════════════════════════════════════════════
// SECCIÓN 1: GENERACIÓN BASE DEL QR
// ═══════════════════════════════════════════════════════════════════
QrImage? _buildQrImage(String data) {
  try {
    final qrCode = QrCode.fromData(
      data: data,
      errorCorrectLevel: QrErrorCorrectLevel.H,
    );
    return QrImage(qrCode);
  } catch (_) {
    return null;
  }
}

// ═══════════════════════════════════════════════════════════════════
// SECCIÓN 2: FRENO MATEMÁTICO
// ═══════════════════════════════════════════════════════════════════
double _safeLogoMax({
  required int modules,
  required double auraModules,
  double canvasSize = 270.0,
  double hardMax = 85.0,
  double hardMin = 30.0,
}) {
  final double auraFrac = (auraModules * 2.0) / modules.toDouble();
  final double maxFrac = (math.sqrt(0.27) - auraFrac).clamp(0.08, 0.519);
  return (maxFrac * canvasSize).clamp(hardMin, hardMax);
}

// ═══════════════════════════════════════════════════════════════════
// SECCIÓN 3: SPLASH SCREEN
// ═══════════════════════════════════════════════════════════════════
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.85, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _ctrl.forward();
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 600),
          pageBuilder: (_, __, ___) => const MainScreen(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
        ),
      );
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 100, height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Image.asset(
                        'assets/app_icon.png',
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => const Icon(
                          Icons.qr_code_2, size: 60, color: Colors.black),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text("QR+Logo",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1)),
                  const SizedBox(height: 6),
                  const Text("Diseña tu QR perfecto",
                      style: TextStyle(
                          color: Colors.white38,
                          fontSize: 14,
                          letterSpacing: 0.2)),
                ],
              ),
            ),
          ),
        ),
      );
}

// ═══════════════════════════════════════════════════════════════════
// PANTALLA PRINCIPAL
// ═══════════════════════════════════════════════════════════════════
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with SingleTickerProviderStateMixin {
  final _c1 = TextEditingController();
  final _c2 = TextEditingController();
  final _c3 = TextEditingController();
  final _c4 = TextEditingController();
  final _c5 = TextEditingController();

  int _tab = 0; // 0=Básico, 1=Avanzado
  String _qrType = "Sitio Web (URL)";
  String _estilo = "Liquid Pro (Gusano)";
  String _estiloAvz = "Split Liquid (Mitades)";
  String _qrColorMode = "Sólido (Un Color)";
  String _qrGradDir = "Vertical";
  Color _qrC1 = Colors.black;
  Color _qrC2 = const Color(0xFF1565C0);

  bool _customEyes = false;
  Color _eyeExt = Colors.black;
  Color _eyeInt = Colors.black;

  String _bgMode = "Blanco (Default)";
  String _bgGradDir = "Diagonal";
  Color _bgC1 = Colors.white;
  Color _bgC2 = const Color(0xFFF5F5F5);

  Uint8List? _logoBytes;
  img_lib.Image? _logoImage;
  List<List<bool>>? _outerMask;

  Uint8List? _shapeBytes;
  img_lib.Image? _shapeImage;
  List<List<bool>>? _shapeMask;

  double _logoSize = 60.0;
double _auraSize = 1.5;
double _shapeGap = 0.8;
String _mapSubStyle = "Liquid Pro (Gusano)";
String _advSubStyle = "Liquid Pro (Gusano)";
String _splitDir = "Vertical";

  final GlobalKey _qrKey = GlobalKey();

  static const _basicStyles = [
    "Liquid Pro (Gusano)",
    "Normal (Cuadrado)",
    "Barras (Vertical)",
    "Circular (Puntos)",
    "Diamantes (Rombos)",
  ];

  static const _advStyles = [
    "Liquid Pro (Gusano)",
    "Normal (Cuadrado)",
    "Barras (Vertical)",
    "Circular (Puntos)",
    "Diamantes (Rombos)",
    "Split Liquid (Mitades)",
    "Formas (Máscara)",
  ];

  static const _shapeSubStyles = [
    "Liquid Pro (Gusano)",
    "Normal (Cuadrado)",
    "Barras (Vertical)",
    "Circular (Puntos)",
    "Diamantes (Rombos)",
  ];

  @override
  void dispose() {
    _c1.dispose(); _c2.dispose(); _c3.dispose();
    _c4.dispose(); _c5.dispose();
    super.dispose();
  }

  double _effectiveLogo(bool isShape) {
    if (isShape) return 0.0;
    final data = _getFinalData();
    if (data.isEmpty) return _logoSize;
    final qr = _buildQrImage(data);
    if (qr == null) return _logoSize;
    final maxPx = math.max(30.0,
        _safeLogoMax(modules: qr.moduleCount, auraModules: _auraSize));
    return _logoSize.clamp(30.0, maxPx);
  }

  Future<void> _processLogo(File file) async {
    final bytes = await file.readAsBytes();
    img_lib.Image? img = img_lib.decodeImage(bytes);
    if (img == null) return;
    img = img.convert(numChannels: 4);
    final ext = file.path.toLowerCase();
    if (ext.endsWith('.jpg') || ext.endsWith('.jpeg')) img = _removeWhiteBg(img);
    final w = img.width; final h = img.height;
    final rB = List.generate(h, (_) => List.filled(w, false));
    for (int y = 0; y < h; y++) {
      int fx = -1, lx = -1;
      for (int x = 0; x < w; x++) {
        if (img.getPixel(x, y).a > 30) { if (fx == -1) fx = x; lx = x; }
      }
      if (fx != -1) for (int x = fx; x <= lx; x++) rB[y][x] = true;
    }
    final mask = List.generate(h, (_) => List.filled(w, false));
    for (int x = 0; x < w; x++) {
      int fy = -1, ly = -1;
      for (int y = 0; y < h; y++) {
        if (img.getPixel(x, y).a > 30) { if (fy == -1) fy = y; ly = y; }
      }
      if (fy != -1) for (int y = fy; y <= ly; y++) { if (rB[y][x]) mask[y][x] = true; }
    }
    final png = Uint8List.fromList(img_lib.encodePng(img));
    final palette = await PaletteGenerator.fromImageProvider(MemoryImage(png));
    setState(() {
      _logoBytes = png; _logoImage = img; _outerMask = mask;
      _qrC1 = palette.darkVibrantColor?.color ??
          palette.darkMutedColor?.color ??
          palette.dominantColor?.color ?? Colors.black;
      _qrC2 = palette.vibrantColor?.color ?? palette.lightVibrantColor?.color ?? _qrC1;
      _qrColorMode = "Automático (Logo)";
    });
  }

  bool _hasRealTransparency(img_lib.Image src) {
    final total = src.width * src.height;
    int tp = 0;
    for (int y = 0; y < src.height; y++)
      for (int x = 0; x < src.width; x++)
        if (src.getPixel(x, y).a < 245) tp++;
    return tp > (total * 0.005);
  }

  img_lib.Image _removeEdgeBackground(img_lib.Image src) {
    final w = src.width, h = src.height;
    int sumR = 0, sumG = 0, sumB = 0, count = 0;
    void sample(int x, int y) {
      final p = src.getPixel(x, y);
      sumR += p.r.toInt(); sumG += p.g.toInt(); sumB += p.b.toInt(); count++;
    }
    for (int x = 0; x < w; x++) { sample(x, 0); if (h > 1) sample(x, h - 1); }
    for (int y = 1; y < h - 1; y++) { sample(0, y); if (w > 1) sample(w - 1, y); }
    final double bgR = sumR / count, bgG = sumG / count, bgB = sumB / count;
    const double tol = 68.0; final double tol2 = tol * tol;
    bool isBg(img_lib.Pixel p) {
      final dr = p.r.toDouble() - bgR, dg = p.g.toDouble() - bgG, db = p.b.toDouble() - bgB;
      return (dr*dr+dg*dg+db*db) <= tol2 || (p.r > 242 && p.g > 242 && p.b > 242);
    }
    final visited = List.generate(h, (_) => List.filled(w, false));
    final queue = <List<int>>[];
    void enqueue(int x, int y) {
      if (x < 0 || x >= w || y < 0 || y >= h || visited[y][x]) return;
      if (!isBg(src.getPixel(x, y))) return;
      visited[y][x] = true; queue.add([x, y]);
    }
    for (int x = 0; x < w; x++) { enqueue(x, 0); enqueue(x, h - 1); }
    for (int y = 0; y < h; y++) { enqueue(0, y); enqueue(w - 1, y); }
    while (queue.isNotEmpty) {
      final p = queue.removeLast();
      enqueue(p[0]+1,p[1]); enqueue(p[0]-1,p[1]); enqueue(p[0],p[1]+1); enqueue(p[0],p[1]-1);
    }
    final out = img_lib.Image(width: w, height: h, numChannels: 4);
    for (int y = 0; y < h; y++) for (int x = 0; x < w; x++) {
      final p = src.getPixel(x, y);
      if (visited[y][x]) out.setPixelRgba(x, y, 0, 0, 0, 0);
      else out.setPixelRgba(x, y, p.r.toInt(), p.g.toInt(), p.b.toInt(), 255);
    }
    return out;
  }

  img_lib.Image _normalizeShapeSilhouette(img_lib.Image src) {
    final prepared = _hasRealTransparency(src) ? src : _removeEdgeBackground(src);
    final out = img_lib.Image(width: prepared.width, height: prepared.height, numChannels: 4);
    for (int y = 0; y < prepared.height; y++) for (int x = 0; x < prepared.width; x++) {
      final p = prepared.getPixel(x, y);
      if (p.a > 24) out.setPixelRgba(x, y, 255, 255, 255, 255);
      else out.setPixelRgba(x, y, 0, 0, 0, 0);
    }
    return out;
  }

  List<List<bool>> _maskFromAlpha(img_lib.Image src, {int alphaThreshold = 24}) =>
      List.generate(src.height,
          (y) => List.generate(src.width, (x) => src.getPixel(x, y).a > alphaThreshold));

  Future<void> _processShape(File file) async {
    final bytes = await file.readAsBytes();
    img_lib.Image? decoded = img_lib.decodeImage(bytes);
    if (decoded == null) return;
    decoded = decoded.convert(numChannels: 4);
    final silhouette = _normalizeShapeSilhouette(decoded);
    final mask = _maskFromAlpha(silhouette);
    final png = Uint8List.fromList(img_lib.encodePng(silhouette));
    setState(() {
  _shapeBytes = png;
  _shapeImage = silhouette;
  _shapeMask = mask;
});
  }

  img_lib.Image _removeWhiteBg(img_lib.Image src) {
    final w = src.width, h = src.height;
    const thr = 230;
    final vis = List.generate(h, (_) => List.filled(w, false));
    final q = <List<int>>[];
    void enq(int x, int y) {
      if (x < 0 || x >= w || y < 0 || y >= h || vis[y][x]) return;
      final p = src.getPixel(x, y);
      if (p.r > thr && p.g > thr && p.b > thr) { vis[y][x] = true; q.add([x, y]); }
    }
    for (int x = 0; x < w; x++) { enq(x, 0); enq(x, h - 1); }
    for (int y = 0; y < h; y++) { enq(0, y); enq(w - 1, y); }
    while (q.isNotEmpty) {
      final p = q.removeLast();
      enq(p[0]+1,p[1]); enq(p[0]-1,p[1]); enq(p[0],p[1]+1); enq(p[0],p[1]-1);
    }
    final res = img_lib.Image(width: w, height: h, numChannels: 4);
    for (int y = 0; y < h; y++) for (int x = 0; x < w; x++) {
      final p = src.getPixel(x, y);
      if (vis[y][x]) res.setPixelRgba(x, y, 0, 0, 0, 0);
      else res.setPixelRgba(x, y, p.r.toInt(), p.g.toInt(), p.b.toInt(), 255);
    }
    return res;
  }

  String _getFinalData() {
    if (_c1.text.isEmpty) return "";
    switch (_qrType) {
      case "Sitio Web (URL)": return _c1.text;
      case "Red WiFi": return "WIFI:T:WPA;S:${_c1.text};P:${_c2.text};;";
      case "VCard (Contacto)":
        return "BEGIN:VCARD\nVERSION:3.0\nFN:${_c1.text} ${_c2.text}\nORG:${_c3.text}\nTEL:${_c4.text}\nEMAIL:${_c5.text}\nEND:VCARD";
      case "WhatsApp":
        return "https://wa.me/${_c1.text.replaceAll('+', '')}?text=${Uri.encodeComponent(_c2.text)}";
      case "E-mail": return "mailto:${_c1.text}?subject=${_c2.text}&body=${_c3.text}";
      case "SMS (Mensaje)": return "SMSTO:${_c1.text}:${_c2.text}";
      case "Teléfono": return "tel:${_c1.text}";
      default: return _c1.text;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // UI PRINCIPAL
  // ═══════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final data = _getFinalData();
    final isEmpty = data.isEmpty;
    final isAdv = _tab == 1;
    final estilo = isAdv ? _estiloAvz : _estilo;
    final isShape = estilo == "Formas (Máscara)";
    final effLogo = _effectiveLogo(isShape);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            _buildTabSelector(),
            Expanded(
              child: _tab == 0 ? _buildBasicContent(data, isEmpty, effLogo)
                              : _buildAdvancedContent(data, isEmpty, effLogo),
            ),
            _buildQrPreviewPanel(data, isEmpty, estilo, isAdv, effLogo),
            _buildBottomBar(isEmpty),
          ],
        ),
      ),
    );
  }

  // ── Top bar ──────────────────────────────────────────────────────
  Widget _buildTopBar() => Container(
    color: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    child: Row(
      children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(10),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset('assets/app_icon.png',
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) =>
                    const Icon(Icons.qr_code_2, color: Colors.white, size: 22)),
          ),
        ),
        const SizedBox(width: 10),
        const Text("QR+Logo",
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, letterSpacing: -0.8)),
        const Spacer(),
        _iconBtn(Icons.palette_outlined, () => _showOptionsSheet()),
      ],
    ),
  );

  Widget _iconBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: () { HapticFeedback.lightImpact(); onTap(); },
    child: Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 20, color: Colors.black),
    ),
  );

  // ── Tab selector ─────────────────────────────────────────────────
  Widget _buildTabSelector() => Container(
    color: Colors.white,
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    child: Container(
      height: 42,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _tabBtn("Básico", 0),
          _tabBtn("Avanzado", 1),
        ],
      ),
    ),
  );

  Widget _tabBtn(String label, int index) => Expanded(
    child: GestureDetector(
      onTap: () { HapticFeedback.selectionClick(); setState(() => _tab = index); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: _tab == index ? Colors.black : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: _tab == index
              ? [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 8, offset: const Offset(0, 2))]
              : [],
        ),
        child: Center(
          child: Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _tab == index ? Colors.white : Colors.black54)),
        ),
      ),
    ),
  );

  // ── Básico content ───────────────────────────────────────────────
  Widget _buildBasicContent(String data, bool isEmpty, double effLogo) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel("ESTILO"),
          _styleGrid(_basicStyles, _estilo, (s) => setState(() => _estilo = s)),
          const SizedBox(height: 14),
          _sectionLabel("CONTENIDO"),
          _contentCard(),
          const SizedBox(height: 14),
          _sectionLabel("LOGO"),
          _logoCard(effLogo, false),
          const SizedBox(height: 14),
          _sectionLabel("FONDO"),
          _bgCard(false),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ── Avanzado content ─────────────────────────────────────────────
  Widget _buildAdvancedContent(String data, bool isEmpty, double effLogo) {
    final isShape = _estiloAvz == "Formas (Máscara)";
    final isSplit = _estiloAvz == "Split Liquid (Mitades)";

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel("ESTILO AVANZADO"),
          _styleGrid(_advStyles, _estiloAvz, (s) => setState(() => _estiloAvz = s)),

          if (isShape || isSplit) ...[
            const SizedBox(height: 12),
            _sectionLabel(isShape ? "MÓDULOS EN FORMA" : "ESTILO MÓDULOS"),
            _subStyleRow(
                isShape ? _mapSubStyle : _advSubStyle,
                (s) => setState(() { if (isShape) _mapSubStyle = s; else _advSubStyle = s; })),
          ],

          if (isSplit) ...[
            const SizedBox(height: 12),
            _sectionLabel("DIRECCIÓN SPLIT"),
            _chipsRow(["Vertical", "Horizontal", "Diagonal"], _splitDir,
                (v) => setState(() => _splitDir = v)),
          ],

          const SizedBox(height: 14),
          _sectionLabel("COLOR"),
          _colorCardAdv(),

          const SizedBox(height: 14),
          _sectionLabel("OJOS DEL QR"),
          _eyesCard(),

          const SizedBox(height: 14),
          _sectionLabel(isShape ? "FORMA / SILUETA" : "LOGO"),
          isShape ? _shapeCard() : _logoCard(effLogo, false),

          const SizedBox(height: 14),
          _sectionLabel("CONTENIDO"),
          _contentCard(),

          const SizedBox(height: 14),
          _sectionLabel("FONDO"),
          _bgCard(true),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ── Section label ────────────────────────────────────────────────
  Widget _sectionLabel(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(label,
        style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.black38,
            letterSpacing: 1.2)),
  );

  // ── Style grid ───────────────────────────────────────────────────
  Widget _styleGrid(List<String> styles, String selected, Function(String) onSelect) {
    return SizedBox(
      height: 122,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: styles.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (ctx, i) {
          final style = styles[i];
          final sel = style == selected;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onSelect(style);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 100,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: sel ? Colors.black : Colors.transparent, width: 2.5),
                boxShadow: [
                  BoxShadow(
                      color: sel
                          ? Colors.black.withOpacity(0.15)
                          : Colors.black.withOpacity(0.05),
                      blurRadius: sel ? 12 : 4,
                      offset: const Offset(0, 3)),
                ],
              ),
              child: Column(children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                    child: Stack(alignment: Alignment.center, children: [
                      SizedBox(
                        width: 96, height: 96,
                        child: CustomPaint(
                            painter: StylePreviewPainter(
                                style: style, c1: _qrC1, c2: _qrC2)),
                      ),
                      if (_logoBytes != null && !style.contains("Formas"))
                        SizedBox(width: 22, height: 22,
                            child: Image.memory(_logoBytes!, fit: BoxFit.contain))
                      else if (!style.contains("Formas"))
                        const Text("LOGO",
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900,
                                color: Colors.black45)),
                    ]),
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: sel ? Colors.black : const Color(0xFFF8F8F8),
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
                  ),
                  child: Text(_shortName(style),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w700,
                          color: sel ? Colors.white : Colors.black54,
                          letterSpacing: -0.2)),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }

  String _shortName(String s) {
    if (s.contains("Gusano")) return "Liquid";
    if (s.contains("Cuadrado")) return "Normal";
    if (s.contains("Barras")) return "Barras";
    if (s.contains("Puntos")) return "Círculos";
    if (s.contains("Rombos")) return "Diamantes";
    if (s.contains("Split")) return "Split";
    if (s.contains("Formas")) return "Formas";
    return s;
  }

  // ── Sub-style row ────────────────────────────────────────────────
  Widget _subStyleRow(String current, Function(String) onSelect) =>
      _chipsRow(_shapeSubStyles.map(_shortName).toList(),
          _shortName(current),
          (v) => onSelect(_shapeSubStyles.firstWhere((s) => _shortName(s) == v)));

  Widget _chipsRow(List<String> items, String selected, Function(String) onSelect) =>
      SizedBox(
        height: 38,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final item = items[i];
            final sel = item == selected;
            return GestureDetector(
              onTap: () { HapticFeedback.selectionClick(); onSelect(item); },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: sel ? Colors.black : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: sel ? Colors.black : Colors.black12, width: 1.5),
                ),
                child: Text(item,
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600,
                        color: sel ? Colors.white : Colors.black54)),
              ),
            );
          },
        ),
      );

  // ── Content card ─────────────────────────────────────────────────
  Widget _contentCard() => _card(Column(children: [
    _typeDropdown(),
    const SizedBox(height: 10),
    _buildInputs(),
  ]));

  // ── Logo card ────────────────────────────────────────────────────
  Widget _logoCard(double effLogo, bool isShape) => _card(Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(children: [
        Expanded(
          child: _actionTile(
            icon: Icons.image_outlined,
            label: _logoBytes == null ? "Cargar Logo" : "✅ Logo cargado",
            onTap: () async {
              final img = await ImagePicker().pickImage(source: ImageSource.gallery);
              if (img != null) await _processLogo(File(img.path));
            },
          ),
        ),
        if (_logoBytes != null) ...[
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => setState(() { _logoBytes = null; _logoImage = null; _outerMask = null; }),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.delete_outline, color: Colors.red.shade400, size: 20),
            ),
          ),
        ],
      ]),
      if (_logoBytes != null) ...[
        const SizedBox(height: 12),
        Row(children: [
          const Text("Tamaño", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const Spacer(),
          Text("${effLogo.toInt()}px", style: const TextStyle(fontSize: 12, color: Colors.black45)),
        ]),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7)),
          child: Slider(
            value: _logoSize, min: 30, max: 85, divisions: 11,
            activeColor: Colors.black, inactiveColor: Colors.black12,
            onChanged: (v) => setState(() => _logoSize = v),
          ),
        ),
        Row(children: [
          const Text("Separación", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const Spacer(),
          Text("${_auraSize.toStringAsFixed(1)} mód.", style: const TextStyle(fontSize: 12, color: Colors.black45)),
        ]),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7)),
          child: Slider(
            value: _auraSize, min: 1.0, max: 3.0, divisions: 4,
            activeColor: Colors.black, inactiveColor: Colors.black12,
            onChanged: (v) => setState(() => _auraSize = v),
          ),
        ),
      ],
      const Padding(
        padding: EdgeInsets.only(top: 4),
        child: Text("💡 Logo blanco → fondo oscuro",
            style: TextStyle(fontSize: 11, color: Colors.black38, fontStyle: FontStyle.italic)),
      ),
    ],
  ));

  // ── Shape card ───────────────────────────────────────────────────
Widget _shapeCard() => _card(
  Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _actionTile(
        icon: Icons.format_shapes,
        label: _shapeBytes == null
            ? "Cargar imagen de forma (PNG/JPG)"
            : "✅ Forma cargada — Cambiar",
        onTap: () async {
          final img = await ImagePicker().pickImage(source: ImageSource.gallery);
          if (img != null) await _processShape(File(img.path));
        },
      ),
      const SizedBox(height: 12),
      if (_shapeBytes != null) ...[
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F7F7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  "La silueta cargada se usará como base del QR con forma.",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () => setState(() {
                _shapeBytes = null;
                _shapeImage = null;
                _shapeMask = null;
              }),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.delete_outline,
                  color: Colors.red.shade400,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            const Text(
              "Espacio QR / forma",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            Text(
              "${_shapeGap.toStringAsFixed(1)} mód.",
              style: const TextStyle(fontSize: 12, color: Colors.black45),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
          ),
          child: Slider(
            value: _shapeGap,
            min: 0.0,
            max: 3.0,
            divisions: 12,
            activeColor: Colors.black,
            inactiveColor: Colors.black12,
            onChanged: (v) => setState(() => _shapeGap = v),
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Text(
            "0.0 = casi pegado · más alto = más encapsulado dentro de la forma",
            style: TextStyle(
              fontSize: 11,
              color: Colors.black38,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ] else
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Text(
            "Usa una imagen con una silueta clara. PNG transparente ideal; JPG también sirve.",
            style: TextStyle(
              fontSize: 11,
              color: Colors.black38,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
    ],
  ),
);

  // ── Color card Avanzado ──────────────────────────────────────────
  Widget _colorCardAdv() => _card(Column(children: [
    Row(children: [
      Expanded(
        child: _dropdown(
          value: _qrColorMode,
          items: ["Automático (Logo)", "Sólido (Un Color)", "Degradado Custom"],
          onChanged: (v) => setState(() => _qrColorMode = v!),
        ),
      ),
    ]),
    const SizedBox(height: 10),
    Row(children: [
      const Text("Color QR", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      const Spacer(),
      _colorDot(_qrC1, (c) => setState(() => _qrC1 = c)),
      if (_qrColorMode != "Sólido (Un Color)") ...[
        const SizedBox(width: 8),
        _colorDot(_qrC2, (c) => setState(() => _qrC2 = c)),
      ],
    ]),
    if (_qrColorMode == "Degradado Custom") ...[
      const SizedBox(height: 8),
      _dropdown(
        value: _qrGradDir,
        items: ["Vertical", "Horizontal", "Diagonal"],
        onChanged: (v) => setState(() => _qrGradDir = v!),
        label: "Dirección",
      ),
    ],
  ]));

  // ── Eyes card ────────────────────────────────────────────────────
  Widget _eyesCard() => _card(Column(children: [
    Row(children: [
      const Text("Personalizar ojos",
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      const Spacer(),
      Switch.adaptive(
        value: _customEyes,
        activeColor: Colors.black,
        onChanged: (v) => setState(() => _customEyes = v),
      ),
    ]),
    if (_customEyes) ...[
      const SizedBox(height: 8),
      Row(children: [
        const Text("Exterior", style: TextStyle(fontSize: 13)),
        const Spacer(),
        _colorDot(_eyeExt, (c) => setState(() => _eyeExt = c)),
        const SizedBox(width: 16),
        const Text("Interior", style: TextStyle(fontSize: 13)),
        const SizedBox(width: 8),
        _colorDot(_eyeInt, (c) => setState(() => _eyeInt = c)),
      ]),
    ],
  ]));

  // ── BG card ──────────────────────────────────────────────────────
  Widget _bgCard(bool isAdv) => _card(Column(children: [
    _dropdown(
      value: isAdv ? _bgMode : (_bgMode == "Degradado" ? "Blanco (Default)" : _bgMode),
      items: isAdv
          ? ["Blanco (Default)", "Transparente", "Sólido (Color)", "Degradado"]
          : ["Blanco (Default)", "Transparente", "Sólido (Color)"],
      onChanged: (v) => setState(() => _bgMode = v!),
      label: "Fondo",
    ),
    if (_bgMode == "Sólido (Color)" || _bgMode == "Degradado") ...[
      const SizedBox(height: 10),
      Row(children: [
        const Text("Color fondo", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const Spacer(),
        _colorDot(_bgC1, (c) => setState(() => _bgC1 = c)),
        if (_bgMode == "Degradado") ...[
          const SizedBox(width: 8),
          _colorDot(_bgC2, (c) => setState(() => _bgC2 = c)),
        ],
      ]),
      if (_bgMode == "Degradado") ...[
        const SizedBox(height: 8),
        _dropdown(
          value: _bgGradDir,
          items: ["Vertical", "Horizontal", "Diagonal"],
          onChanged: (v) => setState(() => _bgGradDir = v!),
          label: "Dirección",
        ),
      ],
    ],
  ]));

  // ── Options bottom sheet ─────────────────────────────────────────
  void _showOptionsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Opciones rápidas",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            Row(children: [
              const Text("Color QR", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const Spacer(),
              _colorDot(_qrC1, (c) { setState(() => _qrC1 = c); Navigator.pop(context); }),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              const Text("Modo color", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const Spacer(),
              _dropdown(
                value: _qrColorMode,
                items: ["Automático (Logo)", "Sólido (Un Color)", "Degradado Custom"],
                onChanged: (v) => setState(() => _qrColorMode = v!),
              ),
            ]),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ── QR Preview panel ─────────────────────────────────────────────
  Widget _buildQrPreviewPanel(String data, bool isEmpty, String estilo, bool isAdv, double effLogo) {
    final isShape = estilo == "Formas (Máscara)";
    final shapeReady = _shapeMask != null && _shapeMask!.isNotEmpty;
    final isAdvStyle = isAdv && (estilo == "Split Liquid (Mitades)" || isShape);

    final bgColor = _bgMode == "Transparente"
        ? Colors.grey.shade100
        : _bgMode == "Sólido (Color)" ? _bgC1 : Colors.white;
    final bgGrad = _bgMode == "Degradado" ? _getGrad(_bgC1, _bgC2, _bgGradDir) : null;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          // QR Preview — solo visual, no se usa para exportar
          RepaintBoundary(
            key: _qrKey,
            child: Container(
              width: 130, height: 130,
              decoration: BoxDecoration(
                color: bgGrad == null ? bgColor : null,
                gradient: bgGrad,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08),
                    blurRadius: 10, offset: const Offset(0, 3))],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Center(
                  child: isEmpty
                      ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.qr_code_2, size: 36, color: Colors.black12),
                          const SizedBox(height: 4),
                          const Text("Escribe\nalgo...",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.black26, fontSize: 10)),
                        ])
                      : (isShape && !shapeReady)
                          ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              const Icon(Icons.format_shapes, size: 32, color: Colors.black26),
                              const SizedBox(height: 4),
                              const Text("Elige\nforma",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.black26, fontSize: 10)),
                            ])
                          : Stack(alignment: Alignment.center, children: [
                              CustomPaint(
                                size: const Size(120, 120),
                                painter: isAdvStyle
                                    ? QrAdvancedPainter(
                                        data: data, estiloAvanzado: estilo,
                                        mapSubStyle: _mapSubStyle, advSubStyle: _advSubStyle,
                                        splitDir: _splitDir,
                                        logoImage: isShape ? null : _logoImage,
                                        outerMask: isShape ? null : _outerMask,
                                        shapeImage: _shapeImage, shapeMask: _shapeMask,
                                        logoSize: isShape ? 0.0 : effLogo,
                                        auraSize: isShape ? 0.0 : _auraSize,
                                        shapeGap: _shapeGap,
                                        qrC1: _qrC1, qrC2: _qrC2,
                                        qrMode: _qrColorMode, qrDir: _qrGradDir,
                                        customEyes: _customEyes,
                                        eyeExt: _eyeExt, eyeInt: _eyeInt,
                                      )
                                    : QrMasterPainter(
                                        data: data, estilo: estilo,
                                        logoImage: _logoImage, outerMask: _outerMask,
                                        logoSize: effLogo, auraSize: _auraSize,
                                        qrC1: _qrC1, qrC2: _qrC2,
                                        qrMode: _qrColorMode, qrDir: _qrGradDir,
                                        customEyes: _customEyes,
                                        eyeExt: _eyeExt, eyeInt: _eyeInt,
                                      ),
                              ),
                              if (_logoBytes != null && !isShape)
                                SizedBox(
                                  width: effLogo * 120 / 270,
                                  height: effLogo * 120 / 270,
                                  child: Image.memory(_logoBytes!, fit: BoxFit.contain)),
                            ]),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Info + quick type
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Vista previa",
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                        color: Colors.black38, letterSpacing: 0.8)),
                const SizedBox(height: 4),
                Text(
                  isEmpty ? "Sin contenido" : _getFinalData().length > 40
                      ? "${_getFinalData().substring(0, 40)}..." : _getFinalData(),
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                _dropdown(
                  value: _qrType,
                  items: ["Sitio Web (URL)", "WhatsApp", "Red WiFi",
                      "VCard (Contacto)", "Teléfono", "E-mail", "SMS (Mensaje)", "Texto Libre"],
                  onChanged: (v) => setState(() => _qrType = v!),
                  compact: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom bar ───────────────────────────────────────────────────
Widget _buildBottomBar(bool isEmpty) => Container(
  color: Colors.white,
  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
  child: Row(
    children: [
      Expanded(
        child: _bigBtn(
          "GUARDAR",
          Icons.save_alt,
          isEmpty
              ? null
              : () async {
                  HapticFeedback.heavyImpact();
                  await _guardarImagen();
                },
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _bigBtn(
          "COMPARTIR",
          Icons.share_outlined,
          isEmpty
              ? null
              : () async {
                  HapticFeedback.heavyImpact();
                  await _mostrarSelectorCompartir();
                },
          outlined: true,
        ),
      ),
    ],
  ),
);

  Widget _bigBtn(String label, IconData icon, VoidCallback? onTap, {bool outlined = false}) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 50,
        decoration: BoxDecoration(
          color: outlined
              ? (enabled ? Colors.white : Colors.grey.shade100)
              : (enabled ? Colors.black : Colors.grey.shade200),
          borderRadius: BorderRadius.circular(14),
          border: outlined ? Border.all(
              color: enabled ? Colors.black : Colors.grey.shade300, width: 2) : null,
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 18,
              color: outlined
                  ? (enabled ? Colors.black : Colors.grey)
                  : (enabled ? Colors.white : Colors.grey)),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700,
                  color: outlined
                      ? (enabled ? Colors.black : Colors.grey)
                      : (enabled ? Colors.white : Colors.grey))),
        ]),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────
  Widget _card(Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    margin: const EdgeInsets.only(bottom: 0),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
    ),
    child: child,
  );

  Widget _actionTile({required IconData icon, required String label, required VoidCallback onTap}) =>
      GestureDetector(
        onTap: () { HapticFeedback.lightImpact(); onTap(); },
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            color: const Color(0xFFF0F0F0),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 18, color: Colors.black87),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ]),
        ),
      );

  Widget _dropdown({
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
    String? label,
    bool compact = false,
  }) =>
      DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 12),
          border: compact ? OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.black12),
          ) : InputBorder.none,
          contentPadding: compact
              ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
              : EdgeInsets.zero,
          isDense: true,
        ),
        style: TextStyle(fontSize: compact ? 12 : 14, color: Colors.black, fontWeight: FontWeight.w500),
        icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
        items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13)))).toList(),
        onChanged: onChanged,
      );

  Widget _buildInputs() {
    switch (_qrType) {
      case "Sitio Web (URL)":
        return _field(_c1, "https://mipagina.com");
      case "WhatsApp":
        return Column(children: [
          _field(_c1, "+595981000000", type: TextInputType.phone),
          _field(_c2, "Mensaje (opcional)"),
        ]);
      case "Red WiFi":
        return Column(children: [
          _field(_c1, "Nombre de la red"),
          _field(_c2, "Contraseña", obscure: true),
        ]);
      case "VCard (Contacto)":
        return Column(children: [
          Row(children: [
            Expanded(child: _field(_c1, "Nombre")),
            const SizedBox(width: 8),
            Expanded(child: _field(_c2, "Apellido")),
          ]),
          _field(_c3, "Empresa"),
          _field(_c4, "Teléfono", type: TextInputType.phone),
          _field(_c5, "Email", type: TextInputType.emailAddress),
        ]);
      case "Teléfono":
        return _field(_c1, "+595981000000", type: TextInputType.phone);
      case "E-mail":
        return Column(children: [
          _field(_c1, "correo@ejemplo.com", type: TextInputType.emailAddress),
          _field(_c2, "Asunto"),
          _field(_c3, "Mensaje"),
        ]);
      case "SMS (Mensaje)":
        return Column(children: [
          _field(_c1, "+595981000000", type: TextInputType.phone),
          _field(_c2, "Texto del SMS"),
        ]);
      default:
        return _field(_c1, "Escribe tu texto aquí...", maxLines: 2);
    }
  }

  Widget _field(TextEditingController c, String hint,
      {TextInputType type = TextInputType.text, bool obscure = false, int maxLines = 1}) =>
      TextField(
        controller: c,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.black26, fontSize: 13),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.black12),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.black12),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.black, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          isDense: true,
        ),
        style: const TextStyle(fontSize: 13),
        keyboardType: type,
        obscureText: obscure,
        maxLines: maxLines,
        onChanged: (_) => setState(() {}),
      );

  Widget _typeDropdown() => _dropdown(
    value: _qrType,
    items: ["Sitio Web (URL)", "WhatsApp", "Red WiFi", "VCard (Contacto)",
        "Teléfono", "E-mail", "SMS (Mensaje)", "Texto Libre"],
    onChanged: (v) => setState(() => _qrType = v!),
    label: "Tipo de QR",
  );

  Widget _colorDot(Color cur, Function(Color) onTap) => GestureDetector(
    onTap: () => _palette(onTap),
    child: Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
        color: cur, shape: BoxShape.circle,
        border: Border.all(color: Colors.black12, width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)],
      ),
      child: Icon(Icons.colorize, size: 14,
          color: cur.computeLuminance() > 0.5 ? Colors.black54 : Colors.white70),
    ),
  );

  void _palette(Function(Color) onSel) => showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      title: const Text("Color", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      content: Wrap(
        spacing: 10, runSpacing: 10,
        children: [
          Colors.black, Colors.white, const Color(0xFF1565C0),
          Colors.red, Colors.green.shade700, Colors.orange,
          Colors.purple, Colors.teal, const Color(0xFFE91E63),
          const Color(0xFF00BCD4), Colors.brown, Colors.grey.shade600,
        ].map((c) => GestureDetector(
          onTap: () { HapticFeedback.selectionClick(); onSel(c); Navigator.pop(ctx); setState(() {}); },
          child: Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: c, shape: BoxShape.circle,
              border: Border.all(color: Colors.black12),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)],
            ),
          ),
        )).toList(),
      ),
    ),
  );

  LinearGradient _getGrad(Color c1, Color c2, String dir) {
    var b = Alignment.topCenter, e = Alignment.bottomCenter;
    if (dir == "Horizontal") { b = Alignment.centerLeft; e = Alignment.centerRight; }
    if (dir == "Diagonal") { b = Alignment.topLeft; e = Alignment.bottomRight; }
    return LinearGradient(colors: [c1, c2], begin: b, end: e);
  }

 Future<Directory> _getExportDir() async {
  if (Platform.isAndroid) {
    final dirs = await getExternalStorageDirectories(
      type: StorageDirectory.downloads,
    );
    if (dirs != null && dirs.isNotEmpty) {
      return dirs.first;
    }
  }
  return await getApplicationDocumentsDirectory();
}

Future<void> _guardarImagen() async {
  try {
    final pngBytes = await _renderPng();
    await ImageGallerySaver.saveImage(
      pngBytes,
      name: "QR_Logo_${DateTime.now().millisecondsSinceEpoch}",
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("✅ Imagen PNG guardada en galería"),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.black,
        ),
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error al guardar imagen: $e"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

Future<void> _guardarSvg() async {
  try {
    final svg = _buildSvg();
    final svgBytes = Uint8List.fromList(utf8.encode(svg));
    final dir = await _getExportDir();
    final fileName = "QR_Logo_${DateTime.now().millisecondsSinceEpoch}.svg";
    final file = File('${dir.path}/$fileName');

    await file.writeAsBytes(svgBytes);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("✅ SVG guardado en: ${file.path}"),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.black,
        ),
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error al guardar SVG: $e"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

Future<void> _compartirImagen() async {
  try {
    final tmpDir = await getTemporaryDirectory();
    final pngBytes = await _renderPng();
    final pngFile = File(
      '${tmpDir.path}/QR_Logo_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await pngFile.writeAsBytes(pngBytes);

    await Share.shareXFiles(
      [XFile(pngFile.path, mimeType: 'image/png')],
      text: 'Generado con QR+Logo',
    );
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error al compartir imagen: $e"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

Future<void> _compartirSvg() async {
  try {
    final tmpDir = await getTemporaryDirectory();
    final svg = _buildSvg();
    final svgBytes = Uint8List.fromList(utf8.encode(svg));
    final svgFile = File(
      '${tmpDir.path}/QR_Logo_${DateTime.now().millisecondsSinceEpoch}.svg',
    );
    await svgFile.writeAsBytes(svgBytes);

    await Share.shareXFiles(
      [XFile(svgFile.path, mimeType: 'image/svg+xml')],
      text: 'Generado con QR+Logo',
    );
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error al compartir SVG: $e"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

Future<void> _mostrarSelectorCompartir() async {
  if (!mounted) return;

  await showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "¿Qué quieres compartir?",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          _actionTile(
            icon: Icons.image_outlined,
            label: "Compartir imagen PNG",
            onTap: () async {
              Navigator.pop(context);
              await _compartirImagen();
            },
          ),
          const SizedBox(height: 10),
          _actionTile(
            icon: Icons.hexagon_outlined,
            label: "Compartir vector SVG",
            onTap: () async {
              Navigator.pop(context);
              await _compartirSvg();
            },
          ),
        ],
      ),
    ),
  );
}     

  // ═══════════════════════════════════════════════════════════════════
  // EXPORT — SVG vectorial + PNG 1024×1024 sin capturar widget
  // ═══════════════════════════════════════════════════════════════════

  /// Construye el SVG usando el estado actual
String _buildSvg() {
  final estilo = _tab == 0 ? _estilo : _estiloAvz;
  final isShape = estilo == "Formas (Máscara)";
  final effLogo = _effectiveLogo(isShape);

  return QrSvgExporter.generate(
    data: _getFinalData(),
    estilo: estilo,
    qrC1: _qrC1,
    qrC2: _qrC2,
    qrMode: _qrColorMode,
    qrDir: _qrGradDir,
    bgMode: _bgMode,
    bgC1: _bgC1,
    bgC2: _bgC2,
    bgGradDir: _bgGradDir,
    customEyes: _customEyes,
    eyeExt: _eyeExt,
    eyeInt: _eyeInt,
    mapSubStyle: _mapSubStyle,
    advSubStyle: _advSubStyle,
    logoBytes: isShape ? null : _logoBytes,
    logoSizeFrac: isShape ? 0.0 : (effLogo / 270.0),
    logoAuraModules: isShape ? 0.0 : _auraSize,
    size: 1024,
  );
}

  /// Renderiza PNG 1024×1024 directo con PictureRecorder — sin capturar widget de pantalla
  Future<Uint8List> _renderPng() async {
    const double exportSize = 1024.0;
    final data = _getFinalData();
    final estilo = _tab == 0 ? _estilo : _estiloAvz;
    final isShape = estilo == "Formas (Máscara)";
    final effLogo = _effectiveLogo(isShape) / 270.0 * exportSize;
    final isAdvStyle = _tab == 1 && (estilo == "Split Liquid (Mitades)" || isShape);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Fondo
    if (_bgMode != "Transparente") {
      final Paint bgPaint = Paint();
      if (_bgMode == "Degradado") {
        bgPaint.shader = ui.Gradient.linear(
          _gradOffset(_bgGradDir, true, exportSize),
          _gradOffset(_bgGradDir, false, exportSize),
          [_bgC1, _bgC2],
        );
      } else {
        bgPaint.color = _bgMode == "Sólido (Color)" ? _bgC1 : Colors.white;
      }
      canvas.drawRect(Rect.fromLTWH(0, 0, exportSize, exportSize), bgPaint);
    }

    // QR
    if (isAdvStyle) {
      QrAdvancedPainter(
        data: data, estiloAvanzado: estilo,
        mapSubStyle: _mapSubStyle, advSubStyle: _advSubStyle,
        splitDir: _splitDir,
        logoImage: isShape ? null : _logoImage,
        outerMask: isShape ? null : _outerMask,
        shapeImage: _shapeImage, shapeMask: _shapeMask,
        logoSize: isShape ? 0.0 : effLogo,
        auraSize: isShape ? 0.0 : _auraSize,
        shapeGap: _shapeGap,
        qrC1: _qrC1, qrC2: _qrC2,
        qrMode: _qrColorMode, qrDir: _qrGradDir,
        customEyes: _customEyes, eyeExt: _eyeExt, eyeInt: _eyeInt,
      ).paint(canvas, const Size(exportSize, exportSize));
    } else {
      QrMasterPainter(
        data: data, estilo: estilo,
        logoImage: _logoImage, outerMask: _outerMask,
        logoSize: effLogo, auraSize: _auraSize,
        qrC1: _qrC1, qrC2: _qrC2,
        qrMode: _qrColorMode, qrDir: _qrGradDir,
        customEyes: _customEyes, eyeExt: _eyeExt, eyeInt: _eyeInt,
      ).paint(canvas, const Size(exportSize, exportSize));
    }

    // Logo encima si hay
    if (_logoBytes != null && !isShape) {
      final codec = await ui.instantiateImageCodec(
        _logoBytes!,
        targetWidth: effLogo.toInt(),
        targetHeight: effLogo.toInt(),
      );
      final frame = await codec.getNextFrame();
      canvas.drawImage(
        frame.image,
        Offset((exportSize - effLogo) / 2, (exportSize - effLogo) / 2),
        Paint()..isAntiAlias = true,
      );
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(exportSize.toInt(), exportSize.toInt());
    final bd = await img.toByteData(format: ui.ImageByteFormat.png);
    return bd!.buffer.asUint8List();
  }

  /// Helper: offset para degradado según dirección
  Offset _gradOffset(String dir, bool start, double size) {
    if (dir == "Horizontal") return start ? Offset.zero : Offset(size, 0);
    if (dir == "Diagonal")   return start ? Offset.zero : Offset(size, size);
    return start ? Offset.zero : Offset(0, size); // Vertical
  }

  /// GUARDAR: SVG en documentos + PNG en galería
  Future<void> _exportar() async {
    try {
      // PNG → galería
      final pngBytes = await _renderPng();
      await ImageGallerySaver.saveImage(
        pngBytes,
        name: "QR_Logo_${DateTime.now().millisecondsSinceEpoch}",
      );

      // SVG → carpeta de documentos de la app
      final svg = _buildSvg();
      final svgBytes = Uint8List.fromList(utf8.encode(svg));
      final docsDir = await getApplicationDocumentsDirectory();
      final svgFile = File('${docsDir.path}/QR_Logo.svg');
      await svgFile.writeAsBytes(svgBytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ PNG guardado en galería · SVG en documentos"),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.black,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error al guardar: $e"),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// COMPARTIR: envía SVG + PNG juntos
  Future<void> _compartir() async {
    try {
      final tmpDir = await getTemporaryDirectory();

      // PNG
      final pngBytes = await _renderPng();
      final pngFile = File('${tmpDir.path}/QR_Logo.png');
      await pngFile.writeAsBytes(pngBytes);

      // SVG
      final svg = _buildSvg();
      final svgBytes = Uint8List.fromList(utf8.encode(svg));
      final svgFile = File('${tmpDir.path}/QR_Logo.svg');
      await svgFile.writeAsBytes(svgBytes);

      await Share.shareXFiles(
        [
          XFile(pngFile.path, mimeType: 'image/png'),
          XFile(svgFile.path, mimeType: 'image/svg+xml'),
        ],
        text: 'Generado con QR+Logo',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error al compartir: $e"),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

// ═══════════════════════════════════════════════════════════════════
// ENUM GLOBAL
// ═══════════════════════════════════════════════════════════════════
enum EyeStyle { rect, circ, diamond }

// ═══════════════════════════════════════════════════════════════════
// SECCIÓN 9: PINTOR MINIATURAS
// ═══════════════════════════════════════════════════════════════════
class StylePreviewPainter extends CustomPainter {
  final String style;
  final Color c1, c2;
  static const _demo = "https://qr.demo";

  const StylePreviewPainter({required this.style, required this.c1, required this.c2});

  @override
  void paint(Canvas canvas, Size size) {
    final qr = _buildQrImage(_demo);
    if (qr == null) return;
    final int m = qr.moduleCount;
    final double t = size.width / m;
    final paint = Paint()..isAntiAlias = true..color = c1;
    ui.Shader? grad;
    if (c1 != c2) {
      grad = ui.Gradient.linear(Offset.zero, Offset(size.width, size.height), [c1, c2]);
      paint.shader = grad;
    }
    const frac = 0.30;
    const s0 = (1.0 - frac) / 2.0;
    const s1 = s0 + frac;
    bool inCenter(int r, int c) {
      final nx = (c + 0.5) / m; final ny = (r + 0.5) / m;
      return nx >= s0 && nx <= s1 && ny >= s0 && ny <= s1;
    }
    bool isEye(int r, int c) => (r < 7 && c < 7) || (r < 7 && c >= m - 7) || (r >= m - 7 && c < 7);
    final lPath = Path();
    final lPaint = Paint()..isAntiAlias = true..style = PaintingStyle.stroke
        ..strokeWidth = t..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    if (grad != null) lPaint.shader = grad; else lPaint.color = c1;
    bool ok(int r, int c) {
      if (r < 0 || r >= m || c < 0 || c >= m) return false;
      if (!qr.isDark(r, c)) return false;
      if (isEye(r, c)) return false;
      if (inCenter(r, c)) return false;
      return true;
    }

    for (int r = 0; r < m; r++) {
      for (int c = 0; c < m; c++) {
        final double x = c * t, y = r * t, cx = x + t / 2, cy = y + t / 2;

        if (style.contains("Formas")) {
          if (!qr.isDark(r, c) || isEye(r, c)) continue;
          final double nx = (c + 0.5) / m - 0.5;
          final double ny = (r + 0.5) / m - 0.5;
          final double angle = math.atan2(nx, -ny);
          final double dist = math.sqrt(nx * nx + ny * ny);
          final double section = (angle / (2 * math.pi / 5)).floor() * (2 * math.pi / 5);
          final double relAngle = angle - section - math.pi / 5;
          final double limitR = 0.47 * math.cos(math.pi / 5) /
              math.cos(relAngle.clamp(-math.pi / 5, math.pi / 5));
          if (dist > limitR) continue;
          canvas.drawCircle(Offset(cx, cy), t * 0.38, paint);
          continue;
        }

        if (!ok(r, c)) continue;
        if (style.contains("Gusano")) {
          lPath.moveTo(cx, cy); lPath.lineTo(cx, cy);
          if (ok(r, c + 1)) { lPath.moveTo(cx, cy); lPath.lineTo(cx + t, cy); }
          if (ok(r + 1, c)) { lPath.moveTo(cx, cy); lPath.lineTo(cx, cy + t); }
        } else if (style.contains("Barras")) {
          if (r == 0 || !ok(r - 1, c)) {
            int er = r; while (er + 1 < m && ok(er + 1, c)) er++;
            final p2 = Paint()..isAntiAlias = true;
            if (grad != null) p2.shader = grad; else p2.color = c1;
            canvas.drawRRect(RRect.fromRectAndRadius(
                Rect.fromLTWH(x + t * 0.1, y, t * 0.8, (er - r + 1) * t),
                Radius.circular(t * 0.38)), p2);
          }
        } else if (style.contains("Puntos")) {
          final double h = ((r * 13 + c * 29) % 100) / 100.0;
          canvas.drawCircle(Offset(cx, cy), t * (0.35 + 0.13 * h), paint);
        } else if (style.contains("Rombos") || style.contains("Diamant")) {
          final double h = ((r * 17 + c * 31) % 100) / 100.0;
          final double sc = 0.65 + 0.45 * h; final double off = t * (1 - sc) / 2;
          canvas.drawPath(Path()..moveTo(cx, y + off)..lineTo(x + t - off, cy)
              ..lineTo(cx, y + t - off)..lineTo(x + off, cy)..close(), paint);
        } else if (style.contains("Split")) {
          final sp = c < m / 2
              ? (Paint()..isAntiAlias = true..color = c1..style = PaintingStyle.stroke..strokeWidth = t..strokeCap = StrokeCap.round)
              : (Paint()..isAntiAlias = true..color = c2..style = PaintingStyle.stroke..strokeWidth = t..strokeCap = StrokeCap.round);
          final pp = Path()..moveTo(cx, cy)..lineTo(cx, cy);
          if (ok(r, c + 1)) pp.lineTo(cx + t, cy);
          canvas.drawPath(pp, sp);
          if (ok(r + 1, c)) canvas.drawPath(Path()..moveTo(cx, cy)..lineTo(cx, cy + t), sp);
        } else {
          canvas.drawRect(Rect.fromLTWH(x, y, t + 0.3, t + 0.3), paint);
        }
      }
    }
    if (style.contains("Gusano")) canvas.drawPath(lPath, lPaint);
    final pE = Paint()..isAntiAlias = true;
    final pI = Paint()..isAntiAlias = true;
    if (grad != null) { pE.shader = grad; pI.shader = grad; } else { pE.color = c1; pI.color = c1; }
    EyeStyle es = EyeStyle.rect;
    if (style.contains("Puntos")) es = EyeStyle.circ;
    if (style.contains("Rombos") || style.contains("Diamant")) es = EyeStyle.diamond;
    void eye(double x, double y) {
      final s = 7 * t;
      if (es == EyeStyle.circ) {
        canvas.drawPath(Path()..addOval(Rect.fromLTWH(x, y, s, s))..addOval(Rect.fromLTWH(x + t, y + t, s - 2 * t, s - 2 * t))..fillType = PathFillType.evenOdd, pE);
        canvas.drawOval(Rect.fromLTWH(x + 2.1 * t, y + 2.1 * t, s - 4.2 * t, s - 4.2 * t), pI);
      } else if (es == EyeStyle.diamond) {
        final cx = x + 3.5 * t; final cy = y + 3.5 * t;
        canvas.drawPath(Path()..moveTo(cx, y)..lineTo(x + 7 * t, cy)..lineTo(cx, y + 7 * t)..lineTo(x, cy)..moveTo(cx, y + 1.2 * t)..lineTo(x + 5.8 * t, cy)..lineTo(cx, y + 5.8 * t)..lineTo(x + 1.2 * t, cy)..fillType = PathFillType.evenOdd, pE);
        canvas.drawPath(Path()..moveTo(cx, y + 2.2 * t)..lineTo(x + 4.8 * t, cy)..lineTo(cx, y + 4.8 * t)..lineTo(x + 2.2 * t, cy)..close(), pI);
      } else {
        canvas.drawPath(Path()..addRect(Rect.fromLTWH(x, y, s, s))..addRect(Rect.fromLTWH(x + t, y + t, s - 2 * t, s - 2 * t))..fillType = PathFillType.evenOdd, pE);
        canvas.drawRect(Rect.fromLTWH(x + 2.1 * t, y + 2.1 * t, s - 4.2 * t, s - 4.4 * t), pI);
      }
    }
    eye(0, 0); eye((m - 7) * t, 0); eye(0, (m - 7) * t);
  }

  @override
  bool shouldRepaint(StylePreviewPainter o) => o.c1 != c1 || o.c2 != c2 || o.style != style;
}

// ═══════════════════════════════════════════════════════════════════
// SECCIÓN 10: PINTOR QR BÁSICO
// ═══════════════════════════════════════════════════════════════════
class QrMasterPainter extends CustomPainter {
  final String data, estilo, qrMode, qrDir;
  final img_lib.Image? logoImage;
  final List<List<bool>>? outerMask;
  final double logoSize, auraSize;
  final bool customEyes;
  final Color qrC1, qrC2, eyeExt, eyeInt;

  const QrMasterPainter({
    required this.data, required this.estilo,
    required this.logoImage, required this.outerMask,
    required this.logoSize, required this.auraSize,
    required this.qrC1, required this.qrC2,
    required this.qrMode, required this.qrDir,
    required this.customEyes, required this.eyeExt, required this.eyeInt,
  });

  bool _isEye(int r, int c, int m) =>
      (r < 7 && c < 7) || (r < 7 && c >= m - 7) || (r >= m - 7 && c < 7);

  @override
  void paint(Canvas canvas, Size size) {
    final qr = _buildQrImage(data);
    if (qr == null) { _err(canvas, size); return; }
    final int m = qr.moduleCount;
    final double t = size.width / m;
    final double effLogo = logoSize.clamp(30.0, _safeLogoMax(modules: m, auraModules: auraSize));
    final paint = Paint()..isAntiAlias = true;
    ui.Shader? grad;
    if (qrMode != "Sólido (Un Color)") {
      var b = Alignment.topCenter, e = Alignment.bottomCenter;
      if (qrDir == "Horizontal") { b = Alignment.centerLeft; e = Alignment.centerRight; }
      if (qrDir == "Diagonal") { b = Alignment.topLeft; e = Alignment.bottomRight; }
      grad = ui.Gradient.linear(
          Offset(size.width * (b.x + 1) / 2, size.height * (b.y + 1) / 2),
          Offset(size.width * (e.x + 1) / 2, size.height * (e.y + 1) / 2),
          [qrC1, qrC2]);
      paint.shader = grad;
    } else { paint.color = qrC1; }
    final excl = List.generate(m, (_) => List.filled(m, false));
    if (logoImage != null && outerMask != null) {
      final lf = effLogo / 270.0; final ls = (1 - lf) / 2.0; final le = ls + lf;
      final base = List.generate(m, (_) => List.filled(m, false));
      for (int r = 0; r < m; r++) for (int c = 0; c < m; c++) {
        bool hit = false;
        for (double dy = 0.2; dy <= 0.8 && !hit; dy += 0.3)
          for (double dx = 0.2; dx <= 0.8 && !hit; dx += 0.3) {
            final nx = (c + dx) / m; final ny = (r + dy) / m;
            if (nx >= ls && nx <= le && ny >= ls && ny <= le) {
              final px = ((nx - ls) / lf * logoImage!.width).clamp(0, logoImage!.width - 1).toInt();
              final py = ((ny - ls) / lf * logoImage!.height).clamp(0, logoImage!.height - 1).toInt();
              if (outerMask![py][px]) hit = true;
            }
          }
        if (hit) base[r][c] = true;
      }
      final ar = auraSize.toInt();
      for (int r = 0; r < m; r++) for (int c = 0; c < m; c++)
        if (base[r][c]) for (int dr = -ar; dr <= ar; dr++) for (int dc = -ar; dc <= ar; dc++) {
          final nr = r + dr; final nc = c + dc;
          if (nr >= 0 && nr < m && nc >= 0 && nc < m) excl[nr][nc] = true;
        }
    }
    bool ok(int r, int c) {
      if (r < 0 || r >= m || c < 0 || c >= m) return false;
      if (!qr.isDark(r, c)) return false;
      if (_isEye(r, c, m) && estilo != "Normal (Cuadrado)") return false;
      if (excl[r][c]) return false;
      return true;
    }
    final lPath = Path();
    final lPaint = Paint()..isAntiAlias = true..style = PaintingStyle.stroke
        ..strokeWidth = t..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    if (grad != null) lPaint.shader = grad; else lPaint.color = qrC1;
    for (int r = 0; r < m; r++) for (int c = 0; c < m; c++) {
      if (!ok(r, c)) continue;
      final double x = c * t, y = r * t, cx = x + t / 2, cy = y + t / 2;
      if (estilo.contains("Gusano")) {
        lPath.moveTo(cx, cy); lPath.lineTo(cx, cy);
        if (ok(r, c + 1)) { lPath.moveTo(cx, cy); lPath.lineTo(cx + t, cy); }
        if (ok(r + 1, c)) { lPath.moveTo(cx, cy); lPath.lineTo(cx, cy + t); }
      } else if (estilo.contains("Barras")) {
        if (r == 0 || !ok(r - 1, c)) {
          int er = r; while (er + 1 < m && ok(er + 1, c)) er++;
          final p2 = Paint()..isAntiAlias = true;
          if (grad != null) p2.shader = grad; else p2.color = qrC1;
          canvas.drawRRect(RRect.fromRectAndRadius(
              Rect.fromLTWH(x + t * 0.1, y, t * 0.8, (er - r + 1) * t),
              Radius.circular(t * 0.38)), p2);
        }
      } else if (estilo.contains("Puntos")) {
        final double h = ((r * 13 + c * 29) % 100) / 100.0;
        canvas.drawCircle(Offset(cx, cy), t * (0.35 + 0.15 * h), paint);
      } else if (estilo.contains("Diamantes")) {
        final double h = ((r * 17 + c * 31) % 100) / 100.0;
        final double sc = 0.65 + 0.22 * h; final double off = t * (1 - sc) / 2;
        canvas.drawPath(Path()..moveTo(cx, y + off)..lineTo(x + t - off, cy)
            ..lineTo(cx, y + t - off)..lineTo(x + off, cy)..close(), paint);
      } else {
        canvas.drawRect(Rect.fromLTWH(x, y, t + 0.3, t + 0.3), paint);
      }
    }
    if (estilo.contains("Gusano")) canvas.drawPath(lPath, lPaint);
    final pE = Paint()..isAntiAlias = true;
    final pI = Paint()..isAntiAlias = true;
    if (customEyes) { pE.color = eyeExt; pI.color = eyeInt; }
    else if (grad != null) { pE.shader = grad; pI.shader = grad; }
    else { pE.color = qrC1; pI.color = qrC1; }
    EyeStyle es = EyeStyle.rect;
    if (estilo.contains("Puntos")) es = EyeStyle.circ;
    if (estilo.contains("Diamantes")) es = EyeStyle.diamond;
    _eye(canvas, 0, 0, t, pE, pI, es);
    _eye(canvas, (m - 7) * t, 0, t, pE, pI, es);
    _eye(canvas, 0, (m - 7) * t, t, pE, pI, es);
  }

  void _eye(Canvas c, double x, double y, double t, Paint pE, Paint pI, EyeStyle es) {
    final s = 7 * t;
    if (es == EyeStyle.circ) {
      c.drawPath(Path()..addOval(Rect.fromLTWH(x, y, s, s))..addOval(Rect.fromLTWH(x + t, y + t, s - 2 * t, s - 2 * t))..fillType = PathFillType.evenOdd, pE);
      c.drawOval(Rect.fromLTWH(x + 2.1 * t, y + 2.1 * t, s - 4.2 * t, s - 4.2 * t), pI);
    } else if (es == EyeStyle.diamond) {
      final cx = x + 3.5 * t; final cy = y + 3.5 * t;
      c.drawPath(Path()..moveTo(cx, y)..lineTo(x + 7 * t, cy)..lineTo(cx, y + 7 * t)..lineTo(x, cy)..moveTo(cx, y + 1.2 * t)..lineTo(x + 5.8 * t, cy)..lineTo(cx, y + 5.8 * t)..lineTo(x + 1.2 * t, cy)..fillType = PathFillType.evenOdd, pE);
      c.drawPath(Path()..moveTo(cx, y + 2.2 * t)..lineTo(x + 4.8 * t, cy)..lineTo(cx, y + 4.8 * t)..lineTo(x + 2.2 * t, cy)..close(), pI);
    } else {
      c.drawPath(Path()..addRect(Rect.fromLTWH(x, y, s, s))..addRect(Rect.fromLTWH(x + t, y + t, s - 2 * t, s - 2 * t))..fillType = PathFillType.evenOdd, pE);
      c.drawRect(Rect.fromLTWH(x + 2.1 * t, y + 2.1 * t, s - 4.2 * t, s - 4.4 * t), pI);
    }
  }

  void _err(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = Colors.red.withOpacity(0.08));
    final tp = TextPainter(
        text: const TextSpan(text: 'Contenido\ndemasiado largo',
            style: TextStyle(color: Colors.red, fontSize: 15, fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr, textAlign: TextAlign.center)
      ..layout(maxWidth: size.width);
    tp.paint(canvas, Offset((size.width - tp.width) / 2, (size.height - tp.height) / 2));
  }

  @override bool shouldRepaint(CustomPainter o) => true;
}

// ═══════════════════════════════════════════════════════════════════
// SECCIÓN 11: PINTOR QR AVANZADO
// ═══════════════════════════════════════════════════════════════════
class QrAdvancedPainter extends CustomPainter {
  final String data, estiloAvanzado, mapSubStyle, advSubStyle, splitDir, qrMode, qrDir;
  final img_lib.Image? logoImage, shapeImage;
  final List<List<bool>>? outerMask, shapeMask;
  final double logoSize, auraSize, shapeGap;
  final bool customEyes;
  final Color qrC1, qrC2, eyeExt, eyeInt;

  const QrAdvancedPainter({
    required this.data,
    required this.estiloAvanzado,
    required this.mapSubStyle,
    required this.advSubStyle,
    required this.splitDir,
    required this.logoImage,
    required this.outerMask,
    required this.shapeImage,
    required this.shapeMask,
    required this.logoSize,
    required this.auraSize,
    required this.shapeGap,
    required this.qrC1,
    required this.qrC2,
    required this.qrMode,
    required this.qrDir,
    required this.customEyes,
    required this.eyeExt,
    required this.eyeInt,
  });

  bool _isEye(int r, int c, int m) =>
      (r < 7 && c < 7) || (r < 7 && c >= m - 7) || (r >= m - 7 && c < 7);

  void _drawEye(Canvas canvas, double ox, double oy, double t, Paint pE, Paint pI, EyeStyle es) {
    final s = 7 * t;
    if (es == EyeStyle.circ) {
      canvas.drawPath(Path()..addOval(Rect.fromLTWH(ox, oy, s, s))..addOval(Rect.fromLTWH(ox + t, oy + t, s - 2 * t, s - 2 * t))..fillType = PathFillType.evenOdd, pE);
      canvas.drawOval(Rect.fromLTWH(ox + 2.1 * t, oy + 2.1 * t, s - 4.2 * t, s - 4.2 * t), pI);
    } else if (es == EyeStyle.diamond) {
      final cx = ox + 3.5 * t; final cy = oy + 3.5 * t;
      canvas.drawPath(Path()..moveTo(cx, oy)..lineTo(ox + 7 * t, cy)..lineTo(cx, oy + 7 * t)..lineTo(ox, cy)..moveTo(cx, oy + 1.2 * t)..lineTo(ox + 5.8 * t, cy)..lineTo(cx, oy + 5.8 * t)..lineTo(ox + 1.2 * t, cy)..fillType = PathFillType.evenOdd, pE);
      canvas.drawPath(Path()..moveTo(cx, oy + 2.2 * t)..lineTo(ox + 4.8 * t, cy)..lineTo(cx, oy + 4.8 * t)..lineTo(ox + 2.2 * t, cy)..close(), pI);
    } else {
      canvas.drawPath(Path()..addRect(Rect.fromLTWH(ox, oy, s, s))..addRect(Rect.fromLTWH(ox + t, oy + t, s - 2 * t, s - 2 * t))..fillType = PathFillType.evenOdd, pE);
      canvas.drawRect(Rect.fromLTWH(ox + 2.1 * t, oy + 2.1 * t, s - 4.2 * t, s - 4.4 * t), pI);
    }
  }

  List<List<bool>> _buildLogoExcl(int m, double t) {
    final excl = List.generate(m, (_) => List.filled(m, false));
    if (logoImage == null || outerMask == null || logoSize <= 0) return excl;
    final effLogo = logoSize.clamp(30.0, _safeLogoMax(modules: m, auraModules: auraSize));
    final canvasSize = m * t;
    final lf = effLogo / canvasSize;
    final ls = (1 - lf) / 2.0; final le = ls + lf;
    final base = List.generate(m, (_) => List.filled(m, false));
    for (int r = 0; r < m; r++) for (int c = 0; c < m; c++) {
      bool hit = false;
      for (double dy = 0.2; dy <= 0.8 && !hit; dy += 0.3)
        for (double dx = 0.2; dx <= 0.8 && !hit; dx += 0.3) {
          final nx = (c + dx) / m; final ny = (r + dy) / m;
          if (nx >= ls && nx <= le && ny >= ls && ny <= le) {
            final px = ((nx - ls) / lf * logoImage!.width).clamp(0, logoImage!.width - 1).toInt();
            final py = ((ny - ls) / lf * logoImage!.height).clamp(0, logoImage!.height - 1).toInt();
            if (outerMask![py][px]) hit = true;
          }
        }
      if (hit) base[r][c] = true;
    }
    final ar = auraSize.toInt();
    for (int r = 0; r < m; r++) for (int c = 0; c < m; c++)
      if (base[r][c]) for (int dr = -ar; dr <= ar; dr++) for (int dc = -ar; dc <= ar; dc++) {
        final nr = r + dr; final nc = c + dc;
        if (nr >= 0 && nr < m && nc >= 0 && nc < m) excl[nr][nc] = true;
      }
    return excl;
  }

  List<List<bool>> _buildCanvasShapeMask(int width, int height) {
    final canvasMask = List.generate(height, (_) => List.filled(width, false));
    if (shapeMask == null || shapeMask!.isEmpty || shapeMask![0].isEmpty) return canvasMask;
    final int sh = shapeMask!.length; final int sw = shapeMask![0].length;
    final double scale = math.min(width / sw, height / sh);
    final double drawW = sw * scale; final double drawH = sh * scale;
    final double offX = (width - drawW) / 2.0; final double offY = (height - drawH) / 2.0;
    for (int y = 0; y < height; y++) for (int x = 0; x < width; x++) {
      final double sx = ((x + 0.5) - offX) / scale;
      final double sy = ((y + 0.5) - offY) / scale;
      if (sx >= 0 && sx < sw && sy >= 0 && sy < sh) {
        canvasMask[y][x] = shapeMask![sy.floor().clamp(0, sh - 1)][sx.floor().clamp(0, sw - 1)];
      } else { canvasMask[y][x] = false; }
    }
    return canvasMask;
  }

  Rect? _findBestQrSquare(List<List<bool>> canvasMask, {required int minSide, int step = 2}) {
    final int h = canvasMask.length;
    if (h == 0) return null;
    final int w = canvasMask[0].length;
    if (w == 0) return null;
    final prefix = List.generate(h + 1, (_) => List.filled(w + 1, 0));
    for (int y = 0; y < h; y++) {
      int rowAcc = 0;
      for (int x = 0; x < w; x++) {
        rowAcc += canvasMask[y][x] ? 1 : 0;
        prefix[y + 1][x + 1] = prefix[y][x + 1] + rowAcc;
      }
    }
    int areaSum(int left, int top, int side) {
      final int right = left + side; final int bottom = top + side;
      return prefix[bottom][right] - prefix[top][right] - prefix[bottom][left] + prefix[top][left];
    }
    final int maxSide = math.min(w, h);
    final int safeMin = minSide.clamp(1, maxSide).toInt();
    for (int side = maxSide; side >= safeMin; side -= step) {
      Rect? best; double bestDist = double.infinity;
      final int required = (side * side * 0.88).round();
      for (int top = 0; top <= h - side; top += step)
        for (int left = 0; left <= w - side; left += step) {
          if (areaSum(left, top, side) < required) continue;
          final double cx = left + side / 2.0, cy = top + side / 2.0;
          final double dx = cx - w / 2.0, dy = cy - h / 2.0;
          final double dist = dx * dx + dy * dy;
          if (dist < bestDist) { bestDist = dist; best = Rect.fromLTWH(left.toDouble(), top.toDouble(), side.toDouble(), side.toDouble()); }
        }
      if (best != null) return best;
    }
    return null;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final qr = _buildQrImage(data);
    if (qr == null) return;
    final int m = qr.moduleCount;
    final double t = size.width / m;

    final bool isShape = estiloAvanzado.contains("Forma") ||
        estiloAvanzado.contains("Mapa") || estiloAvanzado == "Formas (Máscara)";
    final bool isSplit = estiloAvanzado.contains("Split");

    ui.Shader? grad;
    if (qrMode == "Degradado Custom") {
      var b = Alignment.topCenter, e = Alignment.bottomCenter;
      if (qrDir == "Horizontal") { b = Alignment.centerLeft; e = Alignment.centerRight; }
      if (qrDir == "Diagonal") { b = Alignment.topLeft; e = Alignment.bottomRight; }
      grad = ui.Gradient.linear(
          Offset(size.width * (b.x + 1) / 2, size.height * (b.y + 1) / 2),
          Offset(size.width * (e.x + 1) / 2, size.height * (e.y + 1) / 2),
          [qrC1, qrC2]);
    }

    final solidPaint = Paint()..isAntiAlias = true;
    if (grad != null) solidPaint.shader = grad; else solidPaint.color = qrC1;

    final pE = Paint()..isAntiAlias = true;
    final pI = Paint()..isAntiAlias = true;
    if (customEyes) { pE.color = eyeExt; pI.color = eyeInt; }
    else if (grad != null) { pE.shader = grad; pI.shader = grad; }
    else { pE.color = qrC1; pI.color = qrC1; }

    if (isShape) {
      final int maskW = math.max(size.width.round(), 1);
      final int maskH = math.max(size.height.round(), 1);
      final canvasMask = _buildCanvasShapeMask(maskW, maskH);

      int qrDataCells = 0;
      int qrDarkCells = 0;
      for (int r = 0; r < m; r++) {
        for (int c = 0; c < m; c++) {
          if (_isEye(r, c, m)) continue;
          qrDataCells++;
          if (qr.isDark(r, c)) qrDarkCells++;
        }
      }
      final double qrDarkRatio =
          qrDataCells == 0 ? 0.50 : (qrDarkCells / qrDataCells);

      bool insideShapePoint(double px, double py) {
        final int x = px.floor().clamp(0, maskW - 1).toInt();
        final int y = py.floor().clamp(0, maskH - 1).toInt();
        return canvasMask[y][x];
      }

      double rectCoverage(Rect rect) {
        const probes = [0.12, 0.30, 0.50, 0.70, 0.88];
        int ok = 0;
        int total = 0;
        for (final py in probes) {
          for (final px in probes) {
            total++;
            if (insideShapePoint(
              rect.left + rect.width * px,
              rect.top + rect.height * py,
            )) {
              ok++;
            }
          }
        }
        return total == 0 ? 0.0 : ok / total;
      }

      bool rectMostlyInsideShape(Rect rect, {double minCoverage = 0.68}) {
        return rectCoverage(rect) >= minCoverage;
      }

      int minSX = maskW;
      int minSY = maskH;
      int maxSX = 0;
      int maxSY = 0;
      int shapeCount = 0;
      double sumSX = 0;
      double sumSY = 0;

      for (int y = 0; y < maskH; y++) {
        for (int x = 0; x < maskW; x++) {
          if (!canvasMask[y][x]) continue;
          shapeCount++;
          sumSX += x + 0.5;
          sumSY += y + 0.5;
          if (x < minSX) minSX = x;
          if (x > maxSX) maxSX = x;
          if (y < minSY) minSY = y;
          if (y > maxSY) maxSY = y;
        }
      }

      final Rect shapeBounds = shapeCount == 0
          ? Rect.fromLTWH(0, 0, size.width, size.height)
          : Rect.fromLTRB(
              minSX.toDouble(),
              minSY.toDouble(),
              (maxSX + 1).toDouble(),
              (maxSY + 1).toDouble(),
            );

      final Offset shapeCenter = shapeCount == 0
          ? Offset(size.width / 2, size.height / 2)
          : Offset(sumSX / shapeCount, sumSY / shapeCount);

      double expandedCoverage(Rect rect, double extraPx) {
        return rectCoverage(rect.inflate(extraPx));
      }

      Rect? qrBox;
      double bestScore = -1e18;

final double aspectRatio = shapeBounds.width / math.max(shapeBounds.height, 1.0);
      final bool isNarrowShape = aspectRatio < 0.6 || aspectRatio > 1.6;
      final double maxCandidateSide = isNarrowShape
          ? math.min(shapeBounds.width, shapeBounds.height) * 0.88
          : math.min(shapeBounds.width, shapeBounds.height) * 0.78;

final double minCandidateSide = math.max(
  48.0,
  (m + 2) * 1.80,
);

for (double side = maxCandidateSide; side >= minCandidateSide; side -= 5.0) {
  final double step = math.max(3.0, side * 0.045);
  final double safetyPad = side * (0.18 + (shapeGap.clamp(0.0, 3.0) * 0.04));

  for (double top = shapeBounds.top; top <= shapeBounds.bottom - side; top += step) {
    for (double left = shapeBounds.left; left <= shapeBounds.right - side; left += step) {
      final Rect rect = Rect.fromLTWH(left, top, side, side);

      final double cov = rectCoverage(rect);
      final double minCov = isNarrowShape ? 0.62 : 0.88;
      if (cov < minCov) continue;

      final double safeCov = expandedCoverage(rect, safetyPad);
      final double minSafeCov = isNarrowShape ? 0.48 : 0.70;
      if (safeCov < minSafeCov) continue;

      // Verificar que las 3 zonas de ojos estén dentro de la silueta
// Los 3 ojos deben estar 100% dentro de la silueta
      final double eyeW = side * 7.0 / (m + 2.0);
      bool eyeStrictlyInside(double ex, double ey) {
        for (final fy in [0.05, 0.25, 0.5, 0.75, 0.95])
          for (final fx in [0.05, 0.25, 0.5, 0.75, 0.95])
            if (!insideShapePoint(ex + fx * eyeW, ey + fy * eyeW)) return false;
        return true;
      }
      if (!eyeStrictlyInside(left, top)) continue;
      if (!eyeStrictlyInside(left + side - eyeW, top)) continue;
      if (!eyeStrictlyInside(left, top + side - eyeW)) continue;

      final double dx = rect.center.dx - shapeCenter.dx;
      final double dy = rect.center.dy - shapeCenter.dy;
      final double centerPenalty = (dx * dx + dy * dy) / (side * side);

      double edgePenalty = 0.0;
      if (rect.left - shapeBounds.left < side * 0.10) edgePenalty += 0.22;
      if (shapeBounds.right - rect.right < side * 0.10) edgePenalty += 0.22;
      if (rect.top - shapeBounds.top < side * 0.14) edgePenalty += 0.34;
      if (shapeBounds.bottom - rect.bottom < side * 0.10) edgePenalty += 0.20;

      final double score =
          (side * 0.045) +
          (cov * 2.9) +
          (safeCov * 4.2) -
          (centerPenalty * 1.30) -
          edgePenalty;

      if (score > bestScore) {
        bestScore = score;
        qrBox = rect;
      }
    }
  }
}

qrBox ??= Rect.fromCenter(
  center: shapeCenter,
  width: math.min(size.width, size.height) * 0.48,
  height: math.min(size.width, size.height) * 0.48,
);

      final Rect qrBoxFinal = qrBox!;

      final double gapModules = shapeGap.clamp(0.0, 3.0);
      final double probeQt = qrBoxFinal.width / (m + 2.0);

      final double embedInsetModules = 1.10 + gapModules * 0.55;
      final double embedInsetPx = math.min(
        probeQt * embedInsetModules,
        qrBoxFinal.width * 0.18,
      );

      final Rect embeddedBox = qrBoxFinal.deflate(embedInsetPx);

      const double quietModules = 0.35;
      final double qt = embeddedBox.width / (m + quietModules * 2.0);

      final Rect qrDataRect = Rect.fromLTWH(
        embeddedBox.left + qt * quietModules,
        embeddedBox.top + qt * quietModules,
        qt * m,
        qt * m,
      );

      final Rect quietRect = qrDataRect.inflate(qt * gapModules);

      final bool isLiquid =
          mapSubStyle.contains("Gusano") || mapSubStyle.contains("Liquid");
      final bool isBars = mapSubStyle.contains("Barras");
      final bool isDots = mapSubStyle.contains("Puntos");
      final bool isDiamonds = mapSubStyle.contains("Diamantes");

      double targetDensity = qrDarkRatio;
      if (isBars) targetDensity += 0.02;
      if (isDots || isDiamonds) targetDensity -= 0.01;
      targetDensity = targetDensity.clamp(0.22, 0.80);

      int hashCell(int rr, int cc) {
        int v = ((rr + 101) * 73856093) ^
            ((cc + 211) * 19349663) ^
            ((m + 307) * 83492791);
        v ^= (v >> 13);
        v ^= (v << 7);
        return v & 0x7fffffff;
      }

      final double decoStep = qt;
      final double originX = qrDataRect.left;
      final double originY = qrDataRect.top;

      final int minCol = (((0.0 - originX) / decoStep).floor()) - 2;
      final int maxCol = (((size.width - originX) / decoStep).ceil()) + 2;
      final int minRow = (((0.0 - originY) / decoStep).floor()) - 2;
      final int maxRow = (((size.height - originY) / decoStep).ceil()) + 2;

      final Map<String, bool> active = <String, bool>{};

      String key(int rr, int cc) => '$rr:$cc';

      bool cellAllowed(int rr, int cc) {
        final Rect cellRect = Rect.fromLTWH(
          originX + cc * decoStep,
          originY + rr * decoStep,
          decoStep,
          decoStep,
        );

        if (cellRect.right <= 0 ||
            cellRect.bottom <= 0 ||
            cellRect.left >= size.width ||
            cellRect.top >= size.height) {
          return false;
        }

        if (cellRect.overlaps(quietRect)) return false;

        if (!rectMostlyInsideShape(cellRect, minCoverage: 0.60)) {
          return false;
        }

        return true;
      }

      for (int rr = minRow; rr <= maxRow; rr++) {
        for (int cc = minCol; cc <= maxCol; cc++) {
          if (!cellAllowed(rr, cc)) {
            active[key(rr, cc)] = false;
            continue;
          }
          final double v = (hashCell(rr, cc) % 1000) / 1000.0;
          active[key(rr, cc)] = v < targetDensity;
        }
      }

      bool on(int rr, int cc) => active[key(rr, cc)] ?? false;

      if (isBars) {
        for (int cc = minCol; cc <= maxCol; cc++) {
          for (int rr = minRow; rr <= maxRow; rr++) {
            if (!on(rr, cc)) continue;
            if (on(rr - 1, cc)) continue;

            int endR = rr;
            while (on(endR + 1, cc)) {
              endR++;
            }

            final Rect barRect = Rect.fromLTWH(
              originX + cc * decoStep + decoStep * 0.10,
              originY + rr * decoStep,
              decoStep * 0.80,
              (endR - rr + 1) * decoStep,
            );

            canvas.drawRRect(
              RRect.fromRectAndRadius(
                barRect,
                Radius.circular(decoStep * 0.38),
              ),
              solidPaint,
            );
          }
        }
      } else if (isLiquid) {
        final decoLiquidPen = Paint()
          ..isAntiAlias = true
          ..style = PaintingStyle.stroke
          ..strokeWidth = decoStep
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

        if (grad != null) {
          decoLiquidPen.shader = grad;
        } else {
          decoLiquidPen.color = qrC1;
        }

        final Path decoPath = Path();

        for (int rr = minRow; rr <= maxRow; rr++) {
          for (int cc = minCol; cc <= maxCol; cc++) {
            if (!on(rr, cc)) continue;

            final double x = originX + cc * decoStep;
            final double y = originY + rr * decoStep;
            final double cx = x + decoStep / 2;
            final double cy = y + decoStep / 2;

            decoPath.moveTo(cx, cy);
            decoPath.lineTo(cx, cy);

            if (on(rr, cc + 1)) {
              decoPath.moveTo(cx, cy);
              decoPath.lineTo(cx + decoStep, cy);
            }

            if (on(rr + 1, cc)) {
              decoPath.moveTo(cx, cy);
              decoPath.lineTo(cx, cy + decoStep);
            }
          }
        }

        canvas.drawPath(decoPath, decoLiquidPen);
      } else {
        for (int rr = minRow; rr <= maxRow; rr++) {
          for (int cc = minCol; cc <= maxCol; cc++) {
            if (!on(rr, cc)) continue;

            final double x = originX + cc * decoStep;
            final double y = originY + rr * decoStep;
            final double cx = x + decoStep / 2;
            final double cy = y + decoStep / 2;

            if (isDots) {
              final double h = (hashCell(rr, cc) % 100) / 100.0;
              canvas.drawCircle(
                Offset(cx, cy),
                decoStep * (0.35 + 0.15 * h),
                solidPaint,
              );
            } else if (isDiamonds) {
              final double h = (hashCell(rr, cc) % 100) / 100.0;
              final double sc = 0.65 + 0.22 * h;
              final double off = decoStep * (1 - sc) / 2;
              canvas.drawPath(
                Path()
                  ..moveTo(cx, y + off)
                  ..lineTo(x + decoStep - off, cy)
                  ..lineTo(cx, y + decoStep - off)
                  ..lineTo(x + off, cy)
                  ..close(),
                solidPaint,
              );
            } else {
              canvas.drawRect(
                Rect.fromLTWH(x, y, decoStep + 0.2, decoStep + 0.2),
                solidPaint,
              );
            }
          }
        }
      }

      final qrLiquidPen = Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = qt
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      if (grad != null) {
        qrLiquidPen.shader = grad;
      } else {
        qrLiquidPen.color = qrC1;
      }

      bool darkOk(int r, int c) {
        if (r < 0 || r >= m || c < 0 || c >= m) return false;
        if (!qr.isDark(r, c)) return false;
        if (_isEye(r, c, m)) return false;
        return true;
      }

      EyeStyle eyeStyle = EyeStyle.rect;
      if (mapSubStyle.contains("Puntos")) eyeStyle = EyeStyle.circ;
      if (mapSubStyle.contains("Diamantes")) eyeStyle = EyeStyle.diamond;

      final Path qrPath = Path();

      for (int r = 0; r < m; r++) {
        for (int c = 0; c < m; c++) {
          if (!darkOk(r, c)) continue;

          final double x = qrDataRect.left + c * qt;
          final double y = qrDataRect.top + r * qt;
          final double cx = x + qt / 2;
          final double cy = y + qt / 2;

          if (isLiquid) {
            qrPath.moveTo(cx, cy);
            qrPath.lineTo(cx, cy);

            if (darkOk(r, c + 1)) {
              qrPath.moveTo(cx, cy);
              qrPath.lineTo(cx + qt, cy);
            }

            if (darkOk(r + 1, c)) {
              qrPath.moveTo(cx, cy);
              qrPath.lineTo(cx, cy + qt);
            }
          } else if (isBars) {
            if (r == 0 || !darkOk(r - 1, c)) {
              int er = r;
              while (er + 1 < m && darkOk(er + 1, c)) {
                er++;
              }

              canvas.drawRRect(
                RRect.fromRectAndRadius(
                  Rect.fromLTWH(
                    x + qt * 0.10,
                    y,
                    qt * 0.80,
                    (er - r + 1) * qt,
                  ),
                  Radius.circular(qt * 0.38),
                ),
                solidPaint,
              );
            }
          } else if (isDots) {
            final double h = ((r * 13 + c * 29) % 100) / 100.0;
            canvas.drawCircle(
              Offset(cx, cy),
              qt * (0.35 + 0.15 * h),
              solidPaint,
            );
          } else if (isDiamonds) {
            final double h = ((r * 17 + c * 31) % 100) / 100.0;
            final double sc = 0.65 + 0.22 * h;
            final double off = qt * (1 - sc) / 2;
            canvas.drawPath(
              Path()
                ..moveTo(cx, y + off)
                ..lineTo(x + qt - off, cy)
                ..lineTo(cx, y + qt - off)
                ..lineTo(x + off, cy)
                ..close(),
              solidPaint,
            );
          } else {
            canvas.drawRect(
              Rect.fromLTWH(x, y, qt + 0.2, qt + 0.2),
              solidPaint,
            );
          }
        }
      }

      if (isLiquid) {
        canvas.drawPath(qrPath, qrLiquidPen);
      }

      _drawEye(canvas, qrDataRect.left, qrDataRect.top, qt, pE, pI, eyeStyle);
      _drawEye(
        canvas,
        qrDataRect.right - 7 * qt,
        qrDataRect.top,
        qt,
        pE,
        pI,
        eyeStyle,
      );
      _drawEye(
        canvas,
        qrDataRect.left,
        qrDataRect.bottom - 7 * qt,
        qt,
        pE,
        pI,
        eyeStyle,
      );
    } else if (isSplit) {
          
      final excl = _buildLogoExcl(m, t);

      EyeStyle eyeStyle = EyeStyle.rect;
      if (advSubStyle.contains("Puntos")) eyeStyle = EyeStyle.circ;
      if (advSubStyle.contains("Diamantes")) eyeStyle = EyeStyle.diamond;

      bool isSide1(int r, int c) {
        if (splitDir == "Horizontal") return r < m / 2;
        if (splitDir == "Diagonal") return (r + c) < m;
        return c < m / 2;
      }

      bool sameGroupNeighbor(int r, int c, int r2, int c2) {
        if (r2 < 0 || r2 >= m || c2 < 0 || c2 >= m) return false;
        return isSide1(r, c) == isSide1(r2, c2);
      }

      final pen1 = Paint()..isAntiAlias = true..style = PaintingStyle.stroke
          ..strokeWidth = t..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
      final pen2 = Paint()..isAntiAlias = true..style = PaintingStyle.stroke
          ..strokeWidth = t..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;

      if (grad != null) { pen1.shader = grad; pen2.shader = grad; }
      else { pen1.color = qrC1; pen2.color = qrC2; }

      bool darkOk(int r, int c) {
        if (r < 0 || r >= m || c < 0 || c >= m) return false;
        if (!qr.isDark(r, c)) return false;
        if (_isEye(r, c, m)) return false;
        if (excl[r][c]) return false;
        return true;
      }

      final bool isLiquid = advSubStyle.contains("Gusano") || advSubStyle.contains("Liquid");
      final bool isBars = advSubStyle.contains("Barras");
      final bool isDots = advSubStyle.contains("Puntos");
      final bool isDiamonds = advSubStyle.contains("Diamantes");

      final path1 = Path(), path2 = Path();

      for (int r = 0; r < m; r++) for (int c = 0; c < m; c++) {
        if (!darkOk(r, c)) continue;
        final double x = c * t, y = r * t, cx = x + t / 2, cy = y + t / 2;
        final bool side1 = isSide1(r, c);
        final Paint sp = side1 ? (Paint()..isAntiAlias=true..color=qrC1) : (Paint()..isAntiAlias=true..color=qrC2);

        if (isLiquid) {
          final Path ap = side1 ? path1 : path2;
          ap.moveTo(cx, cy); ap.lineTo(cx, cy);
          if (darkOk(r, c + 1) && sameGroupNeighbor(r, c, r, c + 1)) { ap.moveTo(cx, cy); ap.lineTo(cx + t, cy); }
          if (darkOk(r + 1, c) && sameGroupNeighbor(r, c, r + 1, c)) { ap.moveTo(cx, cy); ap.lineTo(cx, cy + t); }
        } else if (isBars) {
          if (r == 0 || !darkOk(r - 1, c)) {
            int er = r; while (er + 1 < m && darkOk(er + 1, c) && isSide1(er + 1, c) == side1) er++;
            canvas.drawRRect(RRect.fromRectAndRadius(
                Rect.fromLTWH(x + t * 0.10, y, t * 0.80, (er - r + 1) * t),
                Radius.circular(t * 0.38)), sp);
          }
        } else if (isDots) {
          final double h = ((r * 13 + c * 29) % 100) / 100.0;
          canvas.drawCircle(Offset(cx, cy), t * (0.35 + 0.15 * h), sp);
        } else if (isDiamonds) {
          final double h = ((r * 17 + c * 31) % 100) / 100.0;
          final double sc = 0.65 + 0.22 * h; final double off = t * (1 - sc) / 2;
          canvas.drawPath(Path()..moveTo(cx, y + off)..lineTo(x + t - off, cy)
              ..lineTo(cx, y + t - off)..lineTo(x + off, cy)..close(), sp);
        } else {
          canvas.drawRect(Rect.fromLTWH(x, y, t + 0.2, t + 0.2), sp);
        }
      }

      if (isLiquid) {
        canvas.drawPath(path1, pen1);
        canvas.drawPath(path2, pen2);
      }

      _drawEye(canvas, 0, 0, t, pE, pI, eyeStyle);
      _drawEye(canvas, (m - 7) * t, 0, t, pE, pI, eyeStyle);
      _drawEye(canvas, 0, (m - 7) * t, t, pE, pI, eyeStyle);
    }
  }

  @override bool shouldRepaint(CustomPainter o) => true;
}

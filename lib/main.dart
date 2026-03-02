import 'package:flutter/material.dart';
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
      const MaterialApp(
        title: 'QR+Logo',
        home: SplashScreen(),
        debugShowCheckedModeBanner: false,
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

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Image.asset(
            'assets/app_icon.png',
            width: 180,
            errorBuilder: (c, e, s) => const Icon(Icons.qr_code_2, size: 100),
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

  String _qrType = "Sitio Web (URL)";
  String _estilo = "Liquid Pro (Gusano)";
  String _estiloAvz = "Formas Básicas";
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
  String _mapSubStyle = "Liquid Pro (Gusano)";

  // NUEVO: sub-estilos para Split y Circular (separados de Formas)
  String _advSubStyle = "Liquid Pro (Gusano)";

// NUEVO: forma predefinida para "Formas Básicas"
String _basicShapeType = "Círculo";

// NUEVO: dirección del split
String _splitDir = "Vertical";

  late TabController _tabCtrl;
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
  "Formas Básicas",
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
      
  static const _basicShapeOptions = [
  "Círculo",
  "Triángulo",
  "Estrella",
  "Rombo",
  "Pentágono",
  "Flecha",
];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _c1.dispose();
    _c2.dispose();
    _c3.dispose();
    _c4.dispose();
    _c5.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  double _effectiveLogo(bool isShape) {
    if (isShape) return 0.0;

    final data = _getFinalData();
    if (data.isEmpty) return _logoSize;

    final qr = _buildQrImage(data);
    if (qr == null) return _logoSize;

    final maxPx = math.max(
      30.0,
      _safeLogoMax(modules: qr.moduleCount, auraModules: _auraSize),
    );

    return _logoSize.clamp(30.0, maxPx);
  }

  Future<void> _processLogo(File file) async {
    final bytes = await file.readAsBytes();
    img_lib.Image? img = img_lib.decodeImage(bytes);
    if (img == null) return;

    img = img.convert(numChannels: 4);

    final ext = file.path.toLowerCase();
    if (ext.endsWith('.jpg') || ext.endsWith('.jpeg')) {
      img = _removeWhiteBg(img);
    }

    final w = img.width;
    final h = img.height;

    final rB = List.generate(h, (_) => List.filled(w, false));
    for (int y = 0; y < h; y++) {
      int fx = -1, lx = -1;
      for (int x = 0; x < w; x++) {
        if (img.getPixel(x, y).a > 30) {
          if (fx == -1) fx = x;
          lx = x;
        }
      }
      if (fx != -1) {
        for (int x = fx; x <= lx; x++) {
          rB[y][x] = true;
        }
      }
    }

    final mask = List.generate(h, (_) => List.filled(w, false));
    for (int x = 0; x < w; x++) {
      int fy = -1, ly = -1;
      for (int y = 0; y < h; y++) {
        if (img.getPixel(x, y).a > 30) {
          if (fy == -1) fy = y;
          ly = y;
        }
      }
      if (fy != -1) {
        for (int y = fy; y <= ly; y++) {
          if (rB[y][x]) mask[y][x] = true;
        }
      }
    }

    final png = Uint8List.fromList(img_lib.encodePng(img));
    final palette = await PaletteGenerator.fromImageProvider(MemoryImage(png));

    setState(() {
      _logoBytes = png;
      _logoImage = img;
      _outerMask = mask;

      _qrC1 = palette.darkVibrantColor?.color ??
          palette.darkMutedColor?.color ??
          palette.dominantColor?.color ??
          Colors.black;

      _qrC2 =
          palette.vibrantColor?.color ?? palette.lightVibrantColor?.color ?? _qrC1;

      _qrColorMode = "Automático (Logo)";
    });
  }

  bool _hasRealTransparency(img_lib.Image src) {
    final total = src.width * src.height;
    int transparentPixels = 0;
    for (int y = 0; y < src.height; y++) {
      for (int x = 0; x < src.width; x++) {
        if (src.getPixel(x, y).a < 245) transparentPixels++;
      }
    }
    return transparentPixels > (total * 0.005);
  }

  img_lib.Image _removeEdgeBackground(img_lib.Image src) {
    final w = src.width, h = src.height;
    int sumR = 0, sumG = 0, sumB = 0, count = 0;

    void sample(int x, int y) {
      final p = src.getPixel(x, y);
      sumR += p.r.toInt();
      sumG += p.g.toInt();
      sumB += p.b.toInt();
      count++;
    }

    for (int x = 0; x < w; x++) {
      sample(x, 0);
      if (h > 1) sample(x, h - 1);
    }
    for (int y = 1; y < h - 1; y++) {
      sample(0, y);
      if (w > 1) sample(w - 1, y);
    }

    final double bgR = sumR / count;
    final double bgG = sumG / count;
    final double bgB = sumB / count;
    const double tol = 68.0;
    final double tol2 = tol * tol;

    bool isBg(img_lib.Pixel p) {
      final dr = p.r.toDouble() - bgR;
      final dg = p.g.toDouble() - bgG;
      final db = p.b.toDouble() - bgB;
      final dist2 = dr * dr + dg * dg + db * db;
      final nearAverage = dist2 <= tol2;
      final nearWhite = p.r > 242 && p.g > 242 && p.b > 242;
      return nearAverage || nearWhite;
    }

    final visited = List.generate(h, (_) => List.filled(w, false));
    final queue = <List<int>>[];

    void enqueue(int x, int y) {
      if (x < 0 || x >= w || y < 0 || y >= h) return;
      if (visited[y][x]) return;
      final p = src.getPixel(x, y);
      if (!isBg(p)) return;
      visited[y][x] = true;
      queue.add([x, y]);
    }

    for (int x = 0; x < w; x++) {
      enqueue(x, 0);
      enqueue(x, h - 1);
    }
    for (int y = 0; y < h; y++) {
      enqueue(0, y);
      enqueue(w - 1, y);
    }

    while (queue.isNotEmpty) {
      final p = queue.removeLast();
      final x = p[0], y = p[1];
      enqueue(x + 1, y);
      enqueue(x - 1, y);
      enqueue(x, y + 1);
      enqueue(x, y - 1);
    }

    final out = img_lib.Image(width: w, height: h, numChannels: 4);
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final p = src.getPixel(x, y);
        if (visited[y][x]) {
          out.setPixelRgba(x, y, 0, 0, 0, 0);
        } else {
          out.setPixelRgba(x, y, p.r.toInt(), p.g.toInt(), p.b.toInt(), 255);
        }
      }
    }
    return out;
  }

  img_lib.Image _normalizeShapeSilhouette(img_lib.Image src) {
    final prepared = _hasRealTransparency(src) ? src : _removeEdgeBackground(src);
    final out = img_lib.Image(
      width: prepared.width,
      height: prepared.height,
      numChannels: 4,
    );
    for (int y = 0; y < prepared.height; y++) {
      for (int x = 0; x < prepared.width; x++) {
        final p = prepared.getPixel(x, y);
        if (p.a > 24) {
          out.setPixelRgba(x, y, 255, 255, 255, 255);
        } else {
          out.setPixelRgba(x, y, 0, 0, 0, 0);
        }
      }
    }
    return out;
  }

  List<List<bool>> _maskFromAlpha(img_lib.Image src, {int alphaThreshold = 24}) {
    return List.generate(
      src.height,
      (y) => List.generate(src.width, (x) => src.getPixel(x, y).a > alphaThreshold),
    );
  }

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
      if (p.r > thr && p.g > thr && p.b > thr) {
        vis[y][x] = true;
        q.add([x, y]);
      }
    }

    for (int x = 0; x < w; x++) {
      enq(x, 0);
      enq(x, h - 1);
    }
    for (int y = 0; y < h; y++) {
      enq(0, y);
      enq(w - 1, y);
    }

    while (q.isNotEmpty) {
      final p = q.removeLast();
      enq(p[0] + 1, p[1]);
      enq(p[0] - 1, p[1]);
      enq(p[0], p[1] + 1);
      enq(p[0], p[1] - 1);
    }

    final res = img_lib.Image(width: w, height: h, numChannels: 4);
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final p = src.getPixel(x, y);
        if (vis[y][x]) {
          res.setPixelRgba(x, y, 0, 0, 0, 0);
        } else {
          res.setPixelRgba(x, y, p.r.toInt(), p.g.toInt(), p.b.toInt(), 255);
        }
      }
    }
    return res;
  }

  String _getFinalData() {
    if (_c1.text.isEmpty) return "";
    switch (_qrType) {
      case "Sitio Web (URL)":
        return _c1.text;
      case "Red WiFi":
        return "WIFI:T:WPA;S:${_c1.text};P:${_c2.text};;";
      case "VCard (Contacto)":
        return "BEGIN:VCARD\nVERSION:3.0\nFN:${_c1.text} ${_c2.text}\nORG:${_c3.text}\nTEL:${_c4.text}\nEMAIL:${_c5.text}\nEND:VCARD";
      case "WhatsApp":
        return "https://wa.me/${_c1.text.replaceAll('+', '')}?text=${Uri.encodeComponent(_c2.text)}";
      case "E-mail":
        return "mailto:${_c1.text}?subject=${_c2.text}&body=${_c3.text}";
      case "SMS (Mensaje)":
        return "SMSTO:${_c1.text}:${_c2.text}";
      case "Teléfono":
        return "tel:${_c1.text}";
      default:
        return _c1.text;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // UI
  // ═══════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF4F4F6),
        appBar: AppBar(
          title: const Text(
            "QR+Logo",
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w800,
              fontSize: 18,
              letterSpacing: -0.5,
            ),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          bottom: TabBar(
            controller: _tabCtrl,
            labelColor: Colors.black,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.black,
            indicatorWeight: 3,
            labelStyle:
                const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            tabs: const [Tab(text: "Básico"), Tab(text: "Avanzado")],
          ),
        ),
        body: TabBarView(
          controller: _tabCtrl,
          children: [_buildBasicTab(), _buildAdvancedTab()],
        ),
      );

  // ── Tab Básico — SIN CAMBIOS ────────────────────────────────────
  Widget _buildBasicTab() {
    final data = _getFinalData();
    final isEmpty = data.isEmpty;
    final effLogo = _effectiveLogo(false);
    final limited = _logoBytes != null && effLogo < _logoSize - 0.5;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 30),
      child: Column(
        children: [
          _card("1. Estilo del QR",
              _styleSelector(_basicStyles, _estilo, (s) => setState(() => _estilo = s))),
          _card("2. Contenido", Column(children: [
            _typeDropdown(),
            const SizedBox(height: 10),
            _buildInputs(),
          ])),
          _card("3. Logo", _logoSection(effLogo, limited, false)),
          _card("4. Fondo", Column(children: [
            DropdownButtonFormField<String>(
              value: (_bgMode == "Degradado") ? "Blanco (Default)" : _bgMode,
              items: ["Blanco (Default)", "Transparente", "Sólido (Color)"]
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => setState(() => _bgMode = v!),
            ),
            if (_bgMode == "Sólido (Color)") ...[
              const SizedBox(height: 8),
              _colorRow("Color fondo", _bgC1, null,
                  (c) => setState(() => _bgC1 = c), null),
            ],
          ])),
          const SizedBox(height: 10),
          _qrPreview(data, isEmpty, _estilo, false, effLogo),
          const SizedBox(height: 20),
          _actionButtons(isEmpty),
        ],
      ),
    );
  }

  // ── Tab Avanzado ────────────────────────────────────────────────
  Widget _buildAdvancedTab() {
    final data = _getFinalData();
    final isEmpty = data.isEmpty;
    final isShape = _estiloAvz == "Formas (Máscara)";
    final isSplit = _estiloAvz == "Split Liquid (Mitades)";
    final isBasicShape = _estiloAvz == "Formas Básicas";
    final needsLogo = isSplit || isBasicShape; // Split y Formas Básicas usan logo central
    final effLogo = _effectiveLogo(isShape);
    final limited = _logoBytes != null && !isShape && effLogo < _logoSize - 0.5;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 30),
      child: Column(
        children: [
          _card("1. Contenido", Column(children: [
            _typeDropdown(),
            const SizedBox(height: 10),
            _buildInputs(),
          ])),

          _card("2. Estilo del QR", Column(children: [
            _styleSelector(_advStyles, _estiloAvz,
                (s) => setState(() => _estiloAvz = s)),

            // Sub-estilo para Formas (sin cambios)
            if (isShape) ...[
              const Padding(padding: EdgeInsets.only(top: 14, bottom: 4), child: Divider()),
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text("Estilo de módulos en la forma:",
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              ),
              _subStyleChips(_mapSubStyle, (s) => setState(() => _mapSubStyle = s)),
            ],

            // Sub-estilo para Split y Formas Básicas
            if (isSplit || isBasicShape) ...[
              const Padding(padding: EdgeInsets.only(top: 14, bottom: 4), child: Divider()),
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text("Estilo de módulos:",
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              ),
              _subStyleChips(_advSubStyle, (s) => setState(() => _advSubStyle = s)),
            ],

            // Selector de la figura para Formas Básicas
            if (isBasicShape) ...[
              const SizedBox(height: 12),
              const Text("Elige la figura:",
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  "Círculo", "Triángulo", "Corazón", "Estrella", "Rombo", "Pentágono"
                ].map((shape) {
                  final sel = _basicShapeType == shape;
                  return GestureDetector(
                    onTap: () => setState(() => _basicShapeType = shape),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: sel ? Colors.black : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: sel ? Colors.black : Colors.grey.shade300,
                            width: sel ? 2 : 1.5),
                      ),
                      child: Text(shape,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: sel ? Colors.white : Colors.black87)),
                    ),
                  );
                }).toList(),
              ),
            ],

            // Dirección del Split (NUEVO)
            if (isSplit) ...[
              const SizedBox(height: 12),
              const Text("Dirección del Split:",
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 8),
              Row(
                children: ["Vertical", "Horizontal", "Diagonal"].map((dir) {
                  final sel = _splitDir == dir;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _splitDir = dir),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: sel ? Colors.black : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: sel ? Colors.black : Colors.grey.shade300,
                              width: sel ? 2 : 1.5),
                        ),
                        child: Text(dir,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: sel ? Colors.white : Colors.black87)),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ])),

          _card("3. Color y Degradado", Column(children: [
            DropdownButtonFormField<String>(
              value: _qrColorMode,
              items: ["Automático (Logo)", "Sólido (Un Color)", "Degradado Custom"]
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => setState(() => _qrColorMode = v!),
            ),
            const SizedBox(height: 4),
            _colorRow("Color QR", _qrC1,
                _qrColorMode != "Sólido (Un Color)" ? _qrC2 : null,
                (c) => setState(() => _qrC1 = c),
                (c) => setState(() => _qrC2 = c)),
            if (_qrColorMode == "Degradado Custom")
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: "Dirección degradado"),
                value: _qrGradDir,
                items: ["Vertical", "Horizontal", "Diagonal"]
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setState(() => _qrGradDir = v!),
              ),
          ])),

          _card("4. Ojos del QR", Column(children: [
            SwitchListTile(
              title: const Text("Personalizar color de ojos"),
              value: _customEyes,
              onChanged: (v) => setState(() => _customEyes = v),
              contentPadding: EdgeInsets.zero,
            ),
            if (_customEyes)
              _colorRow("Ojos: exterior / interior", _eyeExt, _eyeInt,
                  (c) => setState(() => _eyeExt = c),
                  (c) => setState(() => _eyeInt = c)),
          ])),

          // Sección 5: Logo — Formas sin logo, Split y Circular con logo completo
          _card("5. Logo${isShape ? ' y Forma' : ''}", _logoSection(effLogo, limited, isShape)),

          _card("6. Fondo", Column(children: [
            DropdownButtonFormField<String>(
              value: _bgMode,
              items: ["Blanco (Default)", "Transparente", "Sólido (Color)", "Degradado"]
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => setState(() => _bgMode = v!),
            ),
            if (_bgMode != "Blanco (Default)" && _bgMode != "Transparente") ...[
              const SizedBox(height: 6),
              _colorRow("Color fondo", _bgC1, _bgMode == "Degradado" ? _bgC2 : null,
                  (c) => setState(() => _bgC1 = c),
                  (c) => setState(() => _bgC2 = c)),
              if (_bgMode == "Degradado")
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: "Dirección fondo"),
                  value: _bgGradDir,
                  items: ["Vertical", "Horizontal", "Diagonal"]
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setState(() => _bgGradDir = v!),
                ),
            ],
          ])),

          const SizedBox(height: 10),
          _qrPreview(data, isEmpty, _estiloAvz, true, effLogo),
          const SizedBox(height: 20),
          _actionButtons(isEmpty),
        ],
      ),
    );
  }

  // Widget helper para chips de sub-estilo (reutilizable)
  Widget _subStyleChips(String current, Function(String) onSelect) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _shapeSubStyles.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) {
          final s = _shapeSubStyles[i];
          final sel = s == current;
          return GestureDetector(
            onTap: () => onSelect(s),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: sel ? Colors.black : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: sel ? Colors.black : Colors.grey.shade300,
                    width: sel ? 2 : 1.5),
              ),
              child: Text(_shortName(s),
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: sel ? Colors.white : Colors.black87)),
            ),
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // SELECTOR VISUAL DE ESTILOS — SIN CAMBIOS
  // ═══════════════════════════════════════════════════════════════════
  Widget _styleSelector(List<String> styles, String selected, Function(String) onSelect) {
    return SizedBox(
      height: 128,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(vertical: 2),
        itemCount: styles.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (ctx, i) {
          final style = styles[i];
          final sel = style == selected;
          return GestureDetector(
            onTap: () => onSelect(style),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 96,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: sel ? Colors.black : Colors.grey.shade200,
                    width: sel ? 2.5 : 1.5),
                boxShadow: sel
                    ? [BoxShadow(color: Colors.black.withOpacity(0.14),
                        blurRadius: 10, offset: const Offset(0, 4))]
                    : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4)],
              ),
              child: Column(children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    child: Stack(alignment: Alignment.center, children: [
                      SizedBox(
                        width: 92, height: 92,
                        child: CustomPaint(
                            painter: StylePreviewPainter(style: style, c1: _qrC1, c2: _qrC2)),
                      ),
                      if (style != "Formas (Máscara)") ...[
                        if (_logoBytes != null)
                          SizedBox(width: 24, height: 24,
                              child: Image.memory(_logoBytes!, fit: BoxFit.contain))
                        else
                          const Text("LOGO",
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900,
                                  color: Colors.black, letterSpacing: 0.5)),
                      ],
                    ]),
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  decoration: BoxDecoration(
                    color: sel ? Colors.black : Colors.grey.shade50,
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                  ),
                  child: Text(_shortName(style),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                          color: sel ? Colors.white : Colors.black87, letterSpacing: -0.2)),
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
    if (s.contains("Formas Básicas")) return "F. Básicas";
    if (s.contains("Split")) return "Split";
    if (s.contains("Formas")) return "Formas";
    return s;
  }

  // ═══════════════════════════════════════════════════════════════════
  // SECCIÓN LOGO / FORMA — SIN CAMBIOS excepto que Split/Circular
  // ya usan _effectiveLogo(false) que tiene logo normal
  // ═══════════════════════════════════════════════════════════════════
  Widget _logoSection(double effLogo, bool limited, bool isShape) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isShape) ...[
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFE3F2FD),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(children: [
              Icon(Icons.info_outline, color: Color(0xFF1565C0), size: 18),
              SizedBox(width: 8),
              Expanded(child: Text(
                "Sube una imagen con silueta clara. Se usará solo la forma; en este modo no se usa logo central.",
                style: TextStyle(fontSize: 12, color: Color(0xFF1565C0)),
              )),
            ]),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              final img = await ImagePicker().pickImage(source: ImageSource.gallery);
              if (img != null) await _processShape(File(img.path));
            },
            icon: const Icon(Icons.format_shapes),
            label: Text(_shapeBytes == null
                ? "CARGAR FORMA / SILUETA"
                : "✅ FORMA CARGADA — Cambiar"),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              backgroundColor: const Color(0xFF1565C0),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ] else ...[
          ElevatedButton.icon(
            onPressed: () async {
              final img = await ImagePicker().pickImage(source: ImageSource.gallery);
              if (img != null) await _processLogo(File(img.path));
            },
            icon: const Icon(Icons.image),
            label: Text(_logoBytes == null ? "CARGAR LOGO" : "LOGO CARGADO ✅"),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 8, bottom: 2),
            child: Text("💡 Si tu logo es blanco, elige un fondo oscuro.",
                style: TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic)),
          ),
          if (_logoBytes != null) ...[
            const SizedBox(height: 10),
            Row(children: [
              Text("Tamaño Logo: ${effLogo.toInt()}px",
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const Spacer(),
              if (limited)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: const Text("⚠️ limitado automático",
                      style: TextStyle(fontSize: 11, color: Colors.deepOrange,
                          fontWeight: FontWeight.w600)),
                ),
            ]),
            Slider(
              value: _logoSize, min: 30, max: 85, divisions: 11,
              activeColor: Colors.black,
              onChanged: (v) => setState(() => _logoSize = v),
            ),
            Row(children: [
              const Text("Separación QR–Logo:",
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const Spacer(),
              Text("${_auraSize.toStringAsFixed(1)} módulo(s)",
                  style: const TextStyle(fontSize: 12)),
            ]),
            Slider(
              value: _auraSize, min: 1.0, max: 3.0, divisions: 4,
              activeColor: Colors.black,
              onChanged: (v) => setState(() => _auraSize = v),
            ),
          ],
        ],
      ],
    );
  }

  Widget _qrPreview(String data, bool isEmpty, String estilo, bool isAdv, double effLogo) {
    final isShape = estilo == "Formas (Máscara)";
    final shapeReady = _shapeMask != null && _shapeMask!.isNotEmpty;
    final isAdvStyle = isAdv &&
        (estilo == "Formas Básicas" || estilo == "Split Liquid (Mitades)" || isShape);

    final bgColor = _bgMode == "Transparente"
        ? Colors.transparent
        : _bgMode == "Sólido (Color)" ? _bgC1 : Colors.white;
    final bgGrad = _bgMode == "Degradado" ? _getGrad(_bgC1, _bgC2, _bgGradDir) : null;

    return RepaintBoundary(
      key: _qrKey,
      child: Container(
        width: 320, height: 320,
        decoration: BoxDecoration(
          color: bgGrad == null ? bgColor : null,
          gradient: bgGrad,
          borderRadius: BorderRadius.circular(6),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06),
              blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Center(
          child: isEmpty
              ? Column(mainAxisAlignment: MainAxisAlignment.center, children: const [
                  Icon(Icons.qr_code_2, size: 56, color: Colors.black12),
                  SizedBox(height: 8),
                  Text("Esperando contenido...",
                      style: TextStyle(color: Colors.grey, fontSize: 14)),
                ])
              : (isShape && !shapeReady)
                  ? Column(mainAxisAlignment: MainAxisAlignment.center, children: const [
                      Icon(Icons.format_shapes, size: 52, color: Colors.black26),
                      SizedBox(height: 10),
                      Text("Carga una silueta para usar el modo Formas",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 14)),
                    ])
                  : Stack(alignment: Alignment.center, children: [
                      CustomPaint(
                        size: const Size(270, 270),
                        painter: isAdvStyle
                            ? QrAdvancedPainter(
                                data: data,
                                estiloAvanzado: estilo,
                                mapSubStyle: _mapSubStyle,
                                advSubStyle: _advSubStyle,
                                splitDir: _splitDir,
                                basicShapeType: _basicShapeType, // NUEVO
                                logoImage: isShape ? null : _logoImage,
                                outerMask: isShape ? null : _outerMask,
                                shapeImage: _shapeImage,
                                shapeMask: _shapeMask,
                                logoSize: isShape ? 0.0 : effLogo,
                                auraSize: isShape ? 0.0 : _auraSize,
                                qrC1: _qrC1,
                                qrC2: _qrC2,
                                qrMode: _qrColorMode,
                                qrDir: _qrGradDir,
                                customEyes: _customEyes,
                                eyeExt: _eyeExt,
                                eyeInt: _eyeInt,
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
                      if (_logoBytes != null && estilo != "Formas (Máscara)")
                        SizedBox(width: effLogo, height: effLogo,
                            child: Image.memory(_logoBytes!, fit: BoxFit.contain)),
                    ]),
        ),
      ),
    );
  }

  // ── Inputs, widgets helpers — SIN CAMBIOS ───────────────────────
  Widget _buildInputs() {
    switch (_qrType) {
      case "Sitio Web (URL)":
        return _field(_c1, "Ej: https://mipagina.com");
      case "WhatsApp":
        return Column(children: [
          _field(_c1, "Número con código (+595981...)", type: TextInputType.phone),
          _field(_c2, "Mensaje predefinido (opcional)"),
        ]);
      case "Red WiFi":
        return Column(children: [
          _field(_c1, "Nombre de la red (SSID)"),
          _field(_c2, "Contraseña del WiFi", obscure: true),
        ]);
      case "VCard (Contacto)":
        return Column(children: [
          Row(children: [
            Expanded(child: _field(_c1, "Nombre")),
            const SizedBox(width: 8),
            Expanded(child: _field(_c2, "Apellido")),
          ]),
          _field(_c3, "Empresa / Organización"),
          _field(_c4, "Teléfono (+595...)", type: TextInputType.phone),
          _field(_c5, "Correo electrónico", type: TextInputType.emailAddress),
        ]);
      case "Teléfono":
        return _field(_c1, "Número a marcar (+595981...)", type: TextInputType.phone);
      case "E-mail":
        return Column(children: [
          _field(_c1, "Correo destino", type: TextInputType.emailAddress),
          _field(_c2, "Asunto del correo"),
          _field(_c3, "Cuerpo del mensaje"),
        ]);
      case "SMS (Mensaje)":
        return Column(children: [
          _field(_c1, "Número destino (+595...)", type: TextInputType.phone),
          _field(_c2, "Texto del SMS"),
        ]);
      default:
        return _field(_c1, "Escribe tu texto aquí...", maxLines: 3);
    }
  }

  Widget _field(TextEditingController c, String hint,
      {TextInputType type = TextInputType.text, bool obscure = false, int maxLines = 1}) =>
      TextField(
        controller: c,
        decoration: InputDecoration(hintText: hint),
        keyboardType: type,
        obscureText: obscure,
        maxLines: maxLines,
        onChanged: (_) => setState(() {}),
      );

  Widget _typeDropdown() => DropdownButtonFormField<String>(
        value: _qrType,
        decoration: const InputDecoration(labelText: "Tipo de QR"),
        items: ["Sitio Web (URL)", "WhatsApp", "Red WiFi", "VCard (Contacto)",
                "Teléfono", "E-mail", "SMS (Mensaje)", "Texto Libre"]
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: (v) => setState(() => _qrType = v!),
      );

  Widget _card(String title, Widget child) => Card(
        elevation: 0, color: Colors.white,
        shape: RoundedRectangleBorder(
            side: BorderSide(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800,
                fontSize: 14, letterSpacing: -0.3)),
            const SizedBox(height: 10),
            child,
          ]),
        ),
      );

  Widget _colorRow(String label, Color c1, Color? c2,
      Function(Color) onC1, Function(Color)? onC2) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          const Spacer(),
          _colorDot(c1, onC1),
          if (c2 != null && onC2 != null) ...[
            const SizedBox(width: 10),
            _colorDot(c2, onC2),
          ],
        ]),
      );

  Widget _colorDot(Color cur, Function(Color) onTap) => GestureDetector(
        onTap: () => _palette(onTap),
        child: Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: cur, shape: BoxShape.circle,
            border: Border.all(color: Colors.grey.shade300, width: 1.5),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 4)],
          ),
          child: Icon(Icons.colorize, size: 15,
              color: cur.computeLuminance() > 0.5 ? Colors.black : Colors.white),
        ),
      );

  void _palette(Function(Color) onSel) => showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("Elige un color",
              style: TextStyle(fontWeight: FontWeight.w700)),
          content: Wrap(
            spacing: 10, runSpacing: 10,
            children: [
              Colors.black, Colors.white, const Color(0xFF1565C0),
              Colors.red, Colors.green.shade700, Colors.orange,
              Colors.purple, Colors.teal, const Color(0xFFE91E63),
              const Color(0xFF00BCD4), Colors.brown, Colors.grey.shade700,
            ].map((c) => GestureDetector(
                  onTap: () { onSel(c); Navigator.pop(ctx); },
                  child: Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(color: c, shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey.shade300)),
                  ),
                )).toList(),
          ),
        ),
      );

  Widget _actionButtons(bool isEmpty) => Row(children: [
        Expanded(child: ElevatedButton.icon(
            onPressed: isEmpty ? null : _exportar,
            icon: const Icon(Icons.save_alt),
            label: const Text("GUARDAR"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black, foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ))),
        const SizedBox(width: 12),
        Expanded(child: ElevatedButton.icon(
            onPressed: isEmpty ? null : _compartir,
            icon: const Icon(Icons.share),
            label: const Text("COMPARTIR"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black, foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ))),
      ]);

  LinearGradient _getGrad(Color c1, Color c2, String dir) {
    var b = Alignment.topCenter, e = Alignment.bottomCenter;
    if (dir == "Horizontal") { b = Alignment.centerLeft; e = Alignment.centerRight; }
    if (dir == "Diagonal")   { b = Alignment.topLeft;    e = Alignment.bottomRight; }
    return LinearGradient(colors: [c1, c2], begin: b, end: e);
  }

  Future<void> _exportar() async {
    final boundary = _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 4.0);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await ImageGallerySaver.saveImage(data!.buffer.asUint8List());
    if (mounted) ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("✅ QR guardado en galería")));
  }

  Future<void> _compartir() async {
    final boundary = _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 4.0);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = data!.buffer.asUint8List();
    final dir = await getTemporaryDirectory();
    final file = await File('${dir.path}/QR+Logo.png').create();
    await file.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(file.path)], text: 'Generado con QR+Logo');
  }
}

// ═══════════════════════════════════════════════════════════════════
// ENUM GLOBAL
// ═══════════════════════════════════════════════════════════════════
enum EyeStyle { rect, circ, diamond }

// ═══════════════════════════════════════════════════════════════════
// SECCIÓN 9: PINTOR MINIATURAS — SIN CAMBIOS
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
        if (!ok(r, c)) continue;
        final double x = c * t, y = r * t, cx = x + t / 2, cy = y + t / 2;
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
        } else if (style == "Formas Básicas") {
          // Preview: Círculo perfecto orgánico que envuelve los ojos
          final double nx = (c - m / 2) / (m / 2);
          final double ny = (r - m / 2) / (m / 2);
          bool inShape = (nx * nx + ny * ny) <= 1.25;
          // Siempre proteger las 3 esquinas (ojos)
          if ((r < 8 && c < 8) || (r < 8 && c >= m - 8) || (r >= m - 8 && c < 8)) inShape = true;

          if (!inShape) continue;

          lPath.moveTo(cx, cy); lPath.lineTo(cx, cy);
          if (ok(r, c + 1)) {
             double nx1 = ((c + 1) - m / 2) / (m / 2);
             if ((nx1 * nx1 + ny * ny) <= 1.25 || (r < 8 && c + 1 < 8) || (r < 8 && c + 1 >= m - 8) || (r >= m - 8 && c + 1 < 8)) {
                 lPath.moveTo(cx, cy); lPath.lineTo(cx + t, cy);
             }
          }
          if (ok(r + 1, c)) {
             double ny1 = ((r + 1) - m / 2) / (m / 2);
             if ((nx * nx + ny1 * ny1) <= 1.25 || (r + 1 < 8 && c < 8) || (r + 1 < 8 && c >= m - 8) || (r + 1 >= m - 8 && c < 8)) {
                 lPath.moveTo(cx, cy); lPath.lineTo(cx, cy + t);
             }
          }
        } else if (style.contains("Split")) {
          final sp = c < m / 2
              ? (Paint()..isAntiAlias = true..color = c1..style = PaintingStyle.stroke..strokeWidth = t..strokeCap = StrokeCap.round)
              : (Paint()..isAntiAlias = true..color = c2..style = PaintingStyle.stroke..strokeWidth = t..strokeCap = StrokeCap.round);
          final pp = Path()..moveTo(cx, cy)..lineTo(cx, cy);
          if (ok(r, c + 1)) pp.lineTo(cx + t, cy);
          canvas.drawPath(pp, sp);
          if (ok(r + 1, c)) canvas.drawPath(Path()..moveTo(cx, cy)..lineTo(cx, cy + t), sp);
        } else if (style.contains("Formas")) {
          final d = math.sqrt(math.pow(c - m / 2, 2) + math.pow(r - m / 2, 2));
          if (d > m / 2.2) continue;
          canvas.drawCircle(Offset(cx, cy), t * 0.38, paint);
        } else {
          canvas.drawRect(Rect.fromLTWH(x, y, t + 0.3, t + 0.3), paint);
        }
      }
    }
    if (style.contains("Gusano") || style == "Formas Básicas") canvas.drawPath(lPath, lPaint);
    final pE = Paint()..isAntiAlias = true;
    final pI = Paint()..isAntiAlias = true;
    if (grad != null) { pE.shader = grad; pI.shader = grad; } else { pE.color = c1; pI.color = c1; }
    EyeStyle es = EyeStyle.rect;
    if (style.contains("Puntos") || style == "Formas Básicas") es = EyeStyle.circ;
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
// SECCIÓN 10: PINTOR QR BÁSICO — SIN CAMBIOS
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
      if (qrDir == "Diagonal")   { b = Alignment.topLeft;    e = Alignment.bottomRight; }
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
    if (estilo.contains("Puntos"))    es = EyeStyle.circ;
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
// Formas: SIN CAMBIOS
// Split y QR Circular: MEJORADOS con sub-estilos, logo/aura, splitDir
// ═══════════════════════════════════════════════════════════════════
class QrAdvancedPainter extends CustomPainter {
  final String data, estiloAvanzado, mapSubStyle, advSubStyle, splitDir, basicShapeType, qrMode, qrDir;
  final img_lib.Image? logoImage, shapeImage;
  final List<List<bool>>? outerMask, shapeMask;
  final double logoSize, auraSize;
  final bool customEyes;
  final Color qrC1, qrC2, eyeExt, eyeInt;

  const QrAdvancedPainter({
    required this.data,
    required this.estiloAvanzado,
    required this.mapSubStyle,
    required this.advSubStyle,
    required this.splitDir,
    required this.basicShapeType,
    required this.logoImage,
    required this.outerMask,
    required this.shapeImage,
    required this.shapeMask,
    required this.logoSize,
    required this.auraSize,
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

  // ── Exclusión de logo central (reutilizable) ─────────────────────
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

  // ── Dibujar módulo según sub-estilo ─────────────────────────────
  void _drawModuleStyle(Canvas canvas, int r, int c, double x, double y, double t,
      String subStyle, Paint solidPaint, Path liquidPath, Paint liquidPen,
      bool Function(int, int) okFn) {
    final double cx = x + t / 2, cy = y + t / 2;
    if (subStyle.contains("Gusano") || subStyle.contains("Liquid")) {
      liquidPath.moveTo(cx, cy); liquidPath.lineTo(cx, cy);
      if (okFn(r, c + 1)) { liquidPath.moveTo(cx, cy); liquidPath.lineTo(cx + t, cy); }
      if (okFn(r + 1, c)) { liquidPath.moveTo(cx, cy); liquidPath.lineTo(cx, cy + t); }
    } else if (subStyle.contains("Barras")) {
      // Barras: se llama condicionalmente desde el loop externo
    } else if (subStyle.contains("Puntos")) {
      final double h = ((r * 13 + c * 29) % 100) / 100.0;
      canvas.drawCircle(Offset(cx, cy), t * (0.35 + 0.15 * h), solidPaint);
    } else if (subStyle.contains("Diamantes") || subStyle.contains("Rombos")) {
      final double h = ((r * 17 + c * 31) % 100) / 100.0;
      final double sc = 0.65 + 0.22 * h; final double off = t * (1 - sc) / 2;
      canvas.drawPath(Path()..moveTo(cx, y + off)..lineTo(x + t - off, cy)
          ..lineTo(cx, y + t - off)..lineTo(x + off, cy)..close(), solidPaint);
    } else {
      canvas.drawRect(Rect.fromLTWH(x, y, t + 0.2, t + 0.2), solidPaint);
    }
  }

  // ── Formas helpers — SIN CAMBIOS (copiados exactos) ─────────────
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

  // Genera máscara precargada para Formas Básicas usando Path
  List<List<bool>> _buildBasicShapeMask(int width, int height, String shape) {
    final mask = List.generate(height, (_) => List.filled(width, false));
    final double cx = width / 2.0, cy = height / 2.0;
    final double R = math.min(width, height) / 2.0 - 2;
    final Path p = Path();

    if (shape == "Triángulo") {
      p.moveTo(cx, cy - R * 0.9);
      p.lineTo(cx + R * 0.95, cy + R * 0.85);
      p.lineTo(cx - R * 0.95, cy + R * 0.85);
      p.close();
    } else if (shape == "Rombo") {
      p.moveTo(cx, cy - R); p.lineTo(cx + R, cy);
      p.lineTo(cx, cy + R); p.lineTo(cx - R, cy); p.close();
    } else if (shape == "Corazón") {
      p.moveTo(cx, cy + R * 0.7);
      p.cubicTo(cx + R * 1.2, cy + R * 0.1, cx + R * 1.2, cy - R * 0.8, cx, cy - R * 0.3);
      p.cubicTo(cx - R * 1.2, cy - R * 0.8, cx - R * 1.2, cy + R * 0.1, cx, cy + R * 0.7);
      p.close();
    } else if (shape == "Estrella") {
      for (int i = 0; i < 10; i++) {
        double a = -math.pi / 2.0 + i * math.pi / 5.0;
        double r = (i % 2 == 0) ? R : R * 0.45;
        if (i == 0) p.moveTo(cx + r * math.cos(a), cy + r * math.sin(a));
        else p.lineTo(cx + r * math.cos(a), cy + r * math.sin(a));
      }
      p.close();
    } else if (shape == "Pentágono") {
      for (int i = 0; i < 5; i++) {
        double a = -math.pi / 2.0 + i * 2.0 * math.pi / 5.0;
        if (i == 0) p.moveTo(cx + R * math.cos(a), cy + R * math.sin(a));
        else p.lineTo(cx + R * math.cos(a), cy + R * math.sin(a));
      }
      p.close();
    } else if (shape == "Flecha") {
      p.moveTo(cx, cy - R * 0.9); p.lineTo(cx + R * 0.7, cy - R * 0.1);
      p.lineTo(cx + R * 0.3, cy - R * 0.1); p.lineTo(cx + R * 0.3, cy + R * 0.9);
      p.lineTo(cx - R * 0.3, cy + R * 0.9); p.lineTo(cx - R * 0.3, cy - R * 0.1);
      p.lineTo(cx - R * 0.7, cy - R * 0.1); p.close();
    } else { // Círculo u otro
      p.addOval(Rect.fromCircle(center: Offset(cx, cy), radius: R));
    }

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        mask[y][x] = p.contains(Offset(x + 0.5, y + 0.5));
      }
    }
    return mask;
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
      for (int top = 0; top <= h - side; top += step) for (int left = 0; left <= w - side; left += step) {
        if (areaSum(left, top, side) != side * side) continue;
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

    // ¡AQUÍ ESTABA EL ERROR! Separación estricta para que no se mezclen jamás
    final bool isBasicShape = estiloAvanzado == "Formas Básicas";
    final bool isShape = estiloAvanzado == "Formas (Máscara)" || estiloAvanzado.contains("Mapa");
    final bool isSplit = estiloAvanzado.contains("Split");

    ui.Shader? grad;
    if (qrMode == "Degradado Custom") {
      var b = Alignment.topCenter, e = Alignment.bottomCenter;
      if (qrDir == "Horizontal") { b = Alignment.centerLeft; e = Alignment.centerRight; }
      if (qrDir == "Diagonal")   { b = Alignment.topLeft;    e = Alignment.bottomRight; }
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

    // ════════════════════════════════════════════════════════════
    // FORMAS — SIN CAMBIOS (código exacto del documento original)
    // ════════════════════════════════════════════════════════════
    if (isShape) {
      final int maskW = math.max(size.width.round(), 1);
      final int maskH = math.max(size.height.round(), 1);
      final canvasMask = _buildCanvasShapeMask(maskW, maskH);

      int qrDataCells = 0, qrDarkCells = 0;
      for (int r = 0; r < m; r++) for (int c = 0; c < m; c++) {
        if (_isEye(r, c, m)) continue;
        qrDataCells++;
        if (qr.isDark(r, c)) qrDarkCells++;
      }
      final double qrDarkRatio = qrDataCells == 0 ? 0.55 : (qrDarkCells / qrDataCells).clamp(0.35, 0.75);

      bool insideShapePoint(double px, double py) {
        final int x = px.floor().clamp(0, maskW - 1).toInt();
        final int y = py.floor().clamp(0, maskH - 1).toInt();
        return canvasMask[y][x];
      }

      bool rectWellInsideShape(Rect rect) {
        const probes = [0.18, 0.50, 0.82];
        for (final py in probes) for (final px in probes) {
          if (!insideShapePoint(rect.left + rect.width * px, rect.top + rect.height * py)) return false;
        }
        return true;
      }

      void drawDecorSilhouette({Rect? reservedRect, required double moduleStep}) {
        final double decoT = moduleStep.clamp(1.6, 14.0).toDouble();
        final int cols = (size.width / decoT).ceil();
        final int rows = (size.height / decoT).ceil();

        bool cellAllowed(int rr, int cc) {
          if (rr < 0 || rr >= rows || cc < 0 || cc >= cols) return false;
          final Rect cellRect = Rect.fromLTWH(cc * decoT, rr * decoT, decoT, decoT);
          if (cellRect.right > size.width || cellRect.bottom > size.height) return false;
          if (reservedRect != null && reservedRect.overlaps(cellRect)) return false;
          if (!rectWellInsideShape(cellRect)) return false;
          return true;
        }

        int hashCell(int rr, int cc) {
          int v = ((rr + 11) * 73856093) ^ ((cc + 17) * 19349663) ^ ((m + 23) * 83492791);
          v ^= (v >> 13); v ^= (v << 7);
          return v & 0x7fffffff;
        }

        final bool isLiquidStyle = mapSubStyle.contains("Gusano") || mapSubStyle.contains("Liquid");
        final bool isBarsStyle = mapSubStyle.contains("Barras");
        final bool isDotsStyle = mapSubStyle.contains("Puntos");
        final bool isDiamondStyle = mapSubStyle.contains("Diamantes");
        final bool isNormalStyle = mapSubStyle.contains("Cuadrado") || mapSubStyle.contains("Normal");

        int density = (qrDarkRatio * 100).round();
        if (isBarsStyle) density += 2;
        if (isLiquidStyle) density += 1;
        if (isNormalStyle) density += 2;
        if (isDotsStyle) density -= 1;
        if (isDiamondStyle) density -= 1;
        density = density.clamp(42, 68);

        final active = List.generate(rows, (rr) => List.generate(cols, (cc) {
          if (!cellAllowed(rr, cc)) return false;
          return (hashCell(rr, cc) % 100) < density;
        }));

        bool on(int rr, int cc) {
          if (rr < 0 || rr >= rows || cc < 0 || cc >= cols) return false;
          return active[rr][cc];
        }

        if (isBarsStyle) {
          for (int cc = 0; cc < cols; cc++) for (int rr = 0; rr < rows; rr++) {
            if (!on(rr, cc)) continue;
            if (rr > 0 && on(rr - 1, cc)) continue;
            int endR = rr; while (endR + 1 < rows && on(endR + 1, cc)) endR++;
            canvas.drawRRect(RRect.fromRectAndRadius(
                Rect.fromLTWH(cc * decoT + decoT * 0.10, rr * decoT, decoT * 0.80, (endR - rr + 1) * decoT),
                Radius.circular(decoT * 0.38)), solidPaint);
          }
          return;
        }

        if (isLiquidStyle) {
          final decoLiquidPen = Paint()..isAntiAlias = true..style = PaintingStyle.stroke
              ..strokeWidth = decoT..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
          if (grad != null) decoLiquidPen.shader = grad; else decoLiquidPen.color = qrC1;
          final Path decoPath = Path();
          for (int rr = 0; rr < rows; rr++) for (int cc = 0; cc < cols; cc++) {
            if (!on(rr, cc)) continue;
            final double x = cc * decoT, y = rr * decoT;
            final double cx = x + decoT / 2, cy = y + decoT / 2;
            decoPath.moveTo(cx, cy); decoPath.lineTo(cx, cy);
            if (on(rr, cc + 1)) { decoPath.moveTo(cx, cy); decoPath.lineTo(cx + decoT, cy); }
            if (on(rr + 1, cc)) { decoPath.moveTo(cx, cy); decoPath.lineTo(cx, cy + decoT); }
          }
          canvas.drawPath(decoPath, decoLiquidPen);
          return;
        }

        for (int rr = 0; rr < rows; rr++) for (int cc = 0; cc < cols; cc++) {
          if (!on(rr, cc)) continue;
          final double x = cc * decoT, y = rr * decoT;
          final double cx = x + decoT / 2, cy = y + decoT / 2;
          if (isDotsStyle) {
            final double h = (hashCell(rr, cc) % 100) / 100.0;
            canvas.drawCircle(Offset(cx, cy), decoT * (0.35 + 0.15 * h), solidPaint);
          } else if (isDiamondStyle) {
            final double h = (hashCell(rr, cc) % 100) / 100.0;
            final double sc = 0.65 + 0.22 * h; final double off = decoT * (1 - sc) / 2;
            canvas.drawPath(Path()..moveTo(cx, y + off)..lineTo(x + decoT - off, cy)
                ..lineTo(cx, y + decoT - off)..lineTo(x + off, cy)..close(), solidPaint);
          } else {
            canvas.drawRect(Rect.fromLTWH(x, y, decoT + 0.2, decoT + 0.2), solidPaint);
          }
        }
      }

      final int preferredSide = math.min(math.min(maskW, maskH),
          math.max(((m + 4) * 3.4).round(), 96)).toInt();
      final int relaxedSide = math.min(math.min(maskW, maskH),
          math.max(((m + 4) * 2.8).round(), 76)).toInt();

      Rect? qrBox = _findBestQrSquare(canvasMask, minSide: preferredSide, step: 2);
      qrBox ??= _findBestQrSquare(canvasMask, minSide: relaxedSide, step: 2);
      qrBox ??= _findBestQrSquare(canvasMask, minSide: 72, step: 2);

      if (qrBox == null) { drawDecorSilhouette(moduleStep: size.width / (m + 6.0)); return; }

      const double quietModules = 2.0;
      final double qt = qrBox.width / (m + quietModules * 2.0);
      final Rect qrDataRect = Rect.fromLTWH(
        qrBox.left + qt * quietModules, qrBox.top + qt * quietModules, qt * m, qt * m);

      drawDecorSilhouette(reservedRect: qrDataRect.inflate(qt * 0.25), moduleStep: qt);

      final qrLiquidPen = Paint()..isAntiAlias = true..style = PaintingStyle.stroke
          ..strokeWidth = qt..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
      if (grad != null) qrLiquidPen.shader = grad; else qrLiquidPen.color = qrC1;

      bool darkOk(int r, int c) {
        if (r < 0 || r >= m || c < 0 || c >= m) return false;
        if (!qr.isDark(r, c)) return false;
        if (_isEye(r, c, m)) return false;
        return true;
      }

      final bool isLiquid = mapSubStyle.contains("Gusano") || mapSubStyle.contains("Liquid");
      final bool isBars = mapSubStyle.contains("Barras");
      final bool isDots = mapSubStyle.contains("Puntos");
      final bool isDiamonds = mapSubStyle.contains("Diamantes");
      final qrPath = Path();

      EyeStyle eyeStyle = EyeStyle.rect;
      if (mapSubStyle.contains("Puntos"))    eyeStyle = EyeStyle.circ;
      if (mapSubStyle.contains("Diamantes")) eyeStyle = EyeStyle.diamond;

      for (int r = 0; r < m; r++) for (int c = 0; c < m; c++) {
        if (!darkOk(r, c)) continue;
        final double x = qrDataRect.left + c * qt;
        final double y = qrDataRect.top + r * qt;
        final double cx = x + qt / 2, cy = y + qt / 2;
        if (isLiquid) {
          qrPath.moveTo(cx, cy); qrPath.lineTo(cx, cy);
          if (darkOk(r, c + 1)) { qrPath.moveTo(cx, cy); qrPath.lineTo(cx + qt, cy); }
          if (darkOk(r + 1, c)) { qrPath.moveTo(cx, cy); qrPath.lineTo(cx, cy + qt); }
        } else if (isBars) {
          if (r == 0 || !darkOk(r - 1, c)) {
            int er = r; while (er + 1 < m && darkOk(er + 1, c)) er++;
            canvas.drawRRect(RRect.fromRectAndRadius(
                Rect.fromLTWH(x + qt * 0.10, y, qt * 0.80, (er - r + 1) * qt),
                Radius.circular(qt * 0.38)), solidPaint);
          }
        } else if (isDots) {
          final double h = ((r * 13 + c * 29) % 100) / 100.0;
          canvas.drawCircle(Offset(cx, cy), qt * (0.35 + 0.15 * h), solidPaint);
        } else if (isDiamonds) {
          final double h = ((r * 17 + c * 31) % 100) / 100.0;
          final double sc = 0.65 + 0.22 * h; final double off = qt * (1 - sc) / 2;
          canvas.drawPath(Path()..moveTo(cx, y + off)..lineTo(x + qt - off, cy)
              ..lineTo(cx, y + qt - off)..lineTo(x + off, cy)..close(), solidPaint);
        } else {
          canvas.drawRect(Rect.fromLTWH(x, y, qt + 0.2, qt + 0.2), solidPaint);
        }
      }
      if (isLiquid) canvas.drawPath(qrPath, qrLiquidPen);

      _drawEye(canvas, qrDataRect.left, qrDataRect.top, qt, pE, pI, eyeStyle);
      _drawEye(canvas, qrDataRect.right - 7 * qt, qrDataRect.top, qt, pE, pI, eyeStyle);
      _drawEye(canvas, qrDataRect.left, qrDataRect.bottom - 7 * qt, qt, pE, pI, eyeStyle);

    // ════════════════════════════════════════════════════════════
    // FORMAS BÁSICAS — Algoritmo orgánico puro
    // Sub-estilos, logo/aura completos
    // ════════════════════════════════════════════════════════════
    } else if (isBasicShape) {
      final excl = _buildLogoExcl(m, t);

      EyeStyle eyeStyle = EyeStyle.rect;
      if (advSubStyle.contains("Puntos"))    eyeStyle = EyeStyle.circ;
      if (advSubStyle.contains("Diamantes")) eyeStyle = EyeStyle.diamond;

      final liquidPen = Paint()..isAntiAlias = true..style = PaintingStyle.stroke
          ..strokeWidth = t..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
      if (grad != null) liquidPen.shader = grad; else liquidPen.color = qrC1;

      // Generación 100% matemática, rapidísima e independiente de las imágenes subidas
      bool moduleInShape(int r, int c) {
        // REGLA DE ORO: Los 3 ojos jamás quedan afuera
        if (r < 8 && c < 8) return true;
        if (r < 8 && c >= m - 8) return true;
        if (r >= m - 8 && c < 8) return true;

        final double nx = (c - m / 2.0) / (m / 2.0); // -1.0 a 1.0
        final double ny = (r - m / 2.0) / (m / 2.0); // -1.0 a 1.0

        if (basicShapeType == "Triángulo") {
          return ny - nx <= 1.0 && ny + nx <= 1.0 && ny >= -0.8;
        } else if (basicShapeType == "Rombo") {
          return nx.abs() + ny.abs() <= 1.35;
        } else if (basicShapeType == "Corazón") {
          final double x = nx * 1.2;
          final double y = -ny * 1.2;
          final double eq = x * x + y * y - 1.0;
          return eq * eq * eq - x * x * y * y * y <= 0.15;
        } else if (basicShapeType == "Estrella") {
          return nx.abs() * ny.abs() <= 0.4 || nx.abs() + ny.abs() <= 1.2;
        } else if (basicShapeType == "Pentágono") {
          return ny <= 0.9 && ny - 1.5 * nx <= 1.2 && ny + 1.5 * nx <= 1.2;
        } else if (basicShapeType == "Flecha") {
          if (nx.abs() <= 0.3 && ny >= -0.2 && ny <= 0.9) return true;
          if (ny <= -0.2 && ny - nx <= 0.7 && ny + nx <= 0.7 && ny >= -0.9) return true;
          return false;
        }
        // Círculo por defecto
        return (nx * nx + ny * ny) <= 1.3;
      }

      bool darkOk(int r, int c) {
        if (r < 0 || r >= m || c < 0 || c >= m) return false;
        if (!qr.isDark(r, c)) return false;
        if (_isEye(r, c, m)) return false;
        if (excl[r][c]) return false;
        if (!moduleInShape(r, c)) return false;
        return true;
      }

      // Fantasmas para garantizar la lectura de áreas vacías
      final ghostPaint = Paint()..color = const Color(0xFFF4F4F4)..isAntiAlias = true;
      for (int r = 0; r < m; r++) for (int c = 0; c < m; c++) {
        if (!qr.isDark(r, c)) continue;
        if (_isEye(r, c, m)) continue;
        if (moduleInShape(r, c)) continue;
        canvas.drawCircle(Offset(c * t + t / 2, r * t + t / 2), t * 0.35, ghostPaint);
      }

      final liquidPath = Path();
      final bool isLiquid = advSubStyle.contains("Gusano") || advSubStyle.contains("Liquid");
      final bool isBars = advSubStyle.contains("Barras");

      for (int r = 0; r < m; r++) for (int c = 0; c < m; c++) {
        if (!darkOk(r, c)) continue;
        final double x = c * t, y = r * t, cx = x + t / 2, cy = y + t / 2;
        if (isLiquid) {
          liquidPath.moveTo(cx, cy); liquidPath.lineTo(cx, cy);
          if (darkOk(r, c + 1)) { liquidPath.moveTo(cx, cy); liquidPath.lineTo(cx + t, cy); }
          if (darkOk(r + 1, c)) { liquidPath.moveTo(cx, cy); liquidPath.lineTo(cx, cy + t); }
        } else if (isBars) {
          if (r == 0 || !darkOk(r - 1, c)) {
            int er = r; while (er + 1 < m && darkOk(er + 1, c)) er++;
            canvas.drawRRect(RRect.fromRectAndRadius(
                Rect.fromLTWH(x + t * 0.10, y, t * 0.80, (er - r + 1) * t),
                Radius.circular(t * 0.38)), solidPaint);
          }
        } else if (advSubStyle.contains("Puntos")) {
          final double h = ((r * 13 + c * 29) % 100) / 100.0;
          canvas.drawCircle(Offset(cx, cy), t * (0.35 + 0.15 * h), solidPaint);
        } else if (advSubStyle.contains("Diamantes")) {
          final double h = ((r * 17 + c * 31) % 100) / 100.0;
          final double sc = 0.65 + 0.22 * h; final double off = t * (1 - sc) / 2;
          canvas.drawPath(Path()..moveTo(cx, y + off)..lineTo(x + t - off, cy)
              ..lineTo(cx, y + t - off)..lineTo(x + off, cy)..close(), solidPaint);
        } else {
          canvas.drawRect(Rect.fromLTWH(x, y, t + 0.2, t + 0.2), solidPaint);
        }
      }
      if (isLiquid) canvas.drawPath(liquidPath, liquidPen);

      _drawEye(canvas, 0, 0, t, pE, pI, eyeStyle);
      _drawEye(canvas, (m - 7) * t, 0, t, pE, pI, eyeStyle);
      _drawEye(canvas, 0, (m - 7) * t, t, pE, pI, eyeStyle);

    // ════════════════════════════════════════════════════════════
    // SPLIT — Sub-estilos, logo/aura, dirección Vertical/Horizontal/Diagonal
    // ════════════════════════════════════════════════════════════
    } else if (isSplit) {
      final excl = _buildLogoExcl(m, t);

      EyeStyle eyeStyle = EyeStyle.rect;
      if (advSubStyle.contains("Puntos"))    eyeStyle = EyeStyle.circ;
      if (advSubStyle.contains("Diamantes")) eyeStyle = EyeStyle.diamond;

      // Determinar en qué "lado" está cada módulo según la dirección
      // Retorna true=lado1(c1), false=lado2(c2)
      bool isSide1(int r, int c) {
        if (splitDir == "Horizontal") return r < m / 2;
        if (splitDir == "Diagonal")   return (r + c) < m;
        return c < m / 2; // Vertical (default)
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
      final bool isBars   = advSubStyle.contains("Barras");
      final bool isDots   = advSubStyle.contains("Puntos");
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
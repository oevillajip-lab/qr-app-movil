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
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainScreen()));
    });
  }
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: Icon(Icons.qr_code_2, size: 100, color: Colors.black)),
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

class _MainScreenState extends State<MainScreen> with SingleTickerProviderStateMixin {
  final _c1 = TextEditingController();
  final _c2 = TextEditingController();
  final _c3 = TextEditingController();
  final _c4 = TextEditingController();
  final _c5 = TextEditingController();

  String _qrType = "Sitio Web (URL)";
  String _estilo = "Liquid Pro (Gusano)";
  String _estiloAvz = "Formas (Máscara)";
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
  String _advSubStyle = "Liquid Pro (Gusano)";
  String _basicShapeType = "Personalizada";
  String _splitDir = "Vertical";

  late TabController _tabCtrl;
  final GlobalKey _qrKey = GlobalKey();

  static const _basicStyles = ["Liquid Pro (Gusano)", "Normal (Cuadrado)", "Barras (Vertical)", "Circular (Puntos)", "Diamantes (Rombos)"];
  static const _advStyles = ["Liquid Pro (Gusano)", "Normal (Cuadrado)", "Barras (Vertical)", "Circular (Puntos)", "Diamantes (Rombos)", "Split Liquid (Mitades)", "Formas (Máscara)"];
  static const _shapeSubStyles = ["Liquid Pro (Gusano)", "Normal (Cuadrado)", "Barras (Vertical)", "Circular (Puntos)", "Diamantes (Rombos)"];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _c1.dispose(); _c2.dispose(); _c3.dispose(); _c4.dispose(); _c5.dispose();
    _tabCtrl.dispose(); super.dispose();
  }

  double _effectiveLogo(bool isShape) {
    if (isShape) return 0.0;
    final data = _getFinalData();
    if (data.isEmpty) return _logoSize;
    final qr = _buildQrImage(data);
    if (qr == null) return _logoSize;
    return _logoSize.clamp(30.0, _safeLogoMax(modules: qr.moduleCount, auraModules: _auraSize));
  }

  Future<void> _processLogo(File file) async {
    final bytes = await file.readAsBytes();
    img_lib.Image? img = img_lib.decodeImage(bytes);
    if (img == null) return;
    img = img.convert(numChannels: 4);
    if (file.path.toLowerCase().contains('.jpg')) img = _removeWhiteBg(img);
    final w = img.width, h = img.height;
    final mask = List.generate(h, (y) => List.generate(w, (x) => img!.getPixel(x, y).a > 30));
    final png = Uint8List.fromList(img_lib.encodePng(img));
    final palette = await PaletteGenerator.fromImageProvider(MemoryImage(png));
    setState(() {
      _logoBytes = png; _logoImage = img; _outerMask = mask;
      _qrC1 = palette.dominantColor?.color ?? Colors.black;
      _qrC2 = palette.vibrantColor?.color ?? _qrC1;
      _qrColorMode = "Automático (Logo)";
    });
  }

  Future<void> _processShape(File file) async {
    final bytes = await file.readAsBytes();
    img_lib.Image? decoded = img_lib.decodeImage(bytes);
    if (decoded == null) return;
    decoded = decoded.convert(numChannels: 4);
    final silhouette = _normalizeShapeSilhouette(decoded);
    setState(() {
      _shapeBytes = Uint8List.fromList(img_lib.encodePng(silhouette));
      _shapeImage = silhouette;
      _shapeMask = List.generate(silhouette.height, (y) => List.generate(silhouette.width, (x) => silhouette.getPixel(x, y).a > 24));
    });
  }

  img_lib.Image _normalizeShapeSilhouette(img_lib.Image src) {
    final out = img_lib.Image(width: src.width, height: src.height, numChannels: 4);
    for (int y = 0; y < src.height; y++) {
      for (int x = 0; x < src.width; x++) {
        final p = src.getPixel(x, y);
        if (p.a > 30) out.setPixelRgba(x, y, 255, 255, 255, 255);
        else out.setPixelRgba(x, y, 0, 0, 0, 0);
      }
    }
    return out;
  }

  img_lib.Image _removeWhiteBg(img_lib.Image src) {
    final res = img_lib.Image(width: src.width, height: src.height, numChannels: 4);
    for (int y = 0; y < src.height; y++) {
      for (int x = 0; x < src.width; x++) {
        final p = src.getPixel(x, y);
        if (p.r > 240 && p.g > 240 && p.b > 240) res.setPixelRgba(x, y, 0, 0, 0, 0);
        else res.setPixelRgba(x, y, p.r.toInt(), p.g.toInt(), p.b.toInt(), 255);
      }
    }
    return res;
  }

  String _getFinalData() {
    if (_c1.text.isEmpty) return "";
    switch (_qrType) {
      case "Sitio Web (URL)": return _c1.text;
      case "WhatsApp": return "https://wa.me/${_c1.text.replaceAll('+', '')}?text=${Uri.encodeComponent(_c2.text)}";
      case "Red WiFi": return "WIFI:T:WPA;S:${_c1.text};P:${_c2.text};;";
      default: return _c1.text;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF4F4F6),
        appBar: AppBar(
          title: const Text("QR+Logo", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800)),
          backgroundColor: Colors.white, elevation: 0, centerTitle: true,
          bottom: TabBar(controller: _tabCtrl, labelColor: Colors.black, tabs: const [Tab(text: "Básico"), Tab(text: "Avanzado")]),
        ),
        body: TabBarView(controller: _tabCtrl, children: [_buildBasicTab(), _buildAdvancedTab()]),
      );

  Widget _buildBasicTab() {
    final data = _getFinalData();
    final effLogo = _effectiveLogo(false);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(children: [
        _card("1. Estilo", _styleSelector(_basicStyles, _estilo, (s) => setState(() => _estilo = s))),
        _card("2. Contenido", Column(children: [_typeDropdown(), const SizedBox(height: 10), _buildInputs()])),
        _card("3. Logo", _logoSection(effLogo, false, false)),
        const SizedBox(height: 10),
        _qrPreview(data, data.isEmpty, _estilo, false, effLogo),
        const SizedBox(height: 20),
        _actionButtons(data.isEmpty),
      ]),
    );
  }

  Widget _buildAdvancedTab() {
    final data = _getFinalData();
    final isShape = _estiloAvz == "Formas (Máscara)";
    final isSplit = _estiloAvz == "Split Liquid (Mitades)";
    final effLogo = _effectiveLogo(isShape);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(children: [
        _card("1. Contenido", _buildInputs()),
        _card("2. Estilo Avanzado", Column(children: [
          _styleSelector(_advStyles, _estiloAvz, (s) => setState(() => _estiloAvz = s)),
          if (isShape) ...[
            const Divider(),
            _subStyleChips(_mapSubStyle, (s) => setState(() => _mapSubStyle = s)),
            const SizedBox(height: 12),
            const Text("Elige la figura:", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: ["Personalizada", "Círculo", "Triángulo", "Corazón", "Estrella", "Rombo", "Pentágono", "Flecha"].map((shape) {
                final sel = _basicShapeType == shape;
                return ChoiceChip(label: Text(shape), selected: sel, onSelected: (v) => setState(() => _basicShapeType = shape));
              }).toList(),
            ),
          ],
          if (isSplit) ...[
            const Divider(),
            _subStyleChips(_advSubStyle, (s) => setState(() => _advSubStyle = s)),
            const SizedBox(height: 12),
            _splitDirectionSelector(),
          ]
        ])),
        _card("3. Colores", _colorRow("Color QR", _qrC1, _qrC2, (c) => setState(() => _qrC1 = c), (c) => setState(() => _qrC2 = c))),
        if (!isShape || _basicShapeType == "Personalizada")
           _card(isShape ? "4. Cargar Silueta" : "4. Logo", _logoSection(effLogo, false, isShape)),
        const SizedBox(height: 10),
        _qrPreview(data, data.isEmpty, _estiloAvz, true, effLogo),
        const SizedBox(height: 20),
        _actionButtons(data.isEmpty),
      ]),
    );
  }

  Widget _splitDirectionSelector() {
    return Row(children: ["Vertical", "Horizontal", "Diagonal"].map((dir) {
      return Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(dir), selected: _splitDir == dir, onSelected: (v) => setState(() => _splitDir = dir)));
    }).toList());
  }

  Widget _qrPreview(String data, bool isEmpty, String estilo, bool isAdv, double effLogo) {
    final isShape = estilo == "Formas (Máscara)";
    return RepaintBoundary(
      key: _qrKey,
      child: Container(
        width: 300, height: 300, color: Colors.white,
        child: Center(
          child: isEmpty ? const Icon(Icons.qr_code, size: 100, color: Colors.grey) : Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(260, 260),
                painter: isAdv 
                  ? QrAdvancedPainter(
                      data: data, estiloAvanzado: estilo, mapSubStyle: _mapSubStyle, advSubStyle: _advSubStyle, 
                      splitDir: _splitDir, basicShapeType: _basicShapeType, logoImage: isShape ? null : _logoImage, 
                      outerMask: isShape ? null : _outerMask, shapeImage: _shapeImage, shapeMask: _shapeMask,
                      logoSize: isShape ? 0.0 : effLogo, auraSize: _auraSize, qrC1: _qrC1, qrC2: _qrC2,
                      qrMode: _qrColorMode, qrDir: _qrGradDir, customEyes: _customEyes, eyeExt: _eyeExt, eyeInt: _eyeInt,
                    )
                  : QrMasterPainter(
                      data: data, estilo: estilo, logoImage: _logoImage, outerMask: _outerMask, logoSize: effLogo, 
                      auraSize: _auraSize, qrC1: _qrC1, qrC2: _qrC2, qrMode: _qrColorMode, qrDir: _qrGradDir, 
                      customEyes: _customEyes, eyeExt: _eyeExt, eyeInt: _eyeInt,
                    ),
              ),
              if (_logoBytes != null && !isShape) Image.memory(_logoBytes!, width: effLogo, height: effLogo),
            ],
          ),
        ),
      ),
    );
  }

  Widget _logoSection(double effLogo, bool limited, bool isShape) {
    return Column(children: [
      ElevatedButton(onPressed: () async {
        final xf = await ImagePicker().pickImage(source: ImageSource.gallery);
        if (xf != null) isShape ? await _processShape(File(xf.path)) : await _processLogo(File(xf.path));
      }, child: Text(isShape ? "CARGAR SILUETA" : "CARGAR LOGO")),
      if (!isShape && _logoBytes != null) Slider(value: _logoSize, min: 30, max: 80, onChanged: (v) => setState(() => _logoSize = v)),
    ]);
  }

  Widget _styleSelector(List<String> styles, String selected, Function(String) onSelect) {
    return SizedBox(height: 100, child: ListView(scrollDirection: Axis.horizontal, children: styles.map((s) => 
      GestureDetector(onTap: () => onSelect(s), child: Container(
        margin: const EdgeInsets.all(4), padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: s == selected ? Colors.black : Colors.white, border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)),
        child: Center(child: Text(_shortName(s), style: TextStyle(color: s == selected ? Colors.white : Colors.black))),
      ))).toList()));
  }

  Widget _subStyleChips(String current, Function(String) onSelect) {
    return Wrap(spacing: 8, children: _shapeSubStyles.map((s) => ChoiceChip(label: Text(_shortName(s)), selected: s == current, onSelected: (v) => onSelect(s))).toList());
  }

  String _shortName(String s) => s.split(' ').first;

  Widget _buildInputs() => TextField(controller: _c1, decoration: const InputDecoration(hintText: "Contenido del QR"), onChanged: (v) => setState(() {}));
  Widget _typeDropdown() => DropdownButton(value: _qrType, items: ["Sitio Web (URL)", "WhatsApp", "Red WiFi"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => _qrType = v.toString()));
  Widget _card(String t, Widget c) => Container(width: double.infinity, margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 8), c]));
  Widget _colorRow(String l, Color c1, Color c2, Function(Color) o1, Function(Color) o2) => Row(children: [Text(l), const Spacer(), _colorDot(c1, o1), const SizedBox(width: 8), _colorDot(c2, o2)]);
  Widget _colorDot(Color c, Function(Color) f) => GestureDetector(onTap: () => f(Colors.red), child: Container(width: 30, height: 30, decoration: BoxDecoration(color: c, shape: BoxShape.circle)));
  Widget _actionButtons(bool empty) => Row(children: [Expanded(child: ElevatedButton(onPressed: empty ? null : _exportar, child: const Text("GUARDAR")))]);

  Future<void> _exportar() async {
    final rb = _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final img = await rb.toImage(pixelRatio: 3.0);
    final bd = await img.toByteData(format: ui.ImageByteFormat.png);
    await ImageGallerySaver.saveImage(bd!.buffer.asUint8List());
  }
}

enum EyeStyle { rect, circ, diamond }

// ═══════════════════════════════════════════════════════════════════
// SECCIÓN 9: PINTOR MINIATURAS
// ═══════════════════════════════════════════════════════════════════
class StylePreviewPainter extends CustomPainter {
  final String style; final Color c1, c2;
  const StylePreviewPainter({required this.style, required this.c1, required this.c2});
  @override
  void paint(Canvas canvas, Size size) {
    final qr = _buildQrImage("demo"); if (qr == null) return;
    final double t = size.width / qr.moduleCount;
    final paint = Paint()..color = c1;
    for (int r = 0; r < qr.moduleCount; r++) {
      for (int c = 0; c < qr.moduleCount; c++) {
        if (qr.isDark(r, c)) canvas.drawRect(Rect.fromLTWH(c * t, r * t, t, t), paint);
      }
    }
  }
  @override bool shouldRepaint(covariant CustomPainter old) => true;
}

// ═══════════════════════════════════════════════════════════════════
// SECCIÓN 10: PINTOR QR BÁSICO
// ═══════════════════════════════════════════════════════════════════
class QrMasterPainter extends CustomPainter {
  final String data, estilo, qrMode, qrDir;
  final img_lib.Image? logoImage; final List<List<bool>>? outerMask;
  final double logoSize, auraSize; final bool customEyes;
  final Color qrC1, qrC2, eyeExt, eyeInt;

  const QrMasterPainter({required this.data, required this.estilo, required this.logoImage, required this.outerMask, required this.logoSize, required this.auraSize, required this.qrC1, required this.qrC2, required this.qrMode, required this.qrDir, required this.customEyes, required this.eyeExt, required this.eyeInt});

  @override
  void paint(Canvas canvas, Size size) {
    final qr = _buildQrImage(data); if (qr == null) return;
    final double t = size.width / qr.moduleCount;
    final paint = Paint()..color = qrC1;
    for (int r = 0; r < qr.moduleCount; r++) {
      for (int c = 0; c < qr.moduleCount; c++) {
        if (qr.isDark(r, c)) canvas.drawRect(Rect.fromLTWH(c * t, r * t, t, t), paint);
      }
    }
  }
  @override bool shouldRepaint(covariant CustomPainter old) => true;
}

// ═══════════════════════════════════════════════════════════════════
// SECCIÓN 11: PINTOR QR AVANZADO
// ═══════════════════════════════════════════════════════════════════
class QrAdvancedPainter extends CustomPainter {
  final String data, estiloAvanzado, mapSubStyle, advSubStyle, splitDir, basicShapeType, qrMode, qrDir;
  final img_lib.Image? logoImage, shapeImage; final List<List<bool>>? outerMask, shapeMask;
  final double logoSize, auraSize; final bool customEyes;
  final Color qrC1, qrC2, eyeExt, eyeInt;

  const QrAdvancedPainter({required this.data, required this.estiloAvanzado, required this.mapSubStyle, required this.advSubStyle, required this.splitDir, required this.basicShapeType, required this.logoImage, required this.outerMask, required this.shapeImage, required this.shapeMask, required this.logoSize, required this.auraSize, required this.qrC1, required this.qrC2, required this.qrMode, required this.qrDir, required this.customEyes, required this.eyeExt, required this.eyeInt});

  bool _isEye(int r, int c, int m) => (r < 7 && c < 7) || (r < 7 && c >= m - 7) || (r >= m - 7 && c < 7);

  void _drawEye(Canvas canvas, double ox, double oy, double t, Paint pE, Paint pI, EyeStyle es) {
    canvas.drawRect(Rect.fromLTWH(ox, oy, 7 * t, 7 * t), pE);
    canvas.drawRect(Rect.fromLTWH(ox + 2 * t, oy + 2 * t, 3 * t, 3 * t), pI);
  }

  List<List<bool>> _buildBasicShapeMask(int width, int height, String shape) {
    final mask = List.generate(height, (_) => List.filled(width, false));
    final double cx = width / 2.0, cy = height / 2.0;
    final double R = math.min(width, height) / 2.0 - 2;
    final Path p = Path();
    if (shape == "Triángulo") { p.moveTo(cx, cy - R); p.lineTo(cx + R, cy + R); p.lineTo(cx - R, cy + R); p.close(); }
    else if (shape == "Corazón") { p.moveTo(cx, cy + R * 0.7); p.cubicTo(cx + R * 1.2, cy - R * 0.5, cx - R * 1.2, cy - R * 0.5, cx, cy + R * 0.7); p.close(); }
    else if (shape == "Estrella") { p.addOval(Rect.fromCircle(center: Offset(cx, cy), radius: R)); } // Placeholder
    else { p.addOval(Rect.fromCircle(center: Offset(cx, cy), radius: R)); }
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) { mask[y][x] = p.contains(Offset(x.toDouble(), y.toDouble())); }
    }
    return mask;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final qr = _buildQrImage(data); if (qr == null) return;
    final int m = qr.moduleCount; final double t = size.width / m;
    final bool isShape = estiloAvanzado == "Formas (Máscara)";
    final bool isSplit = estiloAvanzado.contains("Split");

    final Paint solidPaint = Paint()..color = qrC1;
    final Paint pE = Paint()..color = qrC1; final Paint pI = Paint()..color = qrC1;

    if (isShape) {
      final List<List<bool>> canvasMask = (basicShapeType == "Personalizada") ? (shapeMask ?? List.generate(size.height.toInt(), (_) => List.filled(size.width.toInt(), true))) : _buildBasicShapeMask(size.width.toInt(), size.height.toInt(), basicShapeType);
      for (int r = 0; r < m; r++) {
        for (int c = 0; c < m; c++) {
          if (qr.isDark(r, c) && !_isEye(r, c, m)) {
            if (canvasMask[(r * t).toInt()][(c * t).toInt()]) canvas.drawRect(Rect.fromLTWH(c * t, r * t, t, t), solidPaint);
          }
        }
      }
      _drawEye(canvas, 0, 0, t, pE, pI, EyeStyle.rect);
      _drawEye(canvas, (m - 7) * t, 0, t, pE, pI, EyeStyle.rect);
      _drawEye(canvas, 0, (m - 7) * t, t, pE, pI, EyeStyle.rect);
    } else if (isSplit) {
      for (int r = 0; r < m; r++) {
        for (int c = 0; c < m; c++) {
          if (qr.isDark(r, c) && !_isEye(r, c, m)) {
            final Paint p = (c < m / 2) ? (Paint()..color = qrC1) : (Paint()..color = qrC2);
            canvas.drawRect(Rect.fromLTWH(c * t, r * t, t, t), p);
          }
        }
      }
      _drawEye(canvas, 0, 0, t, pE, pI, EyeStyle.rect);
      _drawEye(canvas, (m - 7) * t, 0, t, pE, pI, EyeStyle.rect);
      _drawEye(canvas, 0, (m - 7) * t, t, pE, pI, EyeStyle.rect);
    }
  }
  @override bool shouldRepaint(covariant CustomPainter old) => true;
}
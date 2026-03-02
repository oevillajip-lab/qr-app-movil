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
}) {
  final double auraFrac = (auraModules * 2.0) / modules.toDouble();
  final double maxFrac = (math.sqrt(0.27) - auraFrac).clamp(0.08, 0.519);
  return (maxFrac * canvasSize).clamp(30.0, 85.0);
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
          child: Icon(Icons.qr_code_2, size: 100, color: Colors.black),
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

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  double _effectiveLogo(bool isShape) {
    if (isShape) return 0.0;
    final data = _getFinalData();
    if (data.isEmpty) return _logoSize;
    final qr = _buildQrImage(data);
    if (qr == null) return _logoSize;
    return _logoSize.clamp(30.0, _safeLogoMax(modules: qr.moduleCount, auraModules: _auraSize));
  }

  // --- Lógica de Procesamiento de Imagen ---
  Future<void> _processLogo(File file) async {
    final bytes = await file.readAsBytes();
    img_lib.Image? img = img_lib.decodeImage(bytes);
    if (img == null) return;
    img = img.convert(numChannels: 4);
    if (file.path.toLowerCase().endsWith('.jpg') || file.path.toLowerCase().endsWith('.jpeg')) {
      img = _removeWhiteBg(img);
    }
    final png = Uint8List.fromList(img_lib.encodePng(img));
    final palette = await PaletteGenerator.fromImageProvider(MemoryImage(png));
    setState(() {
      _logoBytes = png;
      _logoImage = img;
      _outerMask = List.generate(img!.height, (y) => List.generate(img.width, (x) => img.getPixel(x, y).a > 30));
      _qrC1 = palette.dominantColor?.color ?? Colors.black;
      _qrColorMode = "Automático (Logo)";
    });
  }

  img_lib.Image _removeWhiteBg(img_lib.Image src) {
    final res = img_lib.Image(width: src.width, height: src.height, numChannels: 4);
    for (int y = 0; y < src.height; y++) {
      for (int x = 0; x < src.width; x++) {
        final p = src.getPixel(x, y);
        if (p.r > 240 && p.g > 240 && p.b > 240) {
          res.setPixelRgba(x, y, 0, 0, 0, 0);
        } else {
          res.setPixelRgba(x, y, p.r.toInt(), p.g.toInt(), p.b.toInt(), 255);
        }
      }
    }
    return res;
  }

  Future<void> _processShape(File file) async {
    final bytes = await file.readAsBytes();
    img_lib.Image? decoded = img_lib.decodeImage(bytes);
    if (decoded == null) return;
    decoded = decoded.convert(numChannels: 4);
    final silhouette = img_lib.Image(width: decoded.width, height: decoded.height, numChannels: 4);
    for (int y = 0; y < decoded.height; y++) {
      for (int x = 0; x < decoded.width; x++) {
        final p = decoded.getPixel(x, y);
        if (p.a > 30) silhouette.setPixelRgba(x, y, 255, 255, 255, 255);
        else silhouette.setPixelRgba(x, y, 0, 0, 0, 0);
      }
    }
    setState(() {
      _shapeBytes = Uint8List.fromList(img_lib.encodePng(silhouette));
      _shapeImage = silhouette;
      _shapeMask = List.generate(silhouette.height, (y) => List.generate(silhouette.width, (x) => silhouette.getPixel(x, y).a > 24));
    });
  }

  String _getFinalData() {
    if (_c1.text.isEmpty) return "";
    switch (_qrType) {
      case "Sitio Web (URL)": return _c1.text;
      case "WhatsApp": return "https://wa.me/${_c1.text.replaceAll('+', '')}?text=${Uri.encodeComponent(_c2.text)}";
      case "Red WiFi": return "WIFI:T:WPA;S:${_c1.text};P:${_c2.text};;";
      case "VCard (Contacto)": return "BEGIN:VCARD\nVERSION:3.0\nFN:${_c1.text} ${_c2.text}\nORG:${_c3.text}\nTEL:${_c4.text}\nEMAIL:${_c5.text}\nEND:VCARD";
      case "E-mail": return "mailto:${_c1.text}?subject=${_c2.text}&body=${_c3.text}";
      case "SMS (Mensaje)": return "SMSTO:${_c1.text}:${_c2.text}";
      case "Teléfono": return "tel:${_c1.text}";
      default: return _c1.text;
    }
  }

  // --- UI Reconstruida ---
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
        _card("3. Logo", _logoSection(effLogo, false)),
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
        _card("1. Contenido", Column(children: [_typeDropdown(), const SizedBox(height: 10), _buildInputs()])),
        _card("2. Estilo QR", Column(children: [
          _styleSelector(_advStyles, _estiloAvz, (s) => setState(() => _estiloAvz = s)),
          if (isShape) ...[
            const Divider(),
            _subStyleChips(_mapSubStyle, (s) => setState(() => _mapSubStyle = s)),
            const SizedBox(height: 12),
            _figureSelector(),
          ],
          if (isSplit) ...[
            const Divider(),
            _subStyleChips(_advSubStyle, (s) => setState(() => _advSubStyle = s)),
            const SizedBox(height: 12),
            _splitDirSelector(),
          ]
        ])),
        if (!isShape || _basicShapeType == "Personalizada")
           _card(isShape ? "3. Cargar Silueta" : "3. Logo", _logoSection(effLogo, isShape)),
        _card("4. Colores", _colorRow("Colores QR", _qrC1, _qrC2, (c) => setState(() => _qrC1 = c), (c) => setState(() => _qrC2 = c))),
        const SizedBox(height: 10),
        _qrPreview(data, data.isEmpty, _estiloAvz, true, effLogo),
        const SizedBox(height: 20),
        _actionButtons(data.isEmpty),
      ]),
    );
  }

  // --- Widgets de Ayuda UI ---
  Widget _figureSelector() => Wrap(spacing: 8, children: ["Personalizada", "Círculo", "Triángulo", "Corazón", "Estrella", "Rombo"].map((f) => ChoiceChip(label: Text(f), selected: _basicShapeType == f, onSelected: (v) => setState(() => _basicShapeType = f))).toList());

  Widget _splitDirSelector() => Row(children: ["Vertical", "Horizontal", "Diagonal"].map((d) => Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(d), selected: _splitDir == d, onSelected: (v) => setState(() => _splitDir = d)))).toList());

  Widget _typeDropdown() => DropdownButtonFormField<String>(value: _qrType, items: ["Sitio Web (URL)", "WhatsApp", "Red WiFi", "VCard (Contacto)", "E-mail", "SMS (Mensaje)", "Teléfono", "Texto Libre"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => _qrType = v!));

  Widget _buildInputs() {
    switch (_qrType) {
      case "WhatsApp": return Column(children: [_field(_c1, "Número"), _field(_c2, "Mensaje")]);
      case "Red WiFi": return Column(children: [_field(_c1, "SSID"), _field(_c2, "Password")]);
      case "VCard (Contacto)": return Column(children: [_field(_c1, "Nombre"), _field(_c2, "Apellido"), _field(_c4, "Teléfono")]);
      case "E-mail": return Column(children: [_field(_c1, "Email"), _field(_c2, "Asunto"), _field(_c3, "Cuerpo")]);
      default: return _field(_c1, "Escribe aquí...");
    }
  }

  Widget _field(TextEditingController c, String h) => TextField(controller: c, decoration: InputDecoration(hintText: h), onChanged: (_) => setState(() {}));

  Widget _card(String t, Widget c) => Container(padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 10), c]));

  Widget _styleSelector(List<String> styles, String selected, Function(String) onSelect) {
    return SizedBox(height: 120, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: styles.length, separatorBuilder: (_, __) => const SizedBox(width: 10), itemBuilder: (ctx, i) {
      final s = styles[i]; final sel = s == selected;
      return GestureDetector(onTap: () => onSelect(s), child: Column(children: [
        Container(width: 80, height: 80, decoration: BoxDecoration(color: Colors.white, border: Border.all(color: sel ? Colors.black : Colors.grey.shade200, width: sel ? 2 : 1), borderRadius: BorderRadius.circular(10)), child: CustomPaint(painter: StylePreviewPainter(style: s, c1: _qrC1, c2: _qrC2))),
        const SizedBox(height: 4), Text(s.split(' ').first, style: TextStyle(fontSize: 10, fontWeight: sel ? FontWeight.bold : FontWeight.normal))
      ]));
    }));
  }

  Widget _subStyleChips(String current, Function(String) onSelect) => Wrap(spacing: 8, children: _basicStyles.map((s) => ChoiceChip(label: Text(s.split(' ').first), selected: s == current, onSelected: (v) => onSelect(s))).toList());

  Widget _logoSection(double logo, bool isShape) => Column(children: [
    ElevatedButton.icon(onPressed: () async { final x = await ImagePicker().pickImage(source: ImageSource.gallery); if (x != null) isShape ? _processShape(File(x.path)) : _processLogo(File(x.path)); }, icon: const Icon(Icons.image), label: Text(isShape ? "SUBIR SILUETA" : "SUBIR LOGO")),
    if (!isShape && _logoBytes != null) Slider(value: _logoSize, min: 30, max: 80, activeColor: Colors.black, onChanged: (v) => setState(() => _logoSize = v)),
  ]);

  Widget _colorRow(String l, Color c1, Color? c2, Function(Color) o1, Function(Color)? o2) => Row(children: [Text(l), const Spacer(), _colorDot(c1, o1), if (o2 != null) ...[const SizedBox(width: 10), _colorDot(c2!, o2)]]);

  Widget _colorDot(Color c, Function(Color) f) => GestureDetector(onTap: () => f(Colors.black), child: Container(width: 30, height: 30, decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: Colors.grey.shade300))));

  Widget _qrPreview(String data, bool empty, String est, bool adv, double logo) => RepaintBoundary(key: _qrKey, child: Container(width: 300, height: 300, color: Colors.white, child: Center(child: empty ? const Icon(Icons.qr_code, size: 80, color: Colors.grey) : Stack(alignment: Alignment.center, children: [
    CustomPaint(size: const Size(260, 260), painter: adv 
      ? QrAdvancedPainter(data: data, estiloAvanzado: est, mapSubStyle: _mapSubStyle, advSubStyle: _advSubStyle, splitDir: _splitDir, basicShapeType: _basicShapeType, logoImage: _logoImage, outerMask: _outerMask, shapeImage: _shapeImage, shapeMask: _shapeMask, logoSize: logo, auraSize: _auraSize, qrC1: _qrC1, qrC2: _qrC2, qrMode: _qrColorMode, qrDir: _qrGradDir, customEyes: _customEyes, eyeExt: _eyeExt, eyeInt: _eyeInt)
      : QrMasterPainter(data: data, estilo: est, logoImage: _logoImage, outerMask: _outerMask, logoSize: logo, auraSize: _auraSize, qrC1: _qrC1, qrC2: _qrC2, qrMode: _qrColorMode, qrDir: _qrGradDir, customEyes: _customEyes, eyeExt: _eyeExt, eyeInt: _eyeInt)),
    if (_logoBytes != null && est != "Formas (Máscara)") Image.memory(_logoBytes!, width: logo, height: logo)
  ]))));

  Widget _actionButtons(bool empty) => Row(children: [Expanded(child: ElevatedButton(onPressed: empty ? null : _export, style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white), child: const Text("GUARDAR")))]);

  Future<void> _export() async {
    final rb = _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final img = await rb.toImage(pixelRatio: 3.0);
    final bd = await img.toByteData(format: ui.ImageByteFormat.png);
    await ImageGallerySaver.saveImage(bd!.buffer.asUint8List());
  }
}

// ═══════════════════════════════════════════════════════════════════
// PINTORES AVANZADOS
// ═══════════════════════════════════════════════════════════════════
class StylePreviewPainter extends CustomPainter {
  final String style; final Color c1, c2;
  StylePreviewPainter({required this.style, required this.c1, required this.c2});
  @override void paint(Canvas canvas, Size size) {
    final qr = _buildQrImage("demo"); if (qr == null) return;
    final double t = size.width / qr.moduleCount; final p = Paint()..color = c1;
    for (int r = 0; r < qr.moduleCount; r++) for (int c = 0; c < qr.moduleCount; c++) if (qr.isDark(r, c)) canvas.drawRect(Rect.fromLTWH(c * t, r * t, t, t), p);
  }
  @override bool shouldRepaint(CustomPainter old) => true;
}

class QrMasterPainter extends CustomPainter {
  final String data, estilo, qrMode, qrDir; final img_lib.Image? logoImage; final List<List<bool>>? outerMask; final double logoSize, auraSize; final bool customEyes; final Color qrC1, qrC2, eyeExt, eyeInt;
  QrMasterPainter({required this.data, required this.estilo, required this.logoImage, required this.outerMask, required this.logoSize, required this.auraSize, required this.qrC1, required this.qrC2, required this.qrMode, required this.qrDir, required this.customEyes, required this.eyeExt, required this.eyeInt});

  @override void paint(Canvas canvas, Size size) {
    final qr = _buildQrImage(data); if (qr == null) return;
    final int m = qr.moduleCount; final double t = size.width / m;
    final p = Paint()..color = qrC1;
    for (int r = 0; r < m; r++) for (int c = 0; c < m; c++) {
      if (!qr.isDark(r, c)) continue;
      final double x = c * t, y = r * t;
      if (estilo.contains("Gusano")) canvas.drawCircle(Offset(x + t/2, y + t/2), t/2.2, p);
      else canvas.drawRect(Rect.fromLTWH(x, y, t, t), p);
    }
  }
  @override bool shouldRepaint(CustomPainter old) => true;
}

class QrAdvancedPainter extends CustomPainter {
  final String data, estiloAvanzado, mapSubStyle, advSubStyle, splitDir, basicShapeType, qrMode, qrDir; 
  final img_lib.Image? logoImage, shapeImage; final List<List<bool>>? outerMask, shapeMask; 
  final double logoSize, auraSize; final bool customEyes; final Color qrC1, qrC2, eyeExt, eyeInt;

  QrAdvancedPainter({required this.data, required this.estiloAvanzado, required this.mapSubStyle, required this.advSubStyle, required this.splitDir, required this.basicShapeType, required this.logoImage, required this.outerMask, required this.shapeImage, required this.shapeMask, required this.logoSize, required this.auraSize, required this.qrC1, required this.qrC2, required this.qrMode, required this.qrDir, required this.customEyes, required this.eyeExt, required this.eyeInt});

  bool _isEye(int r, int c, int m) => (r < 7 && c < 7) || (r < 7 && c >= m - 7) || (r >= m - 7 && c < 7);

  @override void paint(Canvas canvas, Size size) {
    final qr = _buildQrImage(data); if (qr == null) return;
    final int m = qr.moduleCount; final double t = size.width / m;
    final p1 = Paint()..color = qrC1; final p2 = Paint()..color = qrC2;

    for (int r = 0; r < m; r++) {
      for (int c = 0; c < m; c++) {
        if (!qr.isDark(r, c)) continue;
        final double x = c * t, y = r * t;

        // Lógica de Split
        if (estiloAvanzado == "Split Liquid (Mitades)") {
          bool side1 = (splitDir == "Vertical" && c < m/2) || (splitDir == "Horizontal" && r < m/2) || (splitDir == "Diagonal" && (r+c) < m);
          canvas.drawCircle(Offset(x + t/2, y + t/2), t/2.2, side1 ? p1 : p2);
        } 
        // Lógica de Formas
        else if (estiloAvanzado == "Formas (Máscara)") {
          bool inShape = true;
          if (basicShapeType == "Corazón") {
            double nx = (c - m/2)/(m/2) * 1.2; double ny = -(r - m/2)/(m/2) * 1.2;
            inShape = (math.pow(nx*nx + ny*ny - 1, 3) - nx*nx*ny*ny*ny) <= 0.05;
          } else if (basicShapeType == "Círculo") {
            double dx = (c - m/2); double dy = (r - m/2);
            inShape = (dx*dx + dy*dy) <= (m/2 * m/2);
          } else if (basicShapeType == "Estrella") {
            double dx = (c - m/2); double dy = (r - m/2);
            inShape = (dx.abs() + dy.abs()) <= m/1.5;
          }
          if (inShape || _isEye(r, c, m)) canvas.drawRect(Rect.fromLTWH(x, y, t, t), p1);
        }
        else {
          canvas.drawRect(Rect.fromLTWH(x, y, t, t), p1);
        }
      }
    }
  }
  @override bool shouldRepaint(CustomPainter old) => true;
}

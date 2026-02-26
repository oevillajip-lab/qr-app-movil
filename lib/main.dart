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
      const MaterialApp(
        home: SplashScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );

// ═══════════════════════════════════════════════════════════════════
// QR seguro — versión automática
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
// PROTECCIÓN ESTRUCTURAL
// ═══════════════════════════════════════════════════════════════════
bool _isEye(int r, int c, int m) =>
    (r < 7 && c < 7) || (r < 7 && c >= m - 7) || (r >= m - 7 && c < 7);

bool _isVital(int r, int c, int m) {
  if (r <= 8 && c <= 8) return true; // Ojo superior izq + formato
  if (r <= 8 && c >= m - 9) return true; // Ojo superior der + formato
  if (r >= m - 9 && c <= 8) return true; // Ojo inferior izq + formato
  if (r == 6 || c == 6) return true; // Timing patterns

  // Alignment pattern (aprox. suficiente para la mayoría de versiones comunes)
  if (m > 21 &&
      r >= m - 10 &&
      r <= m - 4 &&
      c >= m - 10 &&
      c <= m - 4) {
    return true;
  }

  return false;
}

// FRENO DE SEGURIDAD PARA EL LOGO CENTRAL
double _safeLogoMax({
  required int modules,
  required double auraModules,
  double canvasSize = 270.0,
  double hardMax = 55.0,
  double hardMin = 26.0,
}) {
  final auraFrac = (auraModules * 2.0) / modules.toDouble();
  final maxFrac = (math.sqrt(0.18) - auraFrac).clamp(0.06, 0.28);
  return (maxFrac * canvasSize).clamp(hardMin, hardMax);
}

// ═══════════════════════════════════════════════════════════════════
// SPLASH
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
    Future.delayed(
      const Duration(seconds: 2),
      () => Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainScreen()),
      ),
    );
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
// MAIN SCREEN
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
  String _estiloAvz = "QR Circular (Forma)";
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

  // Fusión
  String _fusionShape = "Círculos";
  ui.Image? _logoUiImage;

  Uint8List? _logoBytes;
  img_lib.Image? _logoImage;
  List<List<bool>>? _outerMask;
  double _logoSize = 48.0;
  double _logoSizeMap = 200.0;
  double _auraSize = 1.0;

  late TabController _tabCtrl;
  final GlobalKey _qrKey = GlobalKey();

  static const _basicStyles = [
    "Liquid Pro (Gusano)",
    "Normal (Cuadrado)",
    "Barras (Vertical)",
    "Circular (Puntos)",
    "Diamantes (Rombos)"
  ];

  static const _advStyles = [
    "Liquid Pro (Gusano)",
    "Normal (Cuadrado)",
    "Barras (Vertical)",
    "Circular (Puntos)",
    "Diamantes (Rombos)",
    "QR Circular (Forma)",
    "Split Liquid (Mitades)",
    "Formas (Máscara)",
    "Fusión (Mapeo Color)"
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _c1.dispose();
    _c2.dispose();
    _c3.dispose();
    _c4.dispose();
    _c5.dispose();
    super.dispose();
  }

  double _effectiveLogo(bool isMap) {
    if (isMap) return _logoSizeMap;

    final data = _getFinalData();
    if (data.isEmpty) return _logoSize;

    final qr = _buildQrImage(data);
    if (qr == null) return _logoSize;

    return _logoSize.clamp(
      26.0,
      _safeLogoMax(
        modules: qr.moduleCount,
        auraModules: _auraSize,
      ),
    );
  }

  Future<void> _processLogo(File file) async {
    final bytes = await file.readAsBytes();
    img_lib.Image? img = img_lib.decodeImage(bytes);
    if (img == null) return;

    img = img.convert(numChannels: 4);

    final lower = file.path.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      img = _removeWhiteBg(img);
    }

    final png = Uint8List.fromList(img_lib.encodePng(img));
    final codec = await ui.instantiateImageCodec(png);
    final frame = await codec.getNextFrame();
    final palette = await PaletteGenerator.fromImageProvider(MemoryImage(png));

    setState(() {
      _logoBytes = png;
      _logoImage = img;
      _logoUiImage = frame.image;
      _qrC1 = palette.darkVibrantColor?.color ??
          palette.dominantColor?.color ??
          Colors.black;
      _qrC2 = palette.vibrantColor?.color ?? _qrC1;
      _qrColorMode = "Automático (Logo)";
    });
  }

  img_lib.Image _removeWhiteBg(img_lib.Image src) {
    final w = src.width;
    final h = src.height;
    const thr = 230;

    final res = img_lib.Image(width: w, height: h, numChannels: 4);

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final p = src.getPixel(x, y);
        if (p.r > thr && p.g > thr && p.b > thr) {
          res.setPixelRgba(x, y, 0, 0, 0, 0);
        } else {
          res.setPixelRgba(
            x,
            y,
            p.r.toInt(),
            p.g.toInt(),
            p.b.toInt(),
            255,
          );
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

      case "WhatsApp":
        return "https://wa.me/${_c1.text.replaceAll('+', '')}?text=${Uri.encodeComponent(_c2.text)}";

      case "Teléfono":
        return "tel:${_c1.text}";

      default:
        return _c1.text;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF4F4F6),
        appBar: AppBar(
          title: const Text(
            "QR + Logo PRO",
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w800,
            ),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          bottom: TabBar(
            controller: _tabCtrl,
            labelColor: Colors.black,
            tabs: const [
              Tab(text: "Básico"),
              Tab(text: "Avanzado"),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabCtrl,
          children: [
            _buildTab(false),
            _buildTab(true),
          ],
        ),
      );

  Widget _buildTab(bool isAdv) {
    final data = _getFinalData();
    final currentStyle = isAdv ? _estiloAvz : _estilo;
    final isFusion = isAdv && currentStyle == "Fusión (Mapeo Color)";
    final isMap = isAdv && currentStyle == "Formas (Máscara)";
    final effLogo = _effectiveLogo(isMap);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          _card(
            "1. Estilo",
            _styleSelector(
              isAdv ? _advStyles : _basicStyles,
              currentStyle,
              (s) {
                setState(() {
                  if (isAdv) {
                    _estiloAvz = s;
                  } else {
                    _estilo = s;
                  }
                });
              },
            ),
          ),
          _card(
            "2. Contenido",
            Column(
              children: [
                _typeDropdown(),
                const SizedBox(height: 10),
                _buildInputs(),
              ],
            ),
          ),
          if (!isFusion) _card("3. Colores", _colorSection()),
          _card(
            isFusion ? "3. Logo Fondo" : "4. Logo",
            isFusion ? _logoSectionFusion() : _logoSection(effLogo, isMap),
          ),
          const SizedBox(height: 10),
          _qrPreview(data, currentStyle, isAdv, effLogo),
          const SizedBox(height: 20),
          _actionButtons(data.isEmpty),
        ],
      ),
    );
  }

  Widget _styleSelector(
    List<String> styles,
    String selected,
    Function(String) onSelect,
  ) {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: styles.length,
        itemBuilder: (ctx, i) {
          final s = styles[i];
          final sel = s == selected;

          return GestureDetector(
            onTap: () => onSelect(s),
            child: Container(
              margin: const EdgeInsets.only(right: 10),
              width: 80,
              decoration: BoxDecoration(
                color: sel ? Colors.black : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Center(
                child: Text(
                  s.split(' ')[0],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: sel ? Colors.white : Colors.black,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _colorSection() => Column(
        children: [
          _colorRow(
            "Principal",
            _qrC1,
            _qrColorMode == "Degradado Custom" ? _qrC2 : null,
            (c) => setState(() => _qrC1 = c),
            (c) => setState(() => _qrC2 = c),
          ),
          DropdownButton<String>(
            value: _qrColorMode,
            items: [
              "Sólido (Un Color)",
              "Degradado Custom",
              "Automático (Logo)"
            ]
                .map(
                  (e) => DropdownMenuItem(
                    value: e,
                    child: Text(e),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _qrColorMode = v!),
          ),
        ],
      );

  Widget _logoSection(double eff, bool isMap) => Column(
        children: [
          ElevatedButton(
            onPressed: () async {
              final picked =
                  await ImagePicker().pickImage(source: ImageSource.gallery);
              if (picked != null) {
                await _processLogo(File(picked.path));
              }
            },
            child: const Text("Cargar Logo"),
          ),
          if (_logoBytes != null && !isMap)
            Slider(
              value: _logoSize,
              min: 26,
              max: 55,
              onChanged: (v) => setState(() => _logoSize = v),
            ),
        ],
      );

  Widget _logoSectionFusion() => Column(
        children: [
          ElevatedButton(
            onPressed: () async {
              final picked =
                  await ImagePicker().pickImage(source: ImageSource.gallery);
              if (picked != null) {
                await _processLogo(File(picked.path));
              }
            },
            child: const Text("Cargar Imagen de Fondo"),
          ),
          DropdownButton<String>(
            value: _fusionShape,
            items: ["Círculos", "Cuadrados Suaves"]
                .map(
                  (e) => DropdownMenuItem(
                    value: e,
                    child: Text(e),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _fusionShape = v!),
          ),
        ],
      );

  Widget _qrPreview(String data, String style, bool isAdv, double eff) {
    final isFusion = style == "Fusión (Mapeo Color)";

    final CustomPainter painter = isFusion
        ? QrFusionPainter(
            data: data,
            logoUiImage: _logoUiImage,
            logoImage: _logoImage,
            shape: _fusionShape,
            dominantColor: _qrC1,
          )
        : (isAdv
            ? QrAdvancedPainter(
                data: data,
                estiloAvanzado: style,
                logoImage: _logoImage,
                qrC1: _qrC1,
                qrC2: _qrC2,
                qrMode: _qrColorMode,
                logoSize: eff,
                auraSize: _auraSize,
              )
            : QrMasterPainter(
                data: data,
                estilo: style,
                logoImage: _logoImage,
                qrC1: _qrC1,
                qrC2: _qrC2,
                qrMode: _qrColorMode,
                logoSize: eff,
                auraSize: _auraSize,
              ));

    return RepaintBoundary(
      key: _qrKey,
      child: Container(
        width: 300,
        height: 300,
        color: Colors.white,
        child: Center(
          child: data.isEmpty
              ? const Text("Sin datos")
              : Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(270, 270),
                      painter: painter,
                    ),
                    if (_logoBytes != null &&
                        style != "Formas (Máscara)" &&
                        !isFusion)
                      SizedBox(
                        width: eff,
                        height: eff,
                        child: Image.memory(
                          _logoBytes!,
                          fit: BoxFit.contain,
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildInputs() => Column(
        children: [
          _field(
            _c1,
            "Dato principal",
            type: _qrType == "WhatsApp"
                ? TextInputType.phone
                : TextInputType.text,
          ),
          if (_qrType == "WhatsApp") _field(_c2, "Mensaje"),
        ],
      );

  Widget _field(
    TextEditingController c,
    String h, {
    TextInputType type = TextInputType.text,
  }) =>
      TextField(
        controller: c,
        keyboardType: type,
        decoration: InputDecoration(hintText: h),
        onChanged: (_) => setState(() {}),
      );

  Widget _typeDropdown() => DropdownButton<String>(
        value: _qrType,
        items: ["Sitio Web (URL)", "WhatsApp", "Teléfono", "Texto Libre"]
            .map(
              (e) => DropdownMenuItem(
                value: e,
                child: Text(e),
              ),
            )
            .toList(),
        onChanged: (v) => setState(() => _qrType = v!),
      );

  Widget _card(String t, Widget c) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            c,
          ],
        ),
      );

  Widget _colorRow(
    String l,
    Color c1,
    Color? c2,
    Function(Color) on1,
    Function(Color) on2,
  ) =>
      Row(
        children: [
          Text(l),
          const Spacer(),
          _dot(c1, on1),
          if (c2 != null) _dot(c2, on2),
        ],
      );

  Widget _dot(Color c, Function(Color) t) => GestureDetector(
        onTap: () => t(Colors.red),
        child: Container(
          width: 25,
          height: 25,
          decoration: BoxDecoration(
            color: c,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey),
          ),
        ),
      );

  Widget _actionButtons(bool empty) => Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: empty ? null : _export,
              child: const Text("Guardar"),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton(
              onPressed: empty ? null : _share,
              child: const Text("Compartir"),
            ),
          ),
        ],
      );

  Future<void> _export() async {
    final boundary =
        _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3.0);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await ImageGallerySaver.saveImage(data!.buffer.asUint8List());
  }

  Future<void> _share() async {
    final boundary =
        _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3.0);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);

    final dir = await getTemporaryDirectory();
    final f = await File('${dir.path}/qr.png').create();
    await f.writeAsBytes(data!.buffer.asUint8List());

    await Share.shareXFiles([XFile(f.path)]);
  }
}

// ═══════════════════════════════════════════════════════════════════
// PAINTERS
// ═══════════════════════════════════════════════════════════════════

enum EyeStyle { rect, circ }

void _drawEye(Canvas canvas, double x, double y, double t, Paint p, EyeStyle s) {
  final rect = Rect.fromLTWH(x, y, 7 * t, 7 * t);

  if (s == EyeStyle.circ) {
    canvas.drawOval(
      rect,
      p
        ..style = PaintingStyle.stroke
        ..strokeWidth = t,
    );
  } else {
    canvas.drawRect(
      rect,
      p
        ..style = PaintingStyle.stroke
        ..strokeWidth = t,
    );
  }

  canvas.drawRect(
    Rect.fromLTWH(x + 2 * t, y + 2 * t, 3 * t, 3 * t),
    p..style = PaintingStyle.fill,
  );
}

// Ojo QR estándar 7-5-3, mucho más estable para lectura
void _drawEyeSafe(Canvas canvas, double x, double y, double t, Color color) {
  final dark = Paint()..color = color;
  final white = Paint()..color = Colors.white;

  // 7x7 oscuro
  canvas.drawRect(Rect.fromLTWH(x, y, 7 * t, 7 * t), dark);

  // 5x5 blanco
  canvas.drawRect(
    Rect.fromLTWH(x + t, y + t, 5 * t, 5 * t),
    white,
  );

  // 3x3 oscuro
  canvas.drawRect(
    Rect.fromLTWH(x + 2 * t, y + 2 * t, 3 * t, 3 * t),
    dark,
  );
}

class QrMasterPainter extends CustomPainter {
  final String data, estilo, qrMode;
  final Color qrC1, qrC2;
  final img_lib.Image? logoImage;
  final double logoSize, auraSize;

  QrMasterPainter({
    required this.data,
    required this.estilo,
    required this.qrMode,
    required this.qrC1,
    required this.qrC2,
    required this.logoImage,
    required this.logoSize,
    required this.auraSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final qr = _buildQrImage(data);
    if (qr == null) return;

    final m = qr.moduleCount;
    final t = size.width / m;
    final paint = Paint()
      ..color = qrC1
      ..isAntiAlias = true;

    for (int r = 0; r < m; r++) {
      for (int c = 0; c < m; c++) {
        if (!qr.isDark(r, c) || _isEye(r, c, m)) continue;

        final x = c * t;
        final y = r * t;

        if (estilo.contains("Gusano")) {
          canvas.drawCircle(
            Offset(x + t / 2, y + t / 2),
            t * 0.45,
            paint,
          );
        } else {
          canvas.drawRect(
            Rect.fromLTWH(x, y, t, t),
            paint,
          );
        }
      }
    }

    _drawEye(canvas, 0, 0, t, paint, EyeStyle.rect);
    _drawEye(canvas, (m - 7) * t, 0, t, paint, EyeStyle.rect);
    _drawEye(canvas, 0, (m - 7) * t, t, paint, EyeStyle.rect);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

class QrAdvancedPainter extends CustomPainter {
  final String data, estiloAvanzado, qrMode;
  final Color qrC1, qrC2;
  final img_lib.Image? logoImage;
  final double logoSize, auraSize;

  QrAdvancedPainter({
    required this.data,
    required this.estiloAvanzado,
    required this.qrMode,
    required this.qrC1,
    required this.qrC2,
    required this.logoImage,
    required this.logoSize,
    required this.auraSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final qr = _buildQrImage(data);
    if (qr == null) return;

    final m = qr.moduleCount;
    final t = size.width / m;
    final paint = Paint()..color = qrC1;

    for (int r = 0; r < m; r++) {
      for (int c = 0; c < m; c++) {
        if (!qr.isDark(r, c) || _isEye(r, c, m)) continue;

        if (estiloAvanzado.contains("Circular") &&
            !_isVital(r, c, m) &&
            math.sqrt(math.pow(c - m / 2, 2) + math.pow(r - m / 2, 2)) >
                m / 2) {
          continue;
        }

        canvas.drawRect(
          Rect.fromLTWH(c * t, r * t, t, t),
          paint,
        );
      }
    }

    _drawEye(canvas, 0, 0, t, paint, EyeStyle.rect);
    _drawEye(canvas, (m - 7) * t, 0, t, paint, EyeStyle.rect);
    _drawEye(canvas, 0, (m - 7) * t, t, paint, EyeStyle.rect);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

// ═══════════════════════════════════════════════════════════════════
// FUSIÓN SEGURO — prioriza lectura sin perder el estilo
// ═══════════════════════════════════════════════════════════════════
class QrFusionPainter extends CustomPainter {
  final String data, shape;
  final ui.Image? logoUiImage;
  final img_lib.Image? logoImage;
  final Color dominantColor;

  QrFusionPainter({
    required this.data,
    required this.logoUiImage,
    required this.logoImage,
    required this.shape,
    required this.dominantColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final qr = _buildQrImage(data);
    if (qr == null) return;

    final m = qr.moduleCount;

    // Ajustes seguros para lectura
    const double quietModules = 4.0; // margen obligatorio
    const double washOpacity = 0.72; // “apaga” el logo
    const double pointRadiusFactor = 0.26; // puntos más pequeños
    const double softSquareFactor = 0.54;

    final t = math.min(size.width, size.height) / (m + quietModules * 2);
    final qrSize = m * t;
    final ox = (size.width - qrSize) / 2;
    final oy = (size.height - qrSize) / 2;
    final qrRect = Rect.fromLTWH(ox, oy, qrSize, qrSize);

    final white = Paint()..color = Colors.white;
    final wash = Paint()..color = Colors.white.withOpacity(washOpacity);
    final dark = Paint()
      ..color = Colors.black
      ..isAntiAlias = true;

    // Ojos oscuros: usa color marca solo si sigue siendo suficientemente oscuro
    final eyeColor =
        dominantColor.computeLuminance() < 0.28 ? dominantColor : Colors.black;

    // 1) Fondo blanco total = quiet zone limpia real
    canvas.drawRect(Offset.zero & size, white);

    // 2) Logo SOLO dentro del área QR
    if (logoUiImage != null) {
      canvas.drawImageRect(
        logoUiImage!,
        Rect.fromLTWH(
          0,
          0,
          logoUiImage!.width.toDouble(),
          logoUiImage!.height.toDouble(),
        ),
        qrRect,
        Paint(),
      );
    }

    // 3) Lavado blanco encima del logo para separar módulos
    canvas.drawRect(qrRect, wash);

    // 4) Zonas limpias de ojos (8x8 para dejar respiración)
    canvas.drawRect(Rect.fromLTWH(ox, oy, 8 * t, 8 * t), white);
    canvas.drawRect(Rect.fromLTWH(ox + (m - 8) * t, oy, 8 * t, 8 * t), white);
    canvas.drawRect(Rect.fromLTWH(ox, oy + (m - 8) * t, 8 * t, 8 * t), white);

    // 5) Módulos
    // IMPORTANTE: solo se dibujan módulos oscuros.
    // NO dibujamos “puntos blancos”, porque eso fue lo que rompía la lectura.
    for (int r = 0; r < m; r++) {
      for (int c = 0; c < m; c++) {
        if (!qr.isDark(r, c) || _isEye(r, c, m)) continue;

        final x = ox + c * t;
        final y = oy + r * t;

        // Módulos vitales: siempre sólidos y completos
        if (_isVital(r, c, m)) {
          canvas.drawRect(
            Rect.fromLTWH(x, y, t, t),
            Paint()..color = Colors.black,
          );
          continue;
        }

        final cx = x + t / 2;
        final cy = y + t / 2;

        if (shape == "Cuadrados Suaves") {
          final s = t * softSquareFactor;
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: Offset(cx, cy),
                width: s,
                height: s,
              ),
              Radius.circular(t * 0.14),
            ),
            dark,
          );
        } else {
          canvas.drawCircle(
            Offset(cx, cy),
            t * pointRadiusFactor,
            dark,
          );
        }
      }
    }

    // 6) Ojos seguros
    _drawEyeSafe(canvas, ox, oy, t, eyeColor);
    _drawEyeSafe(canvas, ox + (m - 7) * t, oy, t, eyeColor);
    _drawEyeSafe(canvas, ox, oy + (m - 7) * t, t, eyeColor);
  }

  @override
  bool shouldRepaint(covariant QrFusionPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.logoUiImage != logoUiImage ||
        oldDelegate.shape != shape ||
        oldDelegate.dominantColor != dominantColor;
  }
}

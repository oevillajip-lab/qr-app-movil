import 'package:flutter/material.dart';
import 'package:qr/qr.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:path_provider/path_provider.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:image/image.dart' as img_lib;
import 'dart:typed_data';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';

void main() => runApp(const MaterialApp(
    home: SplashScreen(), debugShowCheckedModeBanner: false));

// ── Splash ────────────────────────────────────────────────────────
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
        () => Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (context) => const MainScreen())));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
            child: Image.asset('assets/app_icon.png',
                width: 180,
                errorBuilder: (c, e, s) =>
                    const Icon(Icons.qr_code_2, size: 100))));
  }
}

// ── Main Screen ───────────────────────────────────────────────────
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final TextEditingController _c1 = TextEditingController();
  final TextEditingController _c2 = TextEditingController();
  final TextEditingController _c3 = TextEditingController();
  final TextEditingController _c4 = TextEditingController();
  final TextEditingController _c5 = TextEditingController();

  String _qrType = "Sitio Web (URL)";
  String _estilo = "Liquid Pro (Gusano)";
  String _qrColorMode = "Automático (Logo)";
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
  double _logoSize = 65.0;
  double _auraSize = 1.0; 

  final GlobalKey _qrKey = GlobalKey();

  Future<void> _processLogo(File file) async {
    final bytes = await file.readAsBytes();
    img_lib.Image? image = img_lib.decodeImage(bytes);
    if (image == null) return;

    image = image.convert(numChannels: 4);
    final String ext = file.path.toLowerCase();
    final bool isJpg = ext.endsWith('.jpg') || ext.endsWith('.jpeg');

    if (isJpg) {
      image = _removeWhiteBackground(image);
    }

    final int w = image.width;
    final int h = image.height;

    List<List<bool>> rowBound = List.generate(h, (_) => List.filled(w, false));
    for (int y = 0; y < h; y++) {
      int firstX = -1, lastX = -1;
      for (int x = 0; x < w; x++) {
        if (image.getPixel(x, y).a > 30) {
          if (firstX == -1) firstX = x;
          lastX = x;
        }
      }
      if (firstX != -1) {
        for (int x = firstX; x <= lastX; x++) rowBound[y][x] = true;
      }
    }

    List<List<bool>> finalMask = List.generate(h, (_) => List.filled(w, false));
    for (int x = 0; x < w; x++) {
      int firstY = -1, lastY = -1;
      for (int y = 0; y < h; y++) {
        if (image.getPixel(x, y).a > 30) {
          if (firstY == -1) firstY = y;
          lastY = y;
        }
      }
      if (firstY != -1) {
        for (int y = firstY; y <= lastY; y++) {
          if (rowBound[y][x]) finalMask[y][x] = true; 
        }
      }
    }

    final pngBytes = Uint8List.fromList(img_lib.encodePng(image));
    final palette = await PaletteGenerator.fromImageProvider(MemoryImage(pngBytes));

    setState(() {
      _logoBytes = pngBytes;
      _logoImage = image;
      _outerMask = finalMask;
      if (_qrColorMode == "Automático (Logo)") {
        _qrC1 = palette.vibrantColor?.color ??
            palette.darkVibrantColor?.color ??
            palette.dominantColor?.color ??
            Colors.black;
        _qrC2 = palette.darkMutedColor?.color ??
            palette.lightVibrantColor?.color ??
            _qrC1.withOpacity(0.7);
      }
    });
  }

  img_lib.Image _removeWhiteBackground(img_lib.Image src) {
    final int w = src.width;
    final int h = src.height;
    const int thresh = 230;

    final visited = List.generate(h, (_) => List.filled(w, false));
    final queue = <List<int>>[];

    void enqueue(int x, int y) {
      if (x < 0 || x >= w || y < 0 || y >= h) return;
      if (visited[y][x]) return;
      final p = src.getPixel(x, y);
      if (p.r > thresh && p.g > thresh && p.b > thresh) {
        visited[y][x] = true;
        queue.add([x, y]);
      }
    }

    for (int x = 0; x < w; x++) { enqueue(x, 0); enqueue(x, h - 1); }
    for (int y = 0; y < h; y++) { enqueue(0, y); enqueue(w - 1, y); }

    while (queue.isNotEmpty) {
      final pos = queue.removeLast();
      final int x = pos[0];
      final int y = pos[1];
      enqueue(x + 1, y); enqueue(x - 1, y); enqueue(x, y + 1); enqueue(x, y - 1);
    }

    final result = img_lib.Image(width: w, height: h, numChannels: 4);
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final p = src.getPixel(x, y);
        if (visited[y][x]) {
          result.setPixelRgba(x, y, 0, 0, 0, 0);
        } else {
          result.setPixelRgba(x, y, p.r.toInt(), p.g.toInt(), p.b.toInt(), 255);
        }
      }
    }
    return result;
  }

  String _getFinalData() {
    if (_c1.text.isEmpty) return "";
    switch (_qrType) {
      case "Sitio Web (URL)": return _c1.text;
      case "Red WiFi": return "WIFI:T:WPA;S:${_c1.text};P:${_c2.text};;";
      case "VCard (Contacto)": return "BEGIN:VCARD\nVERSION:3.0\nFN:${_c1.text} ${_c2.text}\nORG:${_c3.text}\nTEL:${_c4.text}\nEMAIL:${_c5.text}\nEND:VCARD";
      case "WhatsApp": return "https://wa.me/${_c1.text.replaceAll('+', '')}?text=${Uri.encodeComponent(_c2.text)}";
      case "E-mail": return "mailto:${_c1.text}?subject=${_c2.text}&body=${_c3.text}";
      case "SMS (Mensaje)": return "SMSTO:${_c1.text}:${_c2.text}";
      case "Teléfono": return "tel:${_c1.text}";
      default: return _c1.text;
    }
  }

  @override
  Widget build(BuildContext context) {
    final String finalData = _getFinalData();
    final bool isEmpty = finalData.isEmpty;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
          title: const Text("QR + Logo", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white, elevation: 0, centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(15),
        child: Column(children: [
          _buildCard("1. Contenido", Column(children: [
            DropdownButtonFormField<String>(
                value: _qrType,
                items: ["Sitio Web (URL)", "WhatsApp", "Red WiFi", "VCard (Contacto)", "Teléfono", "E-mail", "SMS (Mensaje)", "Texto Libre"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() => _qrType = v!)),
            const SizedBox(height: 10),
            _buildInputs(),
          ])),

          _buildCard("2. Estilo y Color QR", Column(children: [
            DropdownButtonFormField<String>(
                value: _estilo,
                items: ["Liquid Pro (Gusano)", "Normal (Cuadrado)", "Barras (Vertical)", "Circular (Puntos)", "Diamantes (Rombos)"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() => _estilo = v!)),
            DropdownButtonFormField<String>(
                value: _qrColorMode,
                items: ["Automático (Logo)", "Sólido (Un Color)", "Degradado Custom"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() => _qrColorMode = v!)),
            _buildColorPicker("Colores QR", _qrC1, _qrC2, (c) => setState(() => _qrC1 = c), (c) => setState(() => _qrC2 = c), isGrad: _qrColorMode != "Sólido (Un Color)"),
            if (_qrColorMode != "Sólido (Un Color)")
              DropdownButtonFormField<String>(decoration: const InputDecoration(labelText: "Dirección Degradado"), value: _qrGradDir, items: ["Vertical", "Horizontal", "Diagonal"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => _qrGradDir = v!)),
          ])),

          _buildCard("3. Posicionamiento y Fondo", Column(children: [
            SwitchListTile(title: const Text("Personalizar Ojos"), value: _customEyes, onChanged: (v) => setState(() => _customEyes = v), contentPadding: EdgeInsets.zero),
            if (_customEyes) _buildColorPicker("Colores Ojos", _eyeExt, _eyeInt, (c) => setState(() => _eyeExt = c), (c) => setState(() => _eyeInt = c), isGrad: true),
            const Divider(),
            DropdownButtonFormField<String>(value: _bgMode, items: ["Blanco (Default)", "Transparente", "Sólido (Color)", "Degradado"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => _bgMode = v!)),
            if (_bgMode != "Blanco (Default)" && _bgMode != "Transparente") ...[
              _buildColorPicker("Colores Fondo", _bgC1, _bgC2, (c) => setState(() => _bgC1 = c), (c) => setState(() => _bgC2 = c), isGrad: _bgMode == "Degradado"),
              if (_bgMode == "Degradado")
                DropdownButtonFormField<String>(decoration: const InputDecoration(labelText: "Dirección Fondo"), value: _bgGradDir, items: ["Vertical", "Horizontal", "Diagonal"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => _bgGradDir = v!)),
            ]
          ])),

          _buildCard("4. Logo", Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ElevatedButton.icon(
                onPressed: () async {
                  final img = await ImagePicker().pickImage(source: ImageSource.gallery);
                  if (img != null) await _processLogo(File(img.path));
                },
                icon: const Icon(Icons.image),
                label: Text(_logoBytes == null ? "CARGAR LOGO" : "LOGO CARGADO ✅"),
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: Colors.black, foregroundColor: Colors.white)),
            if (_logoBytes != null) ...[
              const SizedBox(height: 12),
              Text("Tamaño del logo: ${_logoSize.toInt()}px (Tope Seguro)"),
              // Freno de Seguridad para tamaño de logo
              Slider(value: _logoSize, min: 30, max: 85, divisions: 11, activeColor: Colors.black, onChanged: (v) => setState(() => _logoSize = v)),
            ],
          ])),

          _buildCard("5. Ajuste de Aura (Separación QR ↔ Logo)", Column(children: [
            Text("Margen: ${_auraSize.toInt()} Nivel(es)"),
            // Freno de Seguridad para Aura
            Slider(value: _auraSize, min: 1, max: 3, divisions: 2, activeColor: Colors.black, onChanged: (v) => setState(() => _auraSize = v)),
          ])),

          const SizedBox(height: 10),

          RepaintBoundary(
            key: _qrKey,
            child: Container(
              width: 320, height: 320,
              decoration: BoxDecoration(color: _bgMode == "Transparente" ? Colors.transparent : (_bgMode == "Sólido (Color)" ? _bgC1 : Colors.white), gradient: _bgMode == "Degradado" ? _getGrad(_bgC1, _bgC2, _bgGradDir) : null),
              child: Center(
                child: isEmpty
                    ? const Text("Esperando contenido...", style: TextStyle(color: Colors.grey))
                    : Stack(
                        alignment: Alignment.center,
                        children: [
                          CustomPaint(
                            size: const Size(270, 270),
                            painter: QrMasterPainter(
                              data: finalData, estilo: _estilo, logoImage: _logoImage, outerMask: _outerMask, logoSize: _logoSize, auraSize: _auraSize,
                              qrC1: _qrC1, qrC2: _qrC2, qrMode: _qrColorMode, qrDir: _qrGradDir, customEyes: _customEyes, eyeExt: _eyeExt, eyeInt: _eyeInt,
                            ),
                          ),
                          if (_logoBytes != null) SizedBox(width: _logoSize, height: _logoSize, child: Image.memory(_logoBytes!, fit: BoxFit.contain)),
                        ],
                      ),
              ),
            ),
          ),
          const SizedBox(height: 25),
          ElevatedButton(onPressed: isEmpty ? null : () => _exportar(), style: ElevatedButton.styleFrom(backgroundColor: Colors.green[800], foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 60)), child: const Text("GUARDAR EN GALERÍA")),
          const SizedBox(height: 40),
        ]),
      ),
    );
  }

  LinearGradient _getGrad(Color c1, Color c2, String dir) {
    Alignment beg = Alignment.topCenter; Alignment end = Alignment.bottomCenter;
    if (dir == "Horizontal") { beg = Alignment.centerLeft; end = Alignment.centerRight; }
    if (dir == "Diagonal") { beg = Alignment.topLeft; end = Alignment.bottomRight; }
    return LinearGradient(colors: [c1, c2], begin: beg, end: end);
  }

  Widget _buildInputs() {
    switch (_qrType) {
      case "VCard (Contacto)":
        return Column(children: [
          Row(children: [Expanded(child: TextField(controller: _c1, decoration: const InputDecoration(hintText: "Nombre"), onChanged: (v) => setState(() {}))), const SizedBox(width: 5), Expanded(child: TextField(controller: _c2, decoration: const InputDecoration(hintText: "Apellido"), onChanged: (v) => setState(() {})))]),
          TextField(controller: _c3, decoration: const InputDecoration(hintText: "Empresa"), onChanged: (v) => setState(() {})),
          TextField(controller: _c4, decoration: const InputDecoration(hintText: "Teléfono"), keyboardType: TextInputType.phone, onChanged: (v) => setState(() {})),
          TextField(controller: _c5, decoration: const InputDecoration(hintText: "Email"), keyboardType: TextInputType.emailAddress, onChanged: (v) => setState(() {})),
        ]);
      case "WhatsApp":
      case "SMS (Mensaje)": return Column(children: [TextField(controller: _c1, decoration: const InputDecoration(hintText: "Número (+595...)"), keyboardType: TextInputType.phone, onChanged: (v) => setState(() {})), TextField(controller: _c2, decoration: const InputDecoration(hintText: "Mensaje"), onChanged: (v) => setState(() {}))]);
      case "Red WiFi": return Column(children: [TextField(controller: _c1, decoration: const InputDecoration(hintText: "SSID (Nombre Red)"), onChanged: (v) => setState(() {})), TextField(controller: _c2, decoration: const InputDecoration(hintText: "Contraseña"), onChanged: (v) => setState(() {}))]);
      case "E-mail": return Column(children: [TextField(controller: _c1, decoration: const InputDecoration(hintText: "Email Destino"), keyboardType: TextInputType.emailAddress, onChanged: (v) => setState(() {})), TextField(controller: _c2, decoration: const InputDecoration(hintText: "Asunto"), onChanged: (v) => setState(() {})), TextField(controller: _c3, decoration: const InputDecoration(hintText: "Mensaje"), onChanged: (v) => setState(() {}))]);
      default: return TextField(controller: _c1, decoration: InputDecoration(hintText: _qrType == "Sitio Web (URL)" ? "https://..." : "Texto aquí..."), onChanged: (v) => setState(() {}));
    }
  }

  Widget _buildCard(String title, Widget child) { return Card(elevation: 0, shape: RoundedRectangleBorder(side: BorderSide(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(10)), margin: const EdgeInsets.only(bottom: 15), child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 5), child]))); }
  Widget _buildColorPicker(String label, Color c1, Color c2, Function(Color) onC1, Function(Color) onC2, {bool isGrad = false}) { return Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(children: [Text(label), const Spacer(), _colorBtn(c1, onC1), if (isGrad) ...[const SizedBox(width: 15), _colorBtn(c2, onC2)]])); }
  Widget _colorBtn(Color current, Function(Color) onTap) { return GestureDetector(onTap: () => _showPalette(onTap), child: CircleAvatar(backgroundColor: current, radius: 20, child: Icon(Icons.colorize, size: 16, color: current == Colors.white ? Colors.black : Colors.white))); }
  void _showPalette(Function(Color) onSelect) { showDialog(context: context, builder: (ctx) => AlertDialog(content: Wrap(spacing: 12, runSpacing: 12, children: [Colors.black, Colors.white, Colors.red, Colors.blue, Colors.green, Colors.orange, Colors.purple, const Color(0xFF1565C0), Colors.grey].map((c) => GestureDetector(onTap: () { onSelect(c); Navigator.pop(ctx); }, child: CircleAvatar(backgroundColor: c, radius: 25))).toList()))); }
  Future<void> _exportar() async { final boundary = _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary; final ui.Image image = await boundary.toImage(pixelRatio: 4.0); final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png); await ImageGallerySaver.saveImage(byteData!.buffer.asUint8List()); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ QR Guardado"))); }
}

enum EyeStyle { rect, circ, diamond }

class QrMasterPainter extends CustomPainter {
  final String data, estilo, qrMode, qrDir;
  final img_lib.Image? logoImage;
  final List<List<bool>>? outerMask;
  final double logoSize, auraSize;
  final bool customEyes;
  final Color qrC1, qrC2, eyeExt, eyeInt;

  QrMasterPainter({
    required this.data, required this.estilo, required this.logoImage, required this.outerMask,
    required this.logoSize, required this.auraSize, required this.qrC1, required this.qrC2,
    required this.qrMode, required this.qrDir, required this.customEyes, required this.eyeExt, required this.eyeInt,
  });

  bool _isEyeModule(int r, int c, int modules) => (r < 7 && c < 7) || (r < 7 && c >= modules - 7) || (r >= modules - 7 && c < 7);

  @override
  void paint(Canvas canvas, Size size) {
    final qrCode = QrCode(4, QrErrorCorrectLevel.H)..addData(data);
    final qrImage = QrImage(qrCode);
    final int modules = qrImage.moduleCount;
    final double tileSize = size.width / modules;

    final paint = Paint()..isAntiAlias = true;
    ui.Shader? gradShader;

    if (qrMode != "Sólido (Un Color)") {
      Alignment beg = Alignment.topCenter; Alignment end = Alignment.bottomCenter;
      if (qrDir == "Horizontal") { beg = Alignment.centerLeft; end = Alignment.centerRight; }
      if (qrDir == "Diagonal") { beg = Alignment.topLeft; end = Alignment.bottomRight; }
      gradShader = ui.Gradient.linear(Offset(size.width * (beg.x + 1) / 2, size.height * (beg.y + 1) / 2), Offset(size.width * (end.x + 1) / 2, size.height * (end.y + 1) / 2), [qrC1, qrC2]);
      paint.shader = gradShader;
    } else {
      paint.color = qrC1;
    }

    List<List<bool>> exclusionMask = List.generate(modules, (_) => List.filled(modules, false));
    if (logoImage != null && outerMask != null) {
      final double canvasSize = 270.0;
      final double logoFrac = logoSize / canvasSize;
      final double logoStart = (1.0 - logoFrac) / 2.0;
      final double logoEnd = logoStart + logoFrac;

      List<List<bool>> baseLogoModules = List.generate(modules, (_) => List.filled(modules, false));

      for (int r = 0; r < modules; r++) {
        for (int c = 0; c < modules; c++) {
          bool hit = false;
          for (double dy = 0.2; dy <= 0.8; dy += 0.3) {
            for (double dx = 0.2; dx <= 0.8; dx += 0.3) {
              double nx = (c + dx) / modules;
              double ny = (r + dy) / modules;
              if (nx >= logoStart && nx <= logoEnd && ny >= logoStart && ny <= logoEnd) {
                double relX = (nx - logoStart) / logoFrac;
                double relY = (ny - logoStart) / logoFrac;
                int px = (relX * logoImage!.width).clamp(0, logoImage!.width - 1).toInt();
                int py = (relY * logoImage!.height).clamp(0, logoImage!.height - 1).toInt();
                if (outerMask![py][px]) { hit = true; break; }
              }
            }
            if (hit) break;
          }
          if (hit) baseLogoModules[r][c] = true;
        }
      }

      int auraRadius = auraSize.toInt();
      for (int r = 0; r < modules; r++) {
        for (int c = 0; c < modules; c++) {
          if (baseLogoModules[r][c]) {
            for (int dr = -auraRadius; dr <= auraRadius; dr++) {
              for (int dc = -auraRadius; dc <= auraRadius; dc++) {
                int nr = r + dr; int nc = c + dc;
                if (nr >= 0 && nr < modules && nc >= 0 && nc < modules) exclusionMask[nr][nc] = true;
              }
            }
          }
        }
      }
    }

    // ARREGLO DE GLITCH EN OJOS: Evita que se dibujen bloques por debajo de los ojos.
    bool isSafeDark(int r, int c) {
      if (r < 0 || r >= modules || c < 0 || c >= modules) return false;
      if (!qrImage.isDark(r, c)) return false;
      if (_isEyeModule(r, c, modules)) return false; // El área del ojo queda 100% libre para _drawEye
      if (exclusionMask[r][c]) return false;
      return true;
    }

    // ── Módulos de datos ─────────────────────────────────────────
    for (int r = 0; r < modules; r++) {
      for (int c = 0; c < modules; c++) {
        if (!isSafeDark(r, c)) continue;

        final double x = c * tileSize;
        final double y = r * tileSize;

        if (estilo.contains("Gusano")) {
          bool right = isSafeDark(r, c + 1);
          bool bottom = isSafeDark(r + 1, c);

          // RESTAURADO EXACTO: El pegamento visual de +0.5 y -0.5 píxeles que da el efecto líquido.
          canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x + 0.5, y + 0.5, tileSize - 0.5, tileSize - 0.5), Radius.circular(tileSize * 0.35)), paint);
          if (right) canvas.drawRect(Rect.fromLTWH(x + tileSize / 2, y + 0.5, tileSize, tileSize - 0.5), paint);
          if (bottom) canvas.drawRect(Rect.fromLTWH(x + 0.5, y + tileSize / 2, tileSize - 0.5, tileSize), paint);

        } else if (estilo.contains("Barras")) {
          bool bottom = isSafeDark(r + 1, c);
          
          // RESTAURADO EXACTO: Efecto barra suave.
          canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x + tileSize * 0.1, y, tileSize * 0.8, tileSize + 0.5), Radius.circular(tileSize * 0.3)), paint);
          if (bottom) canvas.drawRect(Rect.fromLTWH(x + tileSize * 0.1, y + tileSize / 2, tileSize * 0.8, tileSize), paint);

        } else if (estilo.contains("Puntos")) {
          double hash = ((r * 13 + c * 29) % 100) / 100.0;
          double radius = tileSize * 0.35 + (tileSize * 0.15 * hash);
          canvas.drawCircle(Offset(x + tileSize / 2, y + tileSize / 2), radius, paint);

        } else if (estilo.contains("Diamantes")) {
          double hash = ((r * 17 + c * 31) % 100) / 100.0;
          double scale = 0.65 + (0.5 * hash);
          double offset = tileSize * (1.0 - scale) / 2;
          Path path = Path()
            ..moveTo(x + tileSize / 2, y + offset)
            ..lineTo(x + tileSize - offset, y + tileSize / 2)
            ..lineTo(x + tileSize / 2, y + tileSize - offset)
            ..lineTo(x + offset, y + tileSize / 2)
            ..close();
          canvas.drawPath(path, paint);

        } else {
          canvas.drawRect(Rect.fromLTWH(x, y, tileSize + 0.3, tileSize + 0.3), paint);
        }
      }
    }

    // ── Ojos ─────────────────────────────────────────────────────
    final pE = Paint()..isAntiAlias = true;
    final pI = Paint()..isAntiAlias = true;
    if (customEyes) { pE.color = eyeExt; pI.color = eyeInt; } else if (gradShader != null) { pE.shader = gradShader; pI.shader = gradShader; } else { pE.color = qrC1; pI.color = qrC1; }

    EyeStyle eStyle = EyeStyle.rect;
    if (estilo.contains("Puntos")) eStyle = EyeStyle.circ;
    if (estilo.contains("Diamantes")) eStyle = EyeStyle.diamond;

    _drawEye(canvas, 0, 0, tileSize, pE, pI, eStyle);
    _drawEye(canvas, (modules - 7) * tileSize, 0, tileSize, pE, pI, eStyle);
    _drawEye(canvas, 0, (modules - 7) * tileSize, tileSize, pE, pI, eStyle);
  }

  void _drawEye(Canvas canvas, double x, double y, double t, Paint pE, Paint pI, EyeStyle eStyle) {
    final double s = 7 * t;
    if (eStyle == EyeStyle.circ) {
      canvas.drawPath(Path()..addOval(Rect.fromLTWH(x, y, s, s))..addOval(Rect.fromLTWH(x + t, y + t, s - 2 * t, s - 2 * t))..fillType = PathFillType.evenOdd, pE);
      canvas.drawOval(Rect.fromLTWH(x + 2.1 * t, y + 2.1 * t, s - 4.2 * t, s - 4.2 * t), pI);
    } else if (eStyle == EyeStyle.diamond) {
      double cx = x + 3.5 * t; double cy = y + 3.5 * t;
      Path outPath = Path()..moveTo(cx, y)..lineTo(x + 7*t, cy)..lineTo(cx, y + 7*t)..lineTo(x, cy)..moveTo(cx, y + 1.2*t)..lineTo(x + 5.8*t, cy)..lineTo(cx, y + 5.8*t)..lineTo(x + 1.2*t, cy)..fillType = PathFillType.evenOdd;
      canvas.drawPath(outPath, pE);
      Path inPath = Path()..moveTo(cx, y + 2.2*t)..lineTo(x + 4.8*t, cy)..lineTo(cx, y + 4.8*t)..lineTo(x + 2.2*t, cy)..close();
      canvas.drawPath(inPath, pI);
    } else {
      canvas.drawPath(Path()..addRect(Rect.fromLTWH(x, y, s, s))..addRect(Rect.fromLTWH(x + t, y + t, s - 2 * t, s - 2 * t))..fillType = PathFillType.evenOdd, pE);
      canvas.drawRect(Rect.fromLTWH(x + 2.1 * t, y + 2.1 * t, s - 4.2 * t, s - 4.4 * t), pI);
    }
  }
  @override bool shouldRepaint(CustomPainter old) => true;
}

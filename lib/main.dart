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

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () => Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (context) => const MainScreen())));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
            child: Image.asset('assets/app_icon.png',
                width: 180,
                errorBuilder: (c, e, s) => const Icon(Icons.qr_code_2, size: 100))));
  }
}

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

  String _qrType    = "Sitio Web (URL)";
  String _estilo    = "Liquid Pro (Gusano)";
  String _qrColorMode = "Automático (Logo)";
  String _qrGradDir = "Vertical";
  Color  _qrC1      = Colors.black;
  Color  _qrC2      = const Color(0xFF1565C0);
  bool   _customEyes = false;
  Color  _eyeExt    = Colors.black;
  Color  _eyeInt    = Colors.black;
  String _bgMode    = "Blanco (Default)";
  String _bgGradDir = "Diagonal";
  Color  _bgC1      = Colors.white;
  Color  _bgC2      = const Color(0xFFF5F5F5);

  Uint8List?        _logoBytes;
  img_lib.Image?    _logoImage;
  List<List<bool>>? _outerMask;
  double _logoSize  = 65.0;
  double _auraSize  = 1.0;

  // ── Límites calculados dinámicamente ─────────────────────────
  // El QR versión 4 con nivel H puede perder hasta ~30% de módulos.
  // Reservamos como máximo 28% para ser conservadores.
  // Los 3 ojos (7x7 cada uno) son inamovibles = 147 módulos fijos.
  // Módulos totales en versión 4 = 33x33 = 1089.
  // Módulos de datos disponibles ≈ 1089 - 147 = 942.
  // Máximo excluibles = 942 * 0.28 ≈ 264 módulos.
  static const int    _qrModules      = 33;
  static const double _maxExcludeRatio = 0.28;
  static const int    _maxExcludable  = (_qrModules * _qrModules * _maxExcludeRatio).toInt(); // ~303

  double get _logoSizeMax {
    // Calculamos dinámicamente el máximo logoSize permitido dado _auraSize
    // para no superar _maxExcludable módulos excluidos.
    // Área excluida ≈ (logoSize/270 * _qrModules + 2*aura)² módulos
    // Despejamos logoSize:
    double aura = _auraSize.toDouble();
    double maxModulesLinear = _maxExcludable.toDouble();
    double maxSide = (maxModulesLinear.abs() > 0)
        ? (maxModulesLinear - 2 * aura).clamp(4.0, _qrModules.toDouble())
        : _qrModules.toDouble();
    double maxFrac = maxSide / _qrModules;
    return (maxFrac * 270.0).clamp(30.0, 110.0);
  }

  double get _auraSizeMax {
    // Máxima aura dado el logoSize actual
    double logoModules = (_logoSize / 270.0) * _qrModules;
    double maxAura = ((_maxExcludable - logoModules * logoModules) /
            (4 * logoModules + 4))
        .clamp(1.0, 5.0);
    return maxAura;
  }

  // Valores efectivos seguros (los que realmente se usan)
  double get _effectiveLogo => _logoSize.clamp(30.0, _logoSizeMax);
  double get _effectiveAura => _auraSize.clamp(1.0, _auraSizeMax);

  final GlobalKey _qrKey = GlobalKey();

  Future<void> _processLogo(File file) async {
    final bytes = await file.readAsBytes();
    img_lib.Image? image = img_lib.decodeImage(bytes);
    if (image == null) return;

    image = image.convert(numChannels: 4);
    final String ext = file.path.toLowerCase();
    if (ext.endsWith('.jpg') || ext.endsWith('.jpeg')) {
      image = _removeWhiteBackground(image);
    }

    final int w = image.width;
    final int h = image.height;

    // Silueta sólida: flood-fill inverso desde bordes del alpha
    // Todo transparente alcanzable desde el borde exterior = fondo real
    // Todo lo demás = parte del logo (incluyendo huecos interiores)
    final isBg = List.generate(h, (_) => List.filled(w, false));
    final queue = <List<int>>[];

    void enqAlpha(int x, int y) {
      if (x < 0 || x >= w || y < 0 || y >= h || isBg[y][x]) return;
      if (image!.getPixel(x, y).a <= 30) {
        isBg[y][x] = true;
        queue.add([x, y]);
      }
    }

    for (int x = 0; x < w; x++) { enqAlpha(x, 0); enqAlpha(x, h - 1); }
    for (int y = 0; y < h; y++) { enqAlpha(0, y); enqAlpha(w - 1, y); }
    while (queue.isNotEmpty) {
      final p = queue.removeLast();
      enqAlpha(p[0]+1, p[1]); enqAlpha(p[0]-1, p[1]);
      enqAlpha(p[0], p[1]+1); enqAlpha(p[0], p[1]-1);
    }

    // finalMask[y][x] = true → pertenece al logo (opaco o hueco interior)
    final finalMask = List.generate(h, (y) => List.generate(w, (x) => !isBg[y][x]));

    final pngBytes = Uint8List.fromList(img_lib.encodePng(image));
    final palette  = await PaletteGenerator.fromImageProvider(MemoryImage(pngBytes));

    setState(() {
      _logoBytes  = pngBytes;
      _logoImage  = image;
      _outerMask  = finalMask;
      if (_qrColorMode == "Automático (Logo)") {
        _qrC1 = palette.vibrantColor?.color ??
            palette.darkVibrantColor?.color ??
            palette.dominantColor?.color ?? Colors.black;
        _qrC2 = palette.darkMutedColor?.color ??
            palette.lightVibrantColor?.color ??
            _qrC1.withOpacity(0.7);
      }
    });
  }

  img_lib.Image _removeWhiteBackground(img_lib.Image src) {
    final int w = src.width, h = src.height;
    const int thresh = 230;
    final visited = List.generate(h, (_) => List.filled(w, false));
    final queue   = <List<int>>[];

    void enq(int x, int y) {
      if (x < 0 || x >= w || y < 0 || y >= h || visited[y][x]) return;
      final p = src.getPixel(x, y);
      if (p.r > thresh && p.g > thresh && p.b > thresh) {
        visited[y][x] = true;
        queue.add([x, y]);
      }
    }

    for (int x = 0; x < w; x++) { enq(x, 0); enq(x, h-1); }
    for (int y = 0; y < h; y++) { enq(0, y); enq(w-1, y); }
    while (queue.isNotEmpty) {
      final p = queue.removeLast();
      enq(p[0]+1,p[1]); enq(p[0]-1,p[1]);
      enq(p[0],p[1]+1); enq(p[0],p[1]-1);
    }

    final result = img_lib.Image(width: w, height: h, numChannels: 4);
    for (int y = 0; y < h; y++)
      for (int x = 0; x < w; x++) {
        final p = src.getPixel(x, y);
        if (visited[y][x]) result.setPixelRgba(x, y, 0, 0, 0, 0);
        else result.setPixelRgba(x, y, p.r.toInt(), p.g.toInt(), p.b.toInt(), 255);
      }
    return result;
  }

  String _getFinalData() {
    if (_c1.text.isEmpty) return "";
    switch (_qrType) {
      case "Sitio Web (URL)":  return _c1.text;
      case "Red WiFi":         return "WIFI:T:WPA;S:${_c1.text};P:${_c2.text};;";
      case "VCard (Contacto)": return "BEGIN:VCARD\nVERSION:3.0\nFN:${_c1.text} ${_c2.text}\nORG:${_c3.text}\nTEL:${_c4.text}\nEMAIL:${_c5.text}\nEND:VCARD";
      case "WhatsApp":         return "https://wa.me/${_c1.text.replaceAll('+','')}?text=${Uri.encodeComponent(_c2.text)}";
      case "E-mail":           return "mailto:${_c1.text}?subject=${_c2.text}&body=${_c3.text}";
      case "SMS (Mensaje)":    return "SMSTO:${_c1.text}:${_c2.text}";
      case "Teléfono":         return "tel:${_c1.text}";
      default:                 return _c1.text;
    }
  }

  @override
  Widget build(BuildContext context) {
    final String finalData = _getFinalData();
    final bool isEmpty = finalData.isEmpty;

    // Advertencia de seguridad si el usuario está cerca del límite
    final bool nearLimit = _effectiveLogo < _logoSize - 2 || _effectiveAura < _auraSize - 0.5;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
          title: const Text("QR + Logo",
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white, elevation: 0, centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(15),
        child: Column(children: [
          // 1. Contenido
          _buildCard("1. Contenido", Column(children: [
            DropdownButtonFormField<String>(
                value: _qrType,
                items: ["Sitio Web (URL)","WhatsApp","Red WiFi","VCard (Contacto)",
                        "Teléfono","E-mail","SMS (Mensaje)","Texto Libre"]
                    .map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() => _qrType = v!)),
            const SizedBox(height: 10),
            _buildInputs(),
          ])),

          // 2. Estilo y Color
          _buildCard("2. Estilo y Color QR", Column(children: [
            DropdownButtonFormField<String>(
                value: _estilo,
                items: ["Liquid Pro (Gusano)","Normal (Cuadrado)","Barras (Vertical)",
                        "Circular (Puntos)","Diamantes (Rombos)"]
                    .map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() => _estilo = v!)),
            DropdownButtonFormField<String>(
                value: _qrColorMode,
                items: ["Automático (Logo)","Sólido (Un Color)","Degradado Custom"]
                    .map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() => _qrColorMode = v!)),
            _buildColorPicker("Colores QR", _qrC1, _qrC2,
                (c) => setState(() => _qrC1 = c), (c) => setState(() => _qrC2 = c),
                isGrad: _qrColorMode != "Sólido (Un Color)"),
            if (_qrColorMode != "Sólido (Un Color)")
              DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: "Dirección Degradado"),
                  value: _qrGradDir,
                  items: ["Vertical","Horizontal","Diagonal"]
                      .map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (v) => setState(() => _qrGradDir = v!)),
          ])),

          // 3. Ojos y Fondo
          _buildCard("3. Posicionamiento y Fondo", Column(children: [
            SwitchListTile(
                title: const Text("Personalizar Ojos"),
                value: _customEyes,
                onChanged: (v) => setState(() => _customEyes = v),
                contentPadding: EdgeInsets.zero),
            if (_customEyes)
              _buildColorPicker("Colores Ojos", _eyeExt, _eyeInt,
                  (c) => setState(() => _eyeExt = c), (c) => setState(() => _eyeInt = c),
                  isGrad: true),
            const Divider(),
            DropdownButtonFormField<String>(
                value: _bgMode,
                items: ["Blanco (Default)","Transparente","Sólido (Color)","Degradado"]
                    .map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() => _bgMode = v!)),
            if (_bgMode != "Blanco (Default)" && _bgMode != "Transparente") ...[
              _buildColorPicker("Colores Fondo", _bgC1, _bgC2,
                  (c) => setState(() => _bgC1 = c), (c) => setState(() => _bgC2 = c),
                  isGrad: _bgMode == "Degradado"),
              if (_bgMode == "Degradado")
                DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: "Dirección Fondo"),
                    value: _bgGradDir,
                    items: ["Vertical","Horizontal","Diagonal"]
                        .map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (v) => setState(() => _bgGradDir = v!)),
            ],
          ])),

          // 4. Logo
          _buildCard("4. Logo", Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ElevatedButton.icon(
                onPressed: () async {
                  final img = await ImagePicker().pickImage(source: ImageSource.gallery);
                  if (img != null) await _processLogo(File(img.path));
                },
                icon: const Icon(Icons.image),
                label: Text(_logoBytes == null ? "CARGAR LOGO" : "LOGO CARGADO ✅"),
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: Colors.black, foregroundColor: Colors.white)),
            if (_logoBytes != null) ...[
              const SizedBox(height: 12),
              Row(children: [
                Text("Tamaño: ${_effectiveLogo.toInt()}px"),
                const Spacer(),
                if (_effectiveLogo < _logoSize - 1)
                  const Text("⚠️ limitado", style: TextStyle(color: Colors.orange, fontSize: 12)),
              ]),
              Slider(
                  value: _logoSize.clamp(30.0, 110.0),
                  min: 30, max: 110, divisions: 16,
                  activeColor: Colors.black,
                  onChanged: (v) => setState(() => _logoSize = v)),
            ],
          ])),

          // 5. Aura
          _buildCard("5. Ajuste de Aura (Separación QR ↔ Logo)", Column(children: [
            Row(children: [
              Text("Margen: ${_effectiveAura.toInt()} módulo(s)"),
              const Spacer(),
              if (_effectiveAura < _auraSize - 0.5)
                const Text("⚠️ limitado", style: TextStyle(color: Colors.orange, fontSize: 12)),
            ]),
            Slider(
                value: _auraSize.clamp(1.0, 5.0),
                min: 1,   // mínimo garantizado: siempre hay separación visible
                max: 5,
                divisions: 4,
                activeColor: Colors.black,
                onChanged: (v) => setState(() => _auraSize = v)),
            if (nearLimit)
              Container(
                margin: const EdgeInsets.only(top: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200)),
                child: const Text(
                  "⚠️ Logo + Aura ajustados automáticamente para mantener el QR escaneable.",
                  style: TextStyle(fontSize: 11, color: Colors.deepOrange),
                ),
              ),
          ])),

          const SizedBox(height: 10),

          // Preview QR
          RepaintBoundary(
            key: _qrKey,
            child: Container(
              width: 320, height: 320,
              decoration: BoxDecoration(
                color: _bgMode == "Transparente" ? Colors.transparent
                    : (_bgMode == "Sólido (Color)" ? _bgC1 : Colors.white),
                gradient: _bgMode == "Degradado" ? _getGrad(_bgC1, _bgC2, _bgGradDir) : null,
              ),
              child: Center(
                child: isEmpty
                    ? const Text("Esperando contenido...", style: TextStyle(color: Colors.grey))
                    : Stack(alignment: Alignment.center, children: [
                        CustomPaint(
                          size: const Size(270, 270),
                          painter: QrMasterPainter(
                            data: finalData, estilo: _estilo,
                            logoImage: _logoImage, outerMask: _outerMask,
                            logoSize: _effectiveLogo,
                            auraSize: _effectiveAura,
                            qrC1: _qrC1, qrC2: _qrC2,
                            qrMode: _qrColorMode, qrDir: _qrGradDir,
                            customEyes: _customEyes,
                            eyeExt: _eyeExt, eyeInt: _eyeInt,
                          ),
                        ),
                        if (_logoBytes != null)
                          SizedBox(
                              width: _effectiveLogo,
                              height: _effectiveLogo,
                              child: Image.memory(_logoBytes!, fit: BoxFit.contain)),
                      ]),
              ),
            ),
          ),

          const SizedBox(height: 25),
          ElevatedButton(
              onPressed: isEmpty ? null : () => _exportar(),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[800], foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 60)),
              child: const Text("GUARDAR EN GALERÍA")),
          const SizedBox(height: 40),
        ]),
      ),
    );
  }

  LinearGradient _getGrad(Color c1, Color c2, String dir) {
    Alignment beg = Alignment.topCenter, end = Alignment.bottomCenter;
    if (dir == "Horizontal") { beg = Alignment.centerLeft;  end = Alignment.centerRight; }
    if (dir == "Diagonal")   { beg = Alignment.topLeft;     end = Alignment.bottomRight; }
    return LinearGradient(colors: [c1, c2], begin: beg, end: end);
  }

  Widget _buildInputs() {
    switch (_qrType) {
      case "VCard (Contacto)": return Column(children: [
        Row(children: [
          Expanded(child: TextField(controller: _c1, decoration: const InputDecoration(hintText: "Nombre"),   onChanged: (_) => setState((){}))),
          const SizedBox(width: 5),
          Expanded(child: TextField(controller: _c2, decoration: const InputDecoration(hintText: "Apellido"), onChanged: (_) => setState((){}))),
        ]),
        TextField(controller: _c3, decoration: const InputDecoration(hintText: "Empresa"),  onChanged: (_) => setState((){})),
        TextField(controller: _c4, decoration: const InputDecoration(hintText: "Teléfono"), keyboardType: TextInputType.phone,        onChanged: (_) => setState((){})),
        TextField(controller: _c5, decoration: const InputDecoration(hintText: "Email"),    keyboardType: TextInputType.emailAddress,  onChanged: (_) => setState((){})),
      ]);
      case "WhatsApp":
      case "SMS (Mensaje)": return Column(children: [
        TextField(controller: _c1, decoration: const InputDecoration(hintText: "Número (+595...)"), keyboardType: TextInputType.phone, onChanged: (_) => setState((){})),
        TextField(controller: _c2, decoration: const InputDecoration(hintText: "Mensaje"), onChanged: (_) => setState((){})),
      ]);
      case "Red WiFi": return Column(children: [
        TextField(controller: _c1, decoration: const InputDecoration(hintText: "SSID (Nombre Red)"), onChanged: (_) => setState((){})),
        TextField(controller: _c2, decoration: const InputDecoration(hintText: "Contraseña"),         onChanged: (_) => setState((){})),
      ]);
      case "E-mail": return Column(children: [
        TextField(controller: _c1, decoration: const InputDecoration(hintText: "Email Destino"), keyboardType: TextInputType.emailAddress, onChanged: (_) => setState((){})),
        TextField(controller: _c2, decoration: const InputDecoration(hintText: "Asunto"),  onChanged: (_) => setState((){})),
        TextField(controller: _c3, decoration: const InputDecoration(hintText: "Mensaje"), onChanged: (_) => setState((){})),
      ]);
      default: return TextField(controller: _c1,
          decoration: InputDecoration(hintText: _qrType == "Sitio Web (URL)" ? "https://..." : "Texto aquí..."),
          onChanged: (_) => setState((){}));
    }
  }

  Widget _buildCard(String title, Widget child) => Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
          side: BorderSide(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.only(bottom: 15),
      child: Padding(padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 5), child])));

  Widget _buildColorPicker(String label, Color c1, Color c2,
      Function(Color) onC1, Function(Color) onC2, {bool isGrad = false}) =>
      Padding(padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(children: [Text(label), const Spacer(),
            _colorBtn(c1, onC1),
            if (isGrad) ...[const SizedBox(width: 15), _colorBtn(c2, onC2)]]));

  Widget _colorBtn(Color current, Function(Color) onTap) => GestureDetector(
      onTap: () => _showPalette(onTap),
      child: CircleAvatar(backgroundColor: current, radius: 20,
          child: Icon(Icons.colorize, size: 16,
              color: current == Colors.white ? Colors.black : Colors.white)));

  void _showPalette(Function(Color) onSelect) => showDialog(
      context: context,
      builder: (ctx) => AlertDialog(content: Wrap(spacing: 12, runSpacing: 12,
          children: [Colors.black, Colors.white, Colors.red, Colors.blue,
                     Colors.green, Colors.orange, Colors.purple,
                     const Color(0xFF1565C0), Colors.grey]
              .map((c) => GestureDetector(
                  onTap: () { onSelect(c); Navigator.pop(ctx); },
                  child: CircleAvatar(backgroundColor: c, radius: 25))).toList())));

  Future<void> _exportar() async {
    final boundary = _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image    = await boundary.toImage(pixelRatio: 4.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    await ImageGallerySaver.saveImage(byteData!.buffer.asUint8List());
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ QR Guardado")));
  }
}

// ═══════════════════════════════════════════════════════════════════
// QrMasterPainter
// ═══════════════════════════════════════════════════════════════════
class QrMasterPainter extends CustomPainter {
  final String data, estilo, qrMode, qrDir;
  final img_lib.Image?    logoImage;
  final List<List<bool>>? outerMask;
  final double logoSize, auraSize;
  final bool customEyes;
  final Color qrC1, qrC2, eyeExt, eyeInt;

  QrMasterPainter({
    required this.data,      required this.estilo,
    required this.logoImage, required this.outerMask,
    required this.logoSize,  required this.auraSize,
    required this.qrC1,      required this.qrC2,
    required this.qrMode,    required this.qrDir,
    required this.customEyes,
    required this.eyeExt,    required this.eyeInt,
  });

  bool _isEyeModule(int r, int c, int m) =>
      (r < 7 && c < 7) || (r < 7 && c >= m - 7) || (r >= m - 7 && c < 7);

  @override
  void paint(Canvas canvas, Size size) {
    final qrCode  = QrCode(4, QrErrorCorrectLevel.H)..addData(data);
    final qrImage = QrImage(qrCode);
    final int    modules  = qrImage.moduleCount;
    final double tileSize = size.width / modules;

    final paint = Paint()..isAntiAlias = true;
    ui.Shader? gradShader;

    if (qrMode != "Sólido (Un Color)") {
      Alignment beg = Alignment.topCenter, end = Alignment.bottomCenter;
      if (qrDir == "Horizontal") { beg = Alignment.centerLeft;  end = Alignment.centerRight; }
      if (qrDir == "Diagonal")   { beg = Alignment.topLeft;     end = Alignment.bottomRight; }
      gradShader = ui.Gradient.linear(
          Offset(size.width * (beg.x + 1) / 2, size.height * (beg.y + 1) / 2),
          Offset(size.width * (end.x + 1) / 2, size.height * (end.y + 1) / 2),
          [qrC1, qrC2]);
      paint.shader = gradShader;
    } else {
      paint.color = qrC1;
    }

    // ── Construir máscara de exclusión ──────────────────────────
    final excl = List.generate(modules, (_) => List.filled(modules, false));
    if (logoImage != null && outerMask != null) {
      final double lf     = logoSize / 270.0;
      final double lStart = (1.0 - lf) / 2.0;
      final int    imgW   = logoImage!.width;
      final int    imgH   = logoImage!.height;

      // Paso 1: módulos base del logo
      final base = List.generate(modules, (_) => List.filled(modules, false));
      for (int r = 0; r < modules; r++) {
        for (int c = 0; c < modules; c++) {
          final nx = (c + 0.5) / modules;
          final ny = (r + 0.5) / modules;
          if (nx >= lStart && nx <= lStart + lf &&
              ny >= lStart && ny <= lStart + lf) {
            final px = ((nx - lStart) / lf * imgW).clamp(0, imgW - 1).toInt();
            final py = ((ny - lStart) / lf * imgH).clamp(0, imgH - 1).toInt();
            if (outerMask![py][px]) base[r][c] = true;
          }
        }
      }

      // Paso 2: expandir por aura — garantiza separación mínima de 1 módulo
      // auraSize ya viene validado desde _effectiveAura (mín 1)
      final int aura = auraSize.round().clamp(1, 5);
      for (int r = 0; r < modules; r++)
        for (int c = 0; c < modules; c++)
          if (base[r][c])
            for (int dr = -aura; dr <= aura; dr++)
              for (int dc = -aura; dc <= aura; dc++) {
                final nr = r + dr; final nc = c + dc;
                if (nr >= 0 && nr < modules && nc >= 0 && nc < modules)
                  excl[nr][nc] = true;
              }
    }

    // ── isSafeDark ──────────────────────────────────────────────
    bool isSafeDark(int r, int c) {
      if (r < 0 || r >= modules || c < 0 || c >= modules) return false;
      if (!qrImage.isDark(r, c)) return false;
      if (_isEyeModule(r, c, modules) && estilo != "Normal (Cuadrado)") return false;
      if (excl[r][c]) return false;
      return true;
    }

    // ── Dibujar módulos ─────────────────────────────────────────
    for (int r = 0; r < modules; r++) {
      for (int c = 0; c < modules; c++) {
        if (!isSafeDark(r, c)) continue;

        final double x = c * tileSize;
        final double y = r * tileSize;

        if (estilo.contains("Gusano")) {
          final bool rt = isSafeDark(r, c + 1);
          final bool dn = isSafeDark(r + 1, c);
          final bool br = isSafeDark(r + 1, c + 1);

          // Módulo base redondeado con radios de esquina adaptativos
          _drawLiquidModule(canvas, paint, x, y, tileSize,
              isSafeDark(r-1, c), rt, dn, isSafeDark(r, c-1));

          // Puentes limpios hacia vecinos
          if (rt) canvas.drawRect(
              Rect.fromLTWH(x + tileSize / 2, y + tileSize * 0.08,
                  tileSize / 2 + 0.5, tileSize * 0.84), paint);
          if (dn) canvas.drawRect(
              Rect.fromLTWH(x + tileSize * 0.08, y + tileSize / 2,
                  tileSize * 0.84, tileSize / 2 + 0.5), paint);
          // Relleno de esquina interior para 4 módulos unidos
          if (rt && dn && br) canvas.drawRect(
              Rect.fromLTWH(x + tileSize / 2, y + tileSize / 2,
                  tileSize / 2 + 0.5, tileSize / 2 + 0.5), paint);

        } else if (estilo.contains("Barras")) {
          final bool dn = isSafeDark(r + 1, c);
          canvas.drawRRect(RRect.fromRectAndRadius(
              Rect.fromLTWH(x + tileSize * 0.1, y, tileSize * 0.8, tileSize),
              Radius.circular(tileSize * 0.3)), paint);
          if (dn) canvas.drawRect(
              Rect.fromLTWH(x + tileSize * 0.1, y + tileSize / 2,
                  tileSize * 0.8, tileSize / 2 + 0.5), paint);

        } else if (estilo.contains("Puntos")) {
          // Orgánico: 3 tamaños basados en posición (determinista)
          final int seed = (r * 13 + c * 29 + r * c) % 10;
          final double radius = seed < 2 ? tileSize * 0.48
              : seed < 6 ? tileSize * 0.40
              : tileSize * 0.32;
          canvas.drawCircle(Offset(x + tileSize / 2, y + tileSize / 2), radius, paint);

        } else if (estilo.contains("Diamantes")) {
          // Orgánico: 3 escalas de rombo
          final int seed = (r * 11 + c * 17 + r * c) % 10;
          final double scale = seed < 2 ? 0.95 : seed < 6 ? 0.80 : 0.65;
          _drawDiamond(canvas, paint, x, y, tileSize, scale);

        } else {
          // Normal cuadrado
          canvas.drawRect(Rect.fromLTWH(x, y, tileSize + 0.3, tileSize + 0.3), paint);
        }
      }
    }

    // ── Ojos ────────────────────────────────────────────────────
    final pE = Paint()..isAntiAlias = true;
    final pI = Paint()..isAntiAlias = true;
    if (customEyes) {
      pE.color = eyeExt; pI.color = eyeInt;
    } else if (gradShader != null) {
      pE.shader = gradShader; pI.shader = gradShader;
    } else {
      pE.color = qrC1; pI.color = qrC1;
    }

    final bool circEyes    = estilo.contains("Puntos");
    final bool diamondEyes = estilo.contains("Diamantes");

    _drawEye(canvas, 0,                    0,                    tileSize, pE, pI, circEyes, diamondEyes);
    _drawEye(canvas, (modules-7)*tileSize, 0,                    tileSize, pE, pI, circEyes, diamondEyes);
    _drawEye(canvas, 0,                    (modules-7)*tileSize, tileSize, pE, pI, circEyes, diamondEyes);
  }

  // ── Liquid: esquinas adaptativas según vecinos ─────────────────
  void _drawLiquidModule(Canvas canvas, Paint paint,
      double x, double y, double t,
      bool up, bool right, bool down, bool left) {
    final double rad = t * 0.42;
    // Si hay vecino en esa dirección → esquina casi plana
    final double tl = (up || left)  ? rad * 0.1 : rad;
    final double tr = (up || right) ? rad * 0.1 : rad;
    final double br = (down || right) ? rad * 0.1 : rad;
    final double bl = (down || left)  ? rad * 0.1 : rad;

    final path = Path();
    path.moveTo(x + tl, y);
    path.lineTo(x + t - tr, y);
    path.quadraticBezierTo(x + t, y,     x + t, y + tr);
    path.lineTo(x + t, y + t - br);
    path.quadraticBezierTo(x + t, y + t, x + t - br, y + t);
    path.lineTo(x + bl, y + t);
    path.quadraticBezierTo(x, y + t,     x, y + t - bl);
    path.lineTo(x, y + tl);
    path.quadraticBezierTo(x, y,         x + tl, y);
    path.close();
    canvas.drawPath(path, paint);
  }

  // ── Diamante con escala variable ───────────────────────────────
  void _drawDiamond(Canvas canvas, Paint paint,
      double x, double y, double t, double scale) {
    final double cx = x + t / 2, cy = y + t / 2;
    final double h  = (t / 2) * scale;
    canvas.drawPath(
        Path()
          ..moveTo(cx,     cy - h)
          ..lineTo(cx + h, cy)
          ..lineTo(cx,     cy + h)
          ..lineTo(cx - h, cy)
          ..close(),
        paint);
  }

  // ── Ojo del QR: cuadrado, circular o diamante ──────────────────
  void _drawEye(Canvas canvas, double x, double y, double t,
      Paint pE, Paint pI, bool circ, bool diamond) {
    final double s  = 7 * t;
    final double cx = x + s / 2;
    final double cy = y + s / 2;

    if (diamond) {
      // Marco exterior romboidal
      final double ho = s / 2;
      final double hi = s / 2 - t;
      final double hc = s / 2 - 2.2 * t;

      final outer = Path()
        ..moveTo(cx,      cy - ho)
        ..lineTo(cx + ho, cy)
        ..lineTo(cx,      cy + ho)
        ..lineTo(cx - ho, cy)
        ..close();
      final hole = Path()
        ..moveTo(cx,      cy - hi)
        ..lineTo(cx + hi, cy)
        ..lineTo(cx,      cy + hi)
        ..lineTo(cx - hi, cy)
        ..close();
      // Marco = outer - hole
      canvas.drawPath(
          Path.combine(PathOperation.difference, outer, hole), pE);
      // Centro sólido
      canvas.drawPath(
          Path()
            ..moveTo(cx,      cy - hc)
            ..lineTo(cx + hc, cy)
            ..lineTo(cx,      cy + hc)
            ..lineTo(cx - hc, cy)
            ..close(),
          pI);

    } else if (circ) {
      canvas.drawPath(
          Path()
            ..addOval(Rect.fromLTWH(x, y, s, s))
            ..addOval(Rect.fromLTWH(x+t, y+t, s-2*t, s-2*t))
            ..fillType = PathFillType.evenOdd,
          pE);
      canvas.drawOval(
          Rect.fromLTWH(x + 2.1*t, y + 2.1*t, s - 4.2*t, s - 4.2*t), pI);

    } else {
      canvas.drawPath(
          Path()
            ..addRect(Rect.fromLTWH(x, y, s, s))
            ..addRect(Rect.fromLTWH(x+t, y+t, s-2*t, s-2*t))
            ..fillType = PathFillType.evenOdd,
          pE);
      canvas.drawRect(
          Rect.fromLTWH(x + 2.1*t, y + 2.1*t, s - 4.2*t, s - 4.4*t), pI);
    }
  }

  @override
  bool shouldRepaint(CustomPainter old) => true;
}

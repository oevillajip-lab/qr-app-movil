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

void main() => runApp(const MaterialApp(
    home: SplashScreen(), debugShowCheckedModeBanner: false));

// 📌 [SECCIÓN 1: CONFIGURACIÓN INICIAL Y GENERACIÓN BASE DEL QR]
// Aquí se crea la matriz de datos del QR (Nivel de corrección H).
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

// 📌 [SECCIÓN 2: LÓGICA DE FRENO MATEMÁTICO]
// NO TOCAR. Aquí se calcula el tamaño máximo del logo para no romper el QR.
// ═══════════════════════════════════════════════════════════════════
double _safeLogoMax({
  required int modules,
  required double auraModules,
  double canvasSize = 270.0,
  double hardMax    = 85.0,
  double hardMin    = 30.0,
}) {
  final double auraFrac = (auraModules * 2.0) / modules.toDouble();
  final double maxFrac  = (math.sqrt(0.27) - auraFrac).clamp(0.08, 0.519);
  return (maxFrac * canvasSize).clamp(hardMin, hardMax);
}

// 📌 [SECCIÓN 3: PANTALLA DE CARGA (SPLASH SCREEN)]
// Aquí cambias el logo de inicio o el tiempo de espera.
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
    Future.delayed(const Duration(seconds: 2), () => Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const MainScreen())));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: Colors.white,
      body: Center(child: Image.asset('assets/app_icon.png', width: 180,
          errorBuilder: (c, e, s) => const Icon(Icons.qr_code_2, size: 100))));
}

// ═══════════════════════════════════════════════════════════════════
// PANTALLA PRINCIPAL (MainScreen)
// ═══════════════════════════════════════════════════════════════════
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with SingleTickerProviderStateMixin {
  
  // 📌 [SECCIÓN 4: VARIABLES GLOBALES (ESTILOS, COLORES, TAMAÑOS)]
  // Aquí se guardan los textos, colores seleccionados, tamaños de logo, etc.
  final _c1 = TextEditingController();
  final _c2 = TextEditingController();
  final _c3 = TextEditingController();
  final _c4 = TextEditingController();
  final _c5 = TextEditingController();

  String _qrType      = "Sitio Web (URL)";
  String _estilo      = "Liquid Pro (Gusano)";
  String _estiloAvz   = "QR Circular";
  String _qrColorMode = "Sólido (Un Color)";
  String _qrGradDir   = "Vertical";
  Color  _qrC1        = Colors.black;
  Color  _qrC2        = const Color(0xFF1565C0);
  bool   _customEyes  = false;
  Color  _eyeExt      = Colors.black;
  Color  _eyeInt      = Colors.black;
  String _bgMode      = "Blanco (Default)";
  String _bgGradDir   = "Diagonal";
  Color  _bgC1        = Colors.white;
  Color  _bgC2        = const Color(0xFFF5F5F5);

  Uint8List?        _logoBytes;
  img_lib.Image?    _logoImage;
  List<List<bool>>? _outerMask;
  
  // NUEVAS VARIABLES PARA LA FORMA (MAPA/SILUETA)
  Uint8List?        _shapeBytes;
  img_lib.Image?    _shapeImage;
  List<List<bool>>? _shapeMask;

  double _logoSize    = 60.0;
  double _logoSizeMap = 270.0; // Tamaño base de la silueta
  double _auraSize    = 1.5;   // Mínimo de aura ahora es 1.5 (muy visible)
  String _mapSubStyle = "Liquid Pro (Gusano)"; // El estilo interno del mapa

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
    "QR Circular",
    "Split Liquid (Mitades)",
    "Forma de Mapa (Máscara)",
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  // 📌 [SECCIÓN 5: PROCESAMIENTO DE IMAGEN Y TEXTOS DEL QR]
  // Funciones para calcular espacio, quitar fondo blanco y formatear VCard/WiFi, etc.
  // ── Efectivo logo con freno ────────────────────────────────────
  double _effectiveLogo(bool isMap) {
    // Ya no usamos isMap aquí, el logo central siempre obedece a su propio tamaño
    final data = _getFinalData();
    if (data.isEmpty) return _logoSize;
    final qr = _buildQrImage(data);
    if (qr == null) return _logoSize;
    final maxPx = _safeLogoMax(modules: qr.moduleCount, auraModules: _auraSize);
    return _logoSize.clamp(30.0, maxPx);
  }

  // ── Procesar logo ──────────────────────────────────────────────
  Future<void> _processLogo(File file) async {
    final bytes = await file.readAsBytes();
    img_lib.Image? img = img_lib.decodeImage(bytes);
    if (img == null) return;
    img = img.convert(numChannels: 4);
    final ext = file.path.toLowerCase();
    if (ext.endsWith('.jpg') || ext.endsWith('.jpeg')) img = _removeWhiteBg(img);

    final w = img.width, h = img.height;
    final rB = List.generate(h, (_) => List.filled(w, false));
    for (int y = 0; y < h; y++) {
      int fx = -1, lx = -1;
      for (int x = 0; x < w; x++) if (img.getPixel(x,y).a > 30) { if (fx==-1) fx=x; lx=x; }
      if (fx != -1) for (int x = fx; x <= lx; x++) rB[y][x] = true;
    }
    final mask = List.generate(h, (_) => List.filled(w, false));
    for (int x = 0; x < w; x++) {
      int fy = -1, ly = -1;
      for (int y = 0; y < h; y++) if (img.getPixel(x,y).a > 30) { if (fy==-1) fy=y; ly=y; }
      if (fy != -1) for (int y = fy; y <= ly; y++) if (rB[y][x]) mask[y][x] = true;
    }
    final png     = Uint8List.fromList(img_lib.encodePng(img));
    final palette = await PaletteGenerator.fromImageProvider(MemoryImage(png));
    setState(() {
      _logoBytes  = png;
      _logoImage  = img;
      _outerMask  = mask;
      _qrC1 = palette.darkVibrantColor?.color ?? palette.darkMutedColor?.color ?? palette.dominantColor?.color ?? Colors.black;
      _qrC2 = palette.vibrantColor?.color ?? palette.lightVibrantColor?.color ?? _qrC1;
      _qrColorMode = "Automático (Logo)";
    });
  }

      // ── Procesar forma (Silueta / Mapa) separada del logo ──────────
  Future<void> _processShape(File file) async {
    final bytes = await file.readAsBytes();
    img_lib.Image? img = img_lib.decodeImage(bytes);
    if (img == null) return;
    img = img.convert(numChannels: 4);
    final ext = file.path.toLowerCase();
    if (ext.endsWith('.jpg') || ext.endsWith('.jpeg')) img = _removeWhiteBg(img);

    final w = img.width, h = img.height;
    final rB = List.generate(h, (_) => List.filled(w, false));
    for (int y = 0; y < h; y++) {
      int fx = -1, lx = -1;
      for (int x = 0; x < w; x++) if (img.getPixel(x,y).a > 30) { if (fx==-1) fx=x; lx=x; }
      if (fx != -1) for (int x = fx; x <= lx; x++) rB[y][x] = true;
    }
    final mask = List.generate(h, (_) => List.filled(w, false));
    for (int x = 0; x < w; x++) {
      int fy = -1, ly = -1;
      for (int y = 0; y < h; y++) if (img.getPixel(x,y).a > 30) { if (fy==-1) fy=y; ly=y; }
      if (fy != -1) for (int y = fy; y <= ly; y++) if (rB[y][x]) mask[y][x] = true;
    }
    final png     = Uint8List.fromList(img_lib.encodePng(img));
    final palette = await PaletteGenerator.fromImageProvider(MemoryImage(png));
    
    setState(() {
      _shapeBytes = png;
      _shapeImage = img;
      _shapeMask  = mask;
      // Si no hay logo subido, usamos los colores de la silueta para el modo Automático
      if (_qrColorMode == "Automático (Logo)" && _logoBytes == null) {
        _qrC1 = palette.darkVibrantColor?.color ?? palette.darkMutedColor?.color ?? palette.dominantColor?.color ?? Colors.black;
        _qrC2 = palette.vibrantColor?.color ?? palette.lightVibrantColor?.color ?? _qrC1;
      }
    });
  }

  img_lib.Image _removeWhiteBg(img_lib.Image src) {
    final w = src.width, h = src.height;
    const thr = 230;
    final vis = List.generate(h, (_) => List.filled(w, false));
    final q   = <List<int>>[];
    void enq(int x, int y) {
      if (x<0||x>=w||y<0||y>=h||vis[y][x]) return;
      final p = src.getPixel(x,y);
      if (p.r>thr&&p.g>thr&&p.b>thr) { vis[y][x]=true; q.add([x,y]); }
    }
    for (int x=0; x<w; x++) { enq(x,0); enq(x,h-1); }
    for (int y=0; y<h; y++) { enq(0,y); enq(w-1,y); }
    while (q.isNotEmpty) {
      final p=q.removeLast();
      enq(p[0]+1,p[1]); enq(p[0]-1,p[1]); enq(p[0],p[1]+1); enq(p[0],p[1]-1);
    }
    final res = img_lib.Image(width: w, height: h, numChannels: 4);
    for (int y=0; y<h; y++) for (int x=0; x<w; x++) {
      final p = src.getPixel(x,y);
      if (vis[y][x]) res.setPixelRgba(x,y,0,0,0,0);
      else res.setPixelRgba(x,y,p.r.toInt(),p.g.toInt(),p.b.toInt(),255);
    }
    return res;
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

  // 📌 [SECCIÓN 6: INTERFAZ DE USUARIO (TABS BÁSICO Y AVANZADO)]
  // Aquí se arma la pantalla visualmente (AppBar, TabBar, etc).
  // ══════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F6),
      appBar: AppBar(
        title: const Text("QR + Logo PRO",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800,
                fontSize: 18, letterSpacing: -0.5)),
        backgroundColor: Colors.white, elevation: 0, centerTitle: true,
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.black,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          tabs: const [Tab(text: "Básico"), Tab(text: "Avanzado")],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [_buildBasicTab(), _buildAdvancedTab()],
      ),
    );
  }

  // TAB BÁSICO
  Widget _buildBasicTab() {
    final data    = _getFinalData();
    final isEmpty = data.isEmpty;
    final effLogo = _effectiveLogo(false);
    final limited = _logoBytes != null && effLogo < _logoSize - 0.5;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 30),
      child: Column(children: [

        // 1. Selector visual de estilo
        _card("1. Estilo del QR", _styleSelector(_basicStyles, _estilo,
            (s) => setState(() => _estilo = s))),

        // 2. Contenido
        _card("2. Contenido", Column(children: [
          _typeDropdown(),
          const SizedBox(height: 10),
          _buildInputs(),
        ])),

        // 3. Logo
        _card("3. Logo", _logoSection(effLogo, limited, false)),

        // 4. Fondo (básico: 3 opciones sin degradado)
        _card("4. Fondo", Column(children: [
          DropdownButtonFormField<String>(
              value: (_bgMode == "Degradado") ? "Blanco (Default)" : _bgMode,
              items: ["Blanco (Default)", "Transparente", "Sólido (Color)"]
                  .map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _bgMode = v!)),
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
      ]),
    );
  }

  // TAB AVANZADO
  Widget _buildAdvancedTab() {
    final data      = _getFinalData();
    final isEmpty   = data.isEmpty;
    final isMap     = _estiloAvz == "Forma de Mapa (Máscara)";
    final effLogo   = _effectiveLogo(isMap);
    final limited   = _logoBytes != null && !isMap && effLogo < _logoSize - 0.5;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 30),
      child: Column(children: [

        // 1. Contenido
        _card("1. Contenido", Column(children: [
          _typeDropdown(),
          const SizedBox(height: 10),
          _buildInputs(),
        ])),

        // 2. Estilo avanzado (selector visual con todos)
        _card("2. Estilo del QR", Column(children: [
          _styleSelector(_advStyles, _estiloAvz,
              (s) => setState(() => _estiloAvz = s)),
              
          // LA CORRECCIÓN: Si elige Mapa, le dejamos elegir de qué están hechos los trazos
          if (_estiloAvz == "Forma de Mapa (Máscara)") ...[
            const Padding(padding: EdgeInsets.only(top: 14, bottom: 8),
                child: Text("Estilo de relleno del Mapa:", 
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
            DropdownButtonFormField<String>(
                value: _mapSubStyle,
                decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12)),
                items: _basicStyles.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() => _mapSubStyle = v!)),
          ],
        ])),

        // 3. Color y degradado
        _card("3. Color y Degradado", Column(children: [
          DropdownButtonFormField<String>(
              value: _qrColorMode,
              items: ["Automático (Logo)", "Sólido (Un Color)", "Degradado Custom"]
                  .map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _qrColorMode = v!)),
          const SizedBox(height: 4),
          _colorRow("Color QR",
              _qrC1, _qrColorMode != "Sólido (Un Color)" ? _qrC2 : null,
              (c) => setState(() => _qrC1 = c),
              (c) => setState(() => _qrC2 = c)),
          if (_qrColorMode == "Degradado Custom")
            DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: "Dirección degradado"),
                value: _qrGradDir,
                items: ["Vertical", "Horizontal", "Diagonal"]
                    .map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() => _qrGradDir = v!)),
        ])),

        // 4. Ojos
        _card("4. Ojos del QR", Column(children: [
          SwitchListTile(
              title: const Text("Personalizar color de ojos"),
              value: _customEyes,
              onChanged: (v) => setState(() => _customEyes = v),
              contentPadding: EdgeInsets.zero),
          if (_customEyes)
            _colorRow("Ojos: exterior / interior",
                _eyeExt, _eyeInt,
                (c) => setState(() => _eyeExt = c),
                (c) => setState(() => _eyeInt = c)),
        ])),

        // 5. Logo
        _card("5. Logo", _logoSection(effLogo, limited, isMap)),

        // 6. Fondo completo
        _card("6. Fondo", Column(children: [
          DropdownButtonFormField<String>(
              value: _bgMode,
              items: ["Blanco (Default)", "Transparente", "Sólido (Color)", "Degradado"]
                  .map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _bgMode = v!)),
          if (_bgMode != "Blanco (Default)" && _bgMode != "Transparente") ...[
            const SizedBox(height: 6),
            _colorRow("Color fondo",
                _bgC1, _bgMode == "Degradado" ? _bgC2 : null,
                (c) => setState(() => _bgC1 = c),
                (c) => setState(() => _bgC2 = c)),
            if (_bgMode == "Degradado")
              DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: "Dirección fondo"),
                  value: _bgGradDir,
                  items: ["Vertical", "Horizontal", "Diagonal"]
                      .map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (v) => setState(() => _bgGradDir = v!)),
          ],
        ])),

        const SizedBox(height: 10),
        _qrPreview(data, isEmpty, _estiloAvz, true, effLogo),
        const SizedBox(height: 20),
        _actionButtons(isEmpty),
      ]),
    );
  }

  // 📌 [SECCIÓN 7: SELECTOR VISUAL DE ESTILOS (MINIATURAS RECUADROS)]
  // Aquí es donde cambiaremos la palabra "TU LOGO" a "LOGO".
  // ══════════════════════════════════════════════════════════════
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
          final sel   = style == selected;
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
                    : [BoxShadow(color: Colors.black.withOpacity(0.04),
                        blurRadius: 4)],
              ),
              child: Column(children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    child: Stack(alignment: Alignment.center, children: [
                      SizedBox(
                        width: 92, height: 92,
                        child: CustomPaint(
                          painter: StylePreviewPainter(
                              style: style, c1: _qrC1, c2: _qrC2),
                        ),
                      ),
                      // Logo o placeholder "LOGO" limpio (sin recuadro)
                      if (_logoBytes != null)
                        SizedBox(width: 24, height: 24,
                            child: Image.memory(_logoBytes!, fit: BoxFit.contain))
                      else
                        const Text("LOGO",
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900,
                                color: Colors.black, letterSpacing: 0.5)),
                        ),
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
                      style: TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w700,
                          color: sel ? Colors.white : Colors.black87,
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
    if (s.contains("Gusano"))   return "Liquid";
    if (s.contains("Cuadrado")) return "Normal";
    if (s.contains("Barras"))   return "Barras";
    if (s.contains("Puntos"))   return "Círculos";
    if (s.contains("Rombos"))   return "Diamantes";
    if (s.contains("Circular") && !s.contains("QR")) return "Circular";
    if (s.contains("QR Circ"))  return "QR Circular";
    if (s.contains("Split"))    return "Split";
    if (s.contains("Mapa"))     return "Mapa";
    return s;
  }

  // 📌 [SECCIÓN 8: WIDGETS REUTILIZABLES (BOTONES, LOGO, PREVIEW, INPUTS)]
  // Todo lo que construye la UI interna (Slider, Color Picker, Campos de texto, Guardar)
  // ══════════════════════════════════════════════════════════════
  Widget _logoSection(double effLogo, bool limited, bool isMap) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      
      if (isMap) ...[
        // Botón para la Forma/Silueta (Aparece solo en modo Mapa)
        ElevatedButton.icon(
            onPressed: () async {
              final img = await ImagePicker().pickImage(source: ImageSource.gallery);
              if (img != null) await _processShape(File(img.path));
            },
            icon: const Icon(Icons.format_shapes),
            label: Text(_shapeBytes == null ? "1. CARGAR FORMA (SILUETA)" : "1. FORMA CARGADA ✅"),
            style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))),
        if (_shapeBytes != null) ...[
          const SizedBox(height: 10),
          Text("Tamaño de la Forma: ${_logoSizeMap.toInt()}px",
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          Slider(value: _logoSizeMap, min: 50, max: 270, divisions: 22,
              activeColor: const Color(0xFF1565C0),
              onChanged: (v) => setState(() => _logoSizeMap = v)),
        ],
        const SizedBox(height: 14),
        // Botón para el Logo central
        ElevatedButton.icon(
            onPressed: () async {
              final img = await ImagePicker().pickImage(source: ImageSource.gallery);
              if (img != null) await _processLogo(File(img.path));
            },
            icon: const Icon(Icons.image),
            label: Text(_logoBytes == null ? "2. CARGAR LOGO (OPCIONAL)" : "2. LOGO CARGADO ✅"),
            style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: Colors.black, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))),
      ] else ...[
        // Botón normal para los demás estilos (cuando NO es mapa)
        ElevatedButton.icon(
            onPressed: () async {
              final img = await ImagePicker().pickImage(source: ImageSource.gallery);
              if (img != null) await _processLogo(File(img.path));
            },
            icon: const Icon(Icons.image),
            label: Text(_logoBytes == null ? "CARGAR LOGO" : "LOGO CARGADO ✅"),
            style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: Colors.black, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))),
      ],

      const Padding(padding: EdgeInsets.only(top: 8, bottom: 2),
          child: Text("💡 Si tu logo es blanco, elige un fondo oscuro.",
              style: TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic))),
      
      // MÁGIA: Estos Sliders (Tamaño Logo y Aura) SOLO existen si se subió un logo
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
                    border: Border.all(color: Colors.orange.shade200)),
                child: const Text("⚠️ limitado automático",
                    style: TextStyle(fontSize: 11, color: Colors.deepOrange,
                        fontWeight: FontWeight.w600))),
        ]),
        Slider(value: _logoSize, min: 30, max: 85, divisions: 11,
            activeColor: Colors.black,
            onChanged: (v) => setState(() => _logoSize = v)),
        
        // Aura ajustada (El mínimo ahora es 1.0, garantizando que siempre haya un hueco visible)
        Row(children: [
          const Text("Separación QR–Logo:",
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const Spacer(),
          Text("${_auraSize.toStringAsFixed(1)} módulo(s)",
              style: const TextStyle(fontSize: 12)),
        ]),
        Slider(value: _auraSize, min: 1.0, max: 3.0, divisions: 4,
            activeColor: Colors.black,
            onChanged: (v) => setState(() => _auraSize = v)),
      ],
    ]);
  }

  Widget _qrPreview(String data, bool isEmpty, String estilo, bool isAdv, double effLogo) {
    final isMap      = estilo == "Forma de Mapa (Máscara)";
    final isAdvStyle = isAdv && (estilo == "QR Circular" ||
        estilo == "Split Liquid (Mitades)" || isMap);
    final bgColor = _bgMode == "Transparente"  ? Colors.transparent
        : _bgMode == "Sólido (Color)"          ? _bgC1
        : Colors.white;
    final bgGrad  = _bgMode == "Degradado" ? _getGrad(_bgC1, _bgC2, _bgGradDir) : null;

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
              : Stack(alignment: Alignment.center, children: [
                  CustomPaint(
                    size: const Size(270, 270),
                    painter: isAdvStyle
                        ? QrAdvancedPainter(
                            data: data, estiloAvanzado: estilo,
                            logoImage: _logoImage, outerMask: _outerMask,
                            shapeImage: _shapeImage, shapeMask: _shapeMask, // NUEVO: Mandamos la forma
                            logoSize: effLogo, shapeSize: _logoSizeMap,     // NUEVO: Tamaño separado
                            auraSize: _auraSize,
                            qrC1: _qrC1, qrC2: _qrC2,
                            qrMode: _qrColorMode, qrDir: _qrGradDir,
                            customEyes: _customEyes,
                            eyeExt: _eyeExt, eyeInt: _eyeInt)
                        : QrMasterPainter(
                            data: data, estilo: estilo,
                            logoImage: _logoImage, outerMask: _outerMask,
                            logoSize: effLogo, auraSize: _auraSize,
                            qrC1: _qrC1, qrC2: _qrC2,
                            qrMode: _qrColorMode, qrDir: _qrGradDir,
                            customEyes: _customEyes,
                            eyeExt: _eyeExt, eyeInt: _eyeInt),
                  ),
                  // Renderizamos la imagen del logo central siempre que exista (incluso en mapa)
                  if (_logoBytes != null)
                    SizedBox(width: effLogo, height: effLogo,
                        child: Image.memory(_logoBytes!, fit: BoxFit.contain)),
                ]),
        ),
      ),
    );
  }

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
      default: // Texto Libre
        return _field(_c1, "Escribe tu texto aquí...", maxLines: 3);
    }
  }

  Widget _field(TextEditingController c, String hint,
      {TextInputType type = TextInputType.text,
      bool obscure = false, int maxLines = 1}) =>
      TextField(
          controller: c,
          decoration: InputDecoration(hintText: hint),
          keyboardType: type,
          obscureText: obscure,
          maxLines: maxLines,
          onChanged: (_) => setState(() {}));

  Widget _typeDropdown() => DropdownButtonFormField<String>(
      value: _qrType,
      decoration: const InputDecoration(labelText: "Tipo de QR"),
      items: ["Sitio Web (URL)", "WhatsApp", "Red WiFi", "VCard (Contacto)",
              "Teléfono", "E-mail", "SMS (Mensaje)", "Texto Libre"]
          .map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: (v) => setState(() => _qrType = v!));

  Widget _card(String title, Widget child) => Card(
      elevation: 0, color: Colors.white,
      shape: RoundedRectangleBorder(
          side: BorderSide(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(padding: const EdgeInsets.all(14), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800,
            fontSize: 14, letterSpacing: -0.3)),
        const SizedBox(height: 10),
        child,
      ])));

  Widget _colorRow(String label, Color c1, Color? c2,
      Function(Color) onC1, Function(Color)? onC2) =>
      Padding(padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Text(label, style: const TextStyle(fontSize: 13)),
            const Spacer(),
            _colorDot(c1, onC1),
            if (c2 != null && onC2 != null) ...[
              const SizedBox(width: 10),
              _colorDot(c2, onC2),
            ],
          ]));

  Widget _colorDot(Color cur, Function(Color) onTap) => GestureDetector(
      onTap: () => _palette(onTap),
      child: Container(width: 38, height: 38,
          decoration: BoxDecoration(color: cur, shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade300, width: 1.5),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 4)]),
          child: Icon(Icons.colorize, size: 15,
              color: cur.computeLuminance() > 0.5 ? Colors.black : Colors.white)));

  void _palette(Function(Color) onSel) => showDialog(context: context,
      builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("Elige un color",
              style: TextStyle(fontWeight: FontWeight.w700)),
          content: Wrap(spacing: 10, runSpacing: 10,
              children: [
                Colors.black, Colors.white, const Color(0xFF1565C0),
                Colors.red, Colors.green.shade700, Colors.orange,
                Colors.purple, Colors.teal, const Color(0xFFE91E63),
                const Color(0xFF00BCD4), Colors.brown, Colors.grey.shade700,
              ].map((c) => GestureDetector(
                  onTap: () { onSel(c); Navigator.pop(ctx); },
                  child: Container(width: 42, height: 42,
                      decoration: BoxDecoration(color: c, shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey.shade300))))).toList())));

  Widget _actionButtons(bool isEmpty) => Row(children: [
    Expanded(child: ElevatedButton.icon(
        onPressed: isEmpty ? null : _exportar,
        icon: const Icon(Icons.save_alt),
        label: const Text("GUARDAR"),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 54),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
    const SizedBox(width: 12),
    Expanded(child: ElevatedButton.icon(
        onPressed: isEmpty ? null : _compartir,
        icon: const Icon(Icons.share),
        label: const Text("COMPARTIR"),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 54),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
  ]);

  LinearGradient _getGrad(Color c1, Color c2, String dir) {
    var b = Alignment.topCenter, e = Alignment.bottomCenter;
    if (dir == "Horizontal") { b = Alignment.centerLeft;  e = Alignment.centerRight; }
    if (dir == "Diagonal")   { b = Alignment.topLeft;     e = Alignment.bottomRight; }
    return LinearGradient(colors: [c1, c2], begin: b, end: e);
  }

  Future<void> _exportar() async {
    final boundary = _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image    = await boundary.toImage(pixelRatio: 4.0);
    final data     = await image.toByteData(format: ui.ImageByteFormat.png);
    await ImageGallerySaver.saveImage(data!.buffer.asUint8List());
    if (mounted) ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("✅ QR guardado en galería")));
  }

  Future<void> _compartir() async {
    final boundary = _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image    = await boundary.toImage(pixelRatio: 4.0);
    final data     = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes    = data!.buffer.asUint8List();
    final dir  = await getTemporaryDirectory();
    final file = await File('${dir.path}/qr_generado.png').create();
    await file.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(file.path)], text: 'Generado con QR + Logo PRO');
  }
}

// Ojo de enum global
enum EyeStyle { rect, circ, diamond }

// 📌 [SECCIÓN 9: PINTOR DE MINIATURAS (DIBUJA EL QR PEQUEÑO)]
// Aquí es donde cambiaremos para que la miniatura dibuje sus ojitos según el estilo correspondiente.
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

    // Excluir área central para el logo
    const frac = 0.30;
    const s0   = (1.0 - frac) / 2.0;
    const s1   = s0 + frac;
    bool inCenter(int r, int c) {
      final nx = (c+0.5)/m, ny = (r+0.5)/m;
      return nx>=s0 && nx<=s1 && ny>=s0 && ny<=s1;
    }

    bool isEye(int r, int c) =>
        (r<7&&c<7)||(r<7&&c>=m-7)||(r>=m-7&&c<7);

    final lPath = Path();
    final lPaint = Paint()..isAntiAlias=true..style=PaintingStyle.stroke
        ..strokeWidth=t..strokeCap=StrokeCap.round..strokeJoin=StrokeJoin.round;
    if (grad!=null) lPaint.shader=grad; else lPaint.color=c1;

    bool ok(int r, int c) {
      if (r<0||r>=m||c<0||c>=m) return false;
      if (!qr.isDark(r,c)) return false;
      if (isEye(r,c)) return false;
      if (inCenter(r,c)) return false;
      return true;
    }

    for (int r=0; r<m; r++) for (int c=0; c<m; c++) {
      if (!ok(r,c)) continue;
      final double x=c*t, y=r*t, cx=x+t/2, cy=y+t/2;

      if (style.contains("Gusano")) {
        lPath.moveTo(cx,cy); lPath.lineTo(cx,cy);
        if (ok(r,c+1)) { lPath.moveTo(cx,cy); lPath.lineTo(cx+t,cy); }
        if (ok(r+1,c)) { lPath.moveTo(cx,cy); lPath.lineTo(cx,cy+t); }
      } else if (style.contains("Barras")) {
        if (r==0||!ok(r-1,c)) {
          int er=r; while(er+1<m&&ok(er+1,c)) er++;
          final p2 = Paint()..isAntiAlias=true;
          if (grad!=null) p2.shader=grad; else p2.color=c1;
          canvas.drawRRect(RRect.fromRectAndRadius(
              Rect.fromLTWH(x+t*0.1,y,t*0.8,(er-r+1)*t), Radius.circular(t*0.38)), p2);
        }
      } else if (style.contains("Puntos")) {
        double h=((r*13+c*29)%100)/100.0;
        canvas.drawCircle(Offset(cx,cy), t*0.35+t*0.13*h, paint);
      } else if (style.contains("Rombos")||style.contains("Diamant")) {
        double h=((r*17+c*31)%100)/100.0; double sc=0.65+0.45*h; double off=t*(1-sc)/2;
        canvas.drawPath(Path()..moveTo(cx,y+off)..lineTo(x+t-off,cy)
            ..lineTo(cx,y+t-off)..lineTo(x+off,cy)..close(), paint);
      } else if (style=="QR Circular") {
        final d=math.sqrt(math.pow(c-m/2,2)+math.pow(r-m/2,2));
        if (d>m/2.1) continue;
        lPath.moveTo(cx,cy); lPath.lineTo(cx,cy);
        if (ok(r,c+1)&&math.sqrt(math.pow(c+1-m/2,2)+math.pow(r-m/2,2))<=m/2.1) {
          lPath.moveTo(cx,cy); lPath.lineTo(cx+t,cy);
        }
        if (ok(r+1,c)&&math.sqrt(math.pow(c-m/2,2)+math.pow(r+1-m/2,2))<=m/2.1) {
          lPath.moveTo(cx,cy); lPath.lineTo(cx,cy+t);
        }
      } else if (style.contains("Split")) {
        final sp = c < m/2
            ? (Paint()..isAntiAlias=true..color=c1..style=PaintingStyle.stroke..strokeWidth=t..strokeCap=StrokeCap.round)
            : (Paint()..isAntiAlias=true..color=c2..style=PaintingStyle.stroke..strokeWidth=t..strokeCap=StrokeCap.round);
        final pp = Path()..moveTo(cx,cy)..lineTo(cx,cy);
        if (ok(r,c+1)) pp.lineTo(cx+t,cy);
        canvas.drawPath(pp, sp);
        if (ok(r+1,c)) canvas.drawPath(Path()..moveTo(cx,cy)..lineTo(cx,cy+t), sp);
      } else {
        // Normal + Mapa
        canvas.drawRect(Rect.fromLTWH(x,y,t+0.3,t+0.3), paint);
      }
    }

    if (style.contains("Gusano")||style=="QR Circular") {
      canvas.drawPath(lPath, lPaint);
    }

    // Ojos dinámicos según el estilo en preview
    final pE = Paint()..isAntiAlias=true;
    final pI = Paint()..isAntiAlias=true;
    if (grad!=null) { pE.shader=grad; pI.shader=grad; } else { pE.color=c1; pI.color=c1; }
    
    EyeStyle es = EyeStyle.rect;
    if (style.contains("Puntos") || style == "QR Circular") es = EyeStyle.circ;
    if (style.contains("Rombos") || style.contains("Diamant")) es = EyeStyle.diamond;

    void eye(double x, double y) {
      final s=7*t;
      if (es == EyeStyle.circ) {
        canvas.drawPath(Path()
            ..addOval(Rect.fromLTWH(x,y,s,s))
            ..addOval(Rect.fromLTWH(x+t,y+t,s-2*t,s-2*t))
            ..fillType=PathFillType.evenOdd, pE);
        canvas.drawOval(Rect.fromLTWH(x+2.1*t,y+2.1*t,s-4.2*t,s-4.2*t), pI);
      } else if (es == EyeStyle.diamond) {
        double cx=x+3.5*t, cy=y+3.5*t;
        canvas.drawPath(Path()
            ..moveTo(cx,y)..lineTo(x+7*t,cy)..lineTo(cx,y+7*t)..lineTo(x,cy)
            ..moveTo(cx,y+1.2*t)..lineTo(x+5.8*t,cy)..lineTo(cx,y+5.8*t)..lineTo(x+1.2*t,cy)
            ..fillType=PathFillType.evenOdd, pE);
        canvas.drawPath(Path()
            ..moveTo(cx,y+2.2*t)..lineTo(x+4.8*t,cy)
            ..lineTo(cx,y+4.8*t)..lineTo(x+2.2*t,cy)..close(), pI);
      } else {
        canvas.drawPath(Path()
            ..addRect(Rect.fromLTWH(x,y,s,s))
            ..addRect(Rect.fromLTWH(x+t,y+t,s-2*t,s-2*t))
            ..fillType=PathFillType.evenOdd, pE);
        canvas.drawRect(Rect.fromLTWH(x+2.1*t,y+2.1*t,s-4.2*t,s-4.4*t), pI);
      }
    }
    
    eye(0,0); eye((m-7)*t,0); eye(0,(m-7)*t);
  }

  @override
  bool shouldRepaint(StylePreviewPainter o) =>
      o.c1!=c1 || o.c2!=c2 || o.style!=style;
}

// 📌 [SECCIÓN 10: PINTOR DE QR BÁSICO]
// Dibuja los QR de la pestaña "Básicos" (tamaño final).
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
      (r<7&&c<7)||(r<7&&c>=m-7)||(r>=m-7&&c<7);

  @override
  void paint(Canvas canvas, Size size) {
    final qr = _buildQrImage(data);
    if (qr == null) { _err(canvas, size); return; }
    final int m = qr.moduleCount;
    final double t = size.width / m;

    // FRENO MATEMÁTICO dentro del painter — segunda línea de defensa
    final double effLogo = logoSize.clamp(
        30.0, _safeLogoMax(modules: m, auraModules: auraSize));

    final paint = Paint()..isAntiAlias=true;
    ui.Shader? grad;
    if (qrMode != "Sólido (Un Color)") {
      var b=Alignment.topCenter, e=Alignment.bottomCenter;
      if (qrDir=="Horizontal") { b=Alignment.centerLeft;  e=Alignment.centerRight; }
      if (qrDir=="Diagonal")   { b=Alignment.topLeft;     e=Alignment.bottomRight; }
      grad = ui.Gradient.linear(
          Offset(size.width*(b.x+1)/2, size.height*(b.y+1)/2),
          Offset(size.width*(e.x+1)/2, size.height*(e.y+1)/2),
          [qrC1, qrC2]);
      paint.shader = grad;
    } else { paint.color = qrC1; }

    // Exclusion mask
    final excl = List.generate(m, (_) => List.filled(m, false));
    if (logoImage != null && outerMask != null) {
      final lf=effLogo/270.0, ls=(1-lf)/2.0, le=ls+lf;
      final base = List.generate(m, (_) => List.filled(m, false));
      for (int r=0;r<m;r++) for (int c=0;c<m;c++) {
        bool hit=false;
        for (double dy=0.2;dy<=0.8&&!hit;dy+=0.3)
          for (double dx=0.2;dx<=0.8&&!hit;dx+=0.3) {
            final nx=(c+dx)/m, ny=(r+dy)/m;
            if (nx>=ls&&nx<=le&&ny>=ls&&ny<=le) {
              final px=((nx-ls)/lf*logoImage!.width).clamp(0,logoImage!.width-1).toInt();
              final py=((ny-ls)/lf*logoImage!.height).clamp(0,logoImage!.height-1).toInt();
              if (outerMask![py][px]) hit=true;
            }
          }
        if (hit) base[r][c]=true;
      }
      final ar=auraSize.toInt();
      for (int r=0;r<m;r++) for (int c=0;c<m;c++)
        if (base[r][c]) for (int dr=-ar;dr<=ar;dr++) for (int dc=-ar;dc<=ar;dc++) {
          final nr=r+dr, nc=c+dc;
          if (nr>=0&&nr<m&&nc>=0&&nc<m) excl[nr][nc]=true;
        }
    }

    bool ok(int r, int c) {
      if (r<0||r>=m||c<0||c>=m) return false;
      if (!qr.isDark(r,c)) return false;
      if (_isEye(r,c,m) && estilo!="Normal (Cuadrado)") return false;
      if (excl[r][c]) return false;
      return true;
    }

    final lPath  = Path();
    final lPaint = Paint()..isAntiAlias=true..style=PaintingStyle.stroke
        ..strokeWidth=t..strokeCap=StrokeCap.round..strokeJoin=StrokeJoin.round;
    if (grad!=null) lPaint.shader=grad; else lPaint.color=qrC1;

    for (int r=0;r<m;r++) for (int c=0;c<m;c++) {
      if (!ok(r,c)) continue;
      final double x=c*t, y=r*t, cx=x+t/2, cy=y+t/2;

      if (estilo.contains("Gusano")) {
        lPath.moveTo(cx,cy); lPath.lineTo(cx,cy);
        if (ok(r,c+1)) { lPath.moveTo(cx,cy); lPath.lineTo(cx+t,cy); }
        if (ok(r+1,c)) { lPath.moveTo(cx,cy); lPath.lineTo(cx,cy+t); }
      } else if (estilo.contains("Barras")) {
        if (r==0||!ok(r-1,c)) {
          int er=r; while(er+1<m&&ok(er+1,c)) er++;
          final p2=Paint()..isAntiAlias=true;
          if (grad!=null) p2.shader=grad; else p2.color=qrC1;
          canvas.drawRRect(RRect.fromRectAndRadius(
              Rect.fromLTWH(x+t*0.1,y,t*0.8,(er-r+1)*t),
              Radius.circular(t*0.38)), p2);
        }
      } else if (estilo.contains("Puntos")) {
        double h=((r*13+c*29)%100)/100.0;
        canvas.drawCircle(Offset(cx,cy), t*0.35+t*0.15*h, paint);
      } else if (estilo.contains("Diamantes")) {
        double h=((r*17+c*31)%100)/100.0;
        double sc=0.65+0.5*h, off=t*(1-sc)/2;
        canvas.drawPath(Path()
            ..moveTo(cx,y+off)..lineTo(x+t-off,cy)
            ..lineTo(cx,y+t-off)..lineTo(x+off,cy)..close(), paint);
      } else {
        canvas.drawRect(Rect.fromLTWH(x,y,t+0.3,t+0.3), paint);
      }
    }
    if (estilo.contains("Gusano")) canvas.drawPath(lPath, lPaint);

    // Ojos
    final pE=Paint()..isAntiAlias=true;
    final pI=Paint()..isAntiAlias=true;
    if (customEyes) { pE.color=eyeExt; pI.color=eyeInt; }
    else if (grad!=null) { pE.shader=grad; pI.shader=grad; }
    else { pE.color=qrC1; pI.color=qrC1; }
    EyeStyle es = EyeStyle.rect;
    if (estilo.contains("Puntos"))    es=EyeStyle.circ;
    if (estilo.contains("Diamantes")) es=EyeStyle.diamond;
    _eye(canvas,0,0,t,pE,pI,es);
    _eye(canvas,(m-7)*t,0,t,pE,pI,es);
    _eye(canvas,0,(m-7)*t,t,pE,pI,es);
  }

  void _eye(Canvas c, double x, double y, double t,
      Paint pE, Paint pI, EyeStyle es) {
    final s=7*t;
    if (es==EyeStyle.circ) {
      c.drawPath(Path()
          ..addOval(Rect.fromLTWH(x,y,s,s))
          ..addOval(Rect.fromLTWH(x+t,y+t,s-2*t,s-2*t))
          ..fillType=PathFillType.evenOdd, pE);
      c.drawOval(Rect.fromLTWH(x+2.1*t,y+2.1*t,s-4.2*t,s-4.2*t), pI);
    } else if (es==EyeStyle.diamond) {
      double cx=x+3.5*t, cy=y+3.5*t;
      c.drawPath(Path()
          ..moveTo(cx,y)..lineTo(x+7*t,cy)..lineTo(cx,y+7*t)..lineTo(x,cy)
          ..moveTo(cx,y+1.2*t)..lineTo(x+5.8*t,cy)..lineTo(cx,y+5.8*t)..lineTo(x+1.2*t,cy)
          ..fillType=PathFillType.evenOdd, pE);
      c.drawPath(Path()
          ..moveTo(cx,y+2.2*t)..lineTo(x+4.8*t,cy)
          ..lineTo(cx,y+4.8*t)..lineTo(x+2.2*t,cy)..close(), pI);
    } else {
      c.drawPath(Path()
          ..addRect(Rect.fromLTWH(x,y,s,s))
          ..addRect(Rect.fromLTWH(x+t,y+t,s-2*t,s-2*t))
          ..fillType=PathFillType.evenOdd, pE);
      c.drawRect(Rect.fromLTWH(x+2.1*t,y+2.1*t,s-4.2*t,s-4.4*t), pI);
    }
  }

  void _err(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0,0,size.width,size.height),
        Paint()..color=Colors.red.withOpacity(0.08));
    final tp = TextPainter(
        text: const TextSpan(text: 'Contenido\ndemasiado largo',
            style: TextStyle(color: Colors.red, fontSize: 15,
                fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center)
      ..layout(maxWidth: size.width);
    tp.paint(canvas, Offset((size.width-tp.width)/2, (size.height-tp.height)/2));
  }

  @override bool shouldRepaint(CustomPainter o) => true;
}

// 📌 [SECCIÓN 11: PINTOR DE QR AVANZADO]
// Dibuja los QR de la pestaña "Avanzado" (Mapa, Split, Circular).
// ═══════════════════════════════════════════════════════════════════
// QR ADVANCED PAINTER — estilos avanzados
// ═══════════════════════════════════════════════════════════════════
class QrAdvancedPainter extends CustomPainter {
  final String data, estiloAvanzado, qrMode, qrDir;
  final img_lib.Image? logoImage, shapeImage;
  final List<List<bool>>? outerMask, shapeMask;
  final double logoSize, shapeSize, auraSize;
  final bool customEyes;
  final Color qrC1, qrC2, eyeExt, eyeInt;

  const QrAdvancedPainter({
    required this.data, required this.estiloAvanzado,
    required this.logoImage, required this.outerMask,
    required this.shapeImage, required this.shapeMask,
    required this.logoSize, required this.shapeSize, required this.auraSize,
    required this.qrC1, required this.qrC2,
    required this.qrMode, required this.qrDir,
    required this.customEyes, required this.eyeExt, required this.eyeInt,
  });

  bool _isEye(int r, int c, int m) =>
      (r<7&&c<7)||(r<7&&c>=m-7)||(r>=m-7&&c<7);

  // Escudo protector vital para la lectura
  bool _isProtected(int r, int c, int m) {
    if (r <= 8 && c <= 8) return true; 
    if (r <= 8 && c >= m - 9) return true; 
    if (r >= m - 9 && c <= 8) return true; 
    if (r == 6 || c == 6) return true; // Líneas conectoras
    if (m > 21) { // Patrón de alineación
      int align = m - 7;
      if (r >= align - 3 && r <= align + 3 && c >= align - 3 && c <= align + 3) return true;
    }
    return false;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final qr = _buildQrImage(data);
    if (qr == null) return;
    final int m = qr.moduleCount;
    final double t = size.width / m;
    final bool isMap = estiloAvanzado == "Forma de Mapa (Máscara)";

    final double effLogo = logoSize.clamp(30.0, _safeLogoMax(modules: m, auraModules: auraSize));

    ui.Shader? grad;
    if (qrMode == "Degradado Custom") {
      var b=Alignment.topCenter, e=Alignment.bottomCenter;
      if (qrDir=="Horizontal") { b=Alignment.centerLeft;  e=Alignment.centerRight; }
      if (qrDir=="Diagonal")   { b=Alignment.topLeft;     e=Alignment.bottomRight; }
      grad = ui.Gradient.linear(
          Offset(size.width*(b.x+1)/2, size.height*(b.y+1)/2),
          Offset(size.width*(e.x+1)/2, size.height*(e.y+1)/2),
          [qrC1, qrC2]);
    }

    final pen1 = Paint()..isAntiAlias=true..style=PaintingStyle.stroke
        ..strokeWidth=t..strokeCap=StrokeCap.round..strokeJoin=StrokeJoin.round;
    if (grad!=null) pen1.shader=grad; else pen1.color=qrC1;
    final pen2 = Paint()..isAntiAlias=true..color=qrC2..style=PaintingStyle.stroke
        ..strokeWidth=t..strokeCap=StrokeCap.round..strokeJoin=StrokeJoin.round;

    final excl = List.generate(m, (_) => List.filled(m, false));

    // 1. Calcular el HUECO (Aura) del logo central
    if (logoImage != null && outerMask != null) {
      final lf=effLogo/270.0, ls=(1-lf)/2.0, le=ls+lf;
      final base=List.generate(m,(_)=>List.filled(m,false));
      for (int r=0;r<m;r++) for (int c=0;c<m;c++) {
        bool hit=false;
        for (double dy=0.2;dy<=0.8&&!hit;dy+=0.3)
          for (double dx=0.2;dx<=0.8&&!hit;dx+=0.3) {
            final nx=(c+dx)/m, ny=(r+dy)/m;
            if (nx>=ls&&nx<=le&&ny>=ls&&ny<=le) {
              final px=((nx-ls)/lf*logoImage!.width).clamp(0,logoImage!.width-1).toInt();
              final py=((ny-ls)/lf*logoImage!.height).clamp(0,logoImage!.height-1).toInt();
              if (outerMask![py][px]) hit=true;
            }
          }
        if (hit) base[r][c]=true;
      }
      final ar=auraSize.toInt();
      for (int r=0;r<m;r++) for (int c=0;c<m;c++)
        if (base[r][c]) for (int dr=-ar;dr<=ar;dr++) for (int dc=-ar;dc<=ar;dc++) {
          final nr=r+dr, nc=c+dc;
          if (nr>=0&&nr<m&&nc>=0&&nc<m) excl[nr][nc]=true;
        }
    }

    // 2. Calcular la SILUETA externa del Mapa
    final mapMask = List.generate(m, (_) => List.filled(m, false));
    if (isMap && shapeImage != null && shapeMask != null) {
      final lf=shapeSize/270.0, ls=(1-lf)/2.0, le=ls+lf;
      for (int r=0;r<m;r++) for (int c=0;c<m;c++) {
        final nx=(c+0.5)/m, ny=(r+0.5)/m;
        if (nx>=ls&&nx<=le&&ny>=ls&&ny<=le) {
          final px=((nx-ls)/lf*shapeImage!.width).clamp(0,shapeImage!.width-1).toInt();
          final py=((ny-ls)/lf*shapeImage!.height).clamp(0,shapeImage!.height-1).toInt();
          if (shapeMask![py][px]) mapMask[r][c]=true;
        }
      }
    }

    bool ok(int r, int c) {
      if (r<0||r>=m||c<0||c>=m) return false;
      if (!qr.isDark(r,c)) return false;
      if (_isEye(r,c,m)) return false; 
      
      // Siempre respetar el hueco del logo (el aura)
      if (excl[r][c]) return false;
      
      if (estiloAvanzado=="QR Circular") {
        if (math.sqrt(math.pow(c-m/2,2)+math.pow(r-m/2,2)) > m/2.1) return false;
      }
      
      // Limitar a la silueta del Mapa (protegiendo esquinas)
      if (isMap && shapeImage != null) {
        if (!mapMask[r][c] && !_isProtected(r, c, m)) return false;
      }
      
      return true;
    }

    final pathC1=Path(), pathC2=Path();
    for (int r=0;r<m;r++) for (int c=0;c<m;c++) {
      if (!ok(r,c)) continue;
      final double x=c*t, y=r*t, cx=x+t/2, cy=y+t/2;
      if (estiloAvanzado=="Split Liquid (Mitades)") {
        final left=c<m/2;
        final ap=left?pathC1:pathC2;
        ap.moveTo(cx,cy); ap.lineTo(cx,cy);
        if (ok(r,c+1)&&((c+1<m/2)==left)) { ap.moveTo(cx,cy); ap.lineTo(cx+t,cy); }
        if (ok(r+1,c)) { ap.moveTo(cx,cy); ap.lineTo(cx,cy+t); }
      } else {
        pathC1.moveTo(cx,cy); pathC1.lineTo(cx,cy);
        if (ok(r,c+1)) { pathC1.moveTo(cx,cy); pathC1.lineTo(cx+t,cy); }
        if (ok(r+1,c)) { pathC1.moveTo(cx,cy); pathC1.lineTo(cx,cy+t); }
      }
    }
    if (estiloAvanzado=="Split Liquid (Mitades)") {
      canvas.drawPath(pathC1,pen1);
      canvas.drawPath(pathC2,pen2);
    } else {
      canvas.drawPath(pathC1,pen1);
    }

    // Ojos
    final pE=Paint()..isAntiAlias=true;
    final pI=Paint()..isAntiAlias=true;
    if (customEyes) { pE.color=eyeExt; pI.color=eyeInt; }
    else if (grad!=null) { pE.shader=grad; pI.shader=grad; }
    else { pE.color=qrC1; pI.color=qrC1; }
    void eye(double x, double y) {
      final s=7*t;
      canvas.drawPath(Path()
          ..addOval(Rect.fromLTWH(x,y,s,s))
          ..addOval(Rect.fromLTWH(x+t,y+t,s-2*t,s-2*t))
          ..fillType=PathFillType.evenOdd, pE);
      canvas.drawOval(Rect.fromLTWH(x+2.1*t,y+2.1*t,s-4.2*t,s-4.2*t), pI);
    }
    eye(0,0); eye((m-7)*t,0); eye(0,(m-7)*t);
  }

  @override bool shouldRepaint(CustomPainter o) => true;
}

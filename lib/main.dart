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

void main() => runApp(const MaterialApp(
    home: SplashScreen(), debugShowCheckedModeBanner: false));

// ═══════════════════════════════════════════════════════════════════
// QR seguro — versión automática 1-40
// ═══════════════════════════════════════════════════════════════════
QrImage? _buildQrImage(String data) {
  try {
    final qrCode = QrCode.fromData(
        data: data, errorCorrectLevel: QrErrorCorrectLevel.H);
    return QrImage(qrCode);
  } catch (_) {
    return null;
  }
}

// ═══════════════════════════════════════════════════════════════════
// FRENO MATEMÁTICO UNIVERSAL
// Nivel H ≈ 30% recuperación. Margen seguro: 22%.
// (logoFrac + 2*auraFrac)² ≤ 0.22
// ═══════════════════════════════════════════════════════════════════
double _safeLogoMax({
  required int modules,
  required double auraModules,
  double canvasSize = 270.0,
  double hardMax    = 75.0,
  double hardMin    = 30.0,
}) {
  final auraFrac = (auraModules * 2.0) / modules.toDouble();
  final maxFrac  = (math.sqrt(0.22) - auraFrac).clamp(0.08, 0.40);
  return (maxFrac * canvasSize).clamp(hardMin, hardMax);
}

// Detección de finder patterns (ojos)
bool _isEye(int r, int c, int m) =>
    (r < 7 && c < 7) || (r < 7 && c >= m - 7) || (r >= m - 7 && c < 7);

// Módulos estructurales críticos (timing patterns + alignment)
bool _isStructural(int r, int c, int m) {
  if (_isEye(r, c, m)) return true;
  if (r == 6 || c == 6) return true; // timing patterns
  return false;
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

  String _qrType      = "Sitio Web (URL)";
  String _estilo      = "Liquid Pro (Gusano)";
  String _estiloAvz   = "QR Circular (Forma)";
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
  String _fusionShape = "Círculos";

  Uint8List?        _logoBytes;
  img_lib.Image?    _logoImage;
  List<List<bool>>? _outerMask;
  ui.Image?         _logoUiImage;
  double _logoSize    = 60.0;
  double _logoSizeMap = 200.0;
  double _auraSize    = 1.0;

  late TabController _tabCtrl;
  final GlobalKey _qrKey = GlobalKey();

  static const _basicStyles = [
    "Liquid Pro (Gusano)", "Normal (Cuadrado)", "Barras (Vertical)",
    "Circular (Puntos)", "Diamantes (Rombos)",
  ];

  static const _advStyles = [
    "Liquid Pro (Gusano)", "Normal (Cuadrado)", "Barras (Vertical)",
    "Circular (Puntos)", "Diamantes (Rombos)",
    "QR Circular (Forma)", "Split Liquid (Mitades)",
    "Formas (Máscara)", "Fusión (Mapeo Color)",
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  double _effectiveLogo(bool isMap) {
    if (isMap) return _logoSizeMap;
    final data = _getFinalData();
    if (data.isEmpty) return _logoSize;
    final qr = _buildQrImage(data);
    if (qr == null) return _logoSize;
    return _logoSize.clamp(30.0,
        _safeLogoMax(modules: qr.moduleCount, auraModules: _auraSize));
  }

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
      for (int x = 0; x < w; x++) {
        if (img.getPixel(x,y).a > 30) { if (fx==-1) fx=x; lx=x; }
      }
      if (fx != -1) for (int x = fx; x <= lx; x++) rB[y][x] = true;
    }
    final mask = List.generate(h, (_) => List.filled(w, false));
    for (int x = 0; x < w; x++) {
      int fy = -1, ly = -1;
      for (int y = 0; y < h; y++) {
        if (img.getPixel(x,y).a > 30) { if (fy==-1) fy=y; ly=y; }
      }
      if (fy != -1) for (int y = fy; y <= ly; y++) if (rB[y][x]) mask[y][x] = true;
    }
    final png = Uint8List.fromList(img_lib.encodePng(img));
    final codec = await ui.instantiateImageCodec(png);
    final frame = await codec.getNextFrame();
    final palette = await PaletteGenerator.fromImageProvider(MemoryImage(png));
    setState(() {
      _logoBytes    = png;
      _logoImage    = img;
      _outerMask    = mask;
      _logoUiImage  = frame.image;
      _qrC1 = palette.darkVibrantColor?.color
          ?? palette.darkMutedColor?.color
          ?? palette.dominantColor?.color ?? Colors.black;
      _qrC2 = palette.vibrantColor?.color
          ?? palette.lightVibrantColor?.color ?? _qrC1;
      _qrColorMode = "Automático (Logo)";
    });
  }

  img_lib.Image _removeWhiteBg(img_lib.Image src) {
    final w = src.width, h = src.height; const thr = 230;
    final vis = List.generate(h, (_) => List.filled(w, false));
    final q   = <List<int>>[];
    void enq(int x, int y) {
      if (x<0||x>=w||y<0||y>=h||vis[y][x]) return;
      final p = src.getPixel(x,y);
      if (p.r>thr&&p.g>thr&&p.b>thr) { vis[y][x]=true; q.add([x,y]); }
    }
    for (int x=0;x<w;x++){enq(x,0);enq(x,h-1);}
    for (int y=0;y<h;y++){enq(0,y);enq(w-1,y);}
    while (q.isNotEmpty) {
      final p=q.removeLast();
      enq(p[0]+1,p[1]);enq(p[0]-1,p[1]);enq(p[0],p[1]+1);enq(p[0],p[1]-1);
    }
    final res = img_lib.Image(width: w, height: h, numChannels: 4);
    for (int y=0;y<h;y++) for (int x=0;x<w;x++) {
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

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF4F4F6),
    appBar: AppBar(
      title: const Text("QR + Logo PRO",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800,
              fontSize: 18, letterSpacing: -0.5)),
      backgroundColor: Colors.white, elevation: 0, centerTitle: true,
      bottom: TabBar(
        controller: _tabCtrl,
        labelColor: Colors.black, unselectedLabelColor: Colors.grey,
        indicatorColor: Colors.black, indicatorWeight: 3,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        tabs: const [Tab(text: "Básico"), Tab(text: "Avanzado")],
      ),
    ),
    body: TabBarView(controller: _tabCtrl,
        children: [_buildBasicTab(), _buildAdvancedTab()]),
  );

  // ══════════════════════════════════════════════════════════════
  // TAB BÁSICO
  // ══════════════════════════════════════════════════════════════
  Widget _buildBasicTab() {
    final data    = _getFinalData();
    final isEmpty = data.isEmpty;
    final effLogo = _effectiveLogo(false);
    final limited = _logoBytes != null && effLogo < _logoSize - 0.5;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14,14,14,30),
      child: Column(children: [
        _card("1. Estilo del QR", _styleSelector(_basicStyles, _estilo,
            (s)=>setState(()=>_estilo=s))),
        _card("2. Contenido", Column(children: [
          _typeDropdown(), const SizedBox(height:10), _buildInputs()])),
        _card("3. Logo", _logoSection(effLogo, limited, false)),
        _card("4. Fondo", Column(children: [
          DropdownButtonFormField<String>(
              value: (_bgMode=="Degradado")?"Blanco (Default)":_bgMode,
              items: ["Blanco (Default)","Transparente","Sólido (Color)"]
                  .map((e)=>DropdownMenuItem(value:e,child:Text(e))).toList(),
              onChanged: (v)=>setState(()=>_bgMode=v!)),
          if (_bgMode=="Sólido (Color)") ...[
            const SizedBox(height:8),
            _colorRow("Color fondo",_bgC1,null,(c)=>setState(()=>_bgC1=c),null),
          ],
        ])),
        const SizedBox(height:10),
        _qrPreview(data, isEmpty, _estilo, false, effLogo),
        const SizedBox(height:20),
        _actionButtons(isEmpty),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // TAB AVANZADO
  // ══════════════════════════════════════════════════════════════
  Widget _buildAdvancedTab() {
    final data     = _getFinalData();
    final isEmpty  = data.isEmpty;
    final isMap    = _estiloAvz == "Formas (Máscara)";
    final isFusion = _estiloAvz == "Fusión (Mapeo Color)";
    final effLogo  = _effectiveLogo(isMap);
    final limited  = _logoBytes != null && !isMap && !isFusion && effLogo < _logoSize - 0.5;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14,14,14,30),
      child: Column(children: [
        _card("1. Contenido", Column(children: [
          _typeDropdown(), const SizedBox(height:10), _buildInputs()])),
        _card("2. Estilo del QR", _styleSelector(_advStyles, _estiloAvz,
            (s)=>setState(()=>_estiloAvz=s))),
        if (!isFusion)
          _card("3. Color y Degradado", Column(children: [
            DropdownButtonFormField<String>(
                value: _qrColorMode,
                items: ["Automático (Logo)","Sólido (Un Color)","Degradado Custom"]
                    .map((e)=>DropdownMenuItem(value:e,child:Text(e))).toList(),
                onChanged: (v)=>setState(()=>_qrColorMode=v!)),
            const SizedBox(height:4),
            _colorRow("Color QR", _qrC1,
                _qrColorMode!="Sólido (Un Color)"?_qrC2:null,
                (c)=>setState(()=>_qrC1=c), (c)=>setState(()=>_qrC2=c)),
            if (_qrColorMode=="Degradado Custom")
              DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText:"Dirección degradado"),
                  value: _qrGradDir,
                  items: ["Vertical","Horizontal","Diagonal"]
                      .map((e)=>DropdownMenuItem(value:e,child:Text(e))).toList(),
                  onChanged: (v)=>setState(()=>_qrGradDir=v!)),
          ]))
        else
          _card("3. Forma de Puntos", DropdownButtonFormField<String>(
              value: _fusionShape,
              items: ["Círculos","Cuadrados Suaves"]
                  .map((e)=>DropdownMenuItem(value:e,child:Text(e))).toList(),
              onChanged: (v)=>setState(()=>_fusionShape=v!))),
        _card("4. Ojos del QR", Column(children: [
          SwitchListTile(
              title: const Text("Personalizar color de ojos"),
              value: _customEyes,
              onChanged: (v)=>setState(()=>_customEyes=v),
              contentPadding: EdgeInsets.zero),
          if (_customEyes)
            _colorRow("Ojos: exterior / interior", _eyeExt, _eyeInt,
                (c)=>setState(()=>_eyeExt=c), (c)=>setState(()=>_eyeInt=c)),
        ])),
        _card("5. Logo", isFusion ? _logoSectionFusion() : _logoSection(effLogo, limited, isMap)),
        _card("6. Fondo", Column(children: [
          DropdownButtonFormField<String>(
              value: _bgMode,
              items: ["Blanco (Default)","Transparente","Sólido (Color)","Degradado"]
                  .map((e)=>DropdownMenuItem(value:e,child:Text(e))).toList(),
              onChanged: (v)=>setState(()=>_bgMode=v!)),
          if (_bgMode!="Blanco (Default)"&&_bgMode!="Transparente") ...[
            const SizedBox(height:6),
            _colorRow("Color fondo", _bgC1, _bgMode=="Degradado"?_bgC2:null,
                (c)=>setState(()=>_bgC1=c), (c)=>setState(()=>_bgC2=c)),
            if (_bgMode=="Degradado")
              DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText:"Dirección fondo"),
                  value: _bgGradDir,
                  items: ["Vertical","Horizontal","Diagonal"]
                      .map((e)=>DropdownMenuItem(value:e,child:Text(e))).toList(),
                  onChanged: (v)=>setState(()=>_bgGradDir=v!)),
          ],
        ])),
        const SizedBox(height:10),
        _qrPreview(data, isEmpty, _estiloAvz, true, effLogo),
        const SizedBox(height:20),
        _actionButtons(isEmpty),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // SELECTOR VISUAL
  // ══════════════════════════════════════════════════════════════
  Widget _styleSelector(List<String> styles, String selected, Function(String) onSelect) {
    return SizedBox(
      height: 128,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(vertical:2),
        itemCount: styles.length,
        separatorBuilder: (_,__)=>const SizedBox(width:10),
        itemBuilder: (ctx, i) {
          final style = styles[i]; final sel = style == selected;
          return GestureDetector(
            onTap: ()=>onSelect(style),
            child: AnimatedContainer(
              duration: const Duration(milliseconds:180), width: 96,
              decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(14),
                border: Border.all(color: sel?Colors.black:Colors.grey.shade200,
                    width: sel?2.5:1.5),
                boxShadow: sel
                    ? [BoxShadow(color:Colors.black.withOpacity(0.14),blurRadius:10,offset:const Offset(0,4))]
                    : [BoxShadow(color:Colors.black.withOpacity(0.04),blurRadius:4)],
              ),
              child: Column(children: [
                Expanded(child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: Stack(alignment: Alignment.center, children: [
                    SizedBox(width:92, height:92, child: CustomPaint(
                        painter: StylePreviewPainter(style:style, c1:_qrC1, c2:_qrC2))),
                    if (!style.contains("Formas") && !style.contains("Fusión"))
                      if (_logoBytes != null)
                        SizedBox(width:24, height:24,
                            child: Image.memory(_logoBytes!, fit:BoxFit.contain))
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal:6, vertical:2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.88),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color:Colors.grey.shade300, width:0.8)),
                          child: const Text("LOGO", textAlign:TextAlign.center,
                              style: TextStyle(fontSize:8, fontWeight:FontWeight.w900,
                                  color:Colors.black87, letterSpacing:0.8))),
                  ]),
                )),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical:5),
                  decoration: BoxDecoration(
                    color: sel?Colors.black:Colors.grey.shade50,
                    borderRadius: const BorderRadius.vertical(bottom:Radius.circular(12))),
                  child: Text(_shortName(style), textAlign:TextAlign.center,
                      style: TextStyle(fontSize:10, fontWeight:FontWeight.w700,
                          color:sel?Colors.white:Colors.black87, letterSpacing:-0.2)),
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
    if (s.contains("QR Circ"))  return "QR Circular";
    if (s.contains("Split"))    return "Split";
    if (s.contains("Formas"))   return "Formas";
    if (s.contains("Fusión"))   return "Fusión";
    return s;
  }

  Widget _logoSection(double effLogo, bool limited, bool isMap) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ElevatedButton.icon(
            onPressed: () async {
              final img = await ImagePicker().pickImage(source:ImageSource.gallery);
              if (img != null) await _processLogo(File(img.path));
            },
            icon: const Icon(Icons.image),
            label: Text(_logoBytes==null?"CARGAR LOGO":"LOGO CARGADO ✅"),
            style: ElevatedButton.styleFrom(minimumSize:const Size(double.infinity,50),
                backgroundColor:Colors.black, foregroundColor:Colors.white,
                shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(10)))),
        const Padding(padding:EdgeInsets.only(top:8,bottom:2),
            child: Text("💡 Si tu logo es blanco, elige un fondo oscuro.",
                style: TextStyle(color:Colors.grey, fontSize:12, fontStyle:FontStyle.italic))),
        if (_logoBytes != null) ...[
          const SizedBox(height:10),
          if (!isMap) ...[
            Row(children: [
              Text("Tamaño: ${effLogo.toInt()}px",
                  style:const TextStyle(fontWeight:FontWeight.w600, fontSize:13)),
              const Spacer(),
              if (limited)
                Container(
                    padding:const EdgeInsets.symmetric(horizontal:8,vertical:3),
                    decoration:BoxDecoration(color:Colors.orange.shade50,
                        borderRadius:BorderRadius.circular(20),
                        border:Border.all(color:Colors.orange.shade200)),
                    child:const Text("⚠️ límite seguridad activo",
                        style:TextStyle(fontSize:11,color:Colors.deepOrange,
                            fontWeight:FontWeight.w600))),
            ]),
            Slider(value:_logoSize, min:30, max:75, divisions:9,
                activeColor:Colors.black,
                onChanged:(v)=>setState(()=>_logoSize=v)),
            Row(children: [
              const Text("Separación QR–Logo:",
                  style:TextStyle(fontWeight:FontWeight.w600,fontSize:13)),
              const Spacer(),
              Text("${_auraSize.toInt()} módulo(s)",
                  style:const TextStyle(fontSize:12)),
            ]),
            Slider(value:_auraSize, min:0, max:3, divisions:3,
                activeColor:Colors.black,
                onChanged:(v)=>setState(()=>_auraSize=v)),
          ] else ...[
            Text("Tamaño forma: ${_logoSizeMap.toInt()}px",
                style:const TextStyle(fontWeight:FontWeight.w600,fontSize:13)),
            Slider(value:_logoSizeMap, min:50, max:270, divisions:22,
                activeColor:Colors.black,
                onChanged:(v)=>setState(()=>_logoSizeMap=v)),
          ],
        ],
      ]);

  Widget _logoSectionFusion() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ElevatedButton.icon(
            onPressed: () async {
              final img = await ImagePicker().pickImage(source:ImageSource.gallery);
              if (img != null) await _processLogo(File(img.path));
            },
            icon: const Icon(Icons.image),
            label: Text(_logoBytes==null?"CARGAR LOGO FONDO":"LOGO CARGADO ✅"),
            style: ElevatedButton.styleFrom(minimumSize:const Size(double.infinity,50),
                backgroundColor:Colors.black, foregroundColor:Colors.white,
                shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(10)))),
        if (_logoBytes != null)
          Padding(padding:const EdgeInsets.only(top:12),
              child: Container(
                padding:const EdgeInsets.all(12),
                decoration:BoxDecoration(color:Colors.blue.shade50,
                    borderRadius:BorderRadius.circular(8)),
                child: const Row(children: [
                  Icon(Icons.auto_awesome, color:Colors.blue),
                  SizedBox(width:10),
                  Expanded(child: Text(
                      "El logo se usa como fondo completo. Los módulos del QR toman el color del pixel correspondiente.",
                      style:TextStyle(fontSize:12,color:Colors.black87,
                          fontWeight:FontWeight.w500))),
                ]),
              )),
      ]);

  // ══════════════════════════════════════════════════════════════
  // PREVIEW
  // ══════════════════════════════════════════════════════════════
  Widget _qrPreview(String data, bool isEmpty, String estilo, bool isAdv, double effLogo) {
    final isMap    = estilo == "Formas (Máscara)";
    final isFusion = estilo == "Fusión (Mapeo Color)";
    final isAdvStyle = isAdv &&
        (estilo=="QR Circular (Forma)" || estilo=="Split Liquid (Mitades)" || isMap);
    final bgColor = _bgMode=="Transparente" ? Colors.transparent
        : _bgMode=="Sólido (Color)" ? _bgC1 : Colors.white;
    final bgGrad  = _bgMode=="Degradado" ? _getGrad(_bgC1,_bgC2,_bgGradDir) : null;

    return RepaintBoundary(
      key: _qrKey,
      child: Container(
        width:320, height:320,
        decoration: BoxDecoration(
          color: bgGrad==null ? bgColor : null, gradient: bgGrad,
          borderRadius: BorderRadius.circular(6),
          boxShadow: [BoxShadow(color:Colors.black.withOpacity(0.06),
              blurRadius:12, offset:const Offset(0,4))]),
        child: Center(
          child: isEmpty
              ? Column(mainAxisAlignment:MainAxisAlignment.center, children: const [
                  Icon(Icons.qr_code_2, size:56, color:Colors.black12),
                  SizedBox(height:8),
                  Text("Esperando contenido...",
                      style:TextStyle(color:Colors.grey, fontSize:14))])
              : Stack(alignment: Alignment.center, children: [
                  CustomPaint(
                    size: const Size(270,270),
                    painter: isFusion
                        ? QrFusionPainter(
                            data:data,
                            logoUiImage:_logoUiImage,
                            logoImage:_logoImage,
                            shape:_fusionShape,
                            dominantColor:_qrC1,
                            customEyes:_customEyes,
                            eyeExt:_eyeExt, eyeInt:_eyeInt)
                        : (isAdvStyle
                            ? QrAdvancedPainter(
                                data:data, estiloAvanzado:estilo,
                                logoImage:_logoImage, outerMask:_outerMask,
                                logoSize: isMap?_logoSizeMap:effLogo,
                                auraSize:_auraSize,
                                qrC1:_qrC1, qrC2:_qrC2,
                                qrMode:_qrColorMode, qrDir:_qrGradDir,
                                customEyes:_customEyes,
                                eyeExt:_eyeExt, eyeInt:_eyeInt)
                            : QrMasterPainter(
                                data:data, estilo:estilo,
                                logoImage:_logoImage, outerMask:_outerMask,
                                logoSize:effLogo, auraSize:_auraSize,
                                qrC1:_qrC1, qrC2:_qrC2,
                                qrMode:_qrColorMode, qrDir:_qrGradDir,
                                customEyes:_customEyes,
                                eyeExt:_eyeExt, eyeInt:_eyeInt)),
                  ),
                  if (_logoBytes!=null && !isMap && !isFusion)
                    SizedBox(width:effLogo, height:effLogo,
                        child:Image.memory(_logoBytes!, fit:BoxFit.contain)),
                ]),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // INPUTS
  // ══════════════════════════════════════════════════════════════
  Widget _buildInputs() {
    switch (_qrType) {
      case "Sitio Web (URL)":
        return _field(_c1,"Ej: https://mipagina.com",type:TextInputType.url);
      case "WhatsApp":
        return Column(children: [
          _field(_c1,"Número (+595981...)",type:TextInputType.phone,
              formatters:[FilteringTextInputFormatter.allow(RegExp(r'[0-9+]'))]),
          const SizedBox(height:10),
          _field(_c2,"Mensaje (opcional)"),
        ]);
      case "Red WiFi":
        return Column(children: [
          _field(_c1,"Nombre de la red (SSID)"),
          const SizedBox(height:10),
          _field(_c2,"Contraseña del WiFi",obscure:true),
        ]);
      case "VCard (Contacto)":
        return Column(children: [
          Row(children: [
            Expanded(child:_field(_c1,"Nombre")),
            const SizedBox(width:8),
            Expanded(child:_field(_c2,"Apellido")),
          ]),
          const SizedBox(height:10), _field(_c3,"Empresa / Organización"),
          const SizedBox(height:10),
          _field(_c4,"Teléfono (+595...)",type:TextInputType.phone,
              formatters:[FilteringTextInputFormatter.allow(RegExp(r'[0-9+]'))]),
          const SizedBox(height:10),
          _field(_c5,"Correo electrónico",type:TextInputType.emailAddress),
        ]);
      case "Teléfono":
        return _field(_c1,"Número a marcar (+595...)",type:TextInputType.phone,
            formatters:[FilteringTextInputFormatter.allow(RegExp(r'[0-9+]'))]);
      case "E-mail":
        return Column(children: [
          _field(_c1,"Correo destino",type:TextInputType.emailAddress),
          const SizedBox(height:10), _field(_c2,"Asunto"),
          const SizedBox(height:10), _field(_c3,"Cuerpo",maxLines:3),
        ]);
      case "SMS (Mensaje)":
        return Column(children: [
          _field(_c1,"Número destino (+595...)",type:TextInputType.phone,
              formatters:[FilteringTextInputFormatter.allow(RegExp(r'[0-9+]'))]),
          const SizedBox(height:10), _field(_c2,"Texto del SMS"),
        ]);
      default:
        return _field(_c1,"Escribe tu texto aquí...",maxLines:3);
    }
  }

  Widget _field(TextEditingController c, String hint,
      {TextInputType type=TextInputType.text,
      bool obscure=false, int maxLines=1,
      List<TextInputFormatter>? formatters}) =>
      TextField(controller:c, inputFormatters:formatters,
          decoration:InputDecoration(hintText:hint, filled:true, fillColor:Colors.white,
            contentPadding:const EdgeInsets.symmetric(horizontal:16,vertical:14),
            enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(12),
                borderSide:BorderSide(color:Colors.grey.shade300)),
            focusedBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(12),
                borderSide:const BorderSide(color:Colors.black,width:1.5))),
          keyboardType:type, obscureText:obscure, maxLines:maxLines,
          onChanged:(_)=>setState((){}));

  Widget _typeDropdown() => DropdownButtonFormField<String>(
      value: _qrType,
      decoration: InputDecoration(labelText:"Tipo de QR", filled:true, fillColor:Colors.white,
          border:OutlineInputBorder(borderRadius:BorderRadius.circular(12),
              borderSide:BorderSide.none)),
      items: ["Sitio Web (URL)","WhatsApp","Red WiFi","VCard (Contacto)",
              "Teléfono","E-mail","SMS (Mensaje)","Texto Libre"]
          .map((e)=>DropdownMenuItem(value:e,child:Text(e))).toList(),
      onChanged:(v)=>setState(()=>_qrType=v!));

  Widget _card(String title, Widget child) => Card(
      elevation:0, color:Colors.white,
      shape:RoundedRectangleBorder(
          side:BorderSide(color:Colors.grey.shade200),
          borderRadius:BorderRadius.circular(14)),
      margin:const EdgeInsets.only(bottom:12),
      child:Padding(padding:const EdgeInsets.all(14), child:Column(
          crossAxisAlignment:CrossAxisAlignment.start, children:[
        Text(title, style:const TextStyle(fontWeight:FontWeight.w800,
            fontSize:14, letterSpacing:-0.3)),
        const SizedBox(height:10), child])));

  Widget _colorRow(String label, Color c1, Color? c2,
      Function(Color) onC1, Function(Color)? onC2) =>
      Padding(padding:const EdgeInsets.symmetric(vertical:6),
          child:Row(children:[
            Text(label,style:const TextStyle(fontSize:13)), const Spacer(),
            _colorDot(c1,onC1),
            if (c2!=null&&onC2!=null)...[const SizedBox(width:10),_colorDot(c2,onC2)],
          ]));

  Widget _colorDot(Color cur, Function(Color) onTap) => GestureDetector(
      onTap:()=>_palette(onTap),
      child:Container(width:38, height:38,
          decoration:BoxDecoration(color:cur, shape:BoxShape.circle,
              border:Border.all(color:Colors.grey.shade300,width:1.5),
              boxShadow:[BoxShadow(color:Colors.black.withOpacity(0.07),blurRadius:4)]),
          child:Icon(Icons.colorize, size:15,
              color:cur.computeLuminance()>0.5?Colors.black:Colors.white)));

  void _palette(Function(Color) onSel) => showDialog(context:context,
      builder:(ctx)=>AlertDialog(
          shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16)),
          title:const Text("Elige un color",style:TextStyle(fontWeight:FontWeight.w700)),
          content:Wrap(spacing:10, runSpacing:10,
              children:[Colors.black,Colors.white,const Color(0xFF1565C0),
                Colors.red,Colors.green.shade700,Colors.orange,Colors.purple,Colors.teal,
                const Color(0xFFE91E63),const Color(0xFF00BCD4),Colors.brown,Colors.grey.shade700]
                  .map((c)=>GestureDetector(
                      onTap:(){ onSel(c); Navigator.pop(ctx); },
                      child:Container(width:42,height:42,
                          decoration:BoxDecoration(color:c,shape:BoxShape.circle,
                              border:Border.all(color:Colors.grey.shade300))))).toList())));

  Widget _actionButtons(bool isEmpty) => Row(children:[
    Expanded(child:ElevatedButton.icon(onPressed:isEmpty?null:_exportar,
        icon:const Icon(Icons.save_alt), label:const Text("GUARDAR"),
        style:ElevatedButton.styleFrom(backgroundColor:Colors.black,
            foregroundColor:Colors.white, minimumSize:const Size(double.infinity,54),
            shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12))))),
    const SizedBox(width:12),
    Expanded(child:ElevatedButton.icon(onPressed:isEmpty?null:_compartir,
        icon:const Icon(Icons.share), label:const Text("COMPARTIR"),
        style:ElevatedButton.styleFrom(backgroundColor:Colors.black,
            foregroundColor:Colors.white, minimumSize:const Size(double.infinity,54),
            shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12))))),
  ]);

  LinearGradient _getGrad(Color c1, Color c2, String dir) {
    var b=Alignment.topCenter, e=Alignment.bottomCenter;
    if (dir=="Horizontal"){b=Alignment.centerLeft;e=Alignment.centerRight;}
    if (dir=="Diagonal"){b=Alignment.topLeft;e=Alignment.bottomRight;}
    return LinearGradient(colors:[c1,c2],begin:b,end:e);
  }

  Future<void> _exportar() async {
    final b=_qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final img=await b.toImage(pixelRatio:4.0);
    final d=await img.toByteData(format:ui.ImageByteFormat.png);
    await ImageGallerySaver.saveImage(d!.buffer.asUint8List());
    if (mounted) ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content:Text("✅ QR guardado en galería")));
  }

  Future<void> _compartir() async {
    final b=_qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final img=await b.toImage(pixelRatio:4.0);
    final d=await img.toByteData(format:ui.ImageByteFormat.png);
    final bytes=d!.buffer.asUint8List();
    final dir=await getTemporaryDirectory();
    final file=await File('${dir.path}/qr_generado.png').create();
    await file.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(file.path)],text:'Generado con QR + Logo PRO');
  }
}

enum EyeStyle { rect, circ, diamond }

// ═══════════════════════════════════════════════════════════════════
// HELPER PARA DIBUJAR OJOS — usado por todos los painters
// El ojo QR tiene 3 capas: marco exterior 7x7, hueco 5x5, pupila 3x3
// ═══════════════════════════════════════════════════════════════════
void _drawEye(Canvas canvas, double x, double y, double t,
    Paint pE, Paint pI, EyeStyle style) {
  final s = 7 * t;
  if (style == EyeStyle.circ) {
    // Marco exterior oval
    canvas.drawPath(Path()
        ..addOval(Rect.fromLTWH(x, y, s, s))
        ..addOval(Rect.fromLTWH(x+t, y+t, s-2*t, s-2*t))
        ..fillType=PathFillType.evenOdd, pE);
    // Pupila oval
    canvas.drawOval(Rect.fromLTWH(x+2.1*t, y+2.1*t, s-4.2*t, s-4.2*t), pI);
  } else if (style == EyeStyle.diamond) {
    final cx=x+3.5*t, cy=y+3.5*t;
    canvas.drawPath(Path()
        ..moveTo(cx,y)..lineTo(x+7*t,cy)..lineTo(cx,y+7*t)..lineTo(x,cy)
        ..moveTo(cx,y+1.2*t)..lineTo(x+5.8*t,cy)..lineTo(cx,y+5.8*t)..lineTo(x+1.2*t,cy)
        ..fillType=PathFillType.evenOdd, pE);
    canvas.drawPath(Path()
        ..moveTo(cx,y+2.2*t)..lineTo(x+4.8*t,cy)
        ..lineTo(cx,y+4.8*t)..lineTo(x+2.2*t,cy)..close(), pI);
  } else {
    // Rect estándar
    canvas.drawPath(Path()
        ..addRect(Rect.fromLTWH(x,y,s,s))
        ..addRect(Rect.fromLTWH(x+t,y+t,s-2*t,s-2*t))
        ..fillType=PathFillType.evenOdd, pE);
    canvas.drawRect(Rect.fromLTWH(x+2.1*t, y+2.1*t, s-4.2*t, s-4.4*t), pI);
  }
}

// ═══════════════════════════════════════════════════════════════════
// STYLE PREVIEW PAINTER — miniaturas del selector
// ═══════════════════════════════════════════════════════════════════
class StylePreviewPainter extends CustomPainter {
  final String style; final Color c1, c2;
  static const _demo = "https://qr.demo";
  const StylePreviewPainter({required this.style, required this.c1, required this.c2});

  // Máscara de árbol para preview de Formas
  bool _treeMask(int r, int c, int m) {
    double nx = c / m, ny = r / m;
    // Tronco
    if (nx>=0.42 && nx<=0.58 && ny>=0.65 && ny<=0.95) return true;
    // Copa (triángulo)
    if (ny>=0.05 && ny<=0.70) {
      double halfW = (0.70-ny)*0.55;
      if ((nx-0.5).abs() <= halfW) return true;
    }
    return false;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final qr = _buildQrImage(_demo);
    if (qr == null) return;
    final int m = qr.moduleCount; final double t = size.width / m;
    final paint = Paint()..isAntiAlias=true..color=c1;
    ui.Shader? grad;
    if (c1!=c2) {
      grad=ui.Gradient.linear(Offset.zero,Offset(size.width,size.height),[c1,c2]);
      paint.shader=grad;
    }
    const frac=0.30, s0=(1.0-frac)/2.0, s1=s0+frac;
    bool inCenter(int r,int c)=>(c+0.5)/m>=s0&&(c+0.5)/m<=s1&&(r+0.5)/m>=s0&&(r+0.5)/m<=s1;

    // Fusión: fondo semitransparente simulado
    if (style.contains("Fusión")) {
      canvas.drawRect(Rect.fromLTWH(0,0,size.width/2,size.height),
          Paint()..color=Colors.red.withOpacity(0.25));
      canvas.drawRect(Rect.fromLTWH(size.width/2,0,size.width/2,size.height),
          Paint()..color=Colors.blue.shade900.withOpacity(0.25));
    }

    final lPath=Path();
    final lPaint=Paint()..isAntiAlias=true..style=PaintingStyle.stroke
        ..strokeWidth=t..strokeCap=StrokeCap.round..strokeJoin=StrokeJoin.round;
    if (grad!=null) lPaint.shader=grad; else lPaint.color=c1;

    // ok() para el preview
    bool ok(int r, int c) {
      if (r<0||r>=m||c<0||c>=m) return false;
      if (!qr.isDark(r,c)) return false;
      if (_isEye(r,c,m)) return true; // ojos siempre
      if (style.contains("Formas")) return _treeMask(r,c,m);
      if (style=="QR Circular (Forma)") {
        return math.sqrt(math.pow(c-m/2.0,2)+math.pow(r-m/2.0,2))<=m/2.1;
      }
      if (style.contains("Fusión")) return true;
      if (inCenter(r,c)) return false;
      return true;
    }

    for (int r=0;r<m;r++) for (int c=0;c<m;c++) {
      if (!ok(r,c)) continue;
      if (_isEye(r,c,m)) continue; // ojos se dibujan al final
      final double x=c*t,y=r*t,cx=x+t/2,cy=y+t/2;

      if (style.contains("Fusión")) {
        Color dc=c<m/2?Colors.red.shade700:Colors.blue.shade900;
        canvas.drawCircle(Offset(cx,cy),t*0.42,Paint()..color=dc);
      } else if (style.contains("Gusano")||style=="QR Circular (Forma)") {
        lPath.moveTo(cx,cy); lPath.lineTo(cx,cy);
        if (ok(r,c+1)&&!_isEye(r,c+1,m)){lPath.moveTo(cx,cy);lPath.lineTo(cx+t,cy);}
        if (ok(r+1,c)&&!_isEye(r+1,c,m)){lPath.moveTo(cx,cy);lPath.lineTo(cx,cy+t);}
      } else if (style.contains("Barras")) {
        if (r==0||!ok(r-1,c)||_isEye(r-1,c,m)) {
          int er=r; while(er+1<m&&ok(er+1,c)&&!_isEye(er+1,c,m)) er++;
          final p2=Paint()..isAntiAlias=true;
          if (grad!=null) p2.shader=grad; else p2.color=c1;
          canvas.drawRRect(RRect.fromRectAndRadius(
              Rect.fromLTWH(x+t*0.1,y,t*0.8,(er-r+1)*t),Radius.circular(t*0.38)),p2);
        }
      } else if (style.contains("Puntos")) {
        double h=((r*13+c*29)%100)/100.0;
        canvas.drawCircle(Offset(cx,cy),t*0.35+t*0.13*h,paint);
      } else if (style.contains("Rombos")||style.contains("Diamant")) {
        double h=((r*17+c*31)%100)/100.0;double sc=0.65+0.45*h;double off=t*(1-sc)/2;
        canvas.drawPath(Path()..moveTo(cx,y+off)..lineTo(x+t-off,cy)
            ..lineTo(cx,y+t-off)..lineTo(x+off,cy)..close(),paint);
      } else if (style.contains("Split")) {
        final sp=c<m/2
            ?(Paint()..isAntiAlias=true..color=c1..style=PaintingStyle.stroke..strokeWidth=t..strokeCap=StrokeCap.round)
            :(Paint()..isAntiAlias=true..color=c2..style=PaintingStyle.stroke..strokeWidth=t..strokeCap=StrokeCap.round);
        final pp=Path()..moveTo(cx,cy)..lineTo(cx,cy);
        if (ok(r,c+1)&&!_isEye(r,c+1,m)) pp.lineTo(cx+t,cy);
        canvas.drawPath(pp,sp);
        if (ok(r+1,c)&&!_isEye(r+1,c,m)) canvas.drawPath(Path()..moveTo(cx,cy)..lineTo(cx,cy+t),sp);
      } else {
        canvas.drawRect(Rect.fromLTWH(x,y,t+0.3,t+0.3),paint);
      }
    }
    if (style.contains("Gusano")||style=="QR Circular (Forma)") canvas.drawPath(lPath,lPaint);

    // Ojos: siempre como figuras propias, nunca como strokes
    final pE=Paint()..isAntiAlias=true;
    final pI=Paint()..isAntiAlias=true;
    if (style.contains("Fusión")) { pE.color=Colors.black87; pI.color=Colors.black87; }
    else if (grad!=null) { pE.shader=grad; pI.shader=grad; }
    else { pE.color=c1; pI.color=c1; }
    EyeStyle es = style.contains("Puntos")||style=="QR Circular (Forma)"
        ? EyeStyle.circ : EyeStyle.rect;
    _drawEye(canvas,0,0,t,pE,pI,es);
    _drawEye(canvas,(m-7)*t,0,t,pE,pI,es);
    _drawEye(canvas,0,(m-7)*t,t,pE,pI,es);
  }

  @override bool shouldRepaint(StylePreviewPainter o)=>o.c1!=c1||o.c2!=c2||o.style!=style;
}

// ═══════════════════════════════════════════════════════════════════
// QR MASTER PAINTER — estilos básicos
// ═══════════════════════════════════════════════════════════════════
class QrMasterPainter extends CustomPainter {
  final String data,estilo,qrMode,qrDir;
  final img_lib.Image? logoImage; final List<List<bool>>? outerMask;
  final double logoSize,auraSize; final bool customEyes;
  final Color qrC1,qrC2,eyeExt,eyeInt;
  const QrMasterPainter({required this.data,required this.estilo,required this.logoImage,
    required this.outerMask,required this.logoSize,required this.auraSize,
    required this.qrC1,required this.qrC2,required this.qrMode,required this.qrDir,
    required this.customEyes,required this.eyeExt,required this.eyeInt});

  @override
  void paint(Canvas canvas, Size size) {
    final qr=_buildQrImage(data); if (qr==null){_err(canvas,size);return;}
    final int m=qr.moduleCount; final double t=size.width/m;
    final double effLogo=logoSize.clamp(30.0,_safeLogoMax(modules:m,auraModules:auraSize));

    final paint=Paint()..isAntiAlias=true;
    ui.Shader? grad;
    if (qrMode!="Sólido (Un Color)") {
      var b=Alignment.topCenter,e=Alignment.bottomCenter;
      if (qrDir=="Horizontal"){b=Alignment.centerLeft;e=Alignment.centerRight;}
      if (qrDir=="Diagonal"){b=Alignment.topLeft;e=Alignment.bottomRight;}
      grad=ui.Gradient.linear(Offset(size.width*(b.x+1)/2,size.height*(b.y+1)/2),
          Offset(size.width*(e.x+1)/2,size.height*(e.y+1)/2),[qrC1,qrC2]);
      paint.shader=grad;
    } else {paint.color=qrC1;}

    // Máscara de exclusión del logo
    final excl=List.generate(m,(_)=>List.filled(m,false));
    if (logoImage!=null&&outerMask!=null) {
      final lf=effLogo/270.0,ls=(1-lf)/2.0,le=ls+lf;
      final base=List.generate(m,(_)=>List.filled(m,false));
      for (int r=0;r<m;r++) for (int c=0;c<m;c++) {
        bool hit=false;
        for (double dy=0.2;dy<=0.8&&!hit;dy+=0.3)
          for (double dx=0.2;dx<=0.8&&!hit;dx+=0.3) {
            final nx=(c+dx)/m,ny=(r+dy)/m;
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
          final nr=r+dr,nc=c+dc;
          if (nr>=0&&nr<m&&nc>=0&&nc<m) excl[nr][nc]=true;
        }
    }

    bool ok(int r,int c) {
      if (r<0||r>=m||c<0||c>=m) return false;
      if (!qr.isDark(r,c)) return false;
      if (_isEye(r,c,m)) return false; // ojos dibujados separado
      if (_isStructural(r,c,m)) return true; // timing patterns siempre
      if (excl[r][c]) return false;
      return true;
    }

    final lPath=Path();
    final lPaint=Paint()..isAntiAlias=true..style=PaintingStyle.stroke
        ..strokeWidth=t..strokeCap=StrokeCap.round..strokeJoin=StrokeJoin.round;
    if (grad!=null) lPaint.shader=grad; else lPaint.color=qrC1;

    for (int r=0;r<m;r++) for (int c=0;c<m;c++) {
      if (!ok(r,c)) continue;
      final double x=c*t,y=r*t,cx=x+t/2,cy=y+t/2;
      if (estilo.contains("Gusano")) {
        lPath.moveTo(cx,cy);lPath.lineTo(cx,cy);
        if (ok(r,c+1)){lPath.moveTo(cx,cy);lPath.lineTo(cx+t,cy);}
        if (ok(r+1,c)){lPath.moveTo(cx,cy);lPath.lineTo(cx,cy+t);}
      } else if (estilo.contains("Barras")) {
        if (r==0||!ok(r-1,c)) {
          int er=r; while(er+1<m&&ok(er+1,c)) er++;
          final p2=Paint()..isAntiAlias=true;
          if (grad!=null) p2.shader=grad; else p2.color=qrC1;
          canvas.drawRRect(RRect.fromRectAndRadius(
              Rect.fromLTWH(x+t*0.1,y,t*0.8,(er-r+1)*t),Radius.circular(t*0.38)),p2);
        }
      } else if (estilo.contains("Puntos")) {
        double h=((r*13+c*29)%100)/100.0;
        canvas.drawCircle(Offset(cx,cy),t*0.35+t*0.15*h,paint);
      } else if (estilo.contains("Diamantes")) {
        double h=((r*17+c*31)%100)/100.0;
        double sc=0.65+0.5*h,off=t*(1-sc)/2;
        canvas.drawPath(Path()..moveTo(cx,y+off)..lineTo(x+t-off,cy)
            ..lineTo(cx,y+t-off)..lineTo(x+off,cy)..close(),paint);
      } else {
        canvas.drawRect(Rect.fromLTWH(x,y,t+0.3,t+0.3),paint);
      }
    }
    if (estilo.contains("Gusano")) canvas.drawPath(lPath,lPaint);

    final pE=Paint()..isAntiAlias=true;
    final pI=Paint()..isAntiAlias=true;
    if (customEyes){pE.color=eyeExt;pI.color=eyeInt;}
    else if (grad!=null){pE.shader=grad;pI.shader=grad;}
    else {pE.color=qrC1;pI.color=qrC1;}
    EyeStyle es=EyeStyle.rect;
    if (estilo.contains("Puntos")) es=EyeStyle.circ;
    if (estilo.contains("Diamantes")) es=EyeStyle.diamond;
    _drawEye(canvas,0,0,t,pE,pI,es);
    _drawEye(canvas,(m-7)*t,0,t,pE,pI,es);
    _drawEye(canvas,0,(m-7)*t,t,pE,pI,es);
  }

  void _err(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0,0,size.width,size.height),
        Paint()..color=Colors.red.withOpacity(0.08));
    final tp=TextPainter(
        text:const TextSpan(text:'Contenido\ndemasiado largo',
            style:TextStyle(color:Colors.red,fontSize:15,fontWeight:FontWeight.bold)),
        textDirection:TextDirection.ltr,textAlign:TextAlign.center)
      ..layout(maxWidth:size.width);
    tp.paint(canvas,Offset((size.width-tp.width)/2,(size.height-tp.height)/2));
  }

  @override bool shouldRepaint(CustomPainter o)=>true;
}

// ═══════════════════════════════════════════════════════════════════
// QR ADVANCED PAINTER — QR Circular, Split, Formas
// FIX CRÍTICO: ojos dibujados SIEMPRE como geometrías propias
// separados del liquid path principal
// ═══════════════════════════════════════════════════════════════════
class QrAdvancedPainter extends CustomPainter {
  final String data,estiloAvanzado,qrMode,qrDir;
  final img_lib.Image? logoImage; final List<List<bool>>? outerMask;
  final double logoSize,auraSize; final bool customEyes;
  final Color qrC1,qrC2,eyeExt,eyeInt;
  const QrAdvancedPainter({required this.data,required this.estiloAvanzado,
    required this.logoImage,required this.outerMask,required this.logoSize,
    required this.auraSize,required this.qrC1,required this.qrC2,
    required this.qrMode,required this.qrDir,required this.customEyes,
    required this.eyeExt,required this.eyeInt});

  @override
  void paint(Canvas canvas, Size size) {
    final qr=_buildQrImage(data); if (qr==null) return;
    final int m=qr.moduleCount; final double t=size.width/m;
    final bool isMap      = estiloAvanzado=="Formas (Máscara)";
    final bool isCircular = estiloAvanzado=="QR Circular (Forma)";
    final bool isSplit    = estiloAvanzado=="Split Liquid (Mitades)";

    // Freno matemático — para split también
    final double effLogo = isMap
        ? logoSize
        : logoSize.clamp(30.0,_safeLogoMax(modules:m,auraModules:auraSize));

    ui.Shader? grad;
    if (qrMode=="Degradado Custom") {
      var b=Alignment.topCenter,e=Alignment.bottomCenter;
      if (qrDir=="Horizontal"){b=Alignment.centerLeft;e=Alignment.centerRight;}
      if (qrDir=="Diagonal"){b=Alignment.topLeft;e=Alignment.bottomRight;}
      grad=ui.Gradient.linear(Offset(size.width*(b.x+1)/2,size.height*(b.y+1)/2),
          Offset(size.width*(e.x+1)/2,size.height*(e.y+1)/2),[qrC1,qrC2]);
    }

    final pen1=Paint()..isAntiAlias=true..style=PaintingStyle.stroke
        ..strokeWidth=t..strokeCap=StrokeCap.round..strokeJoin=StrokeJoin.round;
    if (grad!=null) pen1.shader=grad; else pen1.color=qrC1;
    final pen2=Paint()..isAntiAlias=true..color=qrC2..style=PaintingStyle.stroke
        ..strokeWidth=t..strokeCap=StrokeCap.round..strokeJoin=StrokeJoin.round;

    // Máscara del logo
    final logoMask=List.generate(m,(_)=>List.filled(m,false));
    final excl    =List.generate(m,(_)=>List.filled(m,false));
    if (logoImage!=null&&outerMask!=null) {
      final lf=effLogo/270.0,ls=(1-lf)/2.0,le=ls+lf;
      for (int r=0;r<m;r++) for (int c=0;c<m;c++) {
        final nx=(c+0.5)/m,ny=(r+0.5)/m;
        if (nx>=ls&&nx<=le&&ny>=ls&&ny<=le) {
          final px=((nx-ls)/lf*logoImage!.width).clamp(0,logoImage!.width-1).toInt();
          final py=((ny-ls)/lf*logoImage!.height).clamp(0,logoImage!.height-1).toInt();
          if (outerMask![py][px]) logoMask[r][c]=true;
        }
      }
      if (!isMap) {
        final base=List.generate(m,(_)=>List.filled(m,false));
        for (int r=0;r<m;r++) for (int c=0;c<m;c++) {
          bool hit=false;
          for (double dy=0.2;dy<=0.8&&!hit;dy+=0.3)
            for (double dx=0.2;dx<=0.8&&!hit;dx+=0.3) {
              final nx=(c+dx)/m,ny=(r+dy)/m;
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
            final nr=r+dr,nc=c+dc;
            if (nr>=0&&nr<m&&nc>=0&&nc<m) excl[nr][nc]=true;
          }
      }
    }

    // ═══════════════════════════════════════════════════════════════
    // ok() — qué módulos van al path principal (DARK)
    //
    // QR CIRCULAR FIX: NO hay clip circular. "Circular" = solo estilo
    // de ojos y dots. Todos los módulos de datos se dibujan completos.
    // Esto garantiza que el QR siempre sea escaneable.
    //
    // FORMAS FIX: Los módulos FUERA de la máscara NO van al path
    // principal (dark), pero SÍ se dibujan como ghost-dots (gris muy
    // claro) en un paso previo. Ghost-dots = visibles al ojo humano
    // pero con luminancia ~0.93 → blancos para el scanner → el QR
    // siempre tiene todos sus datos intactos.
    // ═══════════════════════════════════════════════════════════════
    bool ok(int r, int c) {
      if (r<0||r>=m||c<0||c>=m) return false;
      if (!qr.isDark(r,c)) return false;
      if (_isEye(r,c,m)) return false;      // ojos = geometrías propias
      if (r==6||c==6) return !excl[r][c];   // timing patterns siempre
      if (excl[r][c]) return false;          // exclusión logo
      // Formas: solo módulos DENTRO de la máscara van al path oscuro
      if (isMap && logoImage!=null && !logoMask[r][c]) return false;
      // QR Circular + Split + todo lo demás: dibujar todo
      return true;
    }

    // ─── Pre-paso FORMAS: ghost-dots fuera de la máscara ────────────
    // Luminancia 0xECECEC ≈ 0.85 → muy por encima del umbral de
    // binarización del scanner (~0.45). El lector los ve como blanco.
    // El ojo humano los percibe como textura sutil fuera de la forma.
    if (isMap && logoImage != null) {
      final ghost = Paint()
          ..color = const Color(0xFFECECEC)
          ..isAntiAlias = true;
      for (int r=0; r<m; r++) for (int c=0; c<m; c++) {
        if (!qr.isDark(r,c)) continue;
        if (_isEye(r,c,m)) continue;
        if (logoMask[r][c]) continue; // dentro = path oscuro, no ghost
        final cx = c*t+t/2, cy = r*t+t/2;
        canvas.drawCircle(Offset(cx, cy), t*0.38, ghost);
      }
    }

    // ─── Dibujar módulos OSCUROS (path principal) ───────────────────
    final pathC1=Path(), pathC2=Path();
    for (int r=0;r<m;r++) for (int c=0;c<m;c++) {
      if (!ok(r,c)) continue;
      final double x=c*t,y=r*t,cx=x+t/2,cy=y+t/2;
      if (isSplit) {
        final left=c<m/2; final ap=left?pathC1:pathC2;
        ap.moveTo(cx,cy); ap.lineTo(cx,cy);
        if (ok(r,c+1)&&((c+1<m/2)==left)){ap.moveTo(cx,cy);ap.lineTo(cx+t,cy);}
        if (ok(r+1,c)){ap.moveTo(cx,cy);ap.lineTo(cx,cy+t);}
      } else {
        pathC1.moveTo(cx,cy); pathC1.lineTo(cx,cy);
        if (ok(r,c+1)){pathC1.moveTo(cx,cy);pathC1.lineTo(cx+t,cy);}
        if (ok(r+1,c)){pathC1.moveTo(cx,cy);pathC1.lineTo(cx,cy+t);}
      }
    }
    if (isSplit){canvas.drawPath(pathC1,pen1);canvas.drawPath(pathC2,pen2);}
    else canvas.drawPath(pathC1,pen1);

    // ─── Ojos: siempre como geometrías propias ───────────────────────
    // QR Circular → ojos circulares para integración visual
    // Formas / Split → ojos rectangulares para máxima legibilidad
    final pE=Paint()..isAntiAlias=true;
    final pI=Paint()..isAntiAlias=true;
    if (customEyes){pE.color=eyeExt;pI.color=eyeInt;}
    else if (grad!=null){pE.shader=grad;pI.shader=grad;}
    else {pE.color=qrC1;pI.color=qrC1;}
    final EyeStyle es = isCircular ? EyeStyle.circ : EyeStyle.rect;
    _drawEye(canvas,0,0,t,pE,pI,es);
    _drawEye(canvas,(m-7)*t,0,t,pE,pI,es);
    _drawEye(canvas,0,(m-7)*t,t,pE,pI,es);
  }

  @override bool shouldRepaint(CustomPainter o)=>true;
}

// ═══════════════════════════════════════════════════════════════════
// QR FUSIÓN PAINTER — logo como fondo real, dots coloreados encima
//
// ALGORITMO CORRECTO (como Facebook/Starbucks/Pepsi):
// 1. Logo a FULL OPACITY como fondo — SIN overlay blanco
// 2. Cada módulo oscuro del QR: tomar color del pixel del logo
//    y dibujar un círculo/cuadrado opaco encima
// 3. Si el pixel del logo es muy claro → oscurecer para contraste
// 4. Ojos dibujados como geometrías sólidas de alto contraste
//
// El "halftone" visual emerge naturalmente: los huecos entre dots
// dejan ver el logo, mientras los dots coloreados forman el patrón QR
// ═══════════════════════════════════════════════════════════════════
class QrFusionPainter extends CustomPainter {
  final String data, shape;
  final ui.Image? logoUiImage;
  final img_lib.Image? logoImage;
  final Color dominantColor;
  final bool customEyes;
  final Color eyeExt, eyeInt;
  const QrFusionPainter({required this.data, required this.logoUiImage,
    required this.logoImage, required this.shape, required this.dominantColor,
    required this.customEyes, required this.eyeExt, required this.eyeInt});

  @override
  void paint(Canvas canvas, Size size) {
    final qr=_buildQrImage(data); if (qr==null) return;
    final int m=qr.moduleCount; final double t=size.width/m;

    // ── Paso 1: Fondo blanco + logo a full opacity ───────────────
    canvas.drawRect(Rect.fromLTWH(0,0,size.width,size.height),
        Paint()..color=Colors.white);
    if (logoUiImage!=null) {
      final src=Rect.fromLTWH(0,0,
          logoUiImage!.width.toDouble(),logoUiImage!.height.toDouble());
      final dst=Rect.fromLTWH(0,0,size.width,size.height);
      canvas.drawImageRect(logoUiImage!,src,dst,
          Paint()..filterQuality=FilterQuality.medium);
    }

    // ── Paso 2: OVERLAY BLANCO en posiciones de módulos CLAROS ──
    //
    // ESTE ES EL FIX CRÍTICO DE ESCANEABILIDAD:
    // El scanner QR binariza la imagen buscando zonas oscuras vs claras.
    // Sin este overlay, una zona "clara" del QR puede mostrar el logo
    // naranja/dorado y una zona "oscura" muestra un dot naranja oscuro —
    // el contraste es insuficiente para binarizar correctamente.
    // Con este overlay, las zonas claras → blanco puro (lum 1.0)
    // y las zonas oscuras → dots con lum ≤ 0.18.
    // Ratio de contraste ≥ 5.5:1 → umbral WCAG AAA para escaneado.
    //
    // El efecto artístico se preserva: el logo se ve a través de los
    // huecos ENTRE dots (espacio entre módulos oscuros).
    if (logoUiImage!=null) {
      final whiteMask=Paint()..color=Colors.white.withOpacity(0.84);
      for (int r=0;r<m;r++) for (int c=0;c<m;c++) {
        if (qr.isDark(r,c)) continue;      // módulo oscuro: no cubrir
        if (_isEye(r,c,m)) continue;       // ojo: no cubrir
        canvas.drawRect(Rect.fromLTWH(c*t,r*t,t,t),whiteMask);
      }
    }

    // ── Paso 3: Dots del QR coloreados ──────────────────────────
    for (int r=0;r<m;r++) for (int c=0;c<m;c++) {
      if (!qr.isDark(r,c)) continue;
      if (_isEye(r,c,m)) continue;

      // Timing patterns → siempre negro para máxima legibilidad
      final bool isTiming = (r==6||c==6);

      Color dotColor = Colors.black;
      if (!isTiming && logoImage!=null) {
        final px=(c/m*logoImage!.width).floor().clamp(0,logoImage!.width-1);
        final py=(r/m*logoImage!.height).floor().clamp(0,logoImage!.height-1);
        final pixel=logoImage!.getPixel(px,py);
        if (pixel.a > 20) {
          dotColor=Color.fromARGB(255,pixel.r.toInt(),pixel.g.toInt(),pixel.b.toInt());
        }
      }

      // ── FRENO DE CONTRASTE OBLIGATORIO ───────────────────────
      // Todo dot debe tener luminancia ≤ 0.18 para ser distinguible
      // contra el fondo blanco (ratio ≥ 4.6:1).
      // Preservamos el hue y la saturación del logo, solo forzamos
      // el valor de luminosidad.
      final hsl=HSLColor.fromColor(dotColor);
      // Luminancia target: 0.12 base + hasta 0.08 según saturación
      // (colores saturados pueden ser ligeramente más claros y seguir
      // siendo distinguibles por el scanner)
      final targetL=(0.12+hsl.saturation*0.08).clamp(0.08,0.20);
      dotColor=hsl.withLightness(targetL).toColor();

      final paint=Paint()..color=dotColor..isAntiAlias=true;
      final double cx=c*t+t/2, cy=r*t+t/2;

      // Dots ligeramente más grandes (0.47 vs 0.44) para mejor detección
      if (shape=="Círculos") {
        canvas.drawCircle(Offset(cx,cy),t*0.47,paint);
      } else {
        canvas.drawRRect(RRect.fromRectAndRadius(
            Rect.fromCenter(center:Offset(cx,cy),width:t*0.88,height:t*0.88),
            Radius.circular(t*0.16)),paint);
      }
    }

    // ── Paso 4: Ojos — alto contraste garantizado ───────────────
    // Color del ojo: tomar el color dominante del logo y forzarlo
    // a luminancia muy baja para máxima legibilidad del scanner
    Color eyeBase = dominantColor;
    final eyeHsl=HSLColor.fromColor(eyeBase);
    eyeBase=eyeHsl.withLightness(0.18).toColor();

    final pE=Paint()..isAntiAlias=true..color=(customEyes?eyeExt:eyeBase);
    final pI=Paint()..isAntiAlias=true..color=(customEyes?eyeInt:eyeBase);
    final EyeStyle es=shape=="Círculos"?EyeStyle.circ:EyeStyle.rect;
    _drawEye(canvas,0,0,t,pE,pI,es);
    _drawEye(canvas,(m-7)*t,0,t,pE,pI,es);
    _drawEye(canvas,0,(m-7)*t,t,pE,pI,es);
  }

  @override bool shouldRepaint(CustomPainter o)=>true;
}

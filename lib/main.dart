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

void main() => runApp(MaterialApp(home: const SplashScreen(), debugShowCheckedModeBanner: false));

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MainScreen())));
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(child: Image.asset('assets/app_icon.png', width: 180, errorBuilder: (c,e,s) => const Icon(Icons.qr_code_scanner, size: 100))),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // CONTROLADORES TOTALMENTE VACÍOS
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
  Color _bgC1 = Colors.white;
  Color _bgC2 = const Color(0xFFF5F5F5);

  File? _logo;
  double _auraSize = 3.0; 
  List<List<bool>> _logoAuraMap = []; 
  final GlobalKey _qrKey = GlobalKey();

  Future<void> _processLogo(File file) async {
    final bytes = await file.readAsBytes();
    final image = img_lib.decodeImage(bytes);
    if (image == null) return;

    final palette = await PaletteGenerator.fromImageProvider(FileImage(file));
    setState(() {
      _logo = file;
      if (_qrColorMode == "Automático (Logo)") {
        _qrC1 = palette.darkMutedColor?.color ?? palette.dominantColor?.color ?? Colors.black;
        _qrC2 = palette.vibrantColor?.color ?? palette.lightVibrantColor?.color ?? _qrC1;
      }
      
      int res = 50; 
      _logoAuraMap = List.generate(res, (y) => List.generate(res, (x) {
        int px = (x * image.width ~/ res);
        int py = (y * image.height ~/ res);
        var pixel = image.getPixel(px, py);
        return pixel.luminance < 0.90 && pixel.a > 0.1;
      }));
    });
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
    String finalData = _getFinalData();
    bool isEmpty = finalData.isEmpty;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(title: const Text("QR + Logo", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)), backgroundColor: Colors.white, elevation: 0, centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(15),
        child: Column(
          children: [
            _buildCard("1. Contenido", Column(children: [
              DropdownButtonFormField<String>(
                value: _qrType,
                items: ["Sitio Web (URL)", "WhatsApp", "Red WiFi", "VCard (Contacto)", "Teléfono", "E-mail", "SMS (Mensaje)", "Texto Libre"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() { _qrType = v!; }),
              ),
              const SizedBox(height: 10),
              _buildInputs(),
            ])),

            _buildCard("2. Estilo y Color QR", Column(children: [
              DropdownButtonFormField<String>(
                value: _estilo,
                items: ["Liquid Pro (Gusano)", "Normal (Cuadrado)", "Barras (Vertical)", "Circular (Puntos)"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() => _estilo = v!),
              ),
              DropdownButtonFormField<String>(
                value: _qrColorMode,
                items: ["Automático (Logo)", "Sólido (Un Color)", "Degradado Custom"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() => _qrColorMode = v!),
              ),
              if (_qrColorMode != "Automático (Logo)") 
                _buildColorPicker("Colores QR", _qrC1, _qrC2, (c) => setState(() => _qrC1 = c), (c) => setState(() => _qrC2 = c), isGrad: _qrColorMode.contains("Degradado")),
            ])),

            _buildCard("3. Posicionamiento (Ojos) y Fondo", Column(children: [
              SwitchListTile(title: const Text("Personalizar Ojos"), value: _customEyes, onChanged: (v) => setState(() => _customEyes = v), contentPadding: EdgeInsets.zero),
              if (_customEyes) _buildColorPicker("Colores Ojos", _eyeExt, _eyeInt, (c) => setState(() => _eyeExt = c), (c) => setState(() => _eyeInt = c), isGrad: true),
              DropdownButtonFormField<String>(
                value: _bgMode,
                items: ["Blanco (Default)", "Transparente", "Sólido (Color)", "Degradado"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() => _bgMode = v!),
              ),
              if (_bgMode.contains("Sólido") || _bgMode.contains("Degradado"))
                _buildColorPicker("Colores Fondo", _bgC1, _bgC2, (c) => setState(() => _bgC1 = c), (c) => setState(() => _bgC2 = c), isGrad: _bgMode == "Degradado"),
            ])),

            if (_logo != null) _buildCard("4. Ajuste de Aura (Contorno)", Column(children: [
               Text("Margen: ${_auraSize.toInt()}"),
               Slider(value: _auraSize, min: 1, max: 6, divisions: 5, activeColor: Colors.black, onChanged: (v) => setState(() => _auraSize = v)),
            ])),

            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: () async {
                final img = await ImagePicker().pickImage(source: ImageSource.gallery);
                if (img != null) _processLogo(File(img.path));
              },
              icon: const Icon(Icons.image), label: Text(_logo == null ? "SUBIR LOGO" : "CAMBIAR LOGO ✅"),
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: Colors.black, foregroundColor: Colors.white),
            ),

            const SizedBox(height: 30),

            RepaintBoundary(
              key: _qrKey,
              child: Container(
                width: 320, height: 320,
                decoration: BoxDecoration(
                  color: _bgMode == "Transparente" ? Colors.transparent : (_bgMode == "Sólido (Color)" ? _bgC1 : Colors.white),
                  gradient: _bgMode == "Degradado" ? LinearGradient(colors: [_bgC1, _bgC2], begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
                ),
                child: Center(
                  child: isEmpty ? const Text("Esperando contenido...", style: TextStyle(color: Colors.grey)) : Stack(alignment: Alignment.center, children: [
                    CustomPaint(
                      size: const Size(270, 270),
                      painter: QrMasterPainter(
                        data: finalData, estilo: _estilo, auraMap: _logoAuraMap, auraSize: _auraSize,
                        qrC1: _qrC1, qrC2: _qrC2, qrMode: _qrColorMode,
                        customEyes: _customEyes, eyeExt: _eyeExt, eyeInt: _eyeInt,
                      ),
                    ),
                    if (_logo != null) Container(width: 65, height: 65, child: Image.file(_logo!, fit: BoxFit.contain)),
                  ]),
                ),
              ),
            ),
            
            const SizedBox(height: 25),
            ElevatedButton(onPressed: isEmpty ? null : () => _exportar(), child: const Text("GUARDAR EN GALERÍA"), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 60))),
          ],
        ),
      ),
    );
  }

  Widget _buildInputs() {
    switch (_qrType) {
      case "VCard (Contacto)":
        return Column(children: [
          Row(children: [Expanded(child: TextField(controller: _c1, decoration: const InputDecoration(hintText: "Nombre"), onChanged: (v)=>setState((){}))), const SizedBox(width: 5), Expanded(child: TextField(controller: _c2, decoration: const InputDecoration(hintText: "Apellido"), onChanged: (v)=>setState((){})))]),
          TextField(controller: _c3, decoration: const InputDecoration(hintText: "Empresa"), onChanged: (v)=>setState((){})),
          TextField(controller: _c4, decoration: const InputDecoration(hintText: "Teléfono (+595...)"), keyboardType: TextInputType.phone, onChanged: (v)=>setState((){})),
          TextField(controller: _c5, decoration: const InputDecoration(hintText: "Email (ejemplo@mail.com)"), keyboardType: TextInputType.emailAddress, onChanged: (v)=>setState((){})),
        ]);
      case "WhatsApp":
      case "SMS (Mensaje)":
        return Column(children: [
          TextField(controller: _c1, decoration: const InputDecoration(hintText: "Número con código (ej: +595981...)"), keyboardType: TextInputType.phone, onChanged: (v)=>setState((){})),
          TextField(controller: _c2, decoration: const InputDecoration(hintText: "Mensaje opcional"), onChanged: (v)=>setState((){})),
        ]);
      case "Red WiFi":
        return Column(children: [
          TextField(controller: _c1, decoration: const InputDecoration(hintText: "Nombre de la Red (SSID)"), onChanged: (v)=>setState((){})),
          TextField(controller: _c2, decoration: const InputDecoration(hintText: "Contraseña"), onChanged: (v)=>setState((){})),
        ]);
      case "E-mail":
        return Column(children: [
          TextField(controller: _c1, decoration: const InputDecoration(hintText: "Destinatario"), keyboardType: TextInputType.emailAddress, onChanged: (v)=>setState((){})),
          TextField(controller: _c2, decoration: const InputDecoration(hintText: "Asunto"), onChanged: (v)=>setState((){})),
          TextField(controller: _c3, decoration: const InputDecoration(hintText: "Cuerpo del mensaje"), onChanged: (v)=>setState((){})),
        ]);
      default:
        return TextField(controller: _c1, decoration: InputDecoration(hintText: _qrType == "Sitio Web (URL)" ? "https://www.ejemplo.com" : "Escribe aquí..."), onChanged: (v)=>setState((){}));
    }
  }

  Widget _buildCard(String title, Widget child) {
    return Card(margin: const EdgeInsets.only(bottom: 15), child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), child])));
  }

  Widget _buildColorPicker(String label, Color c1, Color c2, Function(Color) onC1, Function(Color) onC2, {bool isGrad = false}) {
    return Row(children: [
      Text(label), const Spacer(),
      _colorCircle(c1, onC1),
      if (isGrad) ...[const SizedBox(width: 10), _colorCircle(c2, onC2)],
    ]);
  }

  Widget _colorCircle(Color current, Function(Color) onTap) {
    return GestureDetector(
      onTap: () => _showPalette(onTap),
      child: CircleAvatar(backgroundColor: current, radius: 18, child: Icon(Icons.colorize, size: 14, color: current == Colors.white ? Colors.black : Colors.white)),
    );
  }

  void _showPalette(Function(Color) onSelect) {
    showDialog(context: context, builder: (ctx) => AlertDialog(content: Wrap(spacing: 10, runSpacing: 10, children: [Colors.black, Colors.white, Colors.red, Colors.blue, Colors.green, Colors.orange, Colors.purple, const Color(0xFF1565C0)].map((c) => GestureDetector(onTap: () { onSelect(c); Navigator.pop(ctx); }, child: CircleAvatar(backgroundColor: c, radius: 22))).toList())));
  }

  Future<void> _exportar() async {
    RenderRepaintBoundary boundary = _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    ui.Image image = await boundary.toImage(pixelRatio: 4.0);
    ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    await ImageGallerySaver.saveImage(byteData!.buffer.asUint8List());
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Guardado")));
  }
}

class QrMasterPainter extends CustomPainter {
  final String data, estilo, qrMode;
  final List<List<bool>> auraMap;
  final double auraSize;
  final bool customEyes;
  final Color qrC1, qrC2, eyeExt, eyeInt;

  QrMasterPainter({required this.data, required this.estilo, required this.auraMap, required this.auraSize, required this.qrC1, required this.qrC2, required this.qrMode, required this.customEyes, required this.eyeExt, required this.eyeInt});

  @override
  void paint(Canvas canvas, Size size) {
    final qrCode = QrCode(4, QrErrorCorrectLevel.H)..addData(data);
    final qrImage = QrImage(qrCode);
    final int modules = qrImage.moduleCount;
    final double tileSize = size.width / modules;
    
    final paint = Paint()..isAntiAlias = true;
    if (qrMode != "Sólido (Un Color)") {
      paint.shader = ui.Gradient.linear(Offset.zero, Offset(size.width, size.height), [qrC1, qrC2]);
    } else { paint.color = qrC1; }

    for (int r = 0; r < modules; r++) {
      for (int c = 0; c < modules; c++) {
        if (qrImage.isDark(r, c)) {
          if (auraMap.isNotEmpty) {
            int auraX = (c * auraMap.length ~/ modules);
            int auraY = (r * auraMap.length ~/ modules);
            bool skip = false; int m = auraSize.toInt();
            for (int dy = -m; dy <= m; dy++) {
              for (int dx = -m; dx <= m; dx++) {
                int ny = auraY + dy; int nx = auraX + dx;
                if (ny >= 0 && ny < auraMap.length && nx >= 0 && nx < auraMap.length && auraMap[ny][nx]) skip = true;
              }
            }
            if (skip) continue;
          }

          if (((r < 7 && c < 7) || (r < 7 && c >= modules - 7) || (r >= modules - 7 && c < 7)) && estilo != "Normal (Cuadrado)") continue;
          
          double x = c * tileSize; double y = r * tileSize;
          if (estilo.contains("Gusano")) {
            canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x+0.6, y+0.6, tileSize-0.6, tileSize-0.6), Radius.circular(tileSize * 0.35)), paint);
            if (c+1 < modules && qrImage.isDark(r, c+1)) canvas.drawRect(Rect.fromLTWH(x+tileSize/2, y+0.6, tileSize, tileSize-0.6), paint);
            if (r+1 < modules && qrImage.isDark(r+1, c)) canvas.drawRect(Rect.fromLTWH(x+0.6, y+tileSize/2, tileSize-0.6, tileSize), paint);
          } else if (estilo.contains("Barras")) {
            canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x + tileSize*0.1, y, tileSize*0.8, tileSize+0.5), Radius.circular(tileSize*0.3)), paint);
            if (r+1 < modules && qrImage.isDark(r+1, c)) canvas.drawRect(Rect.fromLTWH(x + tileSize*0.1, y + tileSize/2, tileSize*0.8, tileSize), paint);
          } else if (estilo.contains("Puntos")) {
            canvas.drawCircle(Offset(x + tileSize/2, y + tileSize/2), tileSize * 0.45, paint);
          } else { canvas.drawRect(Rect.fromLTWH(x, y, tileSize + 0.3, tileSize + 0.3), paint); }
        }
      }
    }
    final pE = Paint()..color = customEyes ? eyeExt : qrC1; if (!customEyes && qrMode != "Sólido (Un Color)") pE.shader = paint.shader;
    final pI = Paint()..color = customEyes ? eyeInt : qrC1; if (!customEyes && qrMode != "Sólido (Un Color)") pI.shader = paint.shader;
    _drawEye(canvas, 0, 0, tileSize, pE, pI);
    _drawEye(canvas, (modules-7)*tileSize, 0, tileSize, pE, pI);
    _drawEye(canvas, 0, (modules-7)*tileSize, tileSize, pE, pI);
  }

  void _drawEye(Canvas canvas, double x, double y, double t, Paint pE, Paint pI) {
    double s = 7 * t;
    canvas.drawPath(Path()..addRect(Rect.fromLTWH(x, y, s, s))..addRect(Rect.fromLTWH(x+t, y+t, s-2*t, s-2*t))..fillType = PathFillType.evenOdd, pE);
    canvas.drawRect(Rect.fromLTWH(x+2.1*t, y+2.1*t, s-4.2*t, s-4.4*t), pI);
  }
  @override bool shouldRepaint(CustomPainter old) => true;
}
import 'package:flutter/material.dart';
import 'package:qr/qr.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:typed_data';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';

void main() => runApp(MaterialApp(home: SplashScreen(), debugShowCheckedModeBanner: false));

// --- 1. SPLASH SCREEN PROFESIONAL ---
class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(seconds: 2), () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => MainScreen())));
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(child: Image.asset('assets/app_icon.png', width: 180, errorBuilder: (c,e,s) => Icon(Icons.qr_code_scanner, size: 100))),
    );
  }
}

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // Controladores de Contenido
  final TextEditingController _c1 = TextEditingController();
  final TextEditingController _c2 = TextEditingController();
  final TextEditingController _c3 = TextEditingController();
  final TextEditingController _c4 = TextEditingController();
  final TextEditingController _c5 = TextEditingController();

  // Variables de Estado (CÓDIGO PADRE)
  String _qrType = "Sitio Web (URL)";
  String _estilo = "Liquid Pro (Gusano)";
  
  // Colores Cuerpo
  String _qrColorMode = "Sólido (Un Color)";
  String _qrGradDir = "Vertical";
  Color _qrC1 = Colors.black;
  Color _qrC2 = Color(0xFF1565C0);
  
  // Ojos
  bool _customEyes = false;
  Color _eyeExt = Colors.black;
  Color _eyeInt = Colors.black;

  // Fondo
  String _bgMode = "Blanco (Default)";
  String _bgGradDir = "Diagonal";
  Color _bgC1 = Colors.white;
  Color _bgC2 = Color(0xFFF5F5F5);

  File? _logo;
  GlobalKey _qrKey = GlobalKey();

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

  void _pickColor(Color current, Function(Color) onColorSelected) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Color"),
        content: Wrap(
          spacing: 10, runSpacing: 10,
          children: [Colors.black, Colors.white, Colors.red, Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.teal, Color(0xFF1565C0), Colors.grey]
              .map((c) => GestureDetector(
                onTap: () { onColorSelected(c); Navigator.pop(context); },
                child: CircleAvatar(backgroundColor: c, radius: 20, child: current == c ? Icon(Icons.check, color: c == Colors.white ? Colors.black : Colors.white) : null),
              )).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String finalData = _getFinalData();
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(title: Text("QR + Logo", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)), backgroundColor: Colors.white, elevation: 0, centerTitle: true),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(15),
        child: Column(
          children: [
            // SECCIÓN 1: CONTENIDO
            _buildCard("1. Contenido", Column(children: [
              DropdownButtonFormField<String>(
                value: _qrType,
                items: ["Sitio Web (URL)", "WhatsApp", "Red WiFi", "VCard (Contacto)", "Teléfono", "E-mail", "SMS (Mensaje)", "Texto Libre"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() { _qrType = v!; _c1.clear(); }),
                decoration: InputDecoration(labelText: "Tipo"),
              ),
              TextField(controller: _c1, onChanged: (v)=>setState((){}), decoration: InputDecoration(labelText: "Dato principal")),
              if (_qrType == "WhatsApp" || _qrType == "Red WiFi" || _qrType == "SMS (Mensaje)")
                TextField(controller: _c2, onChanged: (v)=>setState((){}), decoration: InputDecoration(labelText: "Mensaje / Contraseña")),
            ])),

            // SECCIÓN 2: ESTILO DE CUERPO
            _buildCard("2. Estilo y Color QR", Column(children: [
              DropdownButtonFormField<String>(
                value: _estilo,
                items: ["Liquid Pro (Gusano)", "Normal (Cuadrado)", "Barras (Vertical)", "Circular (Puntos)"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() => _estilo = v!),
              ),
              Row(children: [
                Expanded(child: DropdownButtonFormField<String>(
                  value: _qrColorMode,
                  items: ["Sólido (Un Color)", "Degradado Custom"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (v) => setState(() => _qrColorMode = v!),
                )),
                IconButton(icon: Icon(Icons.circle, color: _qrC1), onPressed: () => _pickColor(_qrC1, (c) => setState(() => _qrC1 = c))),
                if (_qrColorMode == "Degradado Custom") ...[
                  IconButton(icon: Icon(Icons.circle, color: _qrC2), onPressed: () => _pickColor(_qrC2, (c) => setState(() => _qrC2 = c))),
                  DropdownButton<String>(value: _qrGradDir, items: ["Vertical", "Horizontal", "Diagonal"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => _qrGradDir = v!))
                ]
              ]),
            ])),

            // SECCIÓN 3: OJOS Y FONDO
            _buildCard("3. Ojos y Fondo", Column(children: [
              SwitchListTile(title: Text("Ojos Custom"), value: _customEyes, onChanged: (v) => setState(() => _customEyes = v)),
              if (_customEyes) Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                Text("Ext:"), IconButton(icon: Icon(Icons.circle, color: _eyeExt), onPressed: () => _pickColor(_eyeExt, (c) => setState(() => _eyeExt = c))),
                Text("Int:"), IconButton(icon: Icon(Icons.circle, color: _eyeInt), onPressed: () => _pickColor(_eyeInt, (c) => setState(() => _eyeInt = c))),
              ]),
              DropdownButtonFormField<String>(
                value: _bgMode,
                items: ["Blanco (Default)", "Sólido (Color)", "Degradado"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() => _bgMode = v!),
              ),
              if (_bgMode != "Blanco (Default)") Row(children: [
                IconButton(icon: Icon(Icons.palette, color: _bgC1), onPressed: () => _pickColor(_bgC1, (c) => setState(() => _bgC1 = c))),
                if (_bgMode == "Degradado") ...[
                  IconButton(icon: Icon(Icons.palette_outlined, color: _bgC2), onPressed: () => _pickColor(_bgC2, (c) => setState(() => _bgC2 = c))),
                  DropdownButton<String>(value: _bgGradDir, items: ["Vertical", "Horizontal", "Diagonal"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => _bgGradDir = v!))
                ]
              ]),
            ])),

            ElevatedButton.icon(
              onPressed: () async {
                final img = await ImagePicker().pickImage(source: ImageSource.gallery);
                if (img != null) setState(() => _logo = File(img.path));
              },
              icon: Icon(Icons.upload), label: Text(_logo == null ? "SUBIR LOGO" : "LOGO LISTO ✅"),
              style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 50), backgroundColor: Colors.black, foregroundColor: Colors.white),
            ),

            SizedBox(height: 30),

            // RENDERIZADO FINAL
            RepaintBoundary(
              key: _qrKey,
              child: Container(
                width: 320, height: 320,
                decoration: BoxDecoration(
                  color: _bgMode == "Sólido (Color)" ? _bgC1 : Colors.white,
                  gradient: _bgMode == "Degradado" ? _getGradient(_bgC1, _bgC2, _bgGradDir) : null,
                ),
                child: Center(
                  child: finalData.isEmpty ? Text("Esperando contenido...") : Stack(alignment: Alignment.center, children: [
                    CustomPaint(
                      size: Size(270, 270),
                      painter: QrMasterPainter(
                        data: finalData, estilo: _estilo, hasLogo: _logo != null,
                        qrC1: _qrC1, qrC2: _qrC2, qrMode: _qrColorMode, qrDir: _qrGradDir,
                        customEyes: _customEyes, eyeExt: _eyeExt, eyeInt: _eyeInt,
                      ),
                    ),
                    if (_logo != null) Container(width: 65, height: 65, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), image: DecorationImage(image: FileImage(_logo!), fit: BoxFit.contain))),
                  ]),
                ),
              ),
            ),
            
            SizedBox(height: 25),
            ElevatedButton(onPressed: finalData.isEmpty ? null : () => _exportar(), child: Text("GUARDAR QR"), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, minimumSize: Size(double.infinity, 60))),
          ],
        ),
      ),
    );
  }

  LinearGradient _getGradient(Color c1, Color c2, String dir) {
    if (dir == "Horizontal") return LinearGradient(colors: [c1, c2], begin: Alignment.centerLeft, end: Alignment.centerRight);
    if (dir == "Diagonal") return LinearGradient(colors: [c1, c2], begin: Alignment.topLeft, end: Alignment.bottomRight);
    return LinearGradient(colors: [c1, c2], begin: Alignment.topCenter, end: Alignment.bottomCenter);
  }

  Widget _buildCard(String title, Widget child) {
    return Card(margin: EdgeInsets.only(bottom: 15), child: Padding(padding: EdgeInsets.all(15), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontWeight: FontWeight.bold)), SizedBox(height: 10), child])));
  }

  Future<void> _exportar() async {
    RenderRepaintBoundary boundary = _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    ui.Image image = await boundary.toImage(pixelRatio: 4.0);
    ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    await ImageGallerySaver.saveImage(byteData!.buffer.asUint8List());
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("✅ Guardado en Galería")));
  }
}

// --- MOTOR GRÁFICO CÓDIGO PADRE ---
class QrMasterPainter extends CustomPainter {
  final String data, estilo, qrMode, qrDir;
  final bool hasLogo, customEyes;
  final Color qrC1, qrC2, eyeExt, eyeInt;

  QrMasterPainter({required this.data, required this.estilo, required this.hasLogo, required this.qrC1, required this.qrC2, required this.qrMode, required this.qrDir, required this.customEyes, required this.eyeExt, required this.eyeInt});

  @override
  void paint(Canvas canvas, Size size) {
    final qrCode = QrCode(4, QrErrorCorrectLevel.H)..addData(data);
    final qrImage = QrImage(qrCode);
    final int modules = qrImage.moduleCount;
    final double tileSize = size.width / modules;
    
    final paint = Paint()..isAntiAlias = true;
    if (qrMode == "Degradado Custom") {
      Offset start = Offset.zero; Offset end = Offset(0, size.height);
      if (qrDir == "Horizontal") end = Offset(size.width, 0);
      if (qrDir == "Diagonal") end = Offset(size.width, size.height);
      paint.shader = ui.Gradient.linear(start, end, [qrC1, qrC2]);
    } else { paint.color = qrC1; }

    int skipS = (modules ~/ 2) - 4; int skipE = (modules ~/ 2) + 4;
    bool isE(int r, int c) => (r < 7 && c < 7) || (r < 7 && c >= modules - 7) || (r >= modules - 7 && c < 7);

    for (int r = 0; r < modules; r++) {
      for (int c = 0; c < modules; c++) {
        if (qrImage.isDark(r, c)) {
          if (hasLogo && r >= skipS && r <= skipE && c >= skipS && c <= skipE) continue;
          if (isE(r, c) && estilo != "Normal (Cuadrado)") continue;

          double x = c * tileSize; double y = r * tileSize;

          if (estilo == "Liquid Pro (Gusano)") {
            canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x+0.5, y+0.5, tileSize-0.5, tileSize-0.5), Radius.circular(tileSize * 0.35)), paint);
            if (c+1 < modules && qrImage.isDark(r, c+1)) canvas.drawRect(Rect.fromLTWH(x+tileSize/2, y+0.5, tileSize, tileSize-0.5), paint);
            if (r+1 < modules && qrImage.isDark(r+1, c)) canvas.drawRect(Rect.fromLTWH(x+0.5, y+tileSize/2, tileSize-0.5, tileSize), paint);
          } else if (estilo == "Barras (Vertical)") {
            canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x + tileSize*0.1, y, tileSize*0.8, tileSize+0.5), Radius.circular(tileSize*0.3)), paint);
            if (r+1 < modules && qrImage.isDark(r+1, c) && !isE(r+1, c)) canvas.drawRect(Rect.fromLTWH(x + tileSize*0.1, y + tileSize/2, tileSize*0.8, tileSize), paint);
          } else if (estilo == "Circular (Puntos)") {
            canvas.drawCircle(Offset(x + tileSize/2, y + tileSize/2), tileSize * 0.45, paint);
          } else { canvas.drawRect(Rect.fromLTWH(x, y, tileSize + 0.3, tileSize + 0.3), paint); }
        }
      }
    }
    if (estilo != "Normal (Cuadrado)") {
      final pExt = Paint()..color = customEyes ? eyeExt : qrC1; if (!customEyes && qrMode == "Degradado Custom") pExt.shader = paint.shader;
      final pInt = Paint()..color = customEyes ? eyeInt : qrC1; if (!customEyes && qrMode == "Degradado Custom") pInt.shader = paint.shader;
      _drawEye(canvas, 0, 0, tileSize, pExt, pInt);
      _drawEye(canvas, (modules-7)*tileSize, 0, tileSize, pExt, pInt);
      _drawEye(canvas, 0, (modules-7)*tileSize, tileSize, pExt, pInt);
    }
  }

  void _drawEye(Canvas canvas, double x, double y, double t, Paint pE, Paint pI) {
    double s = 7 * t;
    canvas.drawPath(Path()..addRect(Rect.fromLTWH(x, y, s, s))..addRect(Rect.fromLTWH(x+t, y+t, s-2*t, s-2*t))..fillType = PathFillType.evenOdd, pE);
    canvas.drawRect(Rect.fromLTWH(x+2.2*t, y+2.2*t, s-4.4*t, s-4.4*t), pI);
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
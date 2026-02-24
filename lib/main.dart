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

// --- 1. SPLASH SCREEN (LOGO AL INICIAR) ---
class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(seconds: 2), () {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => MainScreen()));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainValue.center,
          children: [
            // Aquí busca el logo en assets que configuramos en el pubspec
            Image.asset('assets/app_icon.png', width: 150, errorBuilder: (c, e, s) => Icon(Icons.qr_code_2, size: 100)),
            SizedBox(height: 20),
            CircularProgressIndicator(color: Colors.black),
          ],
        ),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final TextEditingController _c1 = TextEditingController();
  final TextEditingController _c2 = TextEditingController();
  final TextEditingController _c3 = TextEditingController();
  final TextEditingController _c4 = TextEditingController();
  final TextEditingController _c5 = TextEditingController();

  String _qrType = "Sitio Web (URL)";
  String _estilo = "Liquid Pro (Gusano)";
  String _qrColorMode = "Degradado Custom";
  Color _qrC1 = Colors.black;
  Color _qrC2 = Color(0xFF1565C0);
  
  bool _customEyes = false;
  Color _eyeExt = Colors.black;
  Color _eyeInt = Colors.black;

  String _bgMode = "Blanco (Default)";
  Color _bgC1 = Colors.white;
  Color _bgC2 = Color(0xFFF0F0F0);

  File? _logo;
  GlobalKey _qrKey = GlobalKey();

  String _getFinalData() {
    if (_c1.text.trim().isEmpty) return "";
    switch (_qrType) {
      case "Sitio Web (URL)": return _c1.text;
      case "Red WiFi": return "WIFI:T:WPA;S:${_c1.text};P:${_c2.text};;";
      case "VCard (Contacto)": return "BEGIN:VCARD\nVERSION:3.0\nFN:${_c1.text} ${_c2.text}\nORG:${_c3.text}\nTEL:${_c4.text}\nEMAIL:${_c5.text}\nEND:VCARD";
      case "Teléfono": return "tel:${_c1.text}";
      case "E-mail": return "mailto:${_c1.text}?subject=${_c2.text}&body=${_c3.text}";
      case "WhatsApp": return "https://wa.me/${_c1.text.replaceAll('+', '')}?text=${Uri.encodeComponent(_c2.text)}";
      default: return _c1.text;
    }
  }

  void _pickColor(Color current, Function(Color) onColorSelected) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Seleccionar Color"),
        content: Wrap(
          spacing: 10, runSpacing: 10,
          children: [Colors.black, Colors.white, Colors.red, Colors.green, Colors.blue, Colors.orange, Colors.purple, Colors.teal, Color(0xFF1565C0), Colors.grey]
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
      backgroundColor: Colors.white,
      appBar: AppBar(title: Text("CÓDIGO PADRE MASTER", style: TextStyle(color: Colors.black)), backgroundColor: Colors.white, elevation: 0),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(15),
        child: Column(
          children: [
            // INTERFAZ DE ENTRADA (Mantenemos tu lógica de PC)
            Card(
              child: Padding(
                padding: EdgeInsets.all(15),
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      value: _qrType,
                      items: ["Sitio Web (URL)", "Red WiFi", "VCard (Contacto)", "Teléfono", "E-mail", "WhatsApp", "Texto Libre"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (v) => setState(() { _qrType = v!; }),
                      decoration: InputDecoration(labelText: "Tipo de Contenido"),
                    ),
                    TextField(controller: _c1, onChanged: (v)=>setState((){}), decoration: InputDecoration(labelText: "Dato principal")),
                    if (_qrType == "WhatsApp" || _qrType == "Red WiFi")
                      TextField(controller: _c2, onChanged: (v)=>setState((){}), decoration: InputDecoration(labelText: "Mensaje / Contraseña")),
                  ],
                ),
              ),
            ),
            
            // CONFIGURACIÓN VISUAL
            Card(
              child: Padding(
                padding: EdgeInsets.all(15),
                child: Column(
                  children: [
                    DropdownButton<String>(
                      value: _estilo,
                      isExpanded: true,
                      items: ["Liquid Pro (Gusano)", "Normal (Cuadrado)", "Circular (Puntos)"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (v) => setState(() => _estilo = v!),
                    ),
                    // Selector de Colores de Fondo
                    ListTile(
                      title: Text("Fondo: $_bgMode"),
                      trailing: Wrap(
                        children: [
                          IconButton(icon: Icon(Icons.palette), onPressed: () => _pickColor(_bgC1, (c) => setState(() => _bgC1 = c))),
                          if (_bgMode == "Degradado")
                            IconButton(icon: Icon(Icons.palette_outlined), onPressed: () => _pickColor(_bgC2, (c) => setState(() => _bgC2 = c))),
                        ],
                      ),
                    ),
                    DropdownButton<String>(
                      value: _bgMode,
                      isExpanded: true,
                      items: ["Blanco (Default)", "Sólido (Color)", "Degradado"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (v) => setState(() => _bgMode = v!),
                    ),
                  ],
                ),
              ),
            ),

            ElevatedButton(onPressed: () async {
              final img = await ImagePicker().pickImage(source: ImageSource.gallery);
              if (img != null) setState(() => _logo = File(img.path));
            }, child: Text("SUBIR LOGO")),

            SizedBox(height: 20),

            // VISUALIZACIÓN
            RepaintBoundary(
              key: _qrKey,
              child: Container(
                width: 320, height: 320,
                decoration: BoxDecoration(
                  color: _bgMode == "Sólido (Color)" ? _bgC1 : Colors.white,
                  gradient: _bgMode == "Degradado" ? LinearGradient(colors: [_bgC1, _bgC2]) : null,
                ),
                child: Center(
                  child: finalData.isEmpty 
                  ? Text("Esperando...") 
                  : Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          size: Size(270, 270),
                          painter: QrMasterPainter(
                            data: finalData,
                            estilo: _estilo,
                            hasLogo: _logo != null,
                            qrC1: _qrC1, qrC2: _qrC2,
                          ),
                        ),
                        if (_logo != null)
                          Image.file(_logo!, width: 60, height: 60, fit: BoxFit.contain),
                      ],
                    ),
                ),
              ),
            ),
            
            SizedBox(height: 20),
            ElevatedButton(onPressed: () => _exportar(false), child: Text("GUARDAR QR"), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: Size(double.infinity, 50))),
          ],
        ),
      ),
    );
  }

  Future<void> _exportar(bool compartir) async {
    RenderRepaintBoundary boundary = _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    ui.Image image = await boundary.toImage(pixelRatio: 4.0);
    ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    await ImageGallerySaver.saveImage(byteData!.buffer.asUint8List());
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("QR Guardado")));
  }
}

// --- EL PINTOR QUE RESPETA EL CÓDIGO PADRE (LEGIBILIDAD 100%) ---
class QrMasterPainter extends CustomPainter {
  final String data;
  final String estilo;
  final bool hasLogo;
  final Color qrC1, qrC2;

  QrMasterPainter({required this.data, required this.estilo, required this.hasLogo, required this.qrC1, required this.qrC2});

  @override
  void paint(Canvas canvas, Size size) {
    // Usamos version 4 o auto para asegurar legibilidad
    final qrCode = QrCode(4, QrErrorCorrectLevel.H)..addData(data);
    final qrImage = QrImage(qrCode);
    final int modules = qrImage.moduleCount;
    final double tileSize = size.width / modules;
    
    final paint = Paint()..isAntiAlias = true;
    paint.shader = ui.Gradient.linear(Offset(0,0), Offset(size.width, size.height), [qrC1, qrC2]);

    // Lógica de "Aura" (Corte inteligente del logo)
    int skipStart = (modules ~/ 2) - 3;
    int skipEnd = (modules ~/ 2) + 3;

    for (int r = 0; r < modules; r++) {
      for (int c = 0; c < modules; c++) {
        if (qrImage.isDark(r, c)) {
          // El corte ahora es inteligente: no dibuja si está en la zona del logo
          if (hasLogo && r >= skipStart && r <= skipEnd && c >= skipStart && c <= skipEnd) continue;

          double x = c * tileSize;
          double y = r * tileSize;

          if (estilo == "Liquid Pro (Gusano)") {
            // Ajustamos el radio para que sea legible por scanners
            canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x+0.5, y+0.5, tileSize-0.5, tileSize-0.5), Radius.circular(tileSize * 0.3)), paint);
            // Uniones (evitan las micro-divisiones)
            if (c+1 < modules && qrImage.isDark(r, c+1)) canvas.drawRect(Rect.fromLTWH(x+tileSize/2, y+0.5, tileSize, tileSize-0.5), paint);
            if (r+1 < modules && qrImage.isDark(r+1, c)) canvas.drawRect(Rect.fromLTWH(x+0.5, y+tileSize/2, tileSize-0.5, tileSize), paint);
          } else if (estilo == "Circular (Puntos)") {
            canvas.drawCircle(Offset(x + tileSize / 2, y + tileSize / 2), tileSize * 0.45, paint);
          } else {
            canvas.drawRect(Rect.fromLTWH(x, y, tileSize + 0.2, tileSize + 0.2), paint);
          }
        }
      }
    }
    // Ojos sólidos para máxima legibilidad
    _drawEye(canvas, 0, 0, tileSize, paint);
    _drawEye(canvas, (modules - 7) * tileSize, 0, tileSize, paint);
    _drawEye(canvas, 0, (modules - 7) * tileSize, tileSize, paint);
  }

  void _drawEye(Canvas canvas, double x, double y, double tileSize, Paint paint) {
    double s = 7 * tileSize;
    canvas.drawPath(Path()
      ..addRect(Rect.fromLTWH(x, y, s, s))
      ..addRect(Rect.fromLTWH(x+tileSize, y+tileSize, s-2*tileSize, s-2*tileSize))
      ..fillType = PathFillType.evenOdd, paint);
    canvas.drawRect(Rect.fromLTWH(x+2*tileSize, y+2*tileSize, s-4*tileSize, s-4*tileSize), paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
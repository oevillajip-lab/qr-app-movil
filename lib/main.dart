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

void main() => runApp(MaterialApp(home: MainScreen(), debugShowCheckedModeBanner: false));

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final TextEditingController _c1 = TextEditingController(text: "COMAGRO S.A.");
  final TextEditingController _c2 = TextEditingController();
  final TextEditingController _c3 = TextEditingController();

  String _qrType = "Sitio Web (URL)";
  String _estilo = "Liquid Pro (Gusano)";
  File? _logo;
  GlobalKey _qrKey = GlobalKey();

  String _getFinalData() {
    if (_qrType == "Sitio Web (URL)") return _c1.text;
    if (_qrType == "WhatsApp") return "https://wa.me/${_c1.text.replaceAll('+', '')}?text=${Uri.encodeComponent(_c2.text)}";
    if (_qrType == "Red WiFi") return "WIFI:T:WPA;S:${_c1.text};P:${_c2.text};;";
    if (_qrType == "VCard (Contacto)") return "BEGIN:VCARD\nVERSION:3.0\nFN:${_c1.text}\nTEL:${_c2.text}\nEMAIL:${_c3.text}\nEND:VCARD";
    return _c1.text;
  }

  Future<void> _pickLogo() async {
    final img = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (img != null) setState(() => _logo = File(img.path));
  }

  Future<void> _exportar(bool compartir) async {
    try {
      RenderRepaintBoundary boundary = _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 4.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      if (compartir) {
        final dir = await getTemporaryDirectory();
        final file = await File('${dir.path}/qr_master.png').create();
        await file.writeAsBytes(pngBytes);
        await Share.shareXFiles([XFile(file.path)]);
      } else {
        await ImageGallerySaver.saveImage(pngBytes);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("✅ QR MASTER GUARDADO EN GALERÍA")));
      }
    } catch (e) { print(e); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(title: Text("QR MASTER NATIVO"), backgroundColor: Colors.black, centerTitle: true),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(15),
        child: Column(
          children: [
            // ERROR 1 SOLUCIONADO: Padding dentro de Card
            Card(
              child: Padding(
                padding: EdgeInsets.all(15),
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      value: _qrType,
                      items: ["Sitio Web (URL)", "WhatsApp", "Red WiFi", "VCard (Contacto)", "Texto Libre"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (v) => setState(() => _qrType = v!),
                      decoration: InputDecoration(labelText: "Tipo de Contenido"),
                    ),
                    TextField(controller: _c1, decoration: InputDecoration(labelText: _qrType == "Red WiFi" ? "SSID (Nombre)" : "Dato principal")),
                    if (_qrType == "WhatsApp" || _qrType == "Red WiFi" || _qrType == "VCard (Contacto)")
                      TextField(controller: _c2, decoration: InputDecoration(labelText: _qrType == "Red WiFi" ? "Contraseña" : "Dato secundario")),
                    SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: _estilo,
                      items: ["Normal", "Liquid Pro (Gusano)", "Circular (Puntos)"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (v) => setState(() => _estilo = v!),
                      decoration: InputDecoration(labelText: "Estilo"),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 10),
            ElevatedButton.icon(onPressed: _pickLogo, icon: Icon(Icons.image), label: Text("CARGAR LOGO"), style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 50))),
            SizedBox(height: 20),
            
            RepaintBoundary(
              key: _qrKey,
              child: Container(
                width: 320, height: 320,
                color: Colors.white,
                child: Center(
                  child: CustomPaint(
                    size: Size(280, 280),
                    painter: QrMasterPainter(
                      data: _getFinalData(),
                      estilo: _estilo,
                      logo: _logo,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: ElevatedButton(onPressed: () => _exportar(false), child: Text("DESCARGAR"), style: ElevatedButton.styleFrom(backgroundColor: Colors.green))),
                SizedBox(width: 10),
                Expanded(child: OutlinedButton(onPressed: () => _exportar(true), child: Text("COMPARTIR"))),
              ],
            )
          ],
        ),
      ),
    );
  }
}

class QrMasterPainter extends CustomPainter {
  final String data;
  final String estilo;
  final File? logo;

  QrMasterPainter({required this.data, required this.estilo, this.logo});

  @override
  void paint(Canvas canvas, Size size) {
    // ERROR 2 SOLUCIONADO: Uso correcto de QrImage
    final qrCode = QrCode(4, QrErrorCorrectLevel.H)..addData(data);
    final qrImage = QrImage(qrCode);
    
    final int modules = qrImage.moduleCount;
    final double tileSize = size.width / modules;
    final paint = Paint()..isAntiAlias = true;

    paint.shader = ui.Gradient.linear(Offset(0,0), Offset(size.width, size.height), [Colors.black, Color(0xFF1565C0)]);

    // ERROR 3 SOLUCIONADO: Variables seguras para el corte del logo
    int skipStart = (modules ~/ 2) - 3;
    int skipEnd = (modules ~/ 2) + 3;
    bool hasLogo = logo != null;

    bool isEye(int r, int c) => (r < 7 && c < 7) || (r < 7 && c >= modules - 7) || (r >= modules - 7 && c < 7);

    for (int r = 0; r < modules; r++) {
      for (int c = 0; c < modules; c++) {
        if (qrImage.isDark(r, c)) { // Ahora usamos qrImage.isDark
          if (hasLogo && r >= skipStart && r <= skipEnd && c >= skipStart && c <= skipEnd) continue;
          if (isEye(r, c) && estilo != "Normal") continue;

          double x = c * tileSize;
          double y = r * tileSize;

          if (estilo == "Liquid Pro (Gusano)") {
            RRect rrect = RRect.fromRectAndRadius(Rect.fromLTWH(x+1, y+1, tileSize-2, tileSize-2), Radius.circular(tileSize * 0.4));
            canvas.drawRRect(rrect, paint);
            if (c + 1 < modules && qrImage.isDark(r, c + 1)) canvas.drawRect(Rect.fromLTWH(x + tileSize / 2, y + 1, tileSize, tileSize - 2), paint);
            if (r + 1 < modules && qrImage.isDark(r + 1, c)) canvas.drawRect(Rect.fromLTWH(x + 1, y + tileSize / 2, tileSize - 2, tileSize), paint);
          } else if (estilo == "Circular (Puntos)") {
            canvas.drawCircle(Offset(x + tileSize / 2, y + tileSize / 2), tileSize * 0.42, paint);
          } else {
            canvas.drawRect(Rect.fromLTWH(x, y, tileSize, tileSize), paint);
          }
        }
      }
    }

    if (estilo != "Normal") {
      _drawEye(canvas, 0, 0, tileSize, paint);
      _drawEye(canvas, (modules - 7) * tileSize, 0, tileSize, paint);
      _drawEye(canvas, 0, (modules - 7) * tileSize, tileSize, paint);
    }
  }

  void _drawEye(Canvas canvas, double x, double y, double tileSize, Paint paint) {
    double eyeSize = 7 * tileSize;
    Path path = Path()
      ..addOval(Rect.fromLTWH(x, y, eyeSize, eyeSize))
      ..addOval(Rect.fromLTWH(x + tileSize, y + tileSize, eyeSize - 2 * tileSize, eyeSize - 2 * tileSize))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, paint);
    canvas.drawOval(Rect.fromLTWH(x + 2 * tileSize, y + 2 * tileSize, eyeSize - 4 * tileSize, eyeSize - 4 * tileSize), paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

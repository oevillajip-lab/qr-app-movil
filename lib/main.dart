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
  // --- ARRANCA TOTALMENTE VACÍO ---
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
    if (_c1.text.trim().isEmpty) return ""; // Retorna vacío si no hay texto
    
    switch (_qrType) {
      case "Sitio Web (URL)": return _c1.text;
      case "Red WiFi": return "WIFI:T:WPA;S:${_c1.text};P:${_c2.text};;";
      case "VCard (Contacto)": return "BEGIN:VCARD\nVERSION:3.0\nFN:${_c1.text} ${_c2.text}\nORG:${_c3.text}\nTEL:${_c4.text}\nEMAIL:${_c5.text}\nEND:VCARD";
      case "Teléfono": return "tel:${_c1.text}";
      case "E-mail": return "mailto:${_c1.text}?subject=${_c2.text}&body=${_c3.text}";
      case "SMS (Mensaje)": return "SMSTO:${_c1.text}:${_c2.text}";
      case "WhatsApp": return "https://wa.me/${_c1.text.replaceAll('+', '')}?text=${Uri.encodeComponent(_c2.text)}";
      case "Texto Libre": return _c1.text;
      default: return _c1.text;
    }
  }

  Future<void> _pickLogo() async {
    final img = await ImagePicker().pickImage(source: ImageSource.gallery);
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
        final file = await File('${dir.path}/qr_comagro.png').create();
        await file.writeAsBytes(pngBytes);
        await Share.shareXFiles([XFile(file.path)]);
      } else {
        await ImageGallerySaver.saveImage(pngBytes);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("✅ QR MASTER GUARDADO", style: TextStyle(color: Colors.white)), backgroundColor: Colors.green));
      }
    } catch (e) { print(e); }
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

  Widget _buildDynamicInputs() {
    List<Widget> fields = [];
    if (_qrType == "Sitio Web (URL)" || _qrType == "Texto Libre") {
      fields.add(TextField(controller: _c1, onChanged: (v)=>setState((){}), decoration: InputDecoration(labelText: "Contenido", filled: true, fillColor: Colors.white)));
    } else if (_qrType == "Red WiFi") {
      fields.add(TextField(controller: _c1, onChanged: (v)=>setState((){}), decoration: InputDecoration(labelText: "Nombre de la Red (SSID)")));
      fields.add(TextField(controller: _c2, onChanged: (v)=>setState((){}), decoration: InputDecoration(labelText: "Contraseña")));
    } else if (_qrType == "VCard (Contacto)") {
      fields.add(Row(children: [Expanded(child: TextField(controller: _c1, onChanged: (v)=>setState((){}), decoration: InputDecoration(labelText: "Nombre"))), SizedBox(width: 10), Expanded(child: TextField(controller: _c2, onChanged: (v)=>setState((){}), decoration: InputDecoration(labelText: "Apellido")))]));
      fields.add(TextField(controller: _c3, onChanged: (v)=>setState((){}), decoration: InputDecoration(labelText: "Empresa")));
      fields.add(TextField(controller: _c4, onChanged: (v)=>setState((){}), keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: "Teléfono")));
      fields.add(TextField(controller: _c5, onChanged: (v)=>setState((){}), keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: "E-mail")));
    } else if (_qrType == "Teléfono") {
      fields.add(TextField(controller: _c1, onChanged: (v)=>setState((){}), keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: "Número (Ej: +595...)")));
    } else if (_qrType == "E-mail") {
      fields.add(TextField(controller: _c1, onChanged: (v)=>setState((){}), keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: "Email Destino")));
      fields.add(TextField(controller: _c2, onChanged: (v)=>setState((){}), decoration: InputDecoration(labelText: "Asunto")));
      fields.add(TextField(controller: _c3, onChanged: (v)=>setState((){}), decoration: InputDecoration(labelText: "Mensaje")));
    } else if (_qrType == "SMS (Mensaje)" || _qrType == "WhatsApp") {
      fields.add(TextField(controller: _c1, onChanged: (v)=>setState((){}), keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: "Número (Ej: +595...)")));
      fields.add(TextField(controller: _c2, onChanged: (v)=>setState((){}), decoration: InputDecoration(labelText: "Mensaje")));
    }
    return Column(children: fields.map((f) => Padding(padding: EdgeInsets.only(bottom: 10), child: f)).toList());
  }

  @override
  Widget build(BuildContext context) {
    String finalData = _getFinalData();
    bool isDataEmpty = finalData.isEmpty;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(title: Text("CÓDIGO PADRE", style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.black, centerTitle: true),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 2,
              child: Padding(
                padding: EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("1. Define el Contenido", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: _qrType,
                      items: ["Sitio Web (URL)", "Red WiFi", "VCard (Contacto)", "Teléfono", "E-mail", "SMS (Mensaje)", "WhatsApp", "Texto Libre"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (v) { setState(() { _qrType = v!; _c1.clear(); _c2.clear(); _c3.clear(); _c4.clear(); _c5.clear(); }); },
                      decoration: InputDecoration(border: OutlineInputBorder()),
                    ),
                    SizedBox(height: 10),
                    _buildDynamicInputs(),
                  ],
                ),
              ),
            ),
            SizedBox(height: 10),

            Card(
              elevation: 2,
              child: Padding(
                padding: EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("2. Personalización Visual", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: _estilo,
                      items: ["Liquid Pro (Gusano)", "Normal (Cuadrado)", "Barras (Vertical)", "Circular (Puntos)"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (v) => setState(() => _estilo = v!),
                      decoration: InputDecoration(labelText: "Estilo de Cuerpo"),
                    ),
                    SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _qrColorMode,
                            items: ["Sólido (Un Color)", "Degradado Custom"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                            onChanged: (v) => setState(() => _qrColorMode = v!),
                            decoration: InputDecoration(labelText: "Color del QR"),
                          ),
                        ),
                        SizedBox(width: 10),
                        InkWell(onTap: () => _pickColor(_qrC1, (c) => setState(() => _qrC1 = c)), child: CircleAvatar(backgroundColor: _qrC1, radius: 15)),
                        if (_qrColorMode == "Degradado Custom") ...[
                          SizedBox(width: 5),
                          InkWell(onTap: () => _pickColor(_qrC2, (c) => setState(() => _qrC2 = c)), child: CircleAvatar(backgroundColor: _qrC2, radius: 15)),
                        ]
                      ],
                    ),
                    SizedBox(height: 10),
                    SwitchListTile(
                      title: Text("Personalizar Ojos", style: TextStyle(fontSize: 14)),
                      value: _customEyes,
                      onChanged: (v) => setState(() => _customEyes = v),
                      contentPadding: EdgeInsets.zero,
                    ),
                    if (_customEyes)
                      Row(
                        children: [
                          Text("Borde: "), InkWell(onTap: () => _pickColor(_eyeExt, (c) => setState(() => _eyeExt = c)), child: CircleAvatar(backgroundColor: _eyeExt, radius: 15)),
                          SizedBox(width: 20),
                          Text("Centro: "), InkWell(onTap: () => _pickColor(_eyeInt, (c) => setState(() => _eyeInt = c)), child: CircleAvatar(backgroundColor: _eyeInt, radius: 15)),
                        ],
                      ),
                    SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _bgMode,
                            items: ["Blanco (Default)", "Transparente", "Sólido (Color)", "Degradado"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                            onChanged: (v) => setState(() => _bgMode = v!),
                            decoration: InputDecoration(labelText: "Fondo del QR"),
                          ),
                        ),
                        if (_bgMode != "Blanco (Default)" && _bgMode != "Transparente") ...[
                          SizedBox(width: 10),
                          InkWell(onTap: () => _pickColor(_bgC1, (c) => setState(() => _bgC1 = c)), child: CircleAvatar(backgroundColor: _bgC1, radius: 15)),
                        ],
                        if (_bgMode == "Degradado") ...[
                          SizedBox(width: 5),
                          InkWell(onTap: () => _pickColor(_bgC2, (c) => setState(() => _bgC2 = c)), child: CircleAvatar(backgroundColor: _bgC2, radius: 15)),
                        ]
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 10),

            ElevatedButton.icon(
              onPressed: _pickLogo, icon: Icon(Icons.image), label: Text(_logo == null ? "CARGAR LOGO (Opcional)" : "CAMBIAR LOGO"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white, padding: EdgeInsets.all(15))
            ),
            if (_logo != null) TextButton(onPressed: () => setState(() => _logo = null), child: Text("Quitar Logo", style: TextStyle(color: Colors.red))),
            
            SizedBox(height: 25),
            
            Center(
              child: RepaintBoundary(
                key: _qrKey,
                child: Container(
                  width: 320, height: 320,
                  decoration: BoxDecoration(
                    color: _bgMode == "Blanco (Default)" ? Colors.white : (_bgMode == "Transparente" ? Colors.transparent : (_bgMode == "Sólido (Color)" ? _bgC1 : null)),
                    gradient: _bgMode == "Degradado" ? LinearGradient(colors: [_bgC1, _bgC2], begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
                  ),
                  child: Center(
                    child: isDataEmpty 
                    // MENSAJE DE ESPERA ELEGANTE
                    ? Text("Esperando contenido...", style: TextStyle(color: Colors.grey, fontSize: 16))
                    : Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          size: Size(260, 260),
                          painter: QrMasterPainter(
                            data: finalData,
                            estilo: _estilo,
                            hasLogo: _logo != null,
                            colorMode: _qrColorMode,
                            qrC1: _qrC1, qrC2: _qrC2,
                            customEyes: _customEyes,
                            eyeExt: _eyeExt, eyeInt: _eyeInt,
                          ),
                        ),
                        if (_logo != null)
                          Container(
                            width: 60, height: 60,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              image: DecorationImage(image: FileImage(_logo!), fit: BoxFit.contain),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            
            SizedBox(height: 25),
            Row(
              children: [
                Expanded(child: ElevatedButton(onPressed: isDataEmpty ? null : () => _exportar(false), child: Text("DESCARGAR", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: EdgeInsets.symmetric(vertical: 15)))),
                SizedBox(width: 10),
                Expanded(child: OutlinedButton(onPressed: isDataEmpty ? null : () => _exportar(true), child: Text("COMPARTIR", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), style: OutlinedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 15)))),
              ],
            ),
            SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

class QrMasterPainter extends CustomPainter {
  final String data;
  final String estilo;
  final bool hasLogo;
  final String colorMode;
  final Color qrC1, qrC2, eyeExt, eyeInt;
  final bool customEyes;

  QrMasterPainter({
    required this.data, required this.estilo, required this.hasLogo,
    required this.colorMode, required this.qrC1, required this.qrC2,
    required this.customEyes, required this.eyeExt, required this.eyeInt,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final qrCode = QrCode(4, QrErrorCorrectLevel.H)..addData(data);
    final qrImage = QrImage(qrCode);
    final int modules = qrImage.moduleCount;
    final double tileSize = size.width / modules;
    
    final paintBody = Paint()..isAntiAlias = true;
    if (colorMode == "Degradado Custom") {
      paintBody.shader = ui.Gradient.linear(Offset(0,0), Offset(size.width, size.height), [qrC1, qrC2]);
    } else {
      paintBody.color = qrC1;
    }

    final paintEyeExt = Paint()..isAntiAlias = true..color = customEyes ? eyeExt : qrC1;
    if (!customEyes && colorMode == "Degradado Custom") paintEyeExt.shader = paintBody.shader;
    
    final paintEyeInt = Paint()..isAntiAlias = true..color = customEyes ? eyeInt : qrC1;
    if (!customEyes && colorMode == "Degradado Custom") paintEyeInt.shader = paintBody.shader;

    int skipStart = (modules ~/ 2) - 4; 
    int skipEnd = (modules ~/ 2) + 4;
    bool isEye(int r, int c) => (r < 7 && c < 7) || (r < 7 && c >= modules - 7) || (r >= modules - 7 && c < 7);

    // FIX MICRO-DIVISIONES: Añadimos 0.5 px de overlap (solapamiento) matemático
    double overlap = 0.5;

    for (int r = 0; r < modules; r++) {
      for (int c = 0; c < modules; c++) {
        if (qrImage.isDark(r, c)) {
          if (hasLogo && r >= skipStart && r <= skipEnd && c >= skipStart && c <= skipEnd) continue;
          if (isEye(r, c) && estilo != "Normal") continue;

          double x = c * tileSize;
          double y = r * tileSize;

          if (estilo == "Liquid Pro (Gusano)") {
            RRect rrect = RRect.fromRectAndRadius(Rect.fromLTWH(x+0.5, y+0.5, tileSize-1, tileSize-1), Radius.circular(tileSize * 0.4));
            canvas.drawRRect(rrect, paintBody);
            if (c + 1 < modules && qrImage.isDark(r, c + 1) && (!hasLogo || !(r >= skipStart && r <= skipEnd && c+1 >= skipStart && c+1 <= skipEnd))) {
              canvas.drawRect(Rect.fromLTWH(x + tileSize / 2, y + 0.5, tileSize + overlap, tileSize - 1), paintBody);
            }
            if (r + 1 < modules && qrImage.isDark(r + 1, c) && (!hasLogo || !(r+1 >= skipStart && r+1 <= skipEnd && c >= skipStart && c <= skipEnd))) {
              canvas.drawRect(Rect.fromLTWH(x + 0.5, y + tileSize / 2, tileSize - 1, tileSize + overlap), paintBody);
            }
          } else if (estilo == "Circular (Puntos)") {
            canvas.drawCircle(Offset(x + tileSize / 2, y + tileSize / 2), tileSize * 0.42, paintBody);
          } else if (estilo == "Barras (Vertical)") {
            RRect rrect = RRect.fromRectAndRadius(Rect.fromLTWH(x + tileSize * 0.1, y - 0.1, tileSize * 0.8, tileSize + overlap), Radius.circular(tileSize * 0.25));
            canvas.drawRRect(rrect, paintBody);
            if (r + 1 < modules && qrImage.isDark(r + 1, c) && !isEye(r + 1, c) && (!hasLogo || !(r+1 >= skipStart && r+1 <= skipEnd && c >= skipStart && c <= skipEnd))) {
              canvas.drawRect(Rect.fromLTWH(x + tileSize * 0.1, y + tileSize / 2, tileSize * 0.8, tileSize + overlap), paintBody);
            }
          } else {
            // FIX MICRO-DIVISION NORMAL: Expansión microscópica
            canvas.drawRect(Rect.fromLTWH(x - 0.1, y - 0.1, tileSize + overlap, tileSize + overlap), paintBody);
          }
        }
      }
    }

    if (estilo != "Normal") {
      _drawEye(canvas, 0, 0, tileSize, paintEyeExt, paintEyeInt);
      _drawEye(canvas, (modules - 7) * tileSize, 0, tileSize, paintEyeExt, paintEyeInt);
      _drawEye(canvas, 0, (modules - 7) * tileSize, tileSize, paintEyeExt, paintEyeInt);
    }
  }

  void _drawEye(Canvas canvas, double x, double y, double tileSize, Paint paintExt, Paint paintInt) {
    double eyeSize = 7 * tileSize;
    Path path = Path()
      ..addOval(Rect.fromLTWH(x, y, eyeSize, eyeSize))
      ..addOval(Rect.fromLTWH(x + tileSize, y + tileSize, eyeSize - 2 * tileSize, eyeSize - 2 * tileSize))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, paintExt);
    canvas.drawOval(Rect.fromLTWH(x + 2.5 * tileSize, y + 2.5 * tileSize, eyeSize - 5 * tileSize, eyeSize - 5 * tileSize), paintInt);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

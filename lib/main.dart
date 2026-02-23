import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:typed_data';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';

void main() => runApp(MaterialApp(
  home: MainScreen(),
  debugShowCheckedModeBanner: false,
  theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: Color(0xFF0F0F0F)),
));

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final TextEditingController _controller = TextEditingController(text: "https://google.com");
  String _estilo = "Gusano"; 
  String _colorTipo = "Degradado";
  File? _logo;
  GlobalKey _qrKey = GlobalKey();

  // Función de guardado de alta resolución
  Future<void> _exportar() async {
    try {
      RenderRepaintBoundary boundary = _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 4.0); // Calidad Ultra HD
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();
      await ImageGallerySaver.saveImage(pngBytes);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("✅ QR MASTER GUARDADO EN GALERÍA")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("❌ Error al guardar")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("QR MASTER ENGINE V1"), backgroundColor: Colors.black),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(labelText: "Contenido", labelStyle: TextStyle(color: Colors.white70)),
              onChanged: (v) => setState(() {}),
            ),
            SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _estilo,
                    items: ["Normal", "Gusano", "Puntos"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (v) => setState(() => _estilo = v!),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _colorTipo,
                    items: ["Sólido", "Degradado"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (v) => setState(() => _colorTipo = v!),
                  ),
                ),
              ],
            ),
            SizedBox(height: 15),
            ElevatedButton.icon(
              onPressed: () async {
                final img = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
                if (img != null) setState(() => _logo = File(img.path));
              },
              icon: Icon(Icons.image),
              label: Text("CARGAR LOGO"),
            ),
            SizedBox(height: 30),
            
            // EL MOTOR DE DIBUJO CUSTOM (AQUÍ ESTÁ EL CÓDIGO PADRE)
            RepaintBoundary(
              key: _qrKey,
              child: Container(
                padding: EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Capa 1: El QR renderizado con tu lógica Master
                    ShaderMask(
                      shaderCallback: (Rect bounds) {
                        if (_colorTipo == "Degradado") {
                          return LinearGradient(
                            colors: [Colors.blue.shade900, Colors.purple.shade700],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ).createShader(bounds);
                        } else {
                          return LinearGradient(colors: [Colors.black, Colors.black]).createShader(bounds);
                        }
                      },
                      blendMode: BlendMode.srcIn,
                      child: QrImageView(
                        data: _controller.text,
                        version: QrVersions.auto,
                        size: 300,
                        gapless: false,
                        eyeStyle: QrEyeStyle(
                          eyeShape: _estilo == "Normal" ? QrEyeShape.square : QrEyeShape.circle,
                        ),
                        dataModuleStyle: QrDataModuleStyle(
                          dataModuleShape: _estilo == "Normal" ? QrDataModuleShape.square : QrDataModuleShape.circle,
                        ),
                        // Máscara de recorte: Esto hace que el QR NO se dibuje debajo del logo
                        embeddedImage: _logo != null ? FileImage(_logo!) : null,
                        embeddedImageStyle: QrEmbeddedImageStyle(
                          size: Size(65, 65), 
                        ),
                      ),
                    ),
                    // Capa 2: El Logo (Se posiciona exactamente en el hueco creado)
                    if (_logo != null)
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          image: DecorationImage(image: FileImage(_logo!), fit: BoxFit.contain),
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 30),
            ElevatedButton(
              onPressed: _exportar,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: Size(double.infinity, 50)),
              child: Text("GENERAR Y GUARDAR MASTER APK", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

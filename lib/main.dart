import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:typed_data';
import 'dart:io';
import 'dart:async';

void main() {
  runApp(MaterialApp(
    title: 'QR + Logo',
    theme: ThemeData(
      scaffoldBackgroundColor: Colors.white,
      primaryColor: Colors.black,
      appBarTheme: AppBarTheme(backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0, iconTheme: IconThemeData(color: Colors.black)),
      elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white)),
      outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(foregroundColor: Colors.black, side: BorderSide(color: Colors.black))),
      inputDecorationTheme: InputDecorationTheme(
        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.black, width: 2)),
        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
        labelStyle: TextStyle(color: Colors.black),
      )
    ),
    home: SplashScreen(),
    debugShowCheckedModeBanner: false,
  ));
}

// ==========================================
// PANTALLA DE PRESENTACIÓN (SPLASH SCREEN)
// ==========================================
class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(seconds: 3), () {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => MainScreen()));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: Colors.white, body: Center(child: Image.asset('assets/app_icon.png', width: 200)));
  }
}

// ==========================================
// PANTALLA PRINCIPAL
// ==========================================
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
  File? _logoFile;
  Uint8List? _resultImage;
  
  bool _loading = false;
  double _progressValue = 0.0;
  Timer? _simulatedTimer;

  Future<void> _pickLogo() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _logoFile = File(picked.path));
  }

  String _getFinalString() {
    String t = _qrType;
    if (t == "Sitio Web (URL)") return _c1.text;
    if (t == "Red WiFi") return "WIFI:T:WPA;S:${_c1.text};P:${_c2.text};;";
    if (t == "Texto Libre") return _c1.text;
    if (t == "VCard (Contacto)") {
      String n = _c1.text; String s = _c2.text; String o = _c3.text; String tel = _c4.text; String em = _c5.text;
      return "BEGIN:VCARD\nVERSION:3.0\nN:$s;$n\nFN:$n $s\nORG:$o\nTEL:$tel\nEMAIL:$em\nEND:VCARD";
    }
    if (t == "Teléfono") return "tel:${_c1.text}";
    if (t == "E-mail") return "mailto:${_c1.text}?subject=${_c2.text}&body=${_c3.text}";
    if (t == "SMS (Mensaje)") return "SMSTO:${_c1.text}:${_c2.text}";
    if (t == "WhatsApp") {
      String numWA = _c1.text.replaceAll("+", "");
      return "https://wa.me/$numWA?text=${_c2.text}";
    }
    return "";
  }

  void _startFakeProgress() {
    _progressValue = 0.05;
    _simulatedTimer = Timer.periodic(Duration(milliseconds: 800), (timer) {
      setState(() {
        if (_progressValue < 0.85) _progressValue += 0.05;
      });
    });
  }

  Future<void> _generate() async {
    String dataStr = _getFinalString();
    if (dataStr.isEmpty) {
      _showMessage("Por favor, completa los campos requeridos.");
      return;
    }
    
    setState(() { _loading = true; _resultImage = null; });
    _startFakeProgress();
    
    try {
      var request = http.MultipartRequest('POST', Uri.parse('https://qr-motor-v53.onrender.com/generate'));
      request.fields['texto'] = dataStr;
      request.fields['estilo'] = _estilo;
      
      if (_logoFile != null) {
        request.files.add(await http.MultipartFile.fromPath('logo', _logoFile!.path));
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      
      _simulatedTimer?.cancel();

      if (response.statusCode == 200) {
        // Carga completada - Se vuelve 100% y Verde
        setState(() { _progressValue = 1.0; });
        
        // Esperamos medio segundo para que el usuario vea el verde de éxito
        await Future.delayed(Duration(milliseconds: 600));
        
        setState(() {
          _resultImage = response.bodyBytes;
          _loading = false;
        });
      } else {
        setState(() { _loading = false; });
        _showMessage("Error del servidor: ${response.statusCode}");
      }
    } catch (e) {
      _simulatedTimer?.cancel();
      setState(() { _loading = false; });
      _showMessage("Error de conexión. El servidor puede estar apagado.");
    }
  }

  // FUNCIÓN GUARDAR EN GALERÍA
  Future<void> _saveToGallery() async {
    if (_resultImage == null) return;
    var status = await Permission.storage.request();
    var statusPhotos = await Permission.photos.request();

    if (status.isGranted || statusPhotos.isGranted) {
      final result = await ImageGallerySaver.saveImage(_resultImage!, quality: 100, name: "QR_Logo_${DateTime.now().millisecondsSinceEpoch}");
      if (result['isSuccess']) {
        _showMessage("¡QR guardado en la galería con éxito!");
      } else {
        _showMessage("Error al guardar la imagen.");
      }
    } else {
      _showMessage("Necesitas dar permisos de almacenamiento para guardar.");
    }
  }

  // FUNCIÓN COMPARTIR NATIVO
  Future<void> _shareImage() async {
    if (_resultImage == null) return;
    try {
      final directory = await getTemporaryDirectory();
      final imagePath = await File('${directory.path}/QR_Compartir.png').create();
      await imagePath.writeAsBytes(_resultImage!);
      await Share.shareXFiles([XFile(imagePath.path)], text: '¡Mira mi nuevo código QR!');
    } catch (e) {
      _showMessage("Error al intentar compartir.");
    }
  }

  void _showMessage(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m, style: TextStyle(color: Colors.white)), backgroundColor: Colors.black, duration: Duration(seconds: 3)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("QR + Logo", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)), centerTitle: true),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("1. Define el Contenido", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _qrType,
              items: ["Sitio Web (URL)", "Red WiFi", "VCard (Contacto)", "Teléfono", "E-mail", "SMS (Mensaje)", "WhatsApp", "Texto Libre"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() { _qrType = v!; _c1.clear(); _c2.clear(); _c3.clear(); _c4.clear(); _c5.clear(); }),
              decoration: InputDecoration(labelText: "Categoría"),
            ),
            SizedBox(height: 15),
            TextField(controller: _c1, decoration: InputDecoration(labelText: _qrType == "Red WiFi" ? "Nombre de la Red (SSID)" : (_qrType == "VCard (Contacto)" ? "Nombre" : (_qrType == "WhatsApp" || _qrType == "Teléfono" || _qrType == "SMS (Mensaje)" ? "Número (Ej: +595...)" : "Contenido / Email")))),
            if (_qrType == "Red WiFi" || _qrType == "WhatsApp" || _qrType == "VCard (Contacto)" || _qrType == "E-mail" || _qrType == "SMS (Mensaje)") ...[
              SizedBox(height: 10),
              TextField(controller: _c2, decoration: InputDecoration(labelText: _qrType == "Red WiFi" ? "Contraseña" : (_qrType == "VCard (Contacto)" ? "Apellido" : (_qrType == "E-mail" ? "Asunto" : "Mensaje")))),
            ],
            if (_qrType == "VCard (Contacto)" || _qrType == "E-mail") ...[
              SizedBox(height: 10),
              TextField(controller: _c3, decoration: InputDecoration(labelText: _qrType == "E-mail" ? "Cuerpo del correo" : "Empresa / Organización")),
            ],
            if (_qrType == "VCard (Contacto)") ...[
              SizedBox(height: 10),
              TextField(controller: _c4, decoration: InputDecoration(labelText: "Teléfono")),
              SizedBox(height: 10),
              TextField(controller: _c5, decoration: InputDecoration(labelText: "Correo Electrónico")),
            ],
            
            SizedBox(height: 25),
            Text("2. Personalización Visual", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _estilo,
              items: ["Normal (Cuadrado)", "Liquid Pro (Gusano)", "Barras (Vertical)", "Circular (Puntos)"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _estilo = v!),
              decoration: InputDecoration(labelText: "Estilo Visual"),
            ),
            SizedBox(height: 15),
            OutlinedButton.icon(
              onPressed: _pickLogo, icon: Icon(Icons.image), 
              label: Text(_logoFile == null ? "Seleccionar Logo (Opcional)" : "Logo Seleccionado ✅"),
              style: OutlinedButton.styleFrom(minimumSize: Size(double.infinity, 50)),
            ),
            SizedBox(height: 30),
            
            // LÓGICA DE CARGA Y RESULTADO
            if (_loading)
              Center(
                child: Column(
                  children: [
                    SizedBox(
                      width: 60, height: 60,
                      child: CircularProgressIndicator(
                        value: _progressValue,
                        backgroundColor: Colors.grey[300],
                        color: _progressValue == 1.0 ? Colors.green : Colors.black, // Se vuelve verde al 100%
                        strokeWidth: 6,
                      ),
                    ),
                    SizedBox(height: 15),
                    Text(
                      _progressValue == 1.0 ? "¡Completado!" : "Procesando código QR...", 
                      style: TextStyle(fontWeight: FontWeight.bold, color: _progressValue == 1.0 ? Colors.green : Colors.black)
                    )
                  ],
                ),
              )
            else if (_resultImage == null)
              ElevatedButton(
                onPressed: _generate, 
                style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 60)),
                child: Text("GENERAR QR + LOGO", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))
              ),
            
            // SI HAY IMAGEN, MUESTRA EL QR Y LOS DOS BOTONES A LA PAR
            if (_resultImage != null && !_loading) ...[
              Padding(padding: EdgeInsets.only(top: 20, bottom: 20), child: Center(child: Image.memory(_resultImage!))),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _saveToGallery, 
                      icon: Icon(Icons.download), 
                      label: Text("Descargar", style: TextStyle(fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 15)),
                    ),
                  ),
                  SizedBox(width: 10), // Separación entre botones
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _shareImage, 
                      icon: Icon(Icons.share, color: Colors.white), 
                      label: Text("Compartir", style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 15)),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 15),
              // Botón extra para hacer uno nuevo
              TextButton(
                onPressed: () => setState(() => _resultImage = null),
                child: Center(child: Text("Generar otro código", style: TextStyle(color: Colors.black, decoration: TextDecoration.underline))),
              )
            ]
          ],
        ),
      ),
    );
  }
}

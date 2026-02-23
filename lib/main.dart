import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'dart:io';

void main() => runApp(MaterialApp(home: QRApp(), debugShowCheckedModeBanner: false));

class QRApp extends StatefulWidget {
  @override
  _QRAppState createState() => _QRAppState();
}

class _QRAppState extends State<QRApp> {
  final TextEditingController _c1 = TextEditingController();
  final TextEditingController _c2 = TextEditingController();
  final TextEditingController _c3 = TextEditingController();
  final TextEditingController _c4 = TextEditingController();
  
  String _qrType = "Sitio Web (URL)";
  String _selectedStyle = "Liquid Pro (Gusano)";
  File? _logoFile;
  Uint8List? _resultImage;
  bool _loading = false;

  Future<void> _pickLogo() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _logoFile = File(picked.path));
  }

  String _buildDataString() {
    String v1 = _c1.text; String v2 = _c2.text; String v3 = _c3.text; String v4 = _c4.text;
    if (_qrType == "Red WiFi") return "WIFI:T:WPA;S:$v1;P:$v2;;";
    if (_qrType == "WhatsApp") return "https://wa.me/$v1?text=${Uri.encodeComponent(v2)}";
    if (_qrType == "VCard (Contacto)") return "BEGIN:VCARD\nVERSION:3.0\nFN:$v1 $v2\nORG:$v3\nTEL:$v4\nEND:VCARD";
    return v1; // URL o Texto
  }

  Future<void> _generate() async {
    if (_c1.text.isEmpty) return;
    setState(() { _loading = true; _resultImage = null; });
    
    try {
      var request = http.MultipartRequest('POST', Uri.parse('https://qr-motor-v53.onrender.com/generate'));
      request.fields['texto'] = _buildDataString();
      request.fields['estilo'] = _selectedStyle;
      if (_logoFile != null) request.files.add(await http.MultipartFile.fromPath('logo', _logoFile!.path));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        setState(() => _resultImage = response.bodyBytes);
      } else {
        _showError("Error del servidor: ${response.statusCode}");
      }
    } catch (e) {
      _showError("No se pudo conectar al servidor. Revisa tu internet.");
    } finally {
      setState(() => _loading = false);
    }
  }

  void _showError(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("COMAGRO QR V53"), backgroundColor: Color(0xFF1A237E)),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: _qrType,
              items: ["Sitio Web (URL)", "Red WiFi", "WhatsApp", "VCard (Contacto)", "Texto Libre"]
                  .map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() { _qrType = v!; _c1.clear(); _c2.clear(); _c3.clear(); _c4.clear(); }),
              decoration: InputDecoration(labelText: "Categoría", border: OutlineInputBorder()),
            ),
            SizedBox(height: 15),
            TextField(controller: _c1, decoration: InputDecoration(labelText: _qrType == "Red WiFi" ? "Nombre WiFi (SSID)" : (_qrType == "VCard (Contacto)" ? "Nombre" : "Contenido"), border: OutlineInputBorder())),
            if (_qrType == "Red WiFi" || _qrType == "WhatsApp" || _qrType == "VCard (Contacto)") ...[
              SizedBox(height: 10),
              TextField(controller: _c2, decoration: InputDecoration(labelText: _qrType == "Red WiFi" ? "Contraseña" : (_qrType == "WhatsApp" ? "Mensaje inicial" : "Apellido"), border: OutlineInputBorder())),
            ],
            if (_qrType == "VCard (Contacto)") ...[
              SizedBox(height: 10),
              TextField(controller: _c3, decoration: InputDecoration(labelText: "Empresa", border: OutlineInputBorder())),
              SizedBox(height: 10),
              TextField(controller: _c4, decoration: InputDecoration(labelText: "Teléfono", border: OutlineInputBorder())),
            ],
            SizedBox(height: 20),
            DropdownButtonFormField<String>(
              value: _selectedStyle,
              items: ["Normal (Cuadrado)", "Liquid Pro (Gusano)", "Circular (Puntos)"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _selectedStyle = v!),
              decoration: InputDecoration(labelText: "Estilo Visual", border: OutlineInputBorder()),
            ),
            SizedBox(height: 20),
            OutlinedButton.icon(onPressed: _pickLogo, icon: Icon(Icons.image), label: Text(_logoFile == null ? "Seleccionar Logo de Galería" : "Logo: ${_logoFile!.path.split('/').last}")),
            SizedBox(height: 30),
            _loading 
              ? Column(children: [CircularProgressIndicator(), Text("\nConectando con motor V53...")]) 
              : ElevatedButton(
                  onPressed: _generate, 
                  style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 60), backgroundColor: Colors.green[800]),
                  child: Text("GENERAR QR V53", style: TextStyle(color: Colors.white, fontSize: 18))
                ),
            if (_resultImage != null) Padding(padding: EdgeInsets.only(top: 25), child: Image.memory(_resultImage!)),
          ],
        ),
      ),
    );
  }
}

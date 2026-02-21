import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'dart:convert';

void main() => runApp(MaterialApp(home: QRApp(), debugShowCheckedModeBanner: false));

class QRApp extends StatefulWidget {
  @override
  _QRAppState createState() => _QRAppState();
}

class _QRAppState extends State<QRApp> {
  TextEditingController _controller = TextEditingController();
  Uint8List? _qrImage;
  String _selectedStyle = "Liquid Pro (Gusano)";
  bool _isLoading = false;

  Future<void> _generateQR() async {
    if (_controller.text.isEmpty) return;
    setState(() => _isLoading = true);
    
    // Conexión con tu servidor de Render
    var url = Uri.parse('https://qr-motor-v53.onrender.com/generate');
    
    try {
      var response = await http.post(url, 
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "texto": _controller.text, 
          "estilo": _selectedStyle,
          "color": "#000000"
        })
      );

      if (response.statusCode == 200) {
        setState(() {
          _qrImage = response.bodyBytes;
          _isLoading = false;
        });
      } else {
        throw "Error del servidor";
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: No se pudo conectar con el motor")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("COMAGRO QR V53", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Color(0xFF1A237E), // Azul corporativo
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(25),
        child: Column(
          children: [
            TextField(
              controller: _controller, 
              decoration: InputDecoration(
                labelText: "Contenido del QR",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.qr_code)
              )
            ),
            SizedBox(height: 20),
            DropdownButtonFormField<String>(
              value: _selectedStyle,
              decoration: InputDecoration(labelText: "Estilo Visual", border: OutlineInputBorder()),
              items: ["Normal (Cuadrado)", "Liquid Pro (Gusano)", "Circular (Puntos)"]
                  .map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (val) => setState(() => _selectedStyle = val!),
            ),
            SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _generateQR,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700]),
                child: _isLoading ? CircularProgressIndicator(color: Colors.white) : Text("GENERAR QR NATIVO", style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
            SizedBox(height: 40),
            _qrImage != null 
              ? Column(
                  children: [
                    Image.memory(_qrImage!, width: 300),
                    SizedBox(height: 20),
                    Text("¡QR Generado con éxito!", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))
                  ],
                )
              : Icon(Icons.image_search, size: 100, color: Colors.grey[300])
          ],
        ),
      ),
    );
  }
}

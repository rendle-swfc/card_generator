import os

# Define project folder structure
directories = [
    "assets/frames",
    "assets/fonts",
    "lib",
]

# File contents to populate
files = {
    # 1. Flutter Dependencies & Asset Configuration
    "pubspec.yaml": """name: card_generator
description: A Flutter Web application for building custom SWFC cards.
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  http: ^1.1.0
  http_parser: ^4.0.2

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^2.0.0

flutter:
  uses-material-design: true

  assets:
    - assets/frames/

  fonts:
    - family: CardFont
      fonts:
        - asset: assets/fonts/card_font.ttf
""",

    # 2. Python OpenCV Backend
    "app.py": """from flask import Flask, request, send_file
from flask_cors import CORS
import cv2
import numpy as np
import io

app = Flask(__name__)
CORS(app)

def apply_painterly_effect(img):
    smoothed = cv2.bilateralFilter(img, d=9, sigmaColor=75, sigmaSpace=75)
    div = 32
    quantized = (smoothed // div) * div + div // 2
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    edges = cv2.adaptiveThreshold(
        gray, 255, cv2.ADAPTIVE_THRESH_MEAN_C, cv2.THRESH_BINARY, 9, 7
    )
    edges_colored = cv2.cvtColor(edges, cv2.COLOR_GRAY2BGR)
    return cv2.bitwise_and(quantized, edges_colored)

@app.route('/process', methods=['POST'])
def process_image():
    if 'image' not in request.files:
        return {"error": "No image uploaded"}, 400
        
    file = request.files['image']
    in_memory_file = io.BytesIO(file.read())
    file_bytes = np.frombuffer(in_memory_file.getvalue(), dtype=np.uint8)
    img = cv2.imdecode(file_bytes, cv2.IMREAD_COLOR)

    styled_img = apply_painterly_effect(img)
    _, buffer = cv2.imencode('.png', styled_img)
    
    return send_file(io.BytesIO(buffer), mimetype='image/png')

if __name__ == '__main__':
    app.run(port=5000, debug=True)
""",

    # 3. Main Flutter App Entry Point
    "lib/main.dart": """import 'package:flutter/material.dart';
import 'card_builder.dart';

void main() {
  runApp(const CardGeneratorApp());
}

class CardGeneratorApp extends StatelessWidget {
  const CardGeneratorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SWFC Card Generator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const CardBuilderScreen(),
    );
  }
}
""",

    # 4. Interactive Card Builder Screen
    "lib/card_builder.dart": """import 'dart:typed_data';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:ui' as ui;

class CardBuilderScreen extends StatefulWidget {
  const CardBuilderScreen({super.key});

  @override
  State<CardBuilderScreen> createState() => _CardBuilderScreenState();
}

class _CardBuilderScreenState extends State<CardBuilderScreen> {
  final GlobalKey _globalKey = GlobalKey();
  
  String _alignment = 'ds';
  String _rarity = '05';
  String _cardName = 'DARTH VADER';
  
  Uint8List? _processedArtBytes;
  bool _isLoading = false;

  String get _framePath => 'assets/frames/${_alignment}_frame_$_rarity.png';

  Future<void> _uploadAndProcessImage(Uint8List rawBytes, String filename) async {
    setState(() => _isLoading = true);
    
    var request = http.MultipartRequest('POST', Uri.parse('http://localhost:5000/process'));
    request.files.add(http.MultipartFile.fromBytes(
      'image', 
      rawBytes,
      filename: filename,
      contentType: MediaType('image', 'png'),
    ));

    try {
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        setState(() {
          _processedArtBytes = response.bodyBytes;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      print("Processing failed: $e");
    }
  }

  Future<void> _exportCard() async {
    RenderRepaintBoundary boundary = 
        _globalKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    ui.Image image = await boundary.toImage(pixelRatio: 1.0);
    ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    
    if (byteData != null) {
      final blob = html.Blob([byteData.buffer.asUint8List()]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute("download", "${_cardName.replaceAll(' ', '_')}_card.png")
        ..click();
      html.Url.revokeObjectUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("SWFC Card Builder")),
      body: Row(
        children: [
          Container(
            width: 320,
            padding: const EdgeInsets.all(16),
            color: Colors.grey[900],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  decoration: const InputDecoration(
                    labelText: "Card Name", 
                    labelStyle: TextStyle(color: Colors.white)
                  ),
                  style: const TextStyle(color: Colors.white),
                  onChanged: (val) => setState(() => _cardName = val),
                ),
                const SizedBox(height: 16),
                DropdownButton<String>(
                  value: _alignment,
                  dropdownColor: Colors.grey[800],
                  style: const TextStyle(color: Colors.white),
                  items: const [
                    DropdownMenuItem(value: 'ds', child: Text("Dark Side")),
                    DropdownMenuItem(value: 'ls', child: Text("Light Side")),
                    DropdownMenuItem(value: 'neutral', child: Text("Neutral")),
                  ],
                  onChanged: (val) => setState(() => _alignment = val!),
                ),
                const SizedBox(height: 16),
                DropdownButton<String>(
                  value: _rarity,
                  dropdownColor: Colors.grey[800],
                  style: const TextStyle(color: TextStyle(color: Colors.white)),
                  items: const [
                    DropdownMenuItem(value: '03', child: Text("3-Star")),
                    DropdownMenuItem(value: '04', child: Text("4-Star")),
                    DropdownMenuItem(value: '05', child: Text("5-Star")),
                  ],
                  onChanged: (val) => setState(() => _rarity = val!),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _exportCard,
                  child: const Text("Export Card PNG"),
                )
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: _isLoading 
                ? const CircularProgressIndicator()
                : SingleChildScrollView(
                    child: RepaintBoundary(
                      key: _globalKey,
                      child: SizedBox(
                        width: 450,
                        height: 640,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: _processedArtBytes != null
                                  ? Image.memory(_processedArtBytes!, fit: BoxFit.cover)
                                  : Container(color: Colors.black),
                            ),
                            Positioned.fill(
                              child: Image.asset(_framePath, fit: BoxFit.cover),
                            ),
                            Positioned(
                              bottom: 85, 
                              left: 0,
                              right: 0,
                              child: Center(
                                child: ShaderMask(
                                  shaderCallback: (bounds) => const LinearGradient(
                                    colors: [
                                      Color(0xFFFFE57F),
                                      Color(0xFFFFB300),
                                      Color(0xFFFF8F00),
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ).createShader(bounds),
                                  child: Text(
                                    _cardName.toUpperCase(),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontFamily: 'CardFont',
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      shadows: [
                                        Shadow(
                                          offset: Offset(2, 2),
                                          blurRadius: 3.0,
                                          color: Colors.black,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
"""
}

def create_structure():
    # 1. Create directories
    for directory in directories:
        os.makedirs(directory, exist_ok=True)
        print(f"Created directory: {directory}/")

    # 2. Write file contents
    for file_path, content in files.items():
        with open(file_path, "w", encoding="utf-8") as f:
            f.write(content.strip() + "\n")
        print(f"Created file: {file_path}")

    print("\n--- NEXT STEPS ---")
    print("1. Copy your 9 frame PNGs into 'assets/frames/' (e.g., ds_frame_05.png).")
    print("2. Copy your title font TTF file into 'assets/fonts/card_font.ttf'.")
    print("3. Run 'flutter pub get' to install Flutter packages.")
    print("4. Start backend: 'python app.py'")
    print("5. Launch app: 'flutter run -d chrome'")

if __name__ == "__main__":
    create_structure()
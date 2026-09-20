import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

// Standalone Enums for the Generator Tool
enum RarityEnum { oneStar, twoStar, threeStar, fourStar, fiveStar }
enum RangeTypeEnum { short, medium, long }
enum AttackPatternEnum { singleTarget, pierce, sweep, sniper, semiCircle, superLaser }
enum WeaponTypeEnum {
  blasterRed,
  blasterBlue,
  blasterGreen,
  lightsaberBlue,
  lightsaberRed,
  lightsaberGreen,
  lightsaberPurple,
  melee,
  forceLightning,
  Chirrut,
  riotBaton,
  magnaguard,
  flamethrower,
  darksaber,
  rocket,
  superLaser,
  saberThrowRed,
  saberThrowBlue,
  saberThrowGreen,
  saberThrowPurple,
}

// Preset unique tags list (excluding alignment and range)
const List<String> kValidPresetTags = [
  'Clone Trooper',
  'Dathomir',
  'Droid',
  'Empire',
  'Ewok',
  'First Order',
  'Galactic Republic',
  'Gungan',
  'Jedi',
  'Rebel',
  'Resistance',
  'Scoundrel',
  'Separatist',
  'Sith',
  'Tusken Raider',
  'Wookiee',
];

class CardBuilderScreen extends StatefulWidget {
  const CardBuilderScreen({super.key});

  @override
  State<CardBuilderScreen> createState() => _CardBuilderScreenState();
}

class _CardBuilderScreenState extends State<CardBuilderScreen> {
  final GlobalKey _globalKey = GlobalKey();

  // Core Text Controllers
  late final TextEditingController _nameController;
  late final TextEditingController _versionNameController;
  late final TextEditingController _customTagsController;

  // Visual Customization States
  String _alignment = 'ds'; // 'ds', 'ls', 'neutral'
  String _rarity = '05'; // '03', '04', '05'
  String _cardName = '';
  String _versionName = '';

  // Processing & Effect Controls
  bool _isOverrideEnabled = false;
  bool _bypassFilter = false;
  String _unitCategory = 'standard';
  String _intensity = 'medium';

  // Image Framing Controls
  double _artOffsetX = 0.0;
  double _artOffsetY = 0.0;
  double _artScale = 1.0;

  // Raw / Processed Image Cache
  Uint8List? _rawArtBytes;
  String? _rawFilename;
  Uint8List? _processedArtBytes;
  bool _isLoading = false;

  // --- STAT GENERATOR CONTROLLERS & STATES ---
  int _capacity = 1;
  int _evoMaxAtk = 1;
  int _evoMaxDef = 1;
  int _evoMaxAcc = 1;
  int _evoMaxEva = 1;
  double _attacksPerTurn = 1;
  RangeTypeEnum _range = RangeTypeEnum.short;
  AttackPatternEnum _attackPattern = AttackPatternEnum.singleTarget;
  String _skillId = 'none';
  WeaponTypeEnum _weaponType = WeaponTypeEnum.blasterRed;
  List<WeaponTypeEnum> _additionalWeapons = [];
  int _baseTradeValue = 10;

  // Tag Management
  final List<String> _selectedPresetTags = [];
  bool _enableFreeTextTags = false;
  String _freeTextTags = '';

  String get _framePath => 'assets/frames/${_alignment}_frame_$_rarity.png';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: _cardName);
    _versionNameController = TextEditingController(text: _versionName);
    _customTagsController = TextEditingController(text: _freeTextTags);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _versionNameController.dispose();
    _customTagsController.dispose();
    super.dispose();
  }

  // --- STAT CONVERSION CALCULATIONS ---

  int _calculateEvo0Stat(int evoMaxStat) {
    double raw = evoMaxStat * 0.56248;
    return (raw / 10.0).round() * 10;
  }

  int _calculateEvo0AccEva(int evoMaxAccEva) {
    return (evoMaxAccEva / 1.10).round();
  }

  String _generateCardId() {
    String cleanChar = _cardName.trim().replaceAll(RegExp(r'[^\w\s]'), '').replaceAll(' ', '_');
    if (cleanChar.isEmpty) cleanChar = 'Unknown';

    String cleanVersion = _versionName.trim().replaceAll(RegExp(r'[^\w\s]'), '');
    String versionInitials = '';
    if (cleanVersion.isNotEmpty) {
      List<String> words = cleanVersion.split(RegExp(r'\s+'));
      versionInitials = words.map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').join('');
    }

    if (versionInitials.isNotEmpty) {
      return '${cleanChar}_$versionInitials';
    } else {
      return '${cleanChar}_$_rarity';
    }
  }

  RarityEnum _getRarityEnum() {
    switch (_rarity) {
      case '01': return RarityEnum.oneStar;
      case '02': return RarityEnum.twoStar;
      case '03': return RarityEnum.threeStar;
      case '04': return RarityEnum.fourStar;
      case '05':
      default: return RarityEnum.fiveStar;
    }
  }

  String _generateDartCodeSnippet() {
    final String cardId = _generateCardId();
    final String fullName = _versionName.trim().isNotEmpty 
        ? '${_cardName.trim()} (${_versionName.trim()})'
        : _cardName.trim();
    
    final int evo0Atk = _calculateEvo0Stat(_evoMaxAtk);
    final int evo0Def = _calculateEvo0Stat(_evoMaxDef);
    final int acc = _calculateEvo0AccEva(_evoMaxAcc);
    final int eva = _calculateEvo0AccEva(_evoMaxEva);

    // Build Tags List
    List<String> tagList = [];
    if (_alignment == 'ds') tagList.add('Dark Side');
    if (_alignment == 'ls') tagList.add('Light Side');
    if (_alignment == 'neutral') tagList.add('Neutral');

    // Add selected preset tags
    tagList.addAll(_selectedPresetTags);

    // Add free text tags if enabled
    if (_enableFreeTextTags && _freeTextTags.trim().isNotEmpty) {
      tagList.addAll(_freeTextTags.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty));
    }

    String rangeTag = _range.name[0].toUpperCase() + _range.name.substring(1);
    if (!tagList.contains(rangeTag)) tagList.add(rangeTag);

    String formattedTags = tagList.map((t) => "'$t'").join(', ');

    String formattedAttacks = _attacksPerTurn % 1 == 0 
        ? _attacksPerTurn.toInt().toString() 
        : _attacksPerTurn.toString();

    String addWeaponsStr = _additionalWeapons.isEmpty 
        ? '' 
        : '\n    additionalWeapons: [${_additionalWeapons.map((w) => 'WeaponType.${w.name}').join(', ')}],';

    return '''const CardMasterData(
    id: '$cardId',
    name: '$fullName',
    assetPath: 'assets/cards/$cardId.png',
    rarity: Rarity.${_getRarityEnum().name}, 
    capacity: $_capacity,
    maxLevelEvo0HP: 1000,
    maxLevelEvo0Attack: $evo0Atk,
    maxLevelEvo0Defense: $evo0Def,
    accuracy: $acc, 
    evasion: $eva,    
    attacksPerTurn: $formattedAttacks, 
    range: RangeType.${_range.name},
    attackPattern: AttackPattern.${_attackPattern.name},      
    skillId: '$_skillId',
    tags: [$formattedTags],$addWeaponsStr
    weaponType: WeaponType.${_weaponType.name}, 
    baseTradeValue: $_baseTradeValue,
),''';
  }

  // --- API & FILE OPERATOR METHODS ---

  Future<void> _pickAndUploadImage() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      if (file.bytes != null) {
        _rawArtBytes = file.bytes;
        _rawFilename = file.name;
        await _uploadAndProcessImage(_rawArtBytes!, _rawFilename!);
      }
    }
  }

  Future<void> _reprocessImage() async {
    if (_rawArtBytes != null && _rawFilename != null) {
      await _uploadAndProcessImage(_rawArtBytes!, _rawFilename!);
    }
  }

  Future<void> _uploadAndProcessImage(Uint8List rawBytes, String filename) async {
    setState(() => _isLoading = true);

    var request = http.MultipartRequest('POST', Uri.parse('http://localhost:5000/process'));
    request.fields['alignment'] = _alignment;
    request.fields['rarity'] = _rarity;
    request.fields['unit_category'] = _unitCategory;
    request.fields['override_enabled'] = _isOverrideEnabled.toString();
    request.fields['bypass_filter'] = _bypassFilter.toString();
    request.fields['intensity'] = _intensity;
    request.fields['card_name'] = _nameController.text.trim();

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
      debugPrint("Processing failed: $e");
    }
  }

  Future<void> _exportCard() async {
    try {
      RenderRepaintBoundary? boundary =
          _globalKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData != null) {
        final Uint8List pngBytes = byteData.buffer.asUint8List();
        final blob = html.Blob([pngBytes], 'image/png');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final fileName = '${_generateCardId()}.png';

        final anchor = html.AnchorElement(href: url)
          ..setAttribute("download", fileName)
          ..click();

        html.Url.revokeObjectUrl(url);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Card image exported as $fileName!')),
        );
      }
    } catch (e) {
      debugPrint("Export failed: $e");
    }
  }

  // --- TEXT SHADER & RENDERING ---

  Gradient _getTextGradient(String rarity) {
    if (rarity == '05') {
      return const LinearGradient(
        colors: [
          Color(0xFFFFFFFF),
          Color(0xFFFFFDE8),
          Color(0xFFF3C04D),
          Color(0xFF80430A),
          Color(0xFFEEA22D),
          Color(0xFFFFF7C2),
          Color(0xFFFFFFFF),
        ],
        stops: [0.00, 0.25, 0.45, 0.47, 0.65, 0.88, 1.00],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );
    } else {
      return const LinearGradient(
        colors: [
          Color(0xFFFFFFFF),
          Color(0xFFF8FAFC),
          Color(0xFFB5BAC0),
          Color(0xFF5A626A),
          Color(0xFFC0C7CE),
          Color(0xFFEDF1F5),
          Color(0xFFFFFFFF),
        ],
        stops: [0.00, 0.25, 0.45, 0.47, 0.65, 0.88, 1.00],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );
    }
  }

  List<String> _calculateTextLines(String text) {
    const int maxSingleLineChars = 17;
    if (text.length <= maxSingleLineChars) return [text];

    List<String> words = text.split(' ');
    if (words.length == 1) return [text];

    int bestSplitIndex = 1;
    int minDifference = 999;

    for (int i = 1; i < words.length; i++) {
      String line1 = words.sublist(0, i).join(' ');
      String line2 = words.sublist(i).join(' ');
      int diff = (line1.length - line2.length).abs();

      if (diff < minDifference) {
        minDifference = diff;
        bestSplitIndex = i;
      }
    }

    return [
      words.sublist(0, bestSplitIndex).join(' '),
      words.sublist(bestSplitIndex).join(' '),
    ];
  }

  double _calculateFontSizeForLine(String line) {
    const double standardSize = 27.0;
    const int maxCharsPerStandardLine = 17;

    if (line.length <= maxCharsPerStandardLine) return standardSize;
    return (standardSize * (maxCharsPerStandardLine / line.length)).clamp(18.0, standardSize);
  }

  Widget _buildCardTitle() {
    final rawName = _cardName.toUpperCase().trim();
    if (rawName.isEmpty) return const SizedBox.shrink();

    List<String> lines = _calculateTextLines(rawName);

    return Positioned(
      bottom: 75.0,
      left: 10,
      right: 10,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(lines.length, (index) {
            final lineText = lines[index];
            double lineFontSize = _calculateFontSizeForLine(lineText);
            final double yOffset = (index > 0) ? -6.0 : 0.0;

            return Transform.translate(
              offset: Offset(0, yOffset),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    lineText,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'CardFont',
                      fontSize: lineFontSize,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      foreground: Paint()
                        ..style = PaintingStyle.stroke
                        ..strokeWidth = 4.5
                        ..strokeJoin = StrokeJoin.bevel
                        ..color = _rarity == '05' ? const Color(0xFF1B0A00) : Colors.black,
                    ),
                  ),
                  Text(
                    lineText,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'CardFont',
                      fontSize: lineFontSize,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      foreground: Paint()
                        ..style = PaintingStyle.stroke
                        ..strokeWidth = 1.8
                        ..strokeJoin = StrokeJoin.bevel
                        ..color = Colors.white,
                    ),
                  ),
                  ShaderMask(
                    shaderCallback: (bounds) => _getTextGradient(_rarity).createShader(bounds),
                    child: Text(
                      lineText,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'CardFont',
                        fontSize: lineFontSize,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        foreground: Paint()
                          ..style = PaintingStyle.fill
                          ..color = Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("SWFC Card Builder & Data Generator"),
        actions: [
          IconButton(
            icon: const Icon(Icons.code),
            tooltip: "Copy CardMasterData Code",
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _generateDartCodeSnippet()));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('CardMasterData copied to clipboard!')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: "Export Card PNG",
            onPressed: _exportCard,
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Row(
        children: [
          // PANEL 1: CARD DATA STATS GENERATOR
          Container(
            width: 380,
            color: Colors.grey[900],
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text("Card Master Data Stats",
                      style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: "Character Name", border: OutlineInputBorder()),
                    style: const TextStyle(color: Colors.white),
                    onChanged: (val) => setState(() => _cardName = val),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _versionNameController,
                    decoration: const InputDecoration(
                      labelText: "Version Name (e.g. Last Stand)",
                      border: OutlineInputBorder(),
                    ),
                    style: const TextStyle(color: Colors.white),
                    onChanged: (val) => setState(() => _versionName = val),
                  ),
                  const SizedBox(height: 10),
                  Text("Generated ID: ${_generateCardId()}",
                      style: const TextStyle(color: Colors.amberAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                  const Divider(color: Colors.white24, height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: _capacity.toString(),
                          decoration: const InputDecoration(labelText: "Capacity", border: OutlineInputBorder()),
                          style: const TextStyle(color: Colors.white),
                          keyboardType: TextInputType.number,
                          onChanged: (val) => setState(() => _capacity = int.tryParse(val) ?? 0),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          initialValue: _baseTradeValue.toString(),
                          decoration: const InputDecoration(labelText: "Trade Value", border: OutlineInputBorder()),
                          style: const TextStyle(color: Colors.white),
                          keyboardType: TextInputType.number,
                          onChanged: (val) => setState(() => _baseTradeValue = int.tryParse(val) ?? 0),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: _evoMaxAtk.toString(),
                          decoration: const InputDecoration(labelText: "Evo-Max ATK", border: OutlineInputBorder()),
                          style: const TextStyle(color: Colors.white),
                          keyboardType: TextInputType.number,
                          onChanged: (val) => setState(() => _evoMaxAtk = int.tryParse(val) ?? 0),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          initialValue: _evoMaxDef.toString(),
                          decoration: const InputDecoration(labelText: "Evo-Max DEF", border: OutlineInputBorder()),
                          style: const TextStyle(color: Colors.white),
                          keyboardType: TextInputType.number,
                          onChanged: (val) => setState(() => _evoMaxDef = int.tryParse(val) ?? 0),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Calculated Evo0 Target -> ATK: ${_calculateEvo0Stat(_evoMaxAtk)} | DEF: ${_calculateEvo0Stat(_evoMaxDef)}",
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                  const SizedBox(height: 10),
                  // STATS & ATTACK CONFIGURATION
Row(
  children: [
    Expanded(
      child: TextFormField(
        initialValue: _evoMaxAcc.toString(),
        decoration: const InputDecoration(labelText: "Max Acc", border: OutlineInputBorder()),
        style: const TextStyle(color: Colors.white),
        keyboardType: TextInputType.number,
        onChanged: (val) => setState(() => _evoMaxAcc = int.tryParse(val) ?? 0),
      ),
    ),
    const SizedBox(width: 8),
    Expanded(
      child: TextFormField(
        initialValue: _evoMaxEva.toString(),
        decoration: const InputDecoration(labelText: "Max Eva", border: OutlineInputBorder()),
        style: const TextStyle(color: Colors.white),
        keyboardType: TextInputType.number,
        onChanged: (val) => setState(() => _evoMaxEva = int.tryParse(val) ?? 0),
      ),
    ),
    const SizedBox(width: 8),
    Expanded(
      child: TextFormField(
        initialValue: _attacksPerTurn.toString(),
        decoration: const InputDecoration(labelText: "Attacks / Turn", border: OutlineInputBorder()),
        style: const TextStyle(color: Colors.white),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (val) => setState(() => _attacksPerTurn = double.tryParse(val) ?? 1.0),
      ),
    ),
  ],
),
const SizedBox(height: 4),
Text(
  "Calculated Base -> Acc: ${_calculateEvo0AccEva(_evoMaxAcc)} | Eva: ${_calculateEvo0AccEva(_evoMaxEva)}",
  style: const TextStyle(color: Colors.white54, fontSize: 11),
),
const SizedBox(height: 10),

// RANGE & ATTACK PATTERN (SAME ROW)
Row(
  children: [
    Expanded(
      child: DropdownButtonFormField<RangeTypeEnum>(
        value: _range,
        decoration: const InputDecoration(labelText: "Range", border: OutlineInputBorder(), isDense: true),
        dropdownColor: Colors.grey[800],
        style: const TextStyle(color: Colors.white, fontSize: 13),
        items: RangeTypeEnum.values
            .map((r) => DropdownMenuItem(value: r, child: Text(r.name)))
            .toList(),
        onChanged: (val) => setState(() => _range = val!),
      ),
    ),
    const SizedBox(width: 8),
    Expanded(
      child: DropdownButtonFormField<AttackPatternEnum>(
        value: _attackPattern,
        decoration: const InputDecoration(labelText: "Attack Pattern", border: OutlineInputBorder(), isDense: true),
        dropdownColor: Colors.grey[800],
        style: const TextStyle(color: Colors.white, fontSize: 13),
        items: AttackPatternEnum.values
            .map((a) => DropdownMenuItem(value: a, child: Text(a.name)))
            .toList(),
        onChanged: (val) => setState(() => _attackPattern = val!),
      ),
    ),
  ],
),
const SizedBox(height: 10),

// MAIN WEAPON + INLINE ADD BUTTON
Row(
  crossAxisAlignment: CrossAxisAlignment.center,
  children: [
    Expanded(
      child: DropdownButtonFormField<WeaponTypeEnum>(
        value: _weaponType,
        decoration: const InputDecoration(labelText: "Main Weapon", border: OutlineInputBorder(), isDense: true),
        dropdownColor: Colors.grey[800],
        style: const TextStyle(color: Colors.white, fontSize: 13),
        items: WeaponTypeEnum.values
            .map((w) => DropdownMenuItem(value: w, child: Text(w.name)))
            .toList(),
        onChanged: (val) => setState(() => _weaponType = val!),
      ),
    ),
    const SizedBox(width: 8),
    IconButton(
      icon: const Icon(Icons.add_circle_outline, color: Colors.cyanAccent, size: 26),
      tooltip: "Add Additional Weapon",
      onPressed: () {
        setState(() => _additionalWeapons.add(WeaponTypeEnum.lightsaberGreen));
      },
    ),
  ],
),

// DYNAMIC ADDITIONAL WEAPONS DROPDOWNS
if (_additionalWeapons.isNotEmpty) ...[
  const SizedBox(height: 6),
  ..._additionalWeapons.asMap().entries.map((entry) {
    int idx = entry.key;
    WeaponTypeEnum w = entry.value;
    return Padding(
      padding: const EdgeInsets.only(top: 6.0),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<WeaponTypeEnum>(
              value: w,
              decoration: InputDecoration(
                labelText: "Secondary Weapon #${idx + 1}",
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              dropdownColor: Colors.grey[800],
              style: const TextStyle(color: Colors.white, fontSize: 13),
              items: WeaponTypeEnum.values
                  .map((wp) => DropdownMenuItem(value: wp, child: Text(wp.name)))
                  .toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _additionalWeapons[idx] = val);
                }
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
            tooltip: "Remove Weapon",
            onPressed: () {
              setState(() => _additionalWeapons.removeAt(idx));
            },
          )
        ],
      ),
    );
  }),
],

const Divider(color: Colors.white24, height: 20),

// CONDENSED TAGS SECTION
Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    const Text("Tags", style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 13)),
    FilterChip(
      label: const Text("+ Custom", style: TextStyle(fontSize: 10, color: Colors.white)),
      selected: _enableFreeTextTags,
      selectedColor: Colors.cyan[800],
      backgroundColor: Colors.grey[800],
      showCheckmark: false,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      onSelected: (val) => setState(() => _enableFreeTextTags = val),
    ),
  ],
),
const SizedBox(height: 6),

// CONDENSED TAGS SECTION (Opens UP cleanly)
UpwardTagAutocomplete(
  presetTags: kValidPresetTags,
  selectedTags: _selectedPresetTags,
  onTagSelected: (tag) {
    if (!_selectedPresetTags.contains(tag)) {
      setState(() => _selectedPresetTags.add(tag));
    }
  },
),
const SizedBox(height: 6),

// Inline Selected Tag Chips
if (_selectedPresetTags.isNotEmpty)
  Wrap(
    spacing: 4.0,
    runSpacing: 4.0,
    children: _selectedPresetTags.map((tag) {
      return Chip(
        label: Text(tag, style: const TextStyle(fontSize: 10, color: Colors.white)),
        backgroundColor: Colors.blueGrey[800],
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        deleteIcon: const Icon(Icons.close, size: 12, color: Colors.white70),
        onDeleted: () {
          setState(() => _selectedPresetTags.remove(tag));
        },
      );
    }).toList(),
  ),

if (_enableFreeTextTags) ...[
  const SizedBox(height: 6),
  TextField(
    controller: _customTagsController,
    decoration: const InputDecoration(
      labelText: "Custom Tags Override (comma separated)",
      border: OutlineInputBorder(),
      isDense: true,
      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    ),
    style: const TextStyle(color: Colors.white, fontSize: 12),
    onChanged: (val) => setState(() => _freeTextTags = val),
  ),
],

                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _generateDartCodeSnippet()));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('CardMasterData copied to clipboard!')),
                      );
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text("Copy CardMasterData Code"),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: Colors.deepPurpleAccent,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // PANEL 2: ART & FILTER CONTROLS
          Container(
            width: 320,
            color: Colors.grey[850],
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text("Card Art & Frame Controls",
                      style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _pickAndUploadImage,
                    icon: const Icon(Icons.image_search),
                    label: const Text("Upload Character Art"),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _alignment,
                    decoration: const InputDecoration(labelText: "Alignment", border: OutlineInputBorder()),
                    dropdownColor: Colors.grey[800],
                    style: const TextStyle(color: Colors.white),
                    items: const [
                      DropdownMenuItem(value: 'ds', child: Text("Dark Side")),
                      DropdownMenuItem(value: 'ls', child: Text("Light Side")),
                      DropdownMenuItem(value: 'neutral', child: Text("Neutral")),
                    ],
                    onChanged: (val) {
                      setState(() => _alignment = val!);
                      _reprocessImage();
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _rarity,
                    decoration: const InputDecoration(labelText: "Rarity", border: OutlineInputBorder()),
                    dropdownColor: Colors.grey[800],
                    style: const TextStyle(color: Colors.white),
                    items: const [
                      DropdownMenuItem(value: '03', child: Text("3-Star")),
                      DropdownMenuItem(value: '04', child: Text("4-Star")),
                      DropdownMenuItem(value: '05', child: Text("5-Star")),
                    ],
                    onChanged: (val) {
                      setState(() => _rarity = val!);
                      _reprocessImage();
                    },
                  ),
                  const Divider(color: Colors.white24, height: 24),
                  SwitchListTile(
                    title: const Text("Bypass Painterly Style", style: TextStyle(color: Colors.white, fontSize: 13)),
                    subtitle: const Text("Use original uploaded art directly", style: TextStyle(color: Colors.white54, fontSize: 11)),
                    value: _bypassFilter,
                    activeColor: Colors.amber,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) {
                      setState(() => _bypassFilter = val);
                      _reprocessImage();
                    },
                  ),
                  if (!_bypassFilter) ...[
                    DropdownButtonFormField<String>(
                      value: _intensity,
                      decoration: const InputDecoration(labelText: "Effect Intensity", border: OutlineInputBorder()),
                      dropdownColor: Colors.grey[800],
                      style: const TextStyle(color: Colors.white),
                      items: const [
                        DropdownMenuItem(value: 'subtle', child: Text("Subtle")),
                        DropdownMenuItem(value: 'medium', child: Text("Medium")),
                        DropdownMenuItem(value: 'heavy', child: Text("Heavy")),
                      ],
                      onChanged: (val) {
                        setState(() => _intensity = val!);
                        _reprocessImage();
                      },
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text("Override Unit Category", style: TextStyle(color: Colors.white, fontSize: 13)),
                      subtitle: const Text("Manually select Droid / Masked / Creature", style: TextStyle(color: Colors.white54, fontSize: 11)),
                      value: _isOverrideEnabled,
                      activeColor: Colors.cyanAccent,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) {
                        setState(() => _isOverrideEnabled = val);
                        _reprocessImage();
                      },
                    ),
                    if (_isOverrideEnabled) ...[
                      const SizedBox(height: 4),
                      DropdownButtonFormField<String>(
                        value: _unitCategory,
                        decoration: const InputDecoration(labelText: "Unit Category", border: OutlineInputBorder()),
                        dropdownColor: Colors.grey[800],
                        style: const TextStyle(color: Colors.white),
                        items: const [
                          DropdownMenuItem(value: 'standard', child: Text("Standard Human")),
                          DropdownMenuItem(value: 'masked', child: Text("Masked Unit")),
                          DropdownMenuItem(value: 'droid', child: Text("Droid / Mechanical")),
                          DropdownMenuItem(value: 'creature', child: Text("Creature / Beast")),
                        ],
                        onChanged: (val) {
                          setState(() => _unitCategory = val!);
                          _reprocessImage();
                        },
                      ),
                    ],
                  ],
                  const Divider(color: Colors.white24, height: 24),
                  const Text("Artwork Framing Adjustments", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text("Zoom: ${_artScale.toStringAsFixed(2)}x", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  Slider(
                    value: _artScale,
                    min: 0.5,
                    max: 2.5,
                    onChanged: (val) => setState(() => _artScale = val),
                  ),
                  Text("Horizontal Offset: ${_artOffsetX.toInt()}", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  Slider(
                    value: _artOffsetX,
                    min: -600,
                    max: 600,
                    onChanged: (val) => setState(() => _artOffsetX = val),
                  ),
                  Text("Vertical Offset: ${_artOffsetY.toInt()}", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  Slider(
                    value: _artOffsetY,
                    min: -200,
                    max: 200,
                    onChanged: (val) => setState(() => _artOffsetY = val),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _exportCard,
                    icon: const Icon(Icons.download),
                    label: const Text("Export Card PNG"),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // PANEL 3: LIVE PREVIEW
          Expanded(
            child: Container(
              color: Colors.black26,
              padding: const EdgeInsets.all(24),
              child: Center(
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : FittedBox(
                        fit: BoxFit.contain,
                        child: RepaintBoundary(
                          key: _globalKey,
                          child: SizedBox(
                            width: 450,
                            height: 640,
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: ClipRect(
                                    child: _processedArtBytes != null
                                        ? Transform.translate(
                                            offset: Offset(_artOffsetX, _artOffsetY),
                                            child: Transform.scale(
                                              scale: _artScale,
                                              child: Center(
                                                child: OverflowBox(
                                                  maxWidth: double.infinity,
                                                  maxHeight: double.infinity,
                                                  child: Image.memory(
                                                    _processedArtBytes!,
                                                    fit: BoxFit.fitHeight,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          )
                                        : Container(
                                            color: Colors.grey[850],
                                            child: const Center(
                                              child: Text("No Artwork Uploaded", style: TextStyle(color: Colors.white54)),
                                            ),
                                          ),
                                  ),
                                ),
                                Positioned.fill(
                                  child: Image.asset(_framePath, fit: BoxFit.cover),
                                ),
                                _buildCardTitle(),
                              ],
                            ),
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

class UpwardTagAutocomplete extends StatefulWidget {
  final List<String> presetTags;
  final List<String> selectedTags;
  final ValueChanged<String> onTagSelected;

  const UpwardTagAutocomplete({
    Key? key,
    required this.presetTags,
    required this.selectedTags,
    required this.onTagSelected,
  }) : super(key: key);

  @override
  State<UpwardTagAutocomplete> createState() => _UpwardTagAutocompleteState();
}

class _UpwardTagAutocompleteState extends State<UpwardTagAutocomplete> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  List<String> _filteredOptions = [];

  @override
void initState() {
  super.initState();
  _focusNode.addListener(() {
    if (_focusNode.hasFocus) {
      _updateFilteredOptions(_controller.text);
      _showOverlay();
    } else {
      // Delay closing slightly so onTap callbacks on the overlay have time to execute
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted && !_focusNode.hasFocus) {
          _hideOverlay();
        }
      });
    }
  });
}

  void _updateFilteredOptions(String query) {
    setState(() {
      _filteredOptions = widget.presetTags
          .where((tag) =>
              !widget.selectedTags.contains(tag) &&
              tag.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
    _overlayEntry?.markNeedsBuild();
  }

  void _showOverlay() {
    _hideOverlay(); // Prevent duplicate overlays
    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          // Target Anchor: Top-Left of TextField
          targetAnchor: Alignment.topLeft,
          // Follower Anchor: Bottom-Left of Overlay (pushes overlay directly UP)
          followerAnchor: Alignment.bottomLeft,
          offset: const Offset(0, -6), // 6px gap above textfield
          child: Material(
            elevation: 8,
            color: Colors.grey[850],
            borderRadius: BorderRadius.circular(6),
            child: _filteredOptions.isEmpty
                ? const SizedBox.shrink()
                : Container(
                    constraints: const BoxConstraints(maxHeight: 180),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: _filteredOptions.length,
                      itemBuilder: (context, index) {
                        final tag = _filteredOptions[index];
                        return ListTile(
                          dense: true,
                          title: Text(
                            tag,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                          ),
                          hoverColor: Colors.cyan[900],
                          onTap: () {
                            // 1. Call parent callback to add tag to state
                            widget.onTagSelected(tag);

                            // 2. Clear input & refresh filtered list
                            _controller.clear();
                            _updateFilteredOptions('');

                            // 3. Keep or re-engage focus on input field
                            _focusNode.requestFocus();
                          },
                        );
                      },
                    ),
                  ),
          ),
        ),
      ),
    );

    overlay.insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _hideOverlay();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        style: const TextStyle(color: Colors.white, fontSize: 12),
        decoration: InputDecoration(
          hintText: "Search or add tags...",
          hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          border: const OutlineInputBorder(),
          suffixIcon: _controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.add,
                      size: 18, color: Colors.cyanAccent),
                  onPressed: () {
                    if (_controller.text.trim().isNotEmpty) {
                      widget.onTagSelected(_controller.text.trim());
                      _controller.clear();
                      _updateFilteredOptions('');
                    }
                  },
                )
              : null,
        ),
        onChanged: (val) {
          _updateFilteredOptions(val);
          if (_overlayEntry == null && _focusNode.hasFocus) {
            _showOverlay();
          }
        },
        onSubmitted: (val) {
          if (val.trim().isNotEmpty) {
            widget.onTagSelected(val.trim());
            _controller.clear();
            _updateFilteredOptions('');
          }
        },
      ),
    );
  }
}
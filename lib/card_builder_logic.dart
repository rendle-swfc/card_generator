import 'dart:typed_data';
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

// Preset unique tags list
const List<String> kValidPresetTags = [
  'Clone Trooper',
  'Dathomir',
  'Droid',
  'Male',
  'Female',
  'Beast',
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
  'Mandalorian',
];

class CardDataUtils {
  static int calculateEvo0Stat(int evoMaxStat) {
    double raw = evoMaxStat * 0.56248;
    return (raw / 10.0).round() * 10;
  }

  static int calculateEvo0AccEva(int evoMaxAccEva) {
    return (evoMaxAccEva).round();
  }

  static String generateCardId(String cardName, String versionName, String rarity) {
    String cleanChar =
        cardName.trim().replaceAll(RegExp(r'[^\w\s]'), '').replaceAll(' ', '_');
    if (cleanChar.isEmpty) cleanChar = 'Unknown';

    String cleanVersion = versionName.trim().replaceAll(RegExp(r'[^\w\s]'), '');
    String versionInitials = '';
    if (cleanVersion.isNotEmpty) {
      List<String> words = cleanVersion.split(RegExp(r'\s+'));
      versionInitials =
          words.map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').join('');
    }

    // FIX: Include both version initials AND rarity number in the ID
    if (versionInitials.isNotEmpty) {
      return '${cleanChar}_${versionInitials}_$rarity';
    } else {
      return '${cleanChar}_$rarity';
    }
  }

  static RarityEnum getRarityEnum(String rarity) {
    switch (rarity) {
      case '01':
        return RarityEnum.oneStar;
      case '02':
        return RarityEnum.twoStar;
      case '03':
        return RarityEnum.threeStar;
      case '04':
        return RarityEnum.fourStar;
      case '05':
      default:
        return RarityEnum.fiveStar;
    }
  }

  static String generateDartCodeSnippet({
    required String cardName,
    required String versionName,
    required String rarity,
    required String alignment,
    required int capacity,
    required int evoMaxAtk,
    required int evoMaxDef,
    required int evoMaxAcc,
    required int evoMaxEva,
    required double attacksPerTurn,
    required RangeTypeEnum range,
    required AttackPatternEnum attackPattern,
    required String skillId,
    required WeaponTypeEnum weaponType,
    required List<WeaponTypeEnum> additionalWeapons,
    required int baseTradeValue,
    required List<String> selectedPresetTags,
    required bool enableFreeTextTags,
    required String freeTextTags,
  }) {
    final String cardId = generateCardId(cardName, versionName, rarity);

    // FIX: Added proper $ interpolation and outer parentheses
    final String cleanName = cardName.trim();
    final String cleanVersion = versionName.trim();
    final String fullName = cleanVersion.isNotEmpty
        ? '$cleanName ($cleanVersion)'
        : cleanName;

    final int evo0Atk = calculateEvo0Stat(evoMaxAtk);
    final int evo0Def = calculateEvo0Stat(evoMaxDef);
    final int acc = calculateEvo0AccEva(evoMaxAcc);
    final int eva = calculateEvo0AccEva(evoMaxEva);

    List<String> tagList = [];
    if (alignment == 'ds') tagList.add('Dark Side');
    if (alignment == 'ls') tagList.add('Light Side');
    if (alignment == 'neutral') tagList.add('Neutral');

    tagList.addAll(selectedPresetTags);

    if (enableFreeTextTags && freeTextTags.trim().isNotEmpty) {
      tagList.addAll(freeTextTags
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty));
    }

    String rangeTag = range.name[0].toUpperCase() + range.name.substring(1);
    if (!tagList.contains(rangeTag)) tagList.add(rangeTag);

    String formattedTags = tagList.map((t) => "'$t'").join(', ');

    String formattedAttacks = attacksPerTurn % 1 == 0
        ? attacksPerTurn.toInt().toString()
        : attacksPerTurn.toString();

    String addWeaponsStr = additionalWeapons.isEmpty
        ? ''
        : '\n    additionalWeapons: [${additionalWeapons.map((w) => 'WeaponType.${w.name}').join(', ')}],';

    String tradeValueStr = rarity == '05'
      ? '\n  baseTradeValue: $baseTradeValue,'
      : "";

    return '''const CardMasterData(
    id: '$cardId',
    name: '$fullName',
    assetPath: 'assets/cards/$cardId.png',
    rarity: Rarity.${getRarityEnum(rarity).name}, 
    capacity: $capacity,
    maxLevelEvo0HP: 1000,
    maxLevelEvo0Attack: $evo0Atk,
    maxLevelEvo0Defense: $evo0Def,
    accuracy: $acc, 
    evasion: $eva,    
    attacksPerTurn: $formattedAttacks, 
    range: RangeType.${range.name},
    attackPattern: AttackPattern.${attackPattern.name},      
    skillId: '$skillId',
    tags: [$formattedTags],
    weaponType: WeaponType.${weaponType.name},$addWeaponsStr$tradeValueStr
),''';
  }
}

class CardApiService {
  static const String _endpoint =
      'https://card-generator-um75.onrender.com/process';

  static Future<Uint8List> processImage({
    required Uint8List rawBytes,
    required String filename,
    required String alignment,
    required String rarity,
    required String unitCategory,
    required bool overrideEnabled,
    required bool bypassFilter,
    required String intensity,
    required String cardName,
  }) async {
    var request = http.MultipartRequest('POST', Uri.parse(_endpoint));
    request.fields['alignment'] = alignment;
    request.fields['rarity'] = rarity;
    request.fields['unit_category'] = unitCategory;
    request.fields['override_enabled'] = overrideEnabled.toString();
    request.fields['bypass_filter'] = bypassFilter.toString();
    request.fields['intensity'] = intensity;
    request.fields['card_name'] = cardName;

    request.files.add(http.MultipartFile.fromBytes(
      'image',
      rawBytes,
      filename: filename,
      contentType: MediaType('image', 'png'),
    ));

    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      throw Exception('Server returned HTTP ${response.statusCode}');
    }
  }
}


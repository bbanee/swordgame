import 'dart:convert';
import 'dart:io';

const _inputPath = 'assets/data/swords.json';
const _outputPath = 'lib/data/generated/swords_generated.dart';

void main() {
  final input = File(_inputPath);
  if (!input.existsSync()) {
    stderr.writeln('Missing $_inputPath');
    exitCode = 1;
    return;
  }

  final decoded = jsonDecode(input.readAsStringSync());
  if (decoded is! Map<String, dynamic>) {
    stderr.writeln('Invalid sword data: root must be an object.');
    exitCode = 1;
    return;
  }

  final swords = decoded['swords'];
  if (swords is! List) {
    stderr.writeln('Invalid sword data: "swords" must be a list.');
    exitCode = 1;
    return;
  }
  if (swords.length != 100) {
    stderr.writeln('Expected 100 active swords, found ${swords.length}.');
    exitCode = 1;
    return;
  }

  final buffer = StringBuffer()
    ..writeln('// GENERATED CODE - DO NOT MODIFY BY HAND.')
    ..writeln('// Source: $_inputPath')
    ..writeln('// Regenerate with: dart run tool/generate_swords.dart')
    ..writeln()
    ..writeln("import '../../models/sword_data.dart';")
    ..writeln("import '../../enums/element.dart';")
    ..writeln("import '../../enums/skill_effect.dart';")
    ..writeln("import '../../enums/skill_type.dart';")
    ..writeln("import '../../enums/sword_grade.dart';")
    ..writeln()
    ..writeln('const List<SwordData> generatedSwords = [');

  for (final rawSword in swords) {
    final sword = _asMap(rawSword, 'sword');
    final skills = sword['skills'];
    if (skills is! List || skills.isEmpty) {
      throw FormatException('Sword ${sword['id']} must have skills.');
    }

    buffer
      ..writeln('  SwordData(')
      ..writeln('    id: ${_string(sword['id'])},')
      ..writeln('    name: ${_string(sword['name'])},')
      ..writeln('    grade: SwordGrade.${_identifier(sword['grade'])},')
      ..writeln('    element: GameElement.${_identifier(sword['element'])},')
      ..writeln('    baseAtk: ${_int(sword['baseAtk'])},')
      ..writeln('    skills: [');

    for (final rawSkill in skills) {
      final skill = _asMap(rawSkill, 'skill');
      final element = skill['element'];
      buffer
        ..writeln('      SkillData(')
        ..writeln('        name: ${_string(skill['name'])},')
        ..writeln('        multiplier: ${_double(skill['multiplier'])},')
        ..writeln('        procRate: ${_int(skill['procRate'])},')
        ..writeln('        type: SkillType.${_identifier(skill['type'])},')
        ..writeln(
          '        effect: SkillEffect.${_identifier(skill['effect'])},',
        )
        ..writeln('        value: ${_int(skill['value'])},')
        ..writeln('        cooldownTurns: ${_int(skill['cooldownTurns'])},')
        ..writeln(
          '        element: ${element == null ? 'null' : 'GameElement.${_identifier(element)}'},',
        )
        ..writeln('      ),');
    }

    buffer
      ..writeln('    ],')
      ..writeln('  ),');
  }

  buffer.writeln('];');

  final output = File(_outputPath);
  output.parent.createSync(recursive: true);
  output.writeAsStringSync(buffer.toString());
  stdout.writeln(
    'Generated $_outputPath from $_inputPath (${swords.length} swords).',
  );
}

Map<String, dynamic> _asMap(Object? value, String label) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.cast<String, dynamic>();
  throw FormatException('Invalid $label entry.');
}

String _identifier(Object? value) {
  if (value is! String ||
      !RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*$').hasMatch(value)) {
    throw FormatException('Invalid enum identifier: $value');
  }
  return value;
}

String _string(Object? value) {
  if (value is! String) throw FormatException('Expected string, got $value');
  return jsonEncode(value);
}

int _int(Object? value) {
  if (value is int) return value;
  throw FormatException('Expected int, got $value');
}

String _double(Object? value) {
  if (value is int) return '$value.0';
  if (value is double) return value.toString();
  throw FormatException('Expected number, got $value');
}

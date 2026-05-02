// test/test_helpers.dart
//
// Utilitários compartilhados por toda a suite de testes.

import 'dart:convert';
import 'dart:io';

/// Carrega e decodifica um arquivo JSON de `test/fixtures/[path]`.
///
/// Exemplo:
/// ```dart
/// final json = loadFixture('servico.json');
/// final s = Servico.fromJson(json);
/// ```
Map<String, dynamic> loadFixture(String path) {
  final file = File('test/fixtures/$path');
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

/// Carrega e decodifica um arquivo JSON como lista de objetos.
///
/// Exemplo:
/// ```dart
/// final list = loadFixtureList('servicos.json');
/// final servicos = list.map((e) => Servico.fromJson(e)).toList();
/// ```
List<Map<String, dynamic>> loadFixtureList(String path) {
  final file = File('test/fixtures/$path');
  final decoded = jsonDecode(file.readAsStringSync()) as List<dynamic>;
  return decoded.cast<Map<String, dynamic>>();
}

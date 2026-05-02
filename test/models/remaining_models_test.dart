// test/models/remaining_models_test.dart
//
// Testes para DashboardResponse, Especialidade e PerfilAtuacao.

import 'package:flutter_test/flutter_test.dart';
import 'package:medvie/core/models/dashboard_response.dart';
import 'package:medvie/core/models/especialidade.dart';
import 'package:medvie/core/models/perfil_atuacao.dart';
import '../test_helpers.dart';

void main() {
  // ── DashboardResponse ────────────────────────────────────────────────────

  group('DashboardResponse.fromJson', () {
    test('parseia todos os campos da fixture', () {
      final d = DashboardResponse.fromJson(loadFixture('dashboard.json'));

      expect(d.totalBruto, 15000.0);
      expect(d.totalIss, 450.0);
      expect(d.totalIbs, 0.0);
      expect(d.totalCbs, 0.0);
      expect(d.totalLiquidoEstimado, 13500.0);
      expect(d.notasAutorizadas, 3);
      expect(d.notasPendentes, 1);
      expect(d.notasRejeitadas, 0);
      expect(d.metaMensal, 20000.0);
    });

    test('metaMensal aceita null', () {
      final json = {
        'totalBruto': 0.0,
        'totalIss': 0.0,
        'totalIbs': 0.0,
        'totalCbs': 0.0,
        'totalLiquidoEstimado': 0.0,
        'notasAutorizadas': 0,
        'notasPendentes': 0,
        'notasRejeitadas': 0,
      };
      final d = DashboardResponse.fromJson(json);
      expect(d.metaMensal, isNull);
    });

    test('aceita valores inteiros para campos double', () {
      final json = {
        'totalBruto': 1000,
        'totalIss': 30,
        'totalIbs': 0,
        'totalCbs': 0,
        'totalLiquidoEstimado': 970,
        'notasAutorizadas': 2,
        'notasPendentes': 0,
        'notasRejeitadas': 0,
        'metaMensal': 5000,
      };
      final d = DashboardResponse.fromJson(json);

      expect(d.totalBruto, isA<double>());
      expect(d.totalBruto, 1000.0);
      expect(d.metaMensal, 5000.0);
    });

    test('valores zerados parseados corretamente', () {
      final json = {
        'totalBruto': 0,
        'totalIss': 0,
        'totalIbs': 0,
        'totalCbs': 0,
        'totalLiquidoEstimado': 0,
        'notasAutorizadas': 0,
        'notasPendentes': 0,
        'notasRejeitadas': 0,
      };
      final d = DashboardResponse.fromJson(json);

      expect(d.totalBruto, 0.0);
      expect(d.notasAutorizadas, 0);
    });

    test('parseia contadores int corretamente', () {
      final d = DashboardResponse.fromJson(loadFixture('dashboard.json'));

      expect(d.notasAutorizadas, isA<int>());
      expect(d.notasPendentes, isA<int>());
      expect(d.notasRejeitadas, isA<int>());
    });
  });

  // ── Especialidade ────────────────────────────────────────────────────────

  group('Especialidade.fromJson', () {
    test('parseia id e nome da fixture', () {
      final e = Especialidade.fromJson(loadFixture('especialidade.json'));

      expect(e.id, 1);
      expect(e.nome, 'Anestesiologia');
    });

    test('campos ausentes usam defaults (id=0, nome="")', () {
      final e = Especialidade.fromJson({});

      expect(e.id, 0);
      expect(e.nome, '');
    });
  });

  group('Especialidade.toJson', () {
    test('produz mapa com id e nome corretos', () {
      final e = Especialidade(id: 5, nome: 'Cardiologia');
      final out = e.toJson();

      expect(out['id'], 5);
      expect(out['nome'], 'Cardiologia');
    });

    test('round-trip fromJson → toJson → fromJson preserva dados', () {
      final original = Especialidade.fromJson(loadFixture('especialidade.json'));
      final copy = Especialidade.fromJson(original.toJson());

      expect(copy.id, original.id);
      expect(copy.nome, original.nome);
    });
  });

  group('Especialidade.operator ==', () {
    test('igualdade baseada no id, ignora nome', () {
      final a = Especialidade(id: 1, nome: 'Anestesiologia');
      final b = Especialidade(id: 1, nome: 'Nome Diferente');
      expect(a == b, true);
    });

    test('ids diferentes são desiguais', () {
      final a = Especialidade(id: 1, nome: 'A');
      final c = Especialidade(id: 2, nome: 'A');
      expect(a == c, false);
    });

    test('hashCode igual para mesmo id', () {
      final a = Especialidade(id: 7, nome: 'X');
      final b = Especialidade(id: 7, nome: 'Y');
      expect(a.hashCode, b.hashCode);
    });

    test('hashCode diferente para ids distintos', () {
      final a = Especialidade(id: 1, nome: 'X');
      final b = Especialidade(id: 2, nome: 'X');
      expect(a.hashCode, isNot(b.hashCode));
    });
  });

  // ── PerfilAtuacao ────────────────────────────────────────────────────────

  group('PerfilAtuacao.fromValue', () {
    test('reconhece todos os valores inteiros', () {
      expect(PerfilAtuacao.fromValue(1), PerfilAtuacao.medicoClinico);
      expect(PerfilAtuacao.fromValue(2), PerfilAtuacao.procedimentalistaAmbulatorial);
      expect(PerfilAtuacao.fromValue(3), PerfilAtuacao.plantonistaHospitalar);
      expect(PerfilAtuacao.fromValue(4), PerfilAtuacao.cirurgiao);
    });

    test('valor desconhecido retorna medicoClinico', () {
      expect(PerfilAtuacao.fromValue(0), PerfilAtuacao.medicoClinico);
      expect(PerfilAtuacao.fromValue(99), PerfilAtuacao.medicoClinico);
    });
  });

  group('PerfilAtuacao.fromName', () {
    test('reconhece nomes em PascalCase do backend', () {
      expect(PerfilAtuacao.fromName('MedicoClinico'), PerfilAtuacao.medicoClinico);
      expect(PerfilAtuacao.fromName('ProcedimentalistaAmbulatorial'), PerfilAtuacao.procedimentalistaAmbulatorial);
      expect(PerfilAtuacao.fromName('PlantonistaHospitalar'), PerfilAtuacao.plantonistaHospitalar);
      expect(PerfilAtuacao.fromName('Cirurgiao'), PerfilAtuacao.cirurgiao);
    });

    test('nome desconhecido retorna medicoClinico', () {
      expect(PerfilAtuacao.fromName('Invalido'), PerfilAtuacao.medicoClinico);
      expect(PerfilAtuacao.fromName(''), PerfilAtuacao.medicoClinico);
    });
  });

  group('PerfilAtuacao.fromJson', () {
    test('aceita int diretamente', () {
      expect(PerfilAtuacao.fromJson(1), PerfilAtuacao.medicoClinico);
      expect(PerfilAtuacao.fromJson(2), PerfilAtuacao.procedimentalistaAmbulatorial);
      expect(PerfilAtuacao.fromJson(3), PerfilAtuacao.plantonistaHospitalar);
      expect(PerfilAtuacao.fromJson(4), PerfilAtuacao.cirurgiao);
    });

    test('aceita string numérica', () {
      expect(PerfilAtuacao.fromJson('1'), PerfilAtuacao.medicoClinico);
      expect(PerfilAtuacao.fromJson('3'), PerfilAtuacao.plantonistaHospitalar);
    });

    test('aceita string nome do backend', () {
      expect(PerfilAtuacao.fromJson('Cirurgiao'), PerfilAtuacao.cirurgiao);
      expect(PerfilAtuacao.fromJson('MedicoClinico'), PerfilAtuacao.medicoClinico);
    });

    test('nulo retorna medicoClinico', () {
      expect(PerfilAtuacao.fromJson(null), PerfilAtuacao.medicoClinico);
    });

    test('tipo desconhecido retorna medicoClinico', () {
      expect(PerfilAtuacao.fromJson(3.14), PerfilAtuacao.medicoClinico);
    });
  });

  group('PerfilAtuacao.value', () {
    test('cada enum tem valor inteiro correto', () {
      expect(PerfilAtuacao.medicoClinico.value, 1);
      expect(PerfilAtuacao.procedimentalistaAmbulatorial.value, 2);
      expect(PerfilAtuacao.plantonistaHospitalar.value, 3);
      expect(PerfilAtuacao.cirurgiao.value, 4);
    });
  });
}

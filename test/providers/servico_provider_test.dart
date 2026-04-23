// test/providers/servico_provider_test.dart

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:medvie/core/models/servico.dart';
import 'package:medvie/core/providers/servico_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

int _idCounter = 0;

Servico _buildServico({DateTime? data}) => Servico(
      id: 'test-id-${_idCounter++}',
      tipo: TipoServico.plantao,
      data: data ?? DateTime(2026, 4, 15),
      tomadorCnpj: '00.000.000/0001-00',
      tomadorNome: 'Hospital Teste',
      valor: 1000.0,
      status: StatusServico.pendente,
    );

String _encodeServicos(List<Servico> servicos) =>
    jsonEncode(servicos.map((s) => s.toJson()).toList());

// ─────────────────────────────────────────────────────────────────────────────
// Testes
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    _idCounter = 0;
  });

  // 1 ─ estado inicial
  test('estado inicial — servicos vazio, carregando false', () {
    SharedPreferences.setMockInitialValues({});
    final provider = ServicoProvider();

    expect(provider.servicos, isEmpty);
    expect(provider.carregando, false);
  });

  // 2 ─ carregar() com prefs vazio
  test('carregar() com prefs vazio → servicos permanece vazio', () async {
    SharedPreferences.setMockInitialValues({});
    final provider = ServicoProvider();

    await provider.carregar();

    expect(provider.servicos, isEmpty);
    expect(provider.carregando, false);
  });

  // 3 ─ carregar() com 3 serviços persistidos
  test('carregar() com 3 serviços em prefs → servicos.length == 3', () async {
    final fixtures = [
      _buildServico(),
      _buildServico(),
      _buildServico(),
    ];
    SharedPreferences.setMockInitialValues({
      'servicos': _encodeServicos(fixtures),
    });
    final provider = ServicoProvider();

    await provider.carregar();

    expect(provider.servicos.length, 3);
    expect(provider.carregando, false);
  });

  // 4 ─ filtrarPorDia
  test('filtrarPorDia → servicosFiltrados contém só serviços do dia', () async {
    final dia = DateTime(2026, 4, 10);
    final outroDia = DateTime(2026, 4, 20);

    SharedPreferences.setMockInitialValues({
      'servicos': _encodeServicos([
        _buildServico(data: dia),
        _buildServico(data: dia),
        _buildServico(data: outroDia),
      ]),
    });
    final provider = ServicoProvider();
    await provider.carregar();

    provider.filtrarPorDia(dia);

    expect(provider.servicosFiltrados.length, 2);
    expect(
      provider.servicosFiltrados.every(
        (s) =>
            s.data.year == dia.year &&
            s.data.month == dia.month &&
            s.data.day == dia.day,
      ),
      isTrue,
    );
  });

  // 5 ─ limparFiltro
  test('limparFiltro → servicosFiltrados volta a == servicos', () async {
    final dia = DateTime(2026, 4, 10);

    SharedPreferences.setMockInitialValues({
      'servicos': _encodeServicos([
        _buildServico(data: dia),
        _buildServico(data: DateTime(2026, 4, 11)),
        _buildServico(data: DateTime(2026, 4, 12)),
      ]),
    });
    final provider = ServicoProvider();
    await provider.carregar();

    provider.filtrarPorDia(dia);
    expect(provider.servicosFiltrados.length, 1);

    provider.limparFiltro();
    expect(provider.servicosFiltrados.length, provider.servicos.length);
  });

  // 6 ─ notifyListeners é chamado (listener conta as notificações)
  test('carregar() notifica listeners ao iniciar e ao concluir', () async {
    SharedPreferences.setMockInitialValues({});
    final provider = ServicoProvider();
    int notificacoes = 0;
    provider.addListener(() => notificacoes++);

    await provider.carregar();

    // Notifica 2x: ao setar _carregando=true e ao finalizar _carregando=false
    expect(notificacoes, 2);
  });
}

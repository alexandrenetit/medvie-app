// integration_test/helpers/fakes.dart
//
// Providers falsos usados nos testes de integração.
// Estendem ChangeNotifier e implementam a interface via noSuchMethod,
// expondo apenas o estado necessário para cada cenário de teste.

import 'package:flutter/material.dart';

import 'package:medvie/core/models/medico.dart';
import 'package:medvie/core/models/nota_fiscal.dart';
import 'package:medvie/core/models/perfil_atuacao.dart';
import 'package:medvie/core/models/servico.dart';
import 'package:medvie/core/providers/nota_fiscal_provider.dart';
import 'package:medvie/core/providers/onboarding_provider.dart';
import 'package:medvie/core/providers/relatorio_anual_provider.dart';
import 'package:medvie/core/providers/servico_provider.dart';
import 'package:medvie/core/providers/simulador_provider.dart';
import 'package:medvie/core/services/medvie_api_service.dart';

// ── OnboardingProvider fake ───────────────────────────────────────────────────

class FakeOnboarding extends ChangeNotifier implements OnboardingProvider {
  @override
  String? cpfDigitsSalvo;
  @override
  // ignore: overridden_fields
  Medico? medico;
  @override
  Map<String, String> cnpjProprioIdsPorCnpj = {};
  @override
  String cnpjAtual = '';
  @override
  bool restaurando = false;
  @override
  bool onboardingCompletoFlag = false;
  @override
  int stepAtual = 0;
  @override
  PerfilAtuacao perfilAtuacao = PerfilAtuacao.medicoClinico;
  @override
  String nome = '';
  @override
  String cpf = '';
  @override
  String crm = '';
  @override
  String ufCrm = '';
  @override
  String razaoSocialAtual = '';
  @override
  String municipioAtual = '';
  @override
  String ufAtual = '';
  @override
  String inscricaoMunicipalAtual = '';
  @override
  bool buscandoCnpj = false;
  @override
  bool erroCnpjApiDown = false;
  @override
  bool salvandoMedico = false;
  @override
  bool salvandoCnpj = false;
  @override
  bool salvandoTomadores = false;
  @override
  String email = '';
  @override
  String telefone = '';
  @override
  bool get mostrarStep3 => false;
  @override
  bool get carregandoTomador => false;
  @override
  bool get carregandoCnpjProprio => false;
  @override
  String get razaoSocialPropria => razaoSocialAtual;

  /// true  → loginERestaurar() completa com sucesso
  /// false → loginERestaurar() lança exceção
  bool loginOk;

  FakeOnboarding({
    this.cpfDigitsSalvo,
    this.loginOk = true,
    this.restaurando = false,
    this.onboardingCompletoFlag = false,
  });

  @override
  Future<void> loginERestaurar(String cpf, String senha) async {
    if (!loginOk) throw Exception('Credenciais inválidas');
    onboardingCompletoFlag = true;
    notifyListeners();
  }

  @override
  Future<void> carregarMedico() async {}

  @override
  void resetarSessao() {
    cpfDigitsSalvo = null;
    medico = null;
    onboardingCompletoFlag = false;
    notifyListeners();
  }

  @override
  Future<void> restaurarProgressoDoBackend(String medicoId) async {}

  // Retorna uma instância real (sem credenciais) para satisfazer DashboardProvider.
  // carregar() retorna early quando cnpjAtual está vazio.
  @override
  MedvieApiService get api => MedvieApiService();

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// ── ServicoProvider fake ──────────────────────────────────────────────────────

class FakeServico extends ChangeNotifier implements ServicoProvider {
  @override
  int get countPendentesNf => 0;
  @override
  int get totalConfirmados => 0;
  @override
  int get totalPlanejados => 0;
  @override
  bool get carregando => false;
  @override
  bool get temMais => false;
  @override
  bool get carregandoMais => false;
  @override
  double get totalBruto => 0.0;
  @override
  List<Servico> get servicos => const [];
  @override
  List<Servico> get servicosFiltrados => const [];
  @override
  List<Servico> get confirmados => const [];
  @override
  List<Servico> get planejados => const [];
  @override
  List<Servico> get pendentesDEmissao => const [];
  @override
  List<Servico> doMes(int ano, int mes) => const [];
  @override
  double totalBrutoDoMes(int ano, int mes) => 0.0;

  @override
  Future<void> carregar({String? cnpjProprioId}) async {}
  @override
  Future<void> sincronizarStatusPorTempo() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// ── NotaFiscalProvider fake ───────────────────────────────────────────────────

class FakeNotaFiscal extends ChangeNotifier implements NotaFiscalProvider {
  @override
  void conectarSse() {}
  @override
  void desconectarSse() {}
  @override
  bool get carregando => false;
  @override
  List<NotaFiscal> get notas => const [];
  @override
  List<NotaFiscal> notasDoMes(int ano, int mes) => const [];
  @override
  double totalAutorizadoDoMes(int ano, int mes) => 0.0;
  @override
  int countAutorizadasDoMes(int ano, int mes) => 0;
  @override
  List<NotaFiscal> porStatus(StatusNota status) => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// ── RelatorioAnualProvider fake ───────────────────────────────────────────────

class FakeRelatorioAnual extends ChangeNotifier
    implements RelatorioAnualProvider {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// ── SimuladorProvider fake ────────────────────────────────────────────────────

class FakeSimulador extends ChangeNotifier implements SimuladorProvider {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:medvie/core/models/servico.dart';
import 'package:medvie/core/providers/servico_provider.dart';
import 'package:medvie/features/syncview/widgets/servico_list.dart';

/// Provider falso que expõe uma lista fixa de serviços para a ServicoList.
class _FakeServicoProvider extends ServicoProvider {
  _FakeServicoProvider(this._lista);
  final List<Servico> _lista;

  @override
  List<Servico> get servicosFiltrados => _lista;
  @override
  bool get carregandoMais => false;
  @override
  bool get temMais => false;
}

Servico _servicoPf({String status = 'Incompleto'}) =>
    Servico.fromJson(<String, dynamic>{
      'id': 'serv-pf',
      'tipoServico': 'Consulta',
      'competencia': '2026-06-09',
      'tomadorNome': 'Julia M. Ramos',
      'tomadorCnpj': null,
      'tomadorTipo': 'CPF',
      'tomadorDocumentoMascarado': '***.***.***-09',
      'tomadorEnderecoFiscalStatus': status,
      'valor': 500.0,
      'status': 'pendente',
    });

Servico _servicoCnpj() => Servico.fromJson(<String, dynamic>{
      'id': 'serv-cnpj',
      'tipoServico': 'PlantaoClinico',
      'competencia': '2026-06-01',
      'tomadorNome': 'Hospital Sao Lucas',
      'tomadorCnpj': '12.345.678/0001-90',
      'valor': 1200.0,
      'status': 'nfEmitida',
    });

Future<void> _pump(WidgetTester tester, List<Servico> servicos) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<ServicoProvider>.value(
      value: _FakeServicoProvider(servicos),
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: ServicoList()),
        ),
      ),
    ),
  );
}

void main() {
  group('ServicoList — linhas PF (T050/SC-005)', () {
    testWidgets('PF mostra nome, documento mascarado e chip End. incompleto', (
      tester,
    ) async {
      await _pump(tester, [_servicoPf()]);

      expect(find.text('Julia M. Ramos'), findsOneWidget);
      expect(find.textContaining('***.***.***-09'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('servico-fiscal-pendente')),
        findsOneWidget,
      );
      expect(find.text('End. incompleto'), findsOneWidget);
    });

    testWidgets('PF com endereço completo não mostra chip', (tester) async {
      await _pump(tester, [_servicoPf(status: 'Completo')]);
      expect(
        find.byKey(const ValueKey('servico-fiscal-pendente')),
        findsNothing,
      );
    });

    testWidgets('CNPJ com tomadorCnpj null em PF não quebra a lista', (
      tester,
    ) async {
      // Mistura PF (cnpj null) + CNPJ — renderiza sem exceção (SC-005).
      await _pump(tester, [_servicoPf(), _servicoCnpj()]);
      expect(find.text('Julia M. Ramos'), findsOneWidget);
      expect(find.text('Hospital Sao Lucas'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('linha CNPJ não exibe documento mascarado nem chip', (
      tester,
    ) async {
      await _pump(tester, [_servicoCnpj()]);
      expect(find.textContaining('***.***'), findsNothing);
      expect(
        find.byKey(const ValueKey('servico-fiscal-pendente')),
        findsNothing,
      );
    });
  });
}

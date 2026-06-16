import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:medvie/core/models/medico.dart';
import 'package:medvie/features/syncview/widgets/tomador_selector_sheet.dart';

Tomador _tomador({
  required String id,
  required String razaoSocial,
  required String cnpj,
  bool retemIss = false,
  bool retemIrrf = false,
}) =>
    Tomador(
      id: id,
      cnpj: cnpj,
      razaoSocial: razaoSocial,
      municipio: 'São Paulo',
      uf: 'SP',
      retemIss: retemIss,
      retemIrrf: retemIrrf,
    );

final _tomadores = <Tomador>[
  _tomador(
    id: 'tom-1',
    razaoSocial: 'Hospital Santa Casa',
    cnpj: '11222333000181',
    retemIss: true,
  ),
  _tomador(
    id: 'tom-2',
    razaoSocial: 'Clínica Boa Saúde',
    cnpj: '44555666000172',
    retemIrrf: true,
  ),
  _tomador(
    id: 'tom-3',
    razaoSocial: 'Convênio Vida Plena',
    cnpj: '77888999000163',
  ),
];

/// Monta um botão que abre o sheet e guarda o tomador resolvido em [out].
/// `out[0]` distingue "não retornou ainda" de "retornou null".
Future<void> _pumpAbridor(
  WidgetTester tester, {
  required List<Tomador> tomadores,
  String? selecionadoId,
  VoidCallback? onCadastrar,
  required List<Tomador?> out,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () async {
                final r = await showTomadorSelectorSheet(
                  context: context,
                  tomadores: tomadores,
                  selecionadoId: selecionadoId,
                  onCadastrar: onCadastrar,
                );
                out
                  ..clear()
                  ..add(r);
              },
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _abrir(WidgetTester tester) async {
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

void main() {
  group('TomadorResumoCard', () {
    testWidgets('vazio mostra "Escolher" e estado vazio', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TomadorResumoCard(
              selecionado: null,
              totalCadastrados: 0,
              onTrocar: () {},
            ),
          ),
        ),
      );

      expect(find.text('Nenhum tomador selecionado'), findsOneWidget);
      expect(find.text('Escolher'), findsOneWidget);
      expect(find.text('Trocar'), findsNothing);
    });

    testWidgets('selecionado mostra razão, CNPJ mascarado e "Trocar"',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TomadorResumoCard(
              selecionado: _tomadores.first,
              totalCadastrados: 3,
              onTrocar: () {},
            ),
          ),
        ),
      );

      expect(find.text('Hospital Santa Casa'), findsOneWidget);
      expect(find.text('CNPJ 11.222.333/0001-81'), findsOneWidget);
      expect(find.text('Trocar'), findsOneWidget);
      expect(find.text('3 tomadores cadastrados'), findsOneWidget);
      expect(find.text('Retém ISS'), findsOneWidget);
    });
  });

  group('showTomadorSelectorSheet', () {
    testWidgets('abre e lista todos os tomadores', (tester) async {
      final out = <Tomador?>[];
      await _pumpAbridor(tester, tomadores: _tomadores, out: out);
      await _abrir(tester);

      expect(find.text('Selecionar tomador'), findsOneWidget);
      expect(find.text('Hospital Santa Casa'), findsOneWidget);
      expect(find.text('Clínica Boa Saúde'), findsOneWidget);
      expect(find.text('Convênio Vida Plena'), findsOneWidget);
    });

    testWidgets('busca filtra por razão social', (tester) async {
      final out = <Tomador?>[];
      await _pumpAbridor(tester, tomadores: _tomadores, out: out);
      await _abrir(tester);

      await tester.enterText(find.byType(TextField), 'clínica');
      await tester.pumpAndSettle();

      expect(find.text('Clínica Boa Saúde'), findsOneWidget);
      expect(find.text('Hospital Santa Casa'), findsNothing);
      expect(find.text('Convênio Vida Plena'), findsNothing);
    });

    testWidgets('busca filtra por CNPJ ignorando máscara', (tester) async {
      final out = <Tomador?>[];
      await _pumpAbridor(tester, tomadores: _tomadores, out: out);
      await _abrir(tester);

      // Trecho do CNPJ do segundo tomador, com pontuação que deve ser ignorada.
      await tester.enterText(find.byType(TextField), '44.555');
      await tester.pumpAndSettle();

      expect(find.text('Clínica Boa Saúde'), findsOneWidget);
      expect(find.text('Hospital Santa Casa'), findsNothing);
    });

    testWidgets('seleção retorna o tomador e fecha o sheet', (tester) async {
      final out = <Tomador?>[];
      await _pumpAbridor(tester, tomadores: _tomadores, out: out);
      await _abrir(tester);

      await tester.tap(find.text('Convênio Vida Plena'));
      await tester.pumpAndSettle();

      expect(find.text('Selecionar tomador'), findsNothing);
      expect(out.single?.id, 'tom-3');
    });

    testWidgets('busca sem match mostra estado vazio', (tester) async {
      final out = <Tomador?>[];
      await _pumpAbridor(tester, tomadores: _tomadores, out: out);
      await _abrir(tester);

      await tester.enterText(find.byType(TextField), 'inexistente xyz');
      await tester.pumpAndSettle();

      expect(find.textContaining('Nenhum tomador encontrado'), findsOneWidget);
      expect(find.text('Hospital Santa Casa'), findsNothing);
    });

    testWidgets('sem tomadores mostra estado vazio total com CTA', (tester) async {
      final out = <Tomador?>[];
      var cadastrouTocado = false;
      await _pumpAbridor(
        tester,
        tomadores: const <Tomador>[],
        onCadastrar: () => cadastrouTocado = true,
        out: out,
      );
      await _abrir(tester);

      expect(find.text('Nenhum tomador cadastrado'), findsOneWidget);
      // Sem campo de busca no estado vazio total.
      expect(find.byType(TextField), findsNothing);

      await tester.tap(find.text('Cadastrar primeiro tomador'));
      await tester.pumpAndSettle();
      expect(cadastrouTocado, isTrue);
    });

    testWidgets('rodapé "Cadastrar novo tomador" oculto sem onCadastrar',
        (tester) async {
      final out = <Tomador?>[];
      await _pumpAbridor(tester, tomadores: _tomadores, out: out);
      await _abrir(tester);
      expect(find.text('Cadastrar novo tomador'), findsNothing);
    });

    testWidgets('rodapé "Cadastrar novo tomador" visível com onCadastrar',
        (tester) async {
      final out = <Tomador?>[];
      await _pumpAbridor(
        tester,
        tomadores: _tomadores,
        onCadastrar: () {},
        out: out,
      );
      await _abrir(tester);
      expect(find.text('Cadastrar novo tomador'), findsOneWidget);
    });
  });
}

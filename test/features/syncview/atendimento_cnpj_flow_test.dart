// test/features/syncview/atendimento_cnpj_flow_test.dart
//
// T4.7 — widget tests para AtendimentoCnpjFlow.
// Cobre: CTA gatekeeping, visibilidade horário (condicional Plantão), troca tipo.
//
// T6.4 — widget tests para o toggle "Emitir NFS-e agora?" (F6).
// Cobre: hint dinâmico 3 estados, CTA label/cor reativos, gate do toggle.

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:medvie/core/models/medico.dart';
import 'package:medvie/core/providers/nota_fiscal_provider.dart';
import 'package:medvie/core/providers/onboarding_provider.dart';
import 'package:medvie/core/providers/servico_provider.dart';
import 'package:medvie/core/services/medvie_api_service.dart';
import 'package:medvie/features/syncview/widgets/atendimento_cnpj_flow.dart';

class _MockApi extends Mock implements MedvieApiService {}

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

Tomador _tomador() => Tomador(
      id: 'tom-1',
      cnpj: '11222333000181',
      razaoSocial: 'Hospital Santa Casa',
      municipio: 'São Paulo',
      uf: 'SP',
    );

Future<void> _pump(
  WidgetTester tester, {
  List<Tomador> tomadores = const [],
  VoidCallback? onConcluido,
}) async {
  SharedPreferences.setMockInitialValues({});
  final mockApi = _MockApi();
  final mockStorage = _MockSecureStorage();
  when(() => mockStorage.read(key: any(named: 'key')))
      .thenAnswer((_) async => null);
  when(() => mockStorage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      )).thenAnswer((_) async {});
  when(() => mockStorage.delete(key: any(named: 'key')))
      .thenAnswer((_) async {});

  final onboarding = OnboardingProvider(
    api: mockApi,
    secureStorage: mockStorage,
  )..tomadoresAtual = List<Tomador>.from(tomadores);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<OnboardingProvider>.value(value: onboarding),
        ChangeNotifierProvider<ServicoProvider>(
          create: (_) => ServicoProvider(api: mockApi),
        ),
        ChangeNotifierProvider<NotaFiscalProvider>(
          create: (_) => NotaFiscalProvider(mockApi),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AtendimentoCnpjFlow(
              cnpjProprioId: 'guid-cnpj',
              cnpjEmissor: '11222333000181',
              onConcluido: onConcluido ?? () {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('AtendimentoCnpjFlow — gate CTA (T4.7)', () {
    testWidgets('CTA desabilitado sem tomador e sem valor', (tester) async {
      await _pump(tester);

      final btn = tester.widget<ElevatedButton>(
        find.byKey(const ValueKey('cnpj-cta-registrar')),
      );
      expect(btn.onPressed, isNull);
    });

    testWidgets('CTA desabilitado sem valor mesmo com tomador no provider',
        (tester) async {
      await _pump(tester, tomadores: [_tomador()]);

      // Sem tomador selecionado (nenhum tap no card), CTA permanece desabilitado.
      final btn = tester.widget<ElevatedButton>(
        find.byKey(const ValueKey('cnpj-cta-registrar')),
      );
      expect(btn.onPressed, isNull);
    });

    testWidgets('CTA exibe texto "Registrar serviço"', (tester) async {
      await _pump(tester);
      expect(find.text('Registrar serviço'), findsOneWidget);
    });
  });

  group('AtendimentoCnpjFlow — tipo serviço e horário (T4.7)', () {
    testWidgets('tipo Plantão (default) revela campos de horário', (tester) async {
      await _pump(tester);

      // Plantão é o default — campos Início e Fim devem aparecer.
      expect(find.text('Início'), findsOneWidget);
      expect(find.text('Fim'), findsOneWidget);
    });

    testWidgets('trocar tipo para Procedimento Cirúrgico oculta horário',
        (tester) async {
      await _pump(tester);

      // Confirma horário visível com Plantão.
      expect(find.text('Início'), findsOneWidget);

      // Tap no card de Procedimento Cirúrgico.
      await tester.tap(
        find.byKey(const ValueKey('cnpj-servico-procedimentoCirurgico')),
      );
      await tester.pumpAndSettle();

      // Horário deve desaparecer.
      expect(find.text('Início'), findsNothing);
      expect(find.text('Fim'), findsNothing);
    });

    testWidgets('voltar para Plantão revela horário novamente', (tester) async {
      await _pump(tester);

      // Troca para outro tipo.
      await tester.tap(
        find.byKey(const ValueKey('cnpj-servico-outros')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Início'), findsNothing);

      // Volta para Plantão.
      await tester.tap(
        find.byKey(const ValueKey('cnpj-servico-plantao')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Início'), findsOneWidget);
    });

    testWidgets('troca de tipo atualiza descrição padrão', (tester) async {
      await _pump(tester);

      // Default: descrição = label do Plantão.
      expect(find.text('Plantão'), findsWidgets);

      // Troca para Ato Anestésico.
      await tester.tap(
        find.byKey(const ValueKey('cnpj-servico-atoAnestesico')),
      );
      await tester.pumpAndSettle();

      // Descrição deve ter sido atualizada (campo texto contém o novo label).
      expect(
        find.descendant(
          of: find.byType(TextField),
          matching: find.text('Ato Anestésico'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('chips de status pagamento A receber e Já recebi visíveis',
        (tester) async {
      await _pump(tester);
      expect(find.text('A receber'), findsOneWidget);
      expect(find.text('Já recebi'), findsOneWidget);
    });

    testWidgets('tap em "Já recebi" não quebra a UI', (tester) async {
      await _pump(tester);

      await tester.tap(find.byKey(const ValueKey('cnpj-status-pago')));
      await tester.pumpAndSettle();

      expect(find.text('Já recebi'), findsOneWidget);
      expect(find.text('A receber'), findsOneWidget);
    });
  });

  group('AtendimentoCnpjFlow — toggle "Emitir NFS-e agora?" (T6.4)', () {
    testWidgets('label e hint inicial visíveis (gate sem tomador/valor)',
        (tester) async {
      await _pump(tester);

      expect(find.text('Emitir NFS-e agora?'), findsOneWidget);
      expect(
        find.text('Selecione tomador e valor para emitir'),
        findsOneWidget,
      );
    });

    testWidgets('CTA exibe "Registrar serviço" no estado default (toggle off)',
        (tester) async {
      await _pump(tester);
      expect(find.text('Registrar serviço'), findsOneWidget);
      expect(find.text('Confirmar e emitir NFS-e'), findsNothing);
    });

    testWidgets('toggle desabilitado sem tomador/valor: tap não muda hint',
        (tester) async {
      await _pump(tester);

      // Tap no knob — gate _podeEmitir=false → setState não dispara.
      await tester.tap(find.byKey(const ValueKey('cnpj-toggle-emitir-knob')));
      await tester.pumpAndSettle();

      // Hint permanece no estado gate.
      expect(
        find.text('Selecione tomador e valor para emitir'),
        findsOneWidget,
      );
      // CTA não muda.
      expect(find.text('Registrar serviço'), findsOneWidget);
    });
  });

  group('AtendimentoCnpjFlow — helper text CTA (T8.2)', () {
    testWidgets('helper "Selecione tomador e informe o valor" visível no '
        'estado inicial (sem tomador, sem valor)', (tester) async {
      await _pump(tester);

      expect(find.byKey(const ValueKey('cnpj-cta-helper')), findsOneWidget);
      expect(
        find.text('Selecione tomador e informe o valor'),
        findsOneWidget,
      );
    });

    testWidgets('helper permanece visível com tomador no provider mas '
        'sem seleção e sem valor', (tester) async {
      // Tomador existe no provider mas o usuário não selecionou.
      // Helper ainda deve aparecer (gate: valor<=0).
      await _pump(tester, tomadores: [_tomador()]);

      expect(find.byKey(const ValueKey('cnpj-cta-helper')), findsOneWidget);
    });
  });
}

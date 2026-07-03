// lib/core/models/dashboard_response.dart

class DashboardResponse {
  final double totalBruto;
  final double totalIss;
  final double totalIbs;
  final double totalCbs;
  final double totalLiquidoEstimado;
  final int notasAutorizadas;
  final int notasPendentes;
  final int notasRejeitadas;

  /// Rótulo do mês da consulta em pt-BR minúsculo (ex.: "julho"), pronto do
  /// backend. A UI apenas aplica caixa/estilo — nunca deriva o mês do relógio
  /// local. Vazio quando ausente (backend legado) → título sem "· MÊS".
  final String mesReferenciaLabel;

  final double? metaMensal;
  final CargaTributaria? carga;

  /// Agregados do ciclo do dinheiro do mês (recebido / a receber / aguardando
  /// emissão). Nullable: backend legado sem o campo `pipeline` desserializa como
  /// null — a UI degrada para estado vazio sem quebrar. Fonte única: backend.
  final PipelineResumo? pipeline;

  /// Comparativo do líquido pós-impostos do mês corrente contra o anterior.
  /// Nullable quando não há base de comparação (mês atual sem carga ou mês
  /// anterior sem serviços) — a UI oculta o chip. Fonte única: backend.
  final ComparativoMensal? comparativo;

  const DashboardResponse({
    required this.totalBruto,
    required this.totalIss,
    required this.totalIbs,
    required this.totalCbs,
    required this.totalLiquidoEstimado,
    required this.notasAutorizadas,
    required this.notasPendentes,
    required this.notasRejeitadas,
    required this.mesReferenciaLabel,
    this.metaMensal,
    this.carga,
    this.pipeline,
    this.comparativo,
  });

  factory DashboardResponse.fromJson(Map<String, dynamic> json) =>
      DashboardResponse(
        totalBruto: (json['totalBruto'] as num).toDouble(),
        totalIss: (json['totalIss'] as num).toDouble(),
        totalIbs: (json['totalIbs'] as num).toDouble(),
        totalCbs: (json['totalCbs'] as num).toDouble(),
        totalLiquidoEstimado:
            (json['totalLiquidoEstimado'] as num).toDouble(),
        notasAutorizadas: json['notasAutorizadas'] as int,
        notasPendentes: json['notasPendentes'] as int,
        notasRejeitadas: json['notasRejeitadas'] as int,
        mesReferenciaLabel: json['mesReferenciaLabel'] as String? ?? '',
        metaMensal: (json['metaMensal'] as num?)?.toDouble(),
        carga: json['carga'] == null
            ? null
            : CargaTributaria.fromJson(json['carga'] as Map<String, dynamic>),
        pipeline: json['pipeline'] is Map<String, dynamic>
            ? PipelineResumo.fromJson(json['pipeline'] as Map<String, dynamic>)
            : null,
        comparativo: json['comparativo'] is Map<String, dynamic>
            ? ComparativoMensal.fromJson(
                json['comparativo'] as Map<String, dynamic>)
            : null,
      );
}

/// Comparativo do líquido pós-impostos (o número grande do herói) do mês
/// corrente contra o mês anterior. Fonte única: backend — o app nunca calcula.
class ComparativoMensal {
  /// Líquido pós-impostos do mês anterior (referência da comparação).
  final double liquidoMesAnterior;

  /// Variação em FRAÇÃO: 0.0833 = +8,33%; negativa = queda. Já vem pronta.
  final double variacaoPercentual;

  /// Nome do mês de referência em pt-BR minúsculo (ex.: "junho"), pronto do
  /// backend. O mês comparado é a competência da consulta (mês − 1), não o
  /// relógio do cliente — a UI exibe cru, sem derivar mês localmente. Vazio
  /// quando ausente (backend legado) → a UI omite o trecho "vs mês".
  final String mesAnteriorLabel;

  const ComparativoMensal({
    required this.liquidoMesAnterior,
    required this.variacaoPercentual,
    required this.mesAnteriorLabel,
  });

  factory ComparativoMensal.fromJson(Map<String, dynamic> json) =>
      ComparativoMensal(
        liquidoMesAnterior:
            (json['liquidoMesAnterior'] as num?)?.toDouble() ?? 0,
        variacaoPercentual:
            (json['variacaoPercentual'] as num?)?.toDouble() ?? 0,
        mesAnteriorLabel: json['mesAnteriorLabel'] as String? ?? '',
      );
}

/// Carga tributária mensal estimada (impostos próprios do regime), distinta do
/// líquido pós-retenções na fonte. Fonte única: backend (CargaTributariaCalculator).
class CargaTributaria {
  final double irpj;
  final double adicionalIrpj;
  final double csll;
  final double pis;
  final double cofins;
  final double iss;
  final double ibs;
  final double cbs;
  final double totalImpostos;
  final double aliquotaEfetiva;
  final double liquidoPosImpostos;
  final String regimeDescricao;

  const CargaTributaria({
    required this.irpj,
    required this.adicionalIrpj,
    required this.csll,
    required this.pis,
    required this.cofins,
    required this.iss,
    required this.ibs,
    required this.cbs,
    required this.totalImpostos,
    required this.aliquotaEfetiva,
    required this.liquidoPosImpostos,
    required this.regimeDescricao,
  });

  factory CargaTributaria.fromJson(Map<String, dynamic> json) => CargaTributaria(
        irpj: (json['irpj'] as num?)?.toDouble() ?? 0,
        adicionalIrpj: (json['adicionalIrpj'] as num?)?.toDouble() ?? 0,
        csll: (json['csll'] as num?)?.toDouble() ?? 0,
        pis: (json['pis'] as num?)?.toDouble() ?? 0,
        cofins: (json['cofins'] as num?)?.toDouble() ?? 0,
        iss: (json['iss'] as num?)?.toDouble() ?? 0,
        ibs: (json['ibs'] as num?)?.toDouble() ?? 0,
        cbs: (json['cbs'] as num?)?.toDouble() ?? 0,
        totalImpostos: (json['totalImpostos'] as num?)?.toDouble() ?? 0,
        aliquotaEfetiva: (json['aliquotaEfetiva'] as num?)?.toDouble() ?? 0,
        liquidoPosImpostos: (json['liquidoPosImpostos'] as num?)?.toDouble() ?? 0,
        regimeDescricao: json['regimeDescricao'] as String? ?? '',
      );
}

/// Um estágio do pipeline financeiro do mês: valor agregado + quantidade de
/// itens. Valores vêm prontos do backend (decimal); o app nunca calcula.
class PipelineSegmento {
  final double valor;
  final int quantidade;

  const PipelineSegmento({required this.valor, required this.quantidade});

  static const PipelineSegmento zero = PipelineSegmento(valor: 0, quantidade: 0);

  factory PipelineSegmento.fromJson(Map<String, dynamic> json) =>
      PipelineSegmento(
        valor: (json['valor'] as num?)?.toDouble() ?? 0,
        quantidade: (json['quantidade'] as num?)?.toInt() ?? 0,
      );
}

/// Ciclo do dinheiro do mês, agregado pelo backend:
/// - [recebido]: NFs pagas/conciliadas.
/// - [aReceber]: NFs autorizadas ainda não pagas (com [dataPrevista] opcional).
/// - [aguardandoEmissao]: atendimentos capturados ainda não emitidos.
class PipelineResumo {
  final PipelineSegmento recebido;
  final PipelineSegmento aReceber;
  final PipelineSegmento aguardandoEmissao;

  /// Previsão de recebimento do bloco "a receber". Null quando indisponível.
  final DateTime? dataPrevista;

  const PipelineResumo({
    required this.recebido,
    required this.aReceber,
    required this.aguardandoEmissao,
    this.dataPrevista,
  });

  /// Soma dos valores dos três estágios — largura total da barra segmentada.
  double get total => recebido.valor + aReceber.valor + aguardandoEmissao.valor;

  /// Mês sem movimento algum: barra única cinza + legenda zerada na UI.
  bool get vazio =>
      total == 0 &&
      recebido.quantidade == 0 &&
      aReceber.quantidade == 0 &&
      aguardandoEmissao.quantidade == 0;

  factory PipelineResumo.fromJson(Map<String, dynamic> json) {
    final aReceberNode = json['aReceber'];
    return PipelineResumo(
      recebido: _segmento(json['recebido']),
      aReceber: _segmento(aReceberNode),
      aguardandoEmissao: _segmento(json['aguardandoEmissao']),
      dataPrevista: _parseData(
        aReceberNode is Map<String, dynamic> ? aReceberNode['dataPrevista'] : null,
      ),
    );
  }

  static PipelineSegmento _segmento(Object? node) => node is Map<String, dynamic>
      ? PipelineSegmento.fromJson(node)
      : PipelineSegmento.zero;

  static final RegExp _dateOnly = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  static DateTime? _parseData(Object? value) {
    if (value is! String || value.trim().isEmpty) return null;
    final raw = value.trim();
    // Data-only (contrato .NET DateOnly, ex.: "2026-07-15") → UTC estável,
    // sem deslocar o dia por fuso; caso contrário parse ISO normal.
    if (_dateOnly.hasMatch(raw)) {
      final p = raw.split('-').map(int.parse).toList();
      return DateTime.utc(p[0], p[1], p[2]);
    }
    return DateTime.tryParse(raw)?.toUtc();
  }
}

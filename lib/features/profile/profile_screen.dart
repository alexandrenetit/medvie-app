// lib/features/profile/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/medico.dart';
import '../../core/models/especialidade.dart';
import '../../core/providers/onboarding_provider.dart';
import 'editar_tomador_screen.dart';

// ─── Constantes locais ─────────────────────────────────────────────────────

const _bg = Color(0xFF07090F);
const _surface = Color(0xFF111827);
const _border = Color(0xFF1E293B);

// ─── Tela principal ────────────────────────────────────────────────────────

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: AppColors.text, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Meu Perfil',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
      ),
      body: const _ProfileBody(),
    );
  }
}

// ─── Body com scroll ───────────────────────────────────────────────────────

class _ProfileBody extends StatelessWidget {
  const _ProfileBody();

  @override
  Widget build(BuildContext context) {
    final medico = context.watch<OnboardingProvider>().medico;
    if (medico == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.green),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      children: [
        _AvatarHeader(medico: medico),
        const SizedBox(height: 24),
        const _SecaoHeader(titulo: 'Dados Pessoais', icone: Icons.person_outline),
        const SizedBox(height: 12),
        _DadosPessoaisCard(medico: medico),
        const SizedBox(height: 24),
        const _SecaoHeader(titulo: 'Endereço', icone: Icons.location_on_outlined),
        const SizedBox(height: 12),
        _EnderecoCard(medico: medico),
        const SizedBox(height: 24),
        const _SecaoHeader(
            titulo: 'CNPJs PJ', icone: Icons.business_center_outlined),
        const SizedBox(height: 12),
        _CnpjsCard(medico: medico),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ─── Avatar header ─────────────────────────────────────────────────────────

class _AvatarHeader extends StatelessWidget {
  final Medico medico;
  const _AvatarHeader({required this.medico});

  @override
  Widget build(BuildContext context) {
    final nomeLimpo =
        medico.nome.replaceAll(RegExp(r'^[Dd][Rr]\.?\s*'), '').trim();
    final inicial = nomeLimpo.isNotEmpty ? nomeLimpo[0].toUpperCase() : 'D';

    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [AppColors.green, AppColors.cyan],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: Text(
              inicial,
              style: GoogleFonts.outfit(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Dr. $nomeLimpo',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${medico.especialidade?.nome ?? ''} · CRM-${medico.ufCrm} ${medico.crm}',
          style: GoogleFonts.outfit(
            fontSize: 13,
            color: AppColors.textDim,
          ),
        ),
      ],
    );
  }
}

// ─── Seção header ──────────────────────────────────────────────────────────

class _SecaoHeader extends StatelessWidget {
  final String titulo;
  final IconData icone;
  const _SecaoHeader({required this.titulo, required this.icone});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icone, color: AppColors.green, size: 18),
        const SizedBox(width: 8),
        Text(
          titulo,
          style: GoogleFonts.outfit(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
      ],
    );
  }
}

// ─── Card: Dados Pessoais ──────────────────────────────────────────────────

class _DadosPessoaisCard extends StatefulWidget {
  final Medico medico;
  const _DadosPessoaisCard({required this.medico});

  @override
  State<_DadosPessoaisCard> createState() => _DadosPessoaisCardState();
}

class _DadosPessoaisCardState extends State<_DadosPessoaisCard> {
  bool _editando = false;
  bool _salvando = false;

  late TextEditingController _nomeCtrl;
  late TextEditingController _crmCtrl;
  late TextEditingController _telefoneCtrl;
  late TextEditingController _emailCtrl;
  String _ufCrm = '';

  // Especialidades
  List<Especialidade> _especialidades = [];
  bool _carregandoEspecialidades = false;
  String? _erroEspecialidades;
  Especialidade? _especialidadeSelecionada;

  static const _ufs = [
    'AC','AL','AM','AP','BA','CE','DF','ES','GO','MA','MG','MS','MT',
    'PA','PB','PE','PI','PR','RJ','RN','RO','RR','RS','SC','SE','SP','TO',
  ];

  @override
  void initState() {
    super.initState();
    _nomeCtrl = TextEditingController(text: widget.medico.nome);
    _crmCtrl = TextEditingController(text: widget.medico.crm);
    _telefoneCtrl = TextEditingController(text: widget.medico.telefone);
    _emailCtrl = TextEditingController(text: widget.medico.email);
    _ufCrm = widget.medico.ufCrm;
    _especialidadeSelecionada = widget.medico.especialidade;
    _carregarEspecialidades();
  }

  Future<void> _carregarEspecialidades() async {
    if (!mounted) return;
    setState(() {
      _carregandoEspecialidades = true;
      _erroEspecialidades = null;
    });

    try {
      final provider = context.read<OnboardingProvider>();
      final especialidades = await provider.api.listarEspecialidades();
      if (mounted) {
        setState(() {
          _especialidades = especialidades;
          _carregandoEspecialidades = false;
          // Se não tem selecionada, seleciona a primeira
          if (_especialidadeSelecionada == null && _especialidades.isNotEmpty) {
            _especialidadeSelecionada = _especialidades.first;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _erroEspecialidades = 'Erro ao carregar especialidades';
          _carregandoEspecialidades = false;
        });
      }
    }
  }

  void _tentarNovamenteEspecialidades() {
    _carregarEspecialidades();
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _crmCtrl.dispose();
    _telefoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (_especialidadeSelecionada == null) {
      _mostrarSnack(context, 'Selecione uma especialidade');
      return;
    }

    setState(() => _salvando = true);
    await context.read<OnboardingProvider>().atualizarPerfil(
          nome: _nomeCtrl.text.trim(),
          crm: _crmCtrl.text.trim(),
          ufCrm: _ufCrm,
          especialidade: _especialidadeSelecionada,
          telefone: _telefoneCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
        );
    if (mounted) {
      setState(() {
        _salvando = false;
        _editando = false;
      });
      _mostrarSnack(context, 'Dados pessoais atualizados');
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // CPF — sempre read-only
          _CampoReadOnly(
            label: 'CPF',
            valor: widget.medico.cpf,
            badge: 'não editável',
          ),
          const SizedBox(height: 16),

          if (!_editando) ...[
            _CampoReadOnly(label: 'Nome completo', valor: widget.medico.nome),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                  child:
                      _CampoReadOnly(label: 'CRM', valor: widget.medico.crm)),
              const SizedBox(width: 12),
              Expanded(
                  child: _CampoReadOnly(
                      label: 'UF CRM', valor: widget.medico.ufCrm)),
            ]),
            const SizedBox(height: 12),
            _CampoReadOnly(
                label: 'Especialidade', valor: widget.medico.especialidade?.nome ?? ''),
            const SizedBox(height: 12),
            _CampoReadOnly(
              label: 'Celular',
              valor: widget.medico.telefone.isEmpty
                  ? '—'
                  : widget.medico.telefone,
            ),
            const SizedBox(height: 12),
            _CampoReadOnly(
              label: 'E-mail pessoal',
              valor: widget.medico.email.isEmpty ? '—' : widget.medico.email,
            ),
            const SizedBox(height: 16),
            _BotaoEditar(onTap: () => setState(() => _editando = true)),
          ] else ...[
            _CampoTexto(
                label: 'Nome completo', controller: _nomeCtrl),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                  child:
                      _CampoTexto(label: 'CRM', controller: _crmCtrl)),
              const SizedBox(width: 12),
              Expanded(
                child: _DropdownUf(
                  label: 'UF CRM',
                  value: _ufCrm,
                  ufs: _ufs,
                  onChanged: (v) => setState(() => _ufCrm = v ?? _ufCrm),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            _EspecialidadeDropdown(
              carregando: _carregandoEspecialidades,
              erro: _erroEspecialidades,
              especialidades: _especialidades,
              selecionada: _especialidadeSelecionada,
              onChanged: (esp) =>
                  setState(() => _especialidadeSelecionada = esp),
              onTentarNovamente: _tentarNovamenteEspecialidades,
            ),
            const SizedBox(height: 12),
            _CampoTexto(
              label: 'Celular',
              controller: _telefoneCtrl,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                _TelefoneInputFormatter(),
              ],
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            _CampoTexto(
              label: 'E-mail pessoal',
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: _BotaoCancelar(
                    onTap: () => setState(() => _editando = false)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _BotaoSalvar(
                    salvando: _salvando, onTap: _salvar),
              ),
            ]),
          ],
        ],
      ),
    );
  }
}

// ─── Card: Endereço ────────────────────────────────────────────────────────

class _EnderecoCard extends StatefulWidget {
  final Medico medico;
  const _EnderecoCard({required this.medico});

  @override
  State<_EnderecoCard> createState() => _EnderecoCardState();
}

class _EnderecoCardState extends State<_EnderecoCard> {
  bool _editando = false;
  bool _salvando = false;
  bool _buscandoCep = false;

  late TextEditingController _cepCtrl;
  late TextEditingController _logradouroCtrl;
  late TextEditingController _numeroCtrl;
  late TextEditingController _complementoCtrl;
  late TextEditingController _bairroCtrl;
  late TextEditingController _cidadeCtrl;
  String _uf = '';

  static const _ufs = [
    'AC','AL','AM','AP','BA','CE','DF','ES','GO','MA','MG','MS','MT',
    'PA','PB','PE','PI','PR','RJ','RN','RO','RR','RS','SC','SE','SP','TO',
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.medico.endereco;
    _cepCtrl = TextEditingController(text: e?.cep ?? '');
    _logradouroCtrl = TextEditingController(text: e?.logradouro ?? '');
    _numeroCtrl = TextEditingController(text: e?.numero ?? '');
    _complementoCtrl = TextEditingController(text: e?.complemento ?? '');
    _bairroCtrl = TextEditingController(text: e?.bairro ?? '');
    _cidadeCtrl = TextEditingController(text: e?.cidade ?? '');
    _uf = e?.uf ?? '';
  }

  @override
  void dispose() {
    _cepCtrl.dispose();
    _logradouroCtrl.dispose();
    _numeroCtrl.dispose();
    _complementoCtrl.dispose();
    _bairroCtrl.dispose();
    _cidadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _buscarCep(String cep) async {
    final numero = cep.replaceAll(RegExp(r'\D'), '');
    if (numero.length != 8) return;
    setState(() => _buscandoCep = true);
    try {
      final api = context.read<OnboardingProvider>().api;
      final dados = await api.buscarCep(numero);
      setState(() {
        _logradouroCtrl.text = dados.logradouro;
        _bairroCtrl.text = dados.bairro;
        _cidadeCtrl.text = dados.localidade;
        _uf = dados.uf;
      });
    } catch (_) {}
    if (mounted) setState(() => _buscandoCep = false);
  }

  Future<void> _salvar() async {
    setState(() => _salvando = true);
    await context.read<OnboardingProvider>().atualizarEndereco(
          Endereco(
            cep: _cepCtrl.text.trim(),
            logradouro: _logradouroCtrl.text.trim(),
            numero: _numeroCtrl.text.trim(),
            complemento: _complementoCtrl.text.trim(),
            bairro: _bairroCtrl.text.trim(),
            cidade: _cidadeCtrl.text.trim(),
            uf: _uf,
          ),
        );
    if (mounted) {
      setState(() {
        _salvando = false;
        _editando = false;
      });
      _mostrarSnack(context, 'Endereço atualizado');
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.medico.endereco;
    final temEndereco = e != null && e.preenchido;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_editando) ...[
            if (!temEndereco)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  'Endereço não cadastrado',
                  style: GoogleFonts.outfit(
                      fontSize: 14, color: AppColors.textDim),
                ),
              )
            else ...[
              _CampoReadOnly(label: 'CEP', valor: e.cep),
              const SizedBox(height: 12),
              _CampoReadOnly(
                  label: 'Logradouro',
                  valor: '${e.logradouro}, ${e.numero}'
                      '${e.complemento.isNotEmpty ? ' — ${e.complemento}' : ''}'),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child:
                        _CampoReadOnly(label: 'Bairro', valor: e.bairro)),
                const SizedBox(width: 12),
                Expanded(
                    child: _CampoReadOnly(
                        label: 'Cidade/UF',
                        valor: '${e.cidade} - ${e.uf}')),
              ]),
              const SizedBox(height: 16),
            ],
            _BotaoEditar(
              label: temEndereco ? 'Editar endereço' : 'Adicionar endereço',
              onTap: () => setState(() => _editando = true),
            ),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: _CampoTexto(
                    label: 'CEP',
                    controller: _cepCtrl,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      _CepInputFormatter(),
                    ],
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      if (v.replaceAll(RegExp(r'\D'), '').length == 8) {
                        _buscarCep(v);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                if (_buscandoCep)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 14),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: AppColors.green, strokeWidth: 2),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _CampoTexto(
                label: 'Logradouro', controller: _logradouroCtrl),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                  flex: 2,
                  child: _CampoTexto(
                      label: 'Número', controller: _numeroCtrl)),
              const SizedBox(width: 12),
              Expanded(
                  flex: 3,
                  child: _CampoTexto(
                      label: 'Complemento',
                      controller: _complementoCtrl)),
            ]),
            const SizedBox(height: 12),
            _CampoTexto(label: 'Bairro', controller: _bairroCtrl),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                  flex: 3,
                  child: _CampoTexto(
                      label: 'Cidade', controller: _cidadeCtrl)),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: _DropdownUf(
                  label: 'UF',
                  value: _uf,
                  ufs: _ufs,
                  onChanged: (v) => setState(() => _uf = v ?? _uf),
                ),
              ),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                  child: _BotaoCancelar(
                      onTap: () => setState(() => _editando = false))),
              const SizedBox(width: 12),
              Expanded(
                  child: _BotaoSalvar(
                      salvando: _salvando, onTap: _salvar)),
            ]),
          ],
        ],
      ),
    );
  }
}

// ─── Card: CNPJs ───────────────────────────────────────────────────────────

class _CnpjsCard extends StatelessWidget {
  final Medico medico;
  const _CnpjsCard({required this.medico});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ...medico.cnpjs.asMap().entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _CnpjItemCard(
                  cnpjData: entry.value,
                  indice: entry.key,
                  total: medico.cnpjs.length,
                ),
              ),
            ),
        _BotaoAdicionarCnpj(),
      ],
    );
  }
}

// ─── Card de cada CNPJ (expansível) ───────────────────────────────────────

class _CnpjItemCard extends StatefulWidget {
  final CnpjComTomadores cnpjData;
  final int indice;
  final int total;

  const _CnpjItemCard({
    required this.cnpjData,
    required this.indice,
    required this.total,
  });

  @override
  State<_CnpjItemCard> createState() => _CnpjItemCardState();
}

class _CnpjItemCardState extends State<_CnpjItemCard> {
  bool _expandido = false;

  Future<void> _confirmarRemoverCnpj(BuildContext context) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Remover CNPJ?',
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.w700, color: AppColors.text)),
        content: Text(
          'Remove o CNPJ ${widget.cnpjData.cnpj} e todos os seus tomadores.',
          style: GoogleFonts.outfit(color: AppColors.textDim),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar',
                style: GoogleFonts.outfit(color: AppColors.textDim)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Remover',
                style: GoogleFonts.outfit(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    if (!context.mounted) return;
    await context
        .read<OnboardingProvider>()
        .removerCnpj(widget.cnpjData.cnpj);
    if (context.mounted) _mostrarSnack(context, 'CNPJ removido');
  }

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.cnpjData.razaoSocial,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.cnpjData.cnpj,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 12,
                        color: AppColors.textDim,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.total > 1)
                GestureDetector(
                  onTap: () => _confirmarRemoverCnpj(context),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.delete_outline,
                        color: Colors.redAccent, size: 18),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _RegimeSelector(cnpjData: widget.cnpjData),
          const SizedBox(height: 12),
          Row(children: [
            const Icon(Icons.location_city_outlined,
                color: AppColors.textDim, size: 14),
            const SizedBox(width: 6),
            Text(
              widget.cnpjData.municipio,
              style: GoogleFonts.outfit(
                  fontSize: 12, color: AppColors.textDim),
            ),
          ]),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => setState(() => _expandido = !_expandido),
            child: Row(
              children: [
                Text(
                  'Tomadores (${widget.cnpjData.tomadores.length})',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: AppColors.cyan,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  _expandido
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: AppColors.cyan,
                  size: 18,
                ),
              ],
            ),
          ),
          if (_expandido) ...[
            const SizedBox(height: 12),
            const Divider(color: _border, height: 1),
            const SizedBox(height: 12),
            _TomadoresLista(
                cnpjProprio: widget.cnpjData.cnpj,
                tomadores: widget.cnpjData.tomadores),
            const SizedBox(height: 8),
            _BotaoAdicionarTomador(cnpjProprio: widget.cnpjData.cnpj),
          ],
        ],
      ),
    );
  }
}

// ─── Selector de regime tributário ─────────────────────────────────────────

class _RegimeSelector extends StatelessWidget {
  final CnpjComTomadores cnpjData;
  const _RegimeSelector({required this.cnpjData});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<RegimeTributario>(
      initialValue: cnpjData.regime,
      decoration: InputDecoration(
        labelText: 'Regime tributário',
        labelStyle:
            GoogleFonts.outfit(fontSize: 12, color: AppColors.textDim),
        filled: true,
        fillColor: _bg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.green),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        isDense: true,
      ),
      dropdownColor: _surface,
      style: GoogleFonts.outfit(fontSize: 13, color: AppColors.text),
      items: RegimeTributario.values
          .map((r) => DropdownMenuItem(
                value: r,
                child: Text(r.label,
                    style: GoogleFonts.outfit(
                        fontSize: 13, color: AppColors.text)),
              ))
          .toList(),
      onChanged: (v) {
        if (v != null) {
          context
              .read<OnboardingProvider>()
              .atualizarRegimeCnpj(cnpjData.cnpj, v);
        }
      },
    );
  }
}

// ─── Lista de tomadores ─────────────────────────────────────────────────────

class _TomadoresLista extends StatelessWidget {
  final String cnpjProprio;
  final List<Tomador> tomadores;

  const _TomadoresLista(
      {required this.cnpjProprio, required this.tomadores});

  Future<void> _confirmarRemover(
      BuildContext context, int index, String razaoSocial) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Remover tomador?',
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.w700, color: AppColors.text)),
        content: Text(
          'Remove $razaoSocial da lista de tomadores deste CNPJ.',
          style: GoogleFonts.outfit(color: AppColors.textDim),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar',
                style: GoogleFonts.outfit(color: AppColors.textDim)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Remover',
                style: GoogleFonts.outfit(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    if (!context.mounted) return;
    await context
        .read<OnboardingProvider>()
        .removerTomadorDoCnpj(cnpjProprio, index);
    if (context.mounted) _mostrarSnack(context, 'Tomador removido');
  }

  @override
  Widget build(BuildContext context) {
    if (tomadores.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          'Nenhum tomador cadastrado',
          style:
              GoogleFonts.outfit(fontSize: 13, color: AppColors.textDim),
        ),
      );
    }

    return Column(
      children: tomadores.asMap().entries.map((entry) {
        final i = entry.key;
        final t = entry.value;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.razaoSocial,
                      style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      t.cnpj,
                      style: GoogleFonts.jetBrainsMono(
                          fontSize: 11, color: AppColors.textDim),
                    ),
                    if (t.valorPadrao > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Valor padrão: R\$ ${t.valorPadrao.toStringAsFixed(2).replaceAll('.', ',')}',
                        style: GoogleFonts.jetBrainsMono(
                            fontSize: 11, color: AppColors.green),
                      ),
                    ],
                    if (t.emailFinanceiro != null &&
                        t.emailFinanceiro!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        t.emailFinanceiro!,
                        style: GoogleFonts.outfit(
                            fontSize: 11, color: AppColors.textDim),
                      ),
                    ],
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => EditarTomadorScreen(
                          cnpjProprio: cnpjProprio,
                          tomador: t,
                        ),
                      ),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.edit_outlined,
                          color: AppColors.green, size: 16),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () =>
                        _confirmarRemover(context, i, t.razaoSocial),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.delete_outline,
                          color: Colors.redAccent, size: 16),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ─── Botão adicionar CNPJ ──────────────────────────────────────────────────

class _BotaoAdicionarCnpj extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _abrirModalCnpj(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.green.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add, color: AppColors.green, size: 18),
            const SizedBox(width: 8),
            Text(
              'Adicionar CNPJ PJ',
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _abrirModalCnpj(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<OnboardingProvider>(),
        child: const _ModalAdicionarCnpj(),
      ),
    );
  }
}

// ─── Botão adicionar tomador ───────────────────────────────────────────────

class _BotaoAdicionarTomador extends StatelessWidget {
  final String cnpjProprio;
  const _BotaoAdicionarTomador({required this.cnpjProprio});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _abrirModal(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.cyan.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.cyan.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add, color: AppColors.cyan, size: 16),
            const SizedBox(width: 6),
            Text(
              'Adicionar tomador',
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.cyan,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _abrirModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<OnboardingProvider>(),
        child: _ModalAdicionarTomador(cnpjProprio: cnpjProprio),
      ),
    );
  }
}

// ─── Modal adicionar CNPJ ──────────────────────────────────────────────────

class _ModalAdicionarCnpj extends StatefulWidget {
  const _ModalAdicionarCnpj();

  @override
  State<_ModalAdicionarCnpj> createState() => _ModalAdicionarCnpjState();
}

class _ModalAdicionarCnpjState extends State<_ModalAdicionarCnpj> {
  final _cnpjCtrl = TextEditingController();
  bool _buscando = false;
  String? _erro;

  @override
  void dispose() {
    _cnpjCtrl.dispose();
    super.dispose();
  }

  Future<void> _adicionar() async {
    setState(() {
      _buscando = true;
      _erro = null;
    });
    final erro = await context
        .read<OnboardingProvider>()
        .adicionarCnpj(_cnpjCtrl.text.trim());
    if (!mounted) return;
    if (erro != null) {
      setState(() {
        _buscando = false;
        _erro = erro;
      });
    } else {
      Navigator.of(context).pop();
      _mostrarSnack(context, 'CNPJ adicionado com sucesso');
    }
  }

  @override
  Widget build(BuildContext context) {
    return _ModalBase(
      titulo: 'Adicionar CNPJ PJ',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CampoTexto(
            label: 'CNPJ',
            controller: _cnpjCtrl,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              _CnpjInputFormatter(),
            ],
            keyboardType: TextInputType.number,
          ),
          if (_erro != null) ...[
            const SizedBox(height: 8),
            Text(_erro!,
                style: GoogleFonts.outfit(
                    fontSize: 12, color: Colors.redAccent)),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _buscando ? null : _adicionar,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _buscando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.black, strokeWidth: 2),
                    )
                  : Text('Buscar e adicionar',
                      style: GoogleFonts.outfit(
                          fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Modal adicionar tomador ───────────────────────────────────────────────

class _ModalAdicionarTomador extends StatefulWidget {
  final String cnpjProprio;
  const _ModalAdicionarTomador({required this.cnpjProprio});

  @override
  State<_ModalAdicionarTomador> createState() =>
      _ModalAdicionarTomadorState();
}

class _ModalAdicionarTomadorState extends State<_ModalAdicionarTomador> {
  final _cnpjCtrl = TextEditingController();
  final _valorCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  bool _buscando = false;
  String? _erro;

  @override
  void dispose() {
    _cnpjCtrl.dispose();
    _valorCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _adicionar() async {
    setState(() {
      _buscando = true;
      _erro = null;
    });

    final valorTexto = _valorCtrl.text.trim().replaceAll(',', '.');
    final valor = double.tryParse(valorTexto) ?? 0.0;

    final erro = await context
        .read<OnboardingProvider>()
        .adicionarTomadorAoCnpj(
          widget.cnpjProprio,
          _cnpjCtrl.text.trim(),
          valorPadrao: valor,
          emailFinanceiro: _emailCtrl.text.trim(),
        );
    if (!mounted) return;
    if (erro != null) {
      setState(() {
        _buscando = false;
        _erro = erro;
      });
    } else {
      Navigator.of(context).pop();
      _mostrarSnack(context, 'Tomador adicionado com sucesso');
    }
  }

  @override
  Widget build(BuildContext context) {
    return _ModalBase(
      titulo: 'Adicionar tomador',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CampoTexto(
            label: 'CNPJ do tomador (hospital/clínica)',
            controller: _cnpjCtrl,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              _CnpjInputFormatter(),
            ],
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          _CampoTexto(
            label: 'Valor padrão do serviço (opcional)',
            controller: _valorCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            prefixText: 'R\$ ',
          ),
          const SizedBox(height: 12),
          _CampoTexto(
            label: 'E-mail do financeiro (opcional)',
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
          ),
          if (_erro != null) ...[
            const SizedBox(height: 8),
            Text(_erro!,
                style: GoogleFonts.outfit(
                    fontSize: 12, color: Colors.redAccent)),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _buscando ? null : _adicionar,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _buscando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.black, strokeWidth: 2),
                    )
                  : Text('Buscar e adicionar',
                      style: GoogleFonts.outfit(
                          fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Widgets auxiliares ────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: child,
    );
  }
}

class _ModalBase extends StatelessWidget {
  final String titulo;
  final Widget child;
  const _ModalBase({required this.titulo, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.textDim,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            titulo,
            style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.text),
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

class _CampoReadOnly extends StatelessWidget {
  final String label;
  final String valor;
  final String? badge;
  const _CampoReadOnly(
      {required this.label, required this.valor, this.badge});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label,
                style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: AppColors.textDim,
                    fontWeight: FontWeight.w500)),
            if (badge != null) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  badge!,
                  style: GoogleFonts.outfit(
                      fontSize: 9,
                      color: AppColors.amber,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          valor.isEmpty ? '—' : valor,
          style: GoogleFonts.outfit(
              fontSize: 14,
              color: badge != null ? AppColors.textMid : AppColors.text),
        ),
      ],
    );
  }
}

class _CampoTexto extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final String? prefixText;

  const _CampoTexto({
    required this.label,
    required this.controller,
    this.inputFormatters,
    this.keyboardType,
    this.onChanged,
    this.prefixText,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      inputFormatters: inputFormatters,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: GoogleFonts.outfit(fontSize: 14, color: AppColors.text),
      decoration: InputDecoration(
        labelText: label,
        prefixText: prefixText,
        prefixStyle:
            GoogleFonts.outfit(fontSize: 14, color: AppColors.textDim),
        labelStyle:
            GoogleFonts.outfit(fontSize: 12, color: AppColors.textDim),
        filled: true,
        fillColor: _bg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.green),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}

class _DropdownUf extends StatelessWidget {
  final String label;
  final String value;
  final List<String> ufs;
  final ValueChanged<String?> onChanged;

  const _DropdownUf({
    required this.label,
    required this.value,
    required this.ufs,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final valorValido = ufs.contains(value) ? value : null;
    return DropdownButtonFormField<String>(
      initialValue: valorValido,
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
            GoogleFonts.outfit(fontSize: 12, color: AppColors.textDim),
        filled: true,
        fillColor: _bg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.green),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        isDense: true,
      ),
      dropdownColor: _surface,
      style: GoogleFonts.outfit(fontSize: 14, color: AppColors.text),
      items: ufs
          .map((uf) => DropdownMenuItem(
                value: uf,
                child: Text(uf,
                    style: GoogleFonts.outfit(
                        fontSize: 14, color: AppColors.text)),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _EspecialidadeDropdown extends StatelessWidget {
  final bool carregando;
  final String? erro;
  final List<Especialidade> especialidades;
  final Especialidade? selecionada;
  final ValueChanged<Especialidade?> onChanged;
  final VoidCallback onTentarNovamente;

  const _EspecialidadeDropdown({
    required this.carregando,
    required this.erro,
    required this.especialidades,
    required this.selecionada,
    required this.onChanged,
    required this.onTentarNovamente,
  });

  @override
  Widget build(BuildContext context) {
    // Estado: carregando
    if (carregando) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _border),
        ),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.green),
            ),
          ),
        ),
      );
    }

    // Estado: erro
    if (erro != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    erro!,
                    style: GoogleFonts.outfit(
                      color: Colors.red,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 36,
            child: OutlinedButton(
              onPressed: onTentarNovamente,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.green),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Tentar novamente',
                style: GoogleFonts.outfit(
                  color: AppColors.green,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Estado: carregado
    final valorValido = especialidades.contains(selecionada) ? selecionada : null;
    return DropdownButtonFormField<Especialidade>(
      initialValue: valorValido,
      decoration: InputDecoration(
        labelText: 'Especialidade',
        labelStyle:
            GoogleFonts.outfit(fontSize: 12, color: AppColors.textDim),
        filled: true,
        fillColor: _bg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.green),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        isDense: true,
      ),
      dropdownColor: _surface,
      style: GoogleFonts.outfit(fontSize: 14, color: AppColors.text),
      items: especialidades
          .map((e) => DropdownMenuItem(
                value: e,
                child: Text(e.nome,
                    style: GoogleFonts.outfit(
                        fontSize: 14, color: AppColors.text)),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _BotaoEditar extends StatelessWidget {
  final VoidCallback onTap;
  final String label;
  const _BotaoEditar({required this.onTap, this.label = 'Editar'});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.edit_outlined, size: 16),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.cyan,
          side: BorderSide(color: AppColors.cyan.withValues(alpha: 0.4)),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
          textStyle: GoogleFonts.outfit(
              fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _BotaoCancelar extends StatelessWidget {
  final VoidCallback onTap;
  const _BotaoCancelar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textDim,
        side: BorderSide(color: AppColors.textDim.withValues(alpha: 0.3)),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        textStyle:
            GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      child: Text('Cancelar',
          style: GoogleFonts.outfit(fontSize: 13)),
    );
  }
}

class _BotaoSalvar extends StatelessWidget {
  final bool salvando;
  final VoidCallback onTap;
  const _BotaoSalvar({required this.salvando, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: salvando ? null : onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.green,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        textStyle:
            GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700),
      ),
      child: salvando
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  color: Colors.black, strokeWidth: 2),
            )
          : Text('Salvar',
              style: GoogleFonts.outfit(
                  fontSize: 13, fontWeight: FontWeight.w700)),
    );
  }
}

// ─── Input formatters ──────────────────────────────────────────────────────

class _CnpjInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length && i < 14; i++) {
      if (i == 2 || i == 5) buffer.write('.');
      if (i == 8) buffer.write('/');
      if (i == 12) buffer.write('-');
      buffer.write(digits[i]);
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class _CepInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length && i < 8; i++) {
      if (i == 5) buffer.write('-');
      buffer.write(digits[i]);
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class _TelefoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length && i < 11; i++) {
      if (i == 0) buffer.write('(');
      if (i == 2) buffer.write(') ');
      if (i == 7) buffer.write('-');
      buffer.write(digits[i]);
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

// ─── Helper snack ──────────────────────────────────────────────────────────

void _mostrarSnack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg,
          style: GoogleFonts.outfit(fontSize: 14, color: Colors.black)),
      backgroundColor: AppColors.green,
      behavior: SnackBarBehavior.floating,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 2),
    ),
  );
}
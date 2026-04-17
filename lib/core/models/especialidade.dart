// lib/core/models/especialidade.dart

class Especialidade {
  final int id;
  final String nome;

  Especialidade({
    required this.id,
    required this.nome,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'nome': nome,
      };

  factory Especialidade.fromJson(Map<String, dynamic> json) => Especialidade(
        id: json['id'] ?? 0,
        nome: json['nome'] ?? '',
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Especialidade &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Especialidade(id: $id, nome: $nome)';
}

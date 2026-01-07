import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

import 'llm_provider_type.dart';

class LlmConfig extends Equatable {
  final String id;
  final String name;
  final String? url;
  final String model;
  final String? apiKey;
  final int delay;
  final LlmProviderType providerType;
  final String? mlxPath;

  LlmConfig({
    String? id,
    required this.name,
    this.url,
    required this.model,
    this.apiKey,
    this.delay = 0,
    required this.providerType,
    this.mlxPath,
  }) : id = id ?? const Uuid().v4();

  @override
  List<Object?> get props => <Object?>[
    id,
    name,
    url,
    model,
    apiKey,
    delay,
    providerType,
    mlxPath,
  ];

  LlmConfig copyWith({
    String? id,
    String? name,
    String? url,
    String? model,
    String? apiKey,
    int? delay,
    LlmProviderType? providerType,
    String? mlxPath,
  }) {
    return LlmConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      model: model ?? this.model,
      apiKey: apiKey ?? this.apiKey,
      delay: delay ?? this.delay,
      providerType: providerType ?? this.providerType,
      mlxPath: mlxPath ?? this.mlxPath,
    );
  }

  factory LlmConfig.fromJson(Map<String, dynamic> json) {
    return LlmConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      url: json['url'] as String?,
      model: json['model'] as String,
      apiKey: json['apiKey'] as String?,
      delay: json['delay'] as int,
      providerType: LlmProviderType.values.firstWhere(
        (LlmProviderType e) => e.name == json['providerType'],
        orElse: () => LlmProviderType.remote,
      ),
      mlxPath: json['mlxPath'] as String?,
    );
  }
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'url': url,
      'model': model,
      'apiKey': apiKey,
      'delay': delay,
      'providerType': providerType.name,
      'mlxPath': mlxPath,
    };
  }
}

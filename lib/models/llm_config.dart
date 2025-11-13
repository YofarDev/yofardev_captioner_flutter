import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

class LlmConfig extends Equatable {
  final String id;
  final String name;
  final String url;
  final String model;
  final String apiKey;
  final int delay;
  LlmConfig({
    String? id,
    required this.name,
    required this.url,
    required this.model,
    required this.apiKey,
    required this.delay,
  }) : id = id ?? const Uuid().v4();
  @override
  List<Object?> get props => <Object?>[id, name, url, model, apiKey, delay];
  LlmConfig copyWith({
    String? id,
    String? name,
    String? url,
    String? model,
    String? apiKey,
    int? delay,
  }) {
    return LlmConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      model: model ?? this.model,
      apiKey: apiKey ?? this.apiKey,
      delay: delay ?? this.delay,
    );
  }

  factory LlmConfig.fromJson(Map<String, dynamic> json) {
    return LlmConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      url: json['url'] as String,
      model: json['model'] as String,
      apiKey: json['apiKey'] as String,
      delay: json['delay'] as int,
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
    };
  }
}

import 'package:equatable/equatable.dart';

class StructuredBatchOverrides extends Equatable {
  final bool enabled;
  final bool overrideMedium;
  final String? medium;
  final bool overrideAesthetics;
  final String? aesthetics;
  final bool overrideLighting;
  final String? lighting;

  /// 'photo' or 'art_style' — mutually exclusive, null means no override.
  final String? styleMode;
  final String? styleDetail;
  final bool overrideBackground;
  final String? background;

  const StructuredBatchOverrides({
    this.enabled = false,
    this.overrideMedium = false,
    this.medium,
    this.overrideAesthetics = false,
    this.aesthetics,
    this.overrideLighting = false,
    this.lighting,
    this.styleMode,
    this.styleDetail,
    this.overrideBackground = false,
    this.background,
  });

  factory StructuredBatchOverrides.fromJson(Map<String, dynamic> json) {
    return StructuredBatchOverrides(
      enabled: json['enabled'] as bool? ?? false,
      overrideMedium: json['overrideMedium'] as bool? ?? false,
      medium: json['medium'] as String?,
      overrideAesthetics: json['overrideAesthetics'] as bool? ?? false,
      aesthetics: json['aesthetics'] as String?,
      overrideLighting: json['overrideLighting'] as bool? ?? false,
      lighting: json['lighting'] as String?,
      styleMode: json['styleMode'] as String?,
      styleDetail: json['styleDetail'] as String?,
      overrideBackground: json['overrideBackground'] as bool? ?? false,
      background: json['background'] as String?,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'enabled': enabled,
    'overrideMedium': overrideMedium,
    if (medium != null) 'medium': medium,
    'overrideAesthetics': overrideAesthetics,
    if (aesthetics != null) 'aesthetics': aesthetics,
    'overrideLighting': overrideLighting,
    if (lighting != null) 'lighting': lighting,
    if (styleMode != null) 'styleMode': styleMode,
    if (styleDetail != null) 'styleDetail': styleDetail,
    'overrideBackground': overrideBackground,
    if (background != null) 'background': background,
  };

  StructuredBatchOverrides copyWith({
    bool? enabled,
    bool? overrideMedium,
    String? medium,
    bool clearMedium = false,
    bool? overrideAesthetics,
    String? aesthetics,
    bool clearAesthetics = false,
    bool? overrideLighting,
    String? lighting,
    bool clearLighting = false,
    String? styleMode,
    bool clearStyleMode = false,
    String? styleDetail,
    bool clearStyleDetail = false,
    bool? overrideBackground,
    String? background,
    bool clearBackground = false,
  }) {
    return StructuredBatchOverrides(
      enabled: enabled ?? this.enabled,
      overrideMedium: overrideMedium ?? this.overrideMedium,
      medium: clearMedium ? null : (medium ?? this.medium),
      overrideAesthetics: overrideAesthetics ?? this.overrideAesthetics,
      aesthetics: clearAesthetics ? null : (aesthetics ?? this.aesthetics),
      overrideLighting: overrideLighting ?? this.overrideLighting,
      lighting: clearLighting ? null : (lighting ?? this.lighting),
      styleMode: clearStyleMode ? null : (styleMode ?? this.styleMode),
      styleDetail: clearStyleDetail ? null : (styleDetail ?? this.styleDetail),
      overrideBackground: overrideBackground ?? this.overrideBackground,
      background: clearBackground ? null : (background ?? this.background),
    );
  }

  @override
  List<Object?> get props => <Object?>[
    enabled,
    overrideMedium,
    medium,
    overrideAesthetics,
    aesthetics,
    overrideLighting,
    lighting,
    styleMode,
    styleDetail,
    overrideBackground,
    background,
  ];
}

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'object_attributes.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ObjectAttributes _$ObjectAttributesFromJson(Map<String, dynamic> json) =>
    _ObjectAttributes(
      name: json['name'] as String? ?? '',
      colorArgb: (json['colorArgb'] as num?)?.toInt(),
      visible: json['visible'] as bool? ?? true,
      labelVisible: json['labelVisible'] as bool? ?? true,
      showValue: json['showValue'] as bool? ?? false,
      labelDx: (json['labelDx'] as num?)?.toDouble() ?? 6.0,
      labelDy: (json['labelDy'] as num?)?.toDouble() ?? -18.0,
      labelFontSize: (json['labelFontSize'] as num?)?.toDouble() ?? 12.0,
      strokeWidth: (json['strokeWidth'] as num?)?.toDouble() ?? 2.0,
      dashPeriod: (json['dashPeriod'] as num?)?.toDouble() ?? 0.0,
      pointSize: (json['pointSize'] as num?)?.toDouble() ?? 4.0,
      angleMarkerRadius:
          (json['angleMarkerRadius'] as num?)?.toDouble() ?? 20.0,
      fillAlpha: (json['fillAlpha'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$ObjectAttributesToJson(_ObjectAttributes instance) =>
    <String, dynamic>{
      'name': instance.name,
      'colorArgb': instance.colorArgb,
      'visible': instance.visible,
      'labelVisible': instance.labelVisible,
      'showValue': instance.showValue,
      'labelDx': instance.labelDx,
      'labelDy': instance.labelDy,
      'labelFontSize': instance.labelFontSize,
      'strokeWidth': instance.strokeWidth,
      'dashPeriod': instance.dashPeriod,
      'pointSize': instance.pointSize,
      'angleMarkerRadius': instance.angleMarkerRadius,
      'fillAlpha': instance.fillAlpha,
    };

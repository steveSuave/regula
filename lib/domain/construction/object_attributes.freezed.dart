// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'object_attributes.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ObjectAttributes {

/// User-facing label, e.g. "A" or "circumcircle". Empty = unnamed.
 String get name;/// Explicit ARGB color, or null to inherit the theme default.
 int? get colorArgb; bool get visible; bool get labelVisible;/// Stroke width in logical pixels (lines, circles, arcs).
 double get strokeWidth;/// Dash period in logical pixels for stroked kinds: 0 = solid,
/// > 0 = dashed with dash = gap = period / 2. Like stroke widths,
/// it does not scale with zoom.
 double get dashPeriod;/// Point radius in logical pixels (point kinds only).
 double get pointSize;/// Fill opacity in [0, 1] for filled kinds (sectors); null = unfilled.
 double? get fillAlpha;
/// Create a copy of ObjectAttributes
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ObjectAttributesCopyWith<ObjectAttributes> get copyWith => _$ObjectAttributesCopyWithImpl<ObjectAttributes>(this as ObjectAttributes, _$identity);

  /// Serializes this ObjectAttributes to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ObjectAttributes&&(identical(other.name, name) || other.name == name)&&(identical(other.colorArgb, colorArgb) || other.colorArgb == colorArgb)&&(identical(other.visible, visible) || other.visible == visible)&&(identical(other.labelVisible, labelVisible) || other.labelVisible == labelVisible)&&(identical(other.strokeWidth, strokeWidth) || other.strokeWidth == strokeWidth)&&(identical(other.dashPeriod, dashPeriod) || other.dashPeriod == dashPeriod)&&(identical(other.pointSize, pointSize) || other.pointSize == pointSize)&&(identical(other.fillAlpha, fillAlpha) || other.fillAlpha == fillAlpha));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,colorArgb,visible,labelVisible,strokeWidth,dashPeriod,pointSize,fillAlpha);

@override
String toString() {
  return 'ObjectAttributes(name: $name, colorArgb: $colorArgb, visible: $visible, labelVisible: $labelVisible, strokeWidth: $strokeWidth, dashPeriod: $dashPeriod, pointSize: $pointSize, fillAlpha: $fillAlpha)';
}


}

/// @nodoc
abstract mixin class $ObjectAttributesCopyWith<$Res>  {
  factory $ObjectAttributesCopyWith(ObjectAttributes value, $Res Function(ObjectAttributes) _then) = _$ObjectAttributesCopyWithImpl;
@useResult
$Res call({
 String name, int? colorArgb, bool visible, bool labelVisible, double strokeWidth, double dashPeriod, double pointSize, double? fillAlpha
});




}
/// @nodoc
class _$ObjectAttributesCopyWithImpl<$Res>
    implements $ObjectAttributesCopyWith<$Res> {
  _$ObjectAttributesCopyWithImpl(this._self, this._then);

  final ObjectAttributes _self;
  final $Res Function(ObjectAttributes) _then;

/// Create a copy of ObjectAttributes
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? colorArgb = freezed,Object? visible = null,Object? labelVisible = null,Object? strokeWidth = null,Object? dashPeriod = null,Object? pointSize = null,Object? fillAlpha = freezed,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,colorArgb: freezed == colorArgb ? _self.colorArgb : colorArgb // ignore: cast_nullable_to_non_nullable
as int?,visible: null == visible ? _self.visible : visible // ignore: cast_nullable_to_non_nullable
as bool,labelVisible: null == labelVisible ? _self.labelVisible : labelVisible // ignore: cast_nullable_to_non_nullable
as bool,strokeWidth: null == strokeWidth ? _self.strokeWidth : strokeWidth // ignore: cast_nullable_to_non_nullable
as double,dashPeriod: null == dashPeriod ? _self.dashPeriod : dashPeriod // ignore: cast_nullable_to_non_nullable
as double,pointSize: null == pointSize ? _self.pointSize : pointSize // ignore: cast_nullable_to_non_nullable
as double,fillAlpha: freezed == fillAlpha ? _self.fillAlpha : fillAlpha // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}

}


/// Adds pattern-matching-related methods to [ObjectAttributes].
extension ObjectAttributesPatterns on ObjectAttributes {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ObjectAttributes value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ObjectAttributes() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ObjectAttributes value)  $default,){
final _that = this;
switch (_that) {
case _ObjectAttributes():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ObjectAttributes value)?  $default,){
final _that = this;
switch (_that) {
case _ObjectAttributes() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  int? colorArgb,  bool visible,  bool labelVisible,  double strokeWidth,  double dashPeriod,  double pointSize,  double? fillAlpha)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ObjectAttributes() when $default != null:
return $default(_that.name,_that.colorArgb,_that.visible,_that.labelVisible,_that.strokeWidth,_that.dashPeriod,_that.pointSize,_that.fillAlpha);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  int? colorArgb,  bool visible,  bool labelVisible,  double strokeWidth,  double dashPeriod,  double pointSize,  double? fillAlpha)  $default,) {final _that = this;
switch (_that) {
case _ObjectAttributes():
return $default(_that.name,_that.colorArgb,_that.visible,_that.labelVisible,_that.strokeWidth,_that.dashPeriod,_that.pointSize,_that.fillAlpha);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  int? colorArgb,  bool visible,  bool labelVisible,  double strokeWidth,  double dashPeriod,  double pointSize,  double? fillAlpha)?  $default,) {final _that = this;
switch (_that) {
case _ObjectAttributes() when $default != null:
return $default(_that.name,_that.colorArgb,_that.visible,_that.labelVisible,_that.strokeWidth,_that.dashPeriod,_that.pointSize,_that.fillAlpha);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ObjectAttributes implements ObjectAttributes {
  const _ObjectAttributes({this.name = '', this.colorArgb, this.visible = true, this.labelVisible = true, this.strokeWidth = 2.0, this.dashPeriod = 0.0, this.pointSize = 4.0, this.fillAlpha});
  factory _ObjectAttributes.fromJson(Map<String, dynamic> json) => _$ObjectAttributesFromJson(json);

/// User-facing label, e.g. "A" or "circumcircle". Empty = unnamed.
@override@JsonKey() final  String name;
/// Explicit ARGB color, or null to inherit the theme default.
@override final  int? colorArgb;
@override@JsonKey() final  bool visible;
@override@JsonKey() final  bool labelVisible;
/// Stroke width in logical pixels (lines, circles, arcs).
@override@JsonKey() final  double strokeWidth;
/// Dash period in logical pixels for stroked kinds: 0 = solid,
/// > 0 = dashed with dash = gap = period / 2. Like stroke widths,
/// it does not scale with zoom.
@override@JsonKey() final  double dashPeriod;
/// Point radius in logical pixels (point kinds only).
@override@JsonKey() final  double pointSize;
/// Fill opacity in [0, 1] for filled kinds (sectors); null = unfilled.
@override final  double? fillAlpha;

/// Create a copy of ObjectAttributes
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ObjectAttributesCopyWith<_ObjectAttributes> get copyWith => __$ObjectAttributesCopyWithImpl<_ObjectAttributes>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ObjectAttributesToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ObjectAttributes&&(identical(other.name, name) || other.name == name)&&(identical(other.colorArgb, colorArgb) || other.colorArgb == colorArgb)&&(identical(other.visible, visible) || other.visible == visible)&&(identical(other.labelVisible, labelVisible) || other.labelVisible == labelVisible)&&(identical(other.strokeWidth, strokeWidth) || other.strokeWidth == strokeWidth)&&(identical(other.dashPeriod, dashPeriod) || other.dashPeriod == dashPeriod)&&(identical(other.pointSize, pointSize) || other.pointSize == pointSize)&&(identical(other.fillAlpha, fillAlpha) || other.fillAlpha == fillAlpha));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,colorArgb,visible,labelVisible,strokeWidth,dashPeriod,pointSize,fillAlpha);

@override
String toString() {
  return 'ObjectAttributes(name: $name, colorArgb: $colorArgb, visible: $visible, labelVisible: $labelVisible, strokeWidth: $strokeWidth, dashPeriod: $dashPeriod, pointSize: $pointSize, fillAlpha: $fillAlpha)';
}


}

/// @nodoc
abstract mixin class _$ObjectAttributesCopyWith<$Res> implements $ObjectAttributesCopyWith<$Res> {
  factory _$ObjectAttributesCopyWith(_ObjectAttributes value, $Res Function(_ObjectAttributes) _then) = __$ObjectAttributesCopyWithImpl;
@override @useResult
$Res call({
 String name, int? colorArgb, bool visible, bool labelVisible, double strokeWidth, double dashPeriod, double pointSize, double? fillAlpha
});




}
/// @nodoc
class __$ObjectAttributesCopyWithImpl<$Res>
    implements _$ObjectAttributesCopyWith<$Res> {
  __$ObjectAttributesCopyWithImpl(this._self, this._then);

  final _ObjectAttributes _self;
  final $Res Function(_ObjectAttributes) _then;

/// Create a copy of ObjectAttributes
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? colorArgb = freezed,Object? visible = null,Object? labelVisible = null,Object? strokeWidth = null,Object? dashPeriod = null,Object? pointSize = null,Object? fillAlpha = freezed,}) {
  return _then(_ObjectAttributes(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,colorArgb: freezed == colorArgb ? _self.colorArgb : colorArgb // ignore: cast_nullable_to_non_nullable
as int?,visible: null == visible ? _self.visible : visible // ignore: cast_nullable_to_non_nullable
as bool,labelVisible: null == labelVisible ? _self.labelVisible : labelVisible // ignore: cast_nullable_to_non_nullable
as bool,strokeWidth: null == strokeWidth ? _self.strokeWidth : strokeWidth // ignore: cast_nullable_to_non_nullable
as double,dashPeriod: null == dashPeriod ? _self.dashPeriod : dashPeriod // ignore: cast_nullable_to_non_nullable
as double,pointSize: null == pointSize ? _self.pointSize : pointSize // ignore: cast_nullable_to_non_nullable
as double,fillAlpha: freezed == fillAlpha ? _self.fillAlpha : fillAlpha // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}


}

// dart format on

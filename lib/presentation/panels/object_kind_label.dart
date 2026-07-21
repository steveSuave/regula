import '../../domain/construction/geo_object.dart';
import '../../domain/construction/objects/angle_bisector_line.dart';
import '../../domain/construction/objects/arc.dart';
import '../../domain/construction/objects/area_measurement.dart';
import '../../domain/construction/objects/centroid.dart';
import '../../domain/construction/objects/circle_center.dart';
import '../../domain/construction/objects/circumcenter.dart';
import '../../domain/construction/objects/compass_circle.dart';
import '../../domain/construction/objects/distance_measurement.dart';
import '../../domain/construction/objects/incenter.dart';
import '../../domain/construction/objects/intersection_point.dart';
import '../../domain/construction/objects/length_measurement.dart';
import '../../domain/construction/objects/line_angle.dart';
import '../../domain/construction/objects/midpoint.dart';
import '../../domain/construction/objects/orthocenter.dart';
import '../../domain/construction/objects/parallel_line.dart';
import '../../domain/construction/objects/perpendicular_bisector_line.dart';
import '../../domain/construction/objects/perpendicular_line.dart';
import '../../domain/construction/objects/point_on_object.dart';
import '../../domain/construction/objects/ray.dart';
import '../../domain/construction/objects/sector.dart';
import '../../domain/construction/objects/segment.dart';
import '../../domain/construction/objects/segment_ratio_point.dart';
import '../../domain/construction/objects/tangent_line.dart';
import '../../domain/construction/objects/two_line_bisector_line.dart';

/// The user-facing name of an object's construction kind, for the
/// inspector and (later) the object tree.
///
/// A switch over concrete types rather than `runtimeType.toString()`:
/// dart2js minifies type names in release web builds. Concrete cases
/// come before their sealed kind, whose case doubles as the fallback
/// for types added later — a new object shows its kind ("Point") until
/// someone adds it here.
String objectKindLabel(GeoObject object) => switch (object) {
      Midpoint() => 'Midpoint',
      IntersectionPoint() => 'Intersection point',
      PointOnObject() => 'Point on object',
      SegmentRatioPoint() => 'Segment-ratio point',
      Centroid() => 'Centroid',
      Orthocenter() => 'Orthocenter',
      Incenter() => 'Incenter',
      Circumcenter() => 'Circumcenter',
      CircleCenter() => 'Circle center',
      GeoPoint() => 'Point',
      Segment() => 'Segment',
      Ray() => 'Ray',
      PerpendicularLine() => 'Perpendicular line',
      ParallelLine() => 'Parallel line',
      AngleBisectorLine() => 'Angle bisector',
      TwoLineBisectorLine() => 'Angle bisector',
      PerpendicularBisectorLine() => 'Perpendicular bisector',
      TangentLine() => 'Tangent line',
      GeoLine() => 'Line',
      Arc() => 'Arc',
      Sector() => 'Sector',
      CompassCircle() => 'Compass circle',
      GeoCircle() => 'Circle',
      LineAngle() => 'Angle between lines',
      GeoAngle() => 'Angle',
      GeoPolygon() => 'Polygon',
      DistanceMeasurement() => 'Distance',
      AreaMeasurement() => 'Area',
      LengthMeasurement() => 'Length',
      GeoMeasurement() => 'Measurement',
      GeoText() => 'Text',
      GeoLocus() => 'Locus',
    };

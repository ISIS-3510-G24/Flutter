import 'package:vector_math/vector_math_64.dart';

class MeasurementData {
  final List<MeasurementPoint> points;
  final List<MeasurementLine> lines;
  
  MeasurementData({
    required this.points,
    required this.lines,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'points': points.map((p) => p.toMap()).toList(),
      'lines': lines.map((l) => l.toMap()).toList(),
    };
  }
}

class MeasurementPoint {
  final Vector3 position;
  
  MeasurementPoint({required this.position});
  
  Map<String, dynamic> toMap() {
    return {
      'x': position.x,
      'y': position.y,
      'z': position.z,
    };
  }
}

class MeasurementLine {
  final Vector3 from;
  final Vector3 to;
  final String measurement;
  
  MeasurementLine({
    required this.from,
    required this.to,
    required this.measurement,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'from': {'x': from.x, 'y': from.y, 'z': from.z},
      'to': {'x': to.x, 'y': to.y, 'z': to.z},
      'measurement': measurement,
    };
  }
}
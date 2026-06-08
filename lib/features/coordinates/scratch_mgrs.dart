import 'package:mgrs_dart/mgrs_dart.dart';

void main() {
  final str = Mgrs.forward([26.5678, -33.1234]); // Note: Mgrs_dart forward accuracy arg might be different or optional.
  print('MGRS: $str');
}

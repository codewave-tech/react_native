import 'package:cwa_plugin_core/cwa_plugin_core.dart';

class UnitSpecificationYaml extends SpecificationYamlImpl {
  UnitSpecificationYaml({
    required super.name,
    required super.version,
    required super.sdkConstraints,
    required super.harbor,
    required super.dependencies,
  });

  @override
  SpecificationYamlImpl copyWith() {
    throw UnimplementedError();
  }
}

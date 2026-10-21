import 'calc_tool.dart';
import 'datetime_tool.dart';
import 'tool.dart';

/// Built-in tools available to the on-device agent (v1).
List<JarvisTool> builtInTools() => [
      CalculateTool(),
      CurrentDateTimeTool(),
    ];

Map<String, JarvisTool> toolRegistry(List<JarvisTool> tools) {
  return {for (final t in tools) t.name: t};
}

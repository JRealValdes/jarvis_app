import 'calc_tool.dart';
import 'datetime_tool.dart';
import 'tool.dart';
import 'web_search_tool.dart';

/// Built-in tools available to the on-device / offline agent.
///
/// Server-only (not ported): Google Calendar, speech-to-text, LinkedIn draft /
/// examples, job-preferences YAML. See README.
List<JarvisTool> builtInTools() => [
      CalculateTool(),
      CurrentDateTimeTool(),
      WebSearchTool(),
    ];

/// Contract for a tool exposed to the OpenAI tools API.
abstract class JarvisTool {
  String get name;
  String get description;
  Map<String, dynamic> get parametersSchema;

  Future<String> execute(Map<String, dynamic> arguments);

  Map<String, dynamic> toOpenAiTool() => {
        'type': 'function',
        'function': {
          'name': name,
          'description': description,
          'parameters': parametersSchema,
        },
      };
}

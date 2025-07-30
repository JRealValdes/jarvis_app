import 'package:flutter/material.dart';
import '../services/api_service.dart';

class HomeScreen extends StatelessWidget {
  final ApiService _api = ApiService();

  HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Jarvis')),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            final resp = await _api.postAsk({
              'message': 'Hola',
              'model_name': 'GPT_3_5',
              'thread_id': 'test'
            });
            final data = resp.statusCode == 200 ? resp.body : 'Error: \${resp.statusCode}';
            showDialog(context: context, builder: (_) => AlertDialog(content: Text(data)));
          },
          child: Text('Preguntar a Jarvis'),
        ),
      ),
    );
  }
}

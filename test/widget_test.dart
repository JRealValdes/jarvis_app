import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_app/main.dart';
import 'package:jarvis_app/screens/login_screen.dart';

void main() {
  testWidgets('Login screen renders correctly', (WidgetTester tester) async {
    // Construir la app y lanzar un frame
    await tester.pumpWidget(JarvisApp());

    // Verifica que la pantalla de login está presente
    expect(find.byType(LoginScreen), findsOneWidget);

    // Opcional: puedes buscar textos o elementos concretos si los conoces
    expect(find.text('Iniciar sesión'), findsOneWidget); // Solo si ese texto está en LoginScreen
  });
}

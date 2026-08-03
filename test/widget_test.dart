import 'package:flutter_test/flutter_test.dart';
import 'package:lifelens_mobile/app/lifelens_app.dart';

void main() {
  testWidgets('LifeLens dashboard opens', (tester) async {
    await tester.pumpWidget(const LifeLensApp());

    expect(find.text('LifeLens'), findsOneWidget);
    expect(find.text('Productivity'), findsOneWidget);
    expect(find.text('Financial Health'), findsOneWidget);
    expect(find.text('Stress Risk'), findsOneWidget);
  });
}

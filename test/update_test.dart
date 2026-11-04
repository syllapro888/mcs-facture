import 'package:flutter_test/flutter_test.dart';
import 'package:mcs_facture/services/update_service.dart';

void main() {
  test('comparaison des versions', () {
    expect(UpdateService.isNewer('v1.0.12', '1.0.9'), isTrue);
    expect(UpdateService.isNewer('v1.0.9', '1.0.9'), isFalse);
    expect(UpdateService.isNewer('v1.0.8', '1.0.9'), isFalse);
    expect(UpdateService.isNewer('v1.1.0', '1.0.99'), isTrue);
    expect(UpdateService.isNewer('v2.0.0', '1.9.9'), isTrue);
    expect(UpdateService.parse('v1.0.5+5'), [1, 0, 5]);
  });
}

/// Provat e kodit të partnerit — pika ku një komision mund të humbasë pa zë.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:esim/pagesa/partneri.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Partneri.pastroPerProva();
  });

  Future<SharedPreferences> prefs() => SharedPreferences.getInstance();

  test('kodi merret nga URL-ja dhe RUHET', () async {
    final p = await prefs();
    await Partneri.nis(p, Uri.parse('https://esim.spacecode.tech/?partneri=SP-KS-M4T7'));
    expect(Partneri.kodi, 'SP-KS-M4T7');

    // 🚨 Rasti i vërtetë: blerësi rifreskon faqen dhe URL-ja s'e mban më kodin.
    Partneri.pastroPerProva();
    await Partneri.nis(p, Uri.parse('https://esim.spacecode.tech/'));
    expect(Partneri.kodi, 'SP-KS-M4T7', reason: 'kodi u humb pas rifreskimit');
  });

  test('një kod i ri e zëvendëson të vjetrin', () async {
    final p = await prefs();
    await Partneri.nis(p, Uri.parse('https://x/?partneri=SP-KS-AAAA'));
    await Partneri.nis(p, Uri.parse('https://x/?partneri=SP-AL-BBBB'));
    expect(Partneri.kodi, 'SP-AL-BBBB');
  });

  test('shkronjat e vogla bëhen të mëdha', () async {
    await Partneri.nis(await prefs(), Uri.parse('https://x/?partneri=sp-ks-m4t7'));
    expect(Partneri.kodi, 'SP-KS-M4T7');
  });

  test('pa parametër, kodi mbetet null', () async {
    await Partneri.nis(await prefs(), Uri.parse('https://esim.spacecode.tech/'));
    expect(Partneri.kodi, isNull);
  });

  test('🚨 vargjet e këqija nuk kalojnë te trupi i pagesës', () async {
    final p = await prefs();
    for (final x in ['', '   ', 'A' * 25, '<script>', 'SP KS 1', 'ë', '../../etc']) {
      Partneri.pastroPerProva();
      await Partneri.nis(p, Uri.parse('https://x/?partneri=${Uri.encodeQueryComponent(x)}'));
      expect(Partneri.kodi, isNull, reason: 'kaloi «$x»');
    }
  });

  test('një kod i keq nuk e fshin një kod të mirë të ruajtur', () async {
    final p = await prefs();
    await Partneri.nis(p, Uri.parse('https://x/?partneri=SP-KS-AAAA'));
    Partneri.pastroPerProva();
    await Partneri.nis(p, Uri.parse('https://x/?partneri=<script>'));
    expect(Partneri.kodi, 'SP-KS-AAAA');
  });
}

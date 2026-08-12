import 'dart:typed_data';

import 'package:esim/pamja/qr_eksporti.dart';
import 'package:flutter_test/flutter_test.dart';

/// 🚨 Përse provohet PNG-ja dhe jo butoni.
///
/// Fletën e ndarjes së sistemit një test nuk e hap dot, dhe nuk ka pse: ajo
/// është e Android-it. Ajo që MUND të dalë e gabuar pa u parë është figura —
/// një PNG bosh, i vogël, ose transparent do të dukej si sukses te aplikacioni
/// dhe do të dështonte vetëm te skaneri i dikujt tjetër, në aeroport.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const String lpa = 'LPA:1\$rsp.truphone.com\$QRF-SPACECODE-TEST-0001';

  test('PNG-ja del me përmasën e kërkuar dhe si PNG i vërtetë', () async {
    final Uint8List png = await qrPng(lpa, madhesia: 512);

    // Nënshkrimi i PNG-së: 89 50 4E 47. Pa këtë kontroll, çdo varg bajtesh do
    // ta kalonte provën.
    expect(png.sublist(0, 4), <int>[0x89, 0x50, 0x4E, 0x47]);

    // Gjerësia dhe lartësia rrinë te IHDR-ja, bajtet 16–23, big-endian.
    final ByteData koka = ByteData.sublistView(png, 16, 24);
    expect(koka.getUint32(0), 512, reason: 'gjerësia');
    expect(koka.getUint32(4), 512, reason: 'lartësia');
  });

  test('një QR më i madh jep më shumë bajte se një i vogël', () async {
    final Uint8List vogel = await qrPng(lpa, madhesia: 256);
    final Uint8List madh = await qrPng(lpa, madhesia: 1024);
    expect(madh.length, greaterThan(vogel.length));
  });

  test('emri i skedarit e mban emrin e eSIM-it dhe nuk lë shenja të rrezikshme',
      () {
    expect(emriISkedarit('Turqi 5 GB'), 'eSIM-Turqi-5-GB.png');
    expect(emriISkedarit('Shqipëri / 2026'), 'eSIM-Shqip-ri-2026.png');
    // 🚨 Një emër vetëm me shenja do të jepte «eSIM-.png», dhe te disa sisteme
    // skedarësh një emër që nis me pikë ose mbaron me vizë as nuk shkruhet dot.
    expect(emriISkedarit('«»/'), 'eSIM-profili.png');
  });
}

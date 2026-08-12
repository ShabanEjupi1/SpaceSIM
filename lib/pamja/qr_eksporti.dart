/// Nxjerr kodin QR nga ekrani: te shtypësi, te një pajisje tjetër, te galeria.
///
/// # 🚨🚨 Përse ky skedar ekziston
///
/// Vetë ekrani i profilit i thoshte blerësit: *«Skanoje me një pajisje TJETËR,
/// ose ruaje figurën dhe zgjidhe nga galeria — telefoni nuk e skanon dot ekranin
/// e vet.»* Kjo është e vërtetë dhe është e gjithë pika: një eSIM instalohet
/// duke skanuar një QR, dhe kamera e telefonit nuk e sheh ekranin e vet.
///
/// Po **nuk kishte asnjë buton që e ruante figurën.** Pra i vetmi udhëzim që e
/// zgjidhte problemin ishte i pazbatueshëm — dhe kjo nuk dukej si defekt, sepse
/// ekrani tregonte një QR të bukur, të saktë dhe të palëvizshëm.
///
/// # 🔑 PNG i vizatuar nga e para, jo pamje ekrani
///
/// QR-i vizatohet nga [QrPainter] me përmasa të zgjedhura këtu, jo me ato që
/// ka ekrani. Një pamje ekrani do të merrte dendësinë e pajisjes — te një
/// telefon i vjetër rreth 240 px — dhe një QR i shtypur nga 240 px lexohet keq
/// nga skaneri i telefonit tjetër. Ai defekt do të dukej vetëm te njerëzit, në
/// aeroport, kurrë te ne.
library;

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

/// Sa piksel i gjerë të dalë PNG-ja.
///
/// 🚨 Jo më pak: nën ~600 px moduli i QR-it bie nën një piksel te një shtypës
/// 300 dpi mbi një kuti 4 cm — dhe 4 cm mbi një fletë A4 është pikërisht masa
/// që del kur dikush e shtyp QR-in bashkë me udhëzimet.
const int qrPikselat = 1024;

/// Kthe LPA-në në një PNG bardh e zi.
///
/// 🔑 Sfondi është i bardhë me forcë, jo transparent: një PNG transparent i
/// shtypur mbi letër del në rregull, po i hapur te një galeri me temë të errët
/// del QR i zi mbi të zezë — i palexueshëm, pa asnjë shenjë se çfarë ndodhi.
Future<Uint8List> qrPng(String lpa, {int madhesia = qrPikselat}) async {
  final QrPainter piktori = QrPainter(
    data: lpa,
    version: QrVersions.auto,
    gapless: true,
    // 🚨  dhe  janë të vjetruara te qr_flutter 4.1 dhe
    // shpërfillen te disa rrugë vizatimi — pra një QR i bardhë mbi të bardhë
    // do të dilte pa asnjë gabim. Ngjyrat vendosen te stilet, dhe sfondi vjen
    // nga [ui.Canvas] i vetë [QrPainter.toImageData], i cili e mbush me të
    // bardhë kur  nuk jepet.
    eyeStyle: const QrEyeStyle(
      eyeShape: QrEyeShape.square,
      color: Colors.black,
    ),
    dataModuleStyle: const QrDataModuleStyle(
      dataModuleShape: QrDataModuleShape.square,
      color: Colors.black,
    ),
    // 🚨 Pa këtë, sfondi del TRANSPARENT dhe QR-i i zi mbi një galeri me temë
    // të errët është i palexueshëm. Zëvendësuesi që sugjeron paralajmërimi —
    // «ngjyra e kutisë përreth» — nuk ekziston fare kur vizatohet pa widget.
    // ignore: deprecated_member_use
    emptyColor: Colors.white,
  );

  final ByteData? bajtet = await piktori.toImageData(
    madhesia.toDouble(),
    format: ui.ImageByteFormat.png,
  );
  if (bajtet == null) {
    throw StateError('QR-i nuk u vizatua dot te një figurë');
  }
  return bajtet.buffer.asUint8List();
}

/// Emri i skedarit që e shoqëron figurën kudo ku shkon.
///
/// Pa të, blerësi me tre eSIM-e merr tre skedarë «image.png» dhe nuk di cili
/// është cili — pikërisht atëherë kur po qëndron te sporteli i aeroportit.
String emriISkedarit(String emri) {
  final String i = emri.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-');
  final String pastruar = i.replaceAll(RegExp(r'^-+|-+$'), '');
  return 'eSIM-${pastruar.isEmpty ? 'profili' : pastruar}.png';
}

/// Shkruaje PNG-në te një skedar i përkohshëm dhe hap fletën e ndarjes.
///
/// Nga ajo fletë QR-i shkon te shtypësi, te WhatsApp-i i pajisjes së dytë, te
/// Drive-i ose te galeria — të katër rrugët e vërteta për të skanuar një kod
/// që ndodhet te i njëjti telefon.
Future<void> ndajQr({required String lpa, required String emri}) async {
  final Uint8List png = await qrPng(lpa);
  final Directory dosja = await getTemporaryDirectory();
  final File skedari = File('${dosja.path}/${emriISkedarit(emri)}');
  await skedari.writeAsBytes(png, flush: true);

  await Share.shareXFiles(
    <XFile>[XFile(skedari.path, mimeType: 'image/png')],
    subject: 'eSIM — $emri',
    text: 'Kodi QR i eSIM-it «$emri». Skanoje me pajisjen ku do të instalohet.',
  );
}

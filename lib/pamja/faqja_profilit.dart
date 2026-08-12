/// Kodi QR i një profili — qoftë i blerë, qoftë i ruajtur nga vetë blerësi.
library;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../modele/modele.dart';
import '../te_dhena/katalogu.dart';
import 'qr_eksporti.dart';

class FaqjaProfilit extends StatelessWidget {
  const FaqjaProfilit({super.key, required Porosia porosia, required Katalogu katalogu})
      : _porosia = porosia,
        _katalogu = katalogu,
        _esim = null;

  /// Një eSIM i ruajtur me dorë: nuk ka porosi, nuk ka shtet dhe nuk ka çmim —
  /// vetëm emrin dhe kodin. Prandaj një konstruktor i dytë, jo fusha të
  /// zbrazëta që secili ekran duhet t'i kontrollojë.
  const FaqjaProfilit.iImi({super.key, required ESimIm esim})
      : _esim = esim,
        _porosia = null,
        _katalogu = null;

  final Porosia? _porosia;
  final Katalogu? _katalogu;
  final ESimIm? _esim;

  String get _titulli => _esim != null
      ? _esim.emri
      : _katalogu!.shteti(_porosia!.kodiIShtetit).emri;

  String? get _lpa => _esim?.lpa ?? _porosia?.profili?.lpa;

  @override
  Widget build(BuildContext context) {
    final lpa = _lpa;
    return Scaffold(
      appBar: AppBar(title: Text(_titulli)),
      body: lpa == null
          ? const Center(child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('Kjo porosi ende nuk ka profil.'),
            ))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    // Sfondi i bardhë nuk është zbukurim: një QR mbi sfond të
                    // errët nuk lexohet nga shumica e skanerëve.
                    color: Colors.white,
                    child: QrImageView(
                      data: lpa,
                      size: 240,
                      backgroundColor: Colors.white,
                      version: QrVersions.auto,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Si instalohet',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                // Pa emoji: te Windows-i dhe te Play Games PC ato dalin katrorë
                // bosh, dhe një udhëzim instalimi është pikërisht vendi ku një
                // katror bosh e bën lexuesin të dyshojë se gaboi diçka.
                const Text(
                  'Android: Cilësimet → Rrjeti → SIM → Shto eSIM → Skano kodin.\n'
                  'iPhone: Cilësimet → Celulari → Shto eSIM → Përdor kodin QR.\n\n'
                  'Telefoni nuk e skanon dot ekranin e vet. Prandaj ruaje ose dërgoje '
                  'kodin me butonin poshtë, dhe skanoje nga pajisja tjetër — ose '
                  'shtype dhe skanoje nga letra.',
                ),
                const SizedBox(height: 20),
                if (_esim?.shenim != null) _Rreshti('Shënim', _esim!.shenim!),
                if (_porosia?.profili != null)
                  _Rreshti('ICCID', _porosia!.profili!.iccid),
                _Rreshti('LPA', lpa),
                const SizedBox(height: 12),
                // 🚨 Jo te web-i: `path_provider` nuk ka dosje të përkohshme te
                // shfletuesi dhe do të binte me «MissingPluginException» — pra
                // butoni do të ekzistonte te esim.spacecode.tech vetëm për të
                // treguar një gabim. Aty QR-i ruhet me klikim të djathtë.
                if (!kIsWeb) ...<Widget>[
                // 🚨 Ky buton rri MBI atë të kopjimit sepse është zgjidhja e vërtetë e
                // fjalisë më sipër: telefoni nuk e skanon dot ekranin e vet.
                // Kopjimi i LPA-së ndihmon vetëm atë që di ta ngjisë diku.
                FilledButton.icon(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await ndajQr(lpa: lpa, emri: _titulli);
                    } catch (e) {
                      messenger
                        ..clearSnackBars()
                        ..showSnackBar(SnackBar(
                            content: Text('Kodi QR nuk u ruajt dot: $e')));
                    }
                  },
                  icon: const Icon(Icons.ios_share),
                  label: const Text('Ruaj, shtyp ose dërgo kodin QR'),
                ),
                const SizedBox(height: 8),
                ],
                OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: lpa));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context)
                      ..clearSnackBars()
                      ..showSnackBar(const SnackBar(content: Text('LPA-ja u kopjua')));
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Kopjo LPA-në'),
                ),
              ],
            ),
    );
  }
}

class _Rreshti extends StatelessWidget {
  const _Rreshti(this.emri, this.vlera);

  final String emri;
  final String vlera;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 64, child: Text(emri,
              style: Theme.of(context).textTheme.labelMedium)),
          Expanded(child: SelectableText(vlera,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12))),
        ],
      ),
    );
  }
}

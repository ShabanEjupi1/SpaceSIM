/// Profili i blerë: QR-i dhe udhëzimet e instalimit.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../modele/modele.dart';
import '../te_dhena/katalogu.dart';

class FaqjaProfilit extends StatelessWidget {
  const FaqjaProfilit({super.key, required this.porosia, required this.katalogu});

  final Porosia porosia;
  final Katalogu katalogu;

  @override
  Widget build(BuildContext context) {
    final profili = porosia.profili;
    final shteti = katalogu.shteti(porosia.kodiIShtetit);

    return Scaffold(
      appBar: AppBar(title: Text('${shteti.flamuri}  ${shteti.emri}')),
      body: profili == null
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
                      data: profili.lpa,
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
                const Text(
                  '📱 Android: Cilësimet → Rrjeti → SIM → Shto eSIM → Skano kodin.\n'
                  '🍎 iPhone: Cilësimet → Celulari → Shto eSIM → Përdor kodin QR.\n\n'
                  '🚨 Skanoje me një pajisje TJETËR, ose ruaje figurën dhe zgjidhe '
                  'nga galeria — telefoni nuk e skanon dot ekranin e vet.',
                ),
                const SizedBox(height: 20),
                _Rreshti('ICCID', profili.iccid),
                _Rreshti('LPA', profili.lpa),
                if (profili.kodiIAktivizimit != null)
                  _Rreshti('Kodi', profili.kodiIAktivizimit!),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: profili.lpa));
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

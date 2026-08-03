/// «Shto eSIM-in tënd» — ruaj një profil që e ke nga diku tjetër.
library;

import 'package:flutter/material.dart';

import '../modele/modele.dart';
import '../te_dhena/ruajtja.dart';

class FaqjaShto extends StatefulWidget {
  const FaqjaShto({super.key, required this.ruajtja});

  final Ruajtja ruajtja;

  @override
  State<FaqjaShto> createState() => _FaqjaShtoState();
}

class _FaqjaShtoState extends State<FaqjaShto> {
  final _forma = GlobalKey<FormState>();
  final _emri = TextEditingController();
  final _lpa = TextEditingController();
  final _shenim = TextEditingController();
  DateTime? _skadon;

  @override
  void dispose() {
    _emri.dispose();
    _lpa.dispose();
    _shenim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Shto eSIM-in tënd')),
      body: Form(
        key: _forma,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'QR-të e eSIM-eve vijnë me email ose si foto dhe humbin brenda '
              'javës. Ngjite kodin këtu një herë: aplikacioni e rivizaton si QR '
              'sa herë të duhet, edhe pa internet.',
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emri,
              decoration: const InputDecoration(
                labelText: 'Emri',
                hintText: 'p.sh. Gjermani — korrik',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Vëri një emër që e njeh.' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _lpa,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Kodi LPA',
                hintText: r'LPA:1$rsp.example.com$ABCD-1234',
                border: OutlineInputBorder(),
              ),
              validator: (v) => ESimIm.gabimiILpas(v ?? ''),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _shenim,
              decoration: const InputDecoration(
                labelText: 'Shënim (jo i detyrueshëm)',
                hintText: 'sa GB, cili operator, ku vlen',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: Text(_skadon == null
                  ? 'Skadon më… (jo e detyrueshme)'
                  : 'Skadon më ${_skadon!.day}.${_skadon!.month}.${_skadon!.year}'),
              trailing: _skadon == null
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _skadon = null),
                    ),
              onTap: _zgjidhDaten,
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: _ruaj, child: const Text('Ruaj')),
            const SizedBox(height: 12),
            const Text(
              'Ruhet vetëm në këtë telefon. Nuk ka llogari dhe asgjë nuk dërgohet '
              'askund.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _zgjidhDaten() async {
    final tani = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: tani.add(const Duration(days: 30)),
      firstDate: tani.subtract(const Duration(days: 365)),
      lastDate: tani.add(const Duration(days: 365 * 3)),
    );
    if (d != null) setState(() => _skadon = d);
  }

  Future<void> _ruaj() async {
    if (!_forma.currentState!.validate()) return;
    final e = ESimIm(
      id: 'im${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}',
      emri: _emri.text.trim(),
      lpa: _lpa.text.trim(),
      kur: DateTime.now(),
      shenim: _shenim.text.trim().isEmpty ? null : _shenim.text.trim(),
      skadon: _skadon,
    );
    await widget.ruajtja.shtoEsim(e);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }
}

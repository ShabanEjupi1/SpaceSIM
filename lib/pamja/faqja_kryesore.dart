/// Shtrati i aplikacionit: dy skeda — «Blej» dhe «Të miat».
library;

import 'package:flutter/material.dart';

import '../app/ads.dart';
import '../furnizuesi/furnizuesi.dart';
import '../modele/modele.dart';
import '../pagesa/pagesa.dart';
import '../te_dhena/katalogu.dart';
import '../te_dhena/ruajtja.dart';
import 'faqja_paketave.dart';
import 'faqja_porosive.dart';
import 'shenja_e_shtetit.dart';

class FaqjaKryesore extends StatefulWidget {
  const FaqjaKryesore({
    super.key,
    required this.katalogu,
    required this.ruajtja,
    required this.furnizuesi,
    required this.pagesa,
    this.rifreskimi,
  });

  final Katalogu katalogu;
  final Ruajtja ruajtja;
  final Furnizuesi furnizuesi;
  final Pagesa pagesa;

  /// Katalogu i freskët nga furnizuesi, kur të mbërrijë.
  final Future<Katalogu?>? rifreskimi;

  @override
  State<FaqjaKryesore> createState() => _FaqjaKryesoreState();
}

class _FaqjaKryesoreState extends State<FaqjaKryesore> {
  int _skeda = 0;
  String _kerkim = '';
  late List<Porosia> _porosite = widget.ruajtja.porosite();
  late List<ESimIm> _esimet = widget.ruajtja.esimet();
  late Katalogu _katalogu = widget.katalogu;

  @override
  void initState() {
    super.initState();
    // 🚨 `mounted` para `setState`: rifreskimi zgjat sa rrjeti, dhe blerësi
    // mund ta mbyllë ekranin para tij. Pa këtë kontroll, dalja nga aplikacioni
    // gjatë një rrjeti të ngadaltë jep një përjashtim që del vetëm te logu.
    widget.rifreskimi?.then((k) {
      if (k != null && mounted) setState(() => _katalogu = k);
    });
  }

  void _rifresko() => setState(() {
        _porosite = widget.ruajtja.porosite();
        _esimet = widget.ruajtja.esimet();
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('eSIM Space'),
        // 🚨 Shitja kërkon TË DYJA: furnizuesin dhe pagesën. Pa këtë kusht të
        // dyfishtë, një aplikacion me furnizues të lidhur po pa pagesë do të
        // dukej krejt normal dhe do të dështonte vetëm te shtypja e fundit —
        // gjendja e vërtetë e 12→17 gushtit 2026.
        bottom: !(widget.furnizuesi.mundBlihet && widget.pagesa.mundPaguhet)
            ? const _Shiriti('Shitja hapet së shpejti — çmimet janë orientuese')
            : !widget.furnizuesi.iVertete
                ? const _Shiriti(
                    'PROVË — profilet nuk janë të vërteta dhe asgjë nuk paguhet')
                : null,
      ),
      body: _skeda == 0
          ? _blej(context)
          : FaqjaPorosive(
              porosite: _porosite,
              esimet: _esimet,
              katalogu: _katalogu,
              ruajtja: widget.ruajtja,
              rifresko: _rifresko,
              furnizuesi: widget.furnizuesi,
            ),
      // Banderola rri MBI shiritin e lundrimit, jo nën të: nën të ajo do të
      // ishte pikërisht aty ku bie gishti që ndërron skedën, dhe një klikim i
      // pavullnetshëm te reklama është edhe mashtrim ndaj shpalljesit edhe
      // arsyeja numër një pse mbyllen llogaritë e reja të AdMob-it.
      // `mainAxisSize.min` që kolona të mos e marrë krejt ekranin; kur reklama
      // mungon, `BannerSlot` zë zero hapësirë dhe pamja mbetet e njëjta me atë
      // të versionit pa reklama (web, pa rrjet, pëlqim i refuzuar).
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const BannerSlot(),
          NavigationBar(
            selectedIndex: _skeda,
            onDestinationSelected: (i) {
              setState(() => _skeda = i);
              if (i == 1) _rifresko();
            },
            destinations: const [
              NavigationDestination(icon: Icon(Icons.travel_explore), label: 'Blej'),
              NavigationDestination(icon: Icon(Icons.sim_card), label: 'Të miat'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _blej(BuildContext context) {
    final sipasRajonit = _katalogu.sipasRajonit(kerkim: _kerkim);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Ku po shkon?',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() => _kerkim = v),
          ),
        ),
        Expanded(
          // 🚨 Tri gjendje, jo dy. Deri më 17-08-2026 një katalog bosh jepte
          // «Asnjë shtet me këtë emër» — pra i thoshte blerësit se kërkimi i tij
          // ishte i gabuar, kur në të vërtetë lista nuk ishte marrë kurrë.
          child: _katalogu.bosh
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'Lista e paketave nuk u mor.\n\nLidhu në internet një herë '
                      'dhe ajo ruhet te telefoni — pastaj hapet edhe pa rrjet.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : sipasRajonit.isEmpty
                  ? const Center(child: Text('Asnjë shtet me këtë emër.'))
                  : ListView(
                  children: [
                    for (final hyrja in sipasRajonit.entries) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                        child: Text(
                          hyrja.key.toUpperCase(),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                      for (final s in hyrja.value)
                        ListTile(
                          leading: ShenjaEShtetit(s.kodi),
                          title: Text(s.emri),
                          subtitle: Text(_nga(s.kodi)),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => FaqjaPaketave(
                              shteti: s,
                              katalogu: _katalogu,
                              ruajtja: widget.ruajtja,
                              furnizuesi: widget.furnizuesi,
                              pagesa: widget.pagesa,
                            ),
                          )).then((_) => _rifresko()),
                        ),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
        ),
      ],
    );
  }

  String _nga(String kodi) {
    final p = _katalogu.perShtetin(kodi);
    if (p.isEmpty) return 'ende pa oferta';
    return 'nga ${p.first.cmimi} · ${p.length} paketa';
  }
}

/// Shiriti që nuk lejohet të hiqet derisa furnizuesi të jetë i vërtetë.
/// Pa të, dikush mund të paguajë duke menduar se merr internet.
class _Shiriti extends StatelessWidget implements PreferredSizeWidget {
  const _Shiriti(this.teksti);

  final String teksti;

  @override
  Size get preferredSize => const Size.fromHeight(30);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.amber.shade700,
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Text(
        teksti,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12, color: Colors.black, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Shtrati i aplikacionit: dy skeda — «Blej» dhe «Të miat».
library;

import 'package:flutter/material.dart';

import '../furnizuesi/furnizuesi.dart';
import '../modele/modele.dart';
import '../te_dhena/katalogu.dart';
import '../te_dhena/ruajtja.dart';
import 'faqja_paketave.dart';
import 'faqja_porosive.dart';

class FaqjaKryesore extends StatefulWidget {
  const FaqjaKryesore({
    super.key,
    required this.katalogu,
    required this.ruajtja,
    required this.furnizuesi,
  });

  final Katalogu katalogu;
  final Ruajtja ruajtja;
  final Furnizuesi furnizuesi;

  @override
  State<FaqjaKryesore> createState() => _FaqjaKryesoreState();
}

class _FaqjaKryesoreState extends State<FaqjaKryesore> {
  int _skeda = 0;
  String _kerkim = '';
  late List<Porosia> _porosite = widget.ruajtja.porosite();

  void _rifresko() => setState(() => _porosite = widget.ruajtja.porosite());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SpaceSIM'),
        bottom: widget.furnizuesi.iVertete ? null : const _ShiritiProves(),
      ),
      body: _skeda == 0 ? _blej(context) : FaqjaPorosive(
        porosite: _porosite,
        katalogu: widget.katalogu,
      ),
      bottomNavigationBar: NavigationBar(
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
    );
  }

  Widget _blej(BuildContext context) {
    final sipasRajonit = widget.katalogu.sipasRajonit(kerkim: _kerkim);
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
          child: sipasRajonit.isEmpty
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
                          leading: Text(s.flamuri, style: const TextStyle(fontSize: 26)),
                          title: Text(s.emri),
                          subtitle: Text(_nga(s.kodi)),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => FaqjaPaketave(
                              shteti: s,
                              katalogu: widget.katalogu,
                              ruajtja: widget.ruajtja,
                              furnizuesi: widget.furnizuesi,
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
    final p = widget.katalogu.perShtetin(kodi);
    if (p.isEmpty) return 'ende pa oferta';
    return 'nga ${p.first.cmimi} · ${p.length} paketa';
  }
}

/// Shiriti që nuk lejohet të hiqet derisa furnizuesi të jetë i vërtetë.
/// Pa të, dikush mund të paguajë duke menduar se merr internet.
class _ShiritiProves extends StatelessWidget implements PreferredSizeWidget {
  const _ShiritiProves();

  @override
  Size get preferredSize => const Size.fromHeight(30);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.amber.shade700,
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: const Text(
        'PROVË — profilet nuk janë të vërteta dhe asgjë nuk paguhet',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, color: Colors.black, fontWeight: FontWeight.w600),
      ),
    );
  }
}

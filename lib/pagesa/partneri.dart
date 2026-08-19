/// Kodi i partnerit — nga posteri te porosia.
///
/// ═══════════════════════════════════════════════════════════════════════════
/// 🚨 PSE RUHET, DHE NUK LEXOHET THJESHT NGA URL-JA SA HERË
///
/// Vizitori vjen nga një QR te dera e një kafeneje: `…/?partneri=SP-KS-M4T7`.
/// Pastaj shfleton paketat, ndërron faqe, ndoshta e rifreskon aplikacionin, dhe
/// paguan pas dhjetë minutash. Në atë çast URL-ja mund të mos e mbajë më kodin —
/// dhe komisioni i biznesit do të zhdukej pa asnjë shenjë, ndërsa gjithçka
/// tjetër do të dukej e rregullt.
///
/// Prandaj kodi lexohet një herë te nisja dhe **ruhet**. Zëvendësohet vetëm nga
/// një kod i ri te URL-ja: kush skanon posterin e një biznesi tjetër i takon
/// atij biznesi, jo të parit.
///
/// ⛔ NUK ka afat skadimi këtu. Një afat («30 ditë») do të dukej i drejtë, por
/// do të thoshte se një blerës që kthehet pas dy muajsh nuk i sjell asgjë
/// biznesit që ia solli — dhe ai biznes s'do ta merrte vesh kurrë përse numrat
/// e tij bien. Nëse duhet afat, ai vendoset te relaja, ku shihet dhe matet.
library;

import 'package:shared_preferences/shared_preferences.dart';

class Partneri {
  static const _celesi = 'partneri.v1';

  static String? _kodi;

  /// Kodi aktual, ose `null`. Lexohet nga [PagesaPermesReleje.nis].
  static String? get kodi => _kodi;

  /// Thirret një herë te nisja, pasi `SharedPreferences` është gati.
  ///
  /// `urlja` jepet nga jashtë (`Uri.base`) që kjo klasë të provohet pa
  /// shfletues: një provë që kërkon `dart:html` nuk xhirohet dot te CI-ja.
  static Future<void> nis(SharedPreferences p, Uri urlja) async {
    final ngaUrl = _pastro(urlja.queryParameters['partneri']);
    if (ngaUrl != null) {
      _kodi = ngaUrl;
      await p.setString(_celesi, ngaUrl);
      return;
    }
    _kodi = _pastro(p.getString(_celesi));
  }

  /// 🚨 Pastrimi bëhet KËTU, jo te relaja. Kodi vjen nga një adresë publike që
  /// kushdo e shkruan me dorë: pa këtë, çdo varg i gjatë do të kalonte te trupi
  /// i një kërkese pagese. Relaja e kontrollon prapë — dy anët, si gjithmonë.
  static String? _pastro(String? x) {
    if (x == null) return null;
    final t = x.trim().toUpperCase();
    if (t.isEmpty || t.length > 24) return null;
    if (!RegExp(r'^[A-Z0-9-]+$').hasMatch(t)) return null;
    return t;
  }

  /// Vetëm për provat.
  static void pastroPerProva() => _kodi = null;
}

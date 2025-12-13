import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// ===============================
/// DATENMODELL
/// ===============================
class ReisekostenDaten {
  String vorname = '';
  String nachname = '';

  DateTime? start;
  DateTime? ende;

  int tage24h = 0;
  int tage8h = 0;
  double betrag24h = 0;
  double betrag8h = 0;

  double kilometer = 0;
  double kilometerBetrag = 0;

  int uebernachtungen = 0;
  double preisProUebernachtung = 0;
  double uebernachtungskosten = 0;

  double vorschuss = 0;
  double reisekostenGesamt = 0;
  double saldo = 0;
}

void main() {
  runApp(const ReisekostenApp());
}

class ReisekostenApp extends StatelessWidget {
  const ReisekostenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
        ),
      ),
      home: const ReisekostenSeite(),
    );
  }
}

class ReisekostenSeite extends StatefulWidget {
  const ReisekostenSeite({super.key});

  @override
  State<ReisekostenSeite> createState() => _ReisekostenSeiteState();
}

class _ReisekostenSeiteState extends State<ReisekostenSeite> {
  final daten = ReisekostenDaten();

  final _vorname = TextEditingController();
  final _nachname = TextEditingController();
  final _start = TextEditingController();
  final _ende = TextEditingController();
  final _km = TextEditingController();
  final _uePreis = TextEditingController();
  final _vorschuss = TextEditingController();

  bool get _isWebIOS =>
      kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// ===============================
  /// DATE PICKER
  /// ===============================
  Future<void> _pickDateTime(bool isStart) async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d == null) return;

    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (t == null) return;

    final dt = DateTime(d.year, d.month, d.day, t.hour, t.minute);

    setState(() {
      if (isStart) {
        daten.start = dt;
        _start.text = _fmtDate(dt);
      } else {
        daten.ende = dt;
        _ende.text = _fmtDate(dt);
      }
    });
  }

  /// ===============================
  /// KORREKTE BERECHNUNG (DE)
  /// ===============================
  void _berechnen() {
    daten.vorname = _vorname.text.trim();
    daten.nachname = _nachname.text.trim();

    if (daten.start == null || daten.ende == null) return;

    final start = daten.start!;
    final ende = daten.ende!;

    daten.tage24h = 0;
    daten.tage8h = 0;

    final startDate = DateTime(start.year, start.month, start.day);
    final endDate = DateTime(ende.year, ende.month, ende.day);

    if (startDate == endDate) {
      if (ende.difference(start).inHours >= 8) {
        daten.tage8h = 1;
      }
    } else {
      final anreiseStunden =
          startDate.add(const Duration(days: 1)).difference(start).inHours;
      if (anreiseStunden >= 8) daten.tage8h++;

      final abreiseStunden =
          ende.difference(endDate).inHours;
      if (abreiseStunden >= 8) daten.tage8h++;

      final volleTage = endDate.difference(startDate).inDays - 1;
      if (volleTage > 0) daten.tage24h = volleTage;
    }

    daten.betrag24h = daten.tage24h * 28;
    daten.betrag8h = daten.tage8h * 14;

    daten.kilometer = double.tryParse(_km.text.replaceAll(',', '.')) ?? 0;
    daten.kilometerBetrag = daten.kilometer * 0.30;

    daten.preisProUebernachtung =
        double.tryParse(_uePreis.text.replaceAll(',', '.')) ?? 0;
    daten.uebernachtungen =
        endDate.difference(startDate).inDays.clamp(0, 365);
    daten.uebernachtungskosten =
        daten.uebernachtungen * daten.preisProUebernachtung;

    daten.vorschuss =
        double.tryParse(_vorschuss.text.replaceAll(',', '.')) ?? 0;

    daten.reisekostenGesamt =
        daten.betrag24h +
        daten.betrag8h +
        daten.kilometerBetrag +
        daten.uebernachtungskosten;

    daten.saldo = daten.reisekostenGesamt - daten.vorschuss;

    setState(() {});
  }

  /// ===============================
  /// PDF – ORIGINAL TABELLE
  /// ===============================
  Future<void> _pdf() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Reisekostenabrechnung',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 12),
            _pdfLine('Name:', '${daten.vorname} ${daten.nachname}'),
            _pdfLine('Reisebeginn:', _fmtDate(daten.start!)),
            _pdfLine('Reiseende:', _fmtDate(daten.ende!)),
            pw.SizedBox(height: 16),
            pw.Table(
              border: pw.TableBorder.all(),
              columnWidths: {
                0: const pw.FixedColumnWidth(320),
                1: const pw.FixedColumnWidth(120),
              },
              children: [
                _row('Kostenart', 'Betrag', header: true),

                _sectionRow('I Fahrtkosten'),
                _row(
                  'Kilometerpauschale × ${daten.kilometer.toInt()}',
                  _num(daten.kilometerBetrag),
                ),

                _sectionRow('II Übernachtungskosten'),
                _row(
                  'Übernachtungen × ${daten.uebernachtungen}',
                  _num(daten.uebernachtungskosten),
                ),

                _sectionRow('III Verpflegungskosten'),
                _row(
                  '≥ 24 Stunden × ${daten.tage24h}',
                  _num(daten.betrag24h),
                ),
                _row(
                  '≥ 8 Stunden × ${daten.tage8h}',
                  _num(daten.betrag8h),
                ),

                _row('', ''),
                _row('Gesamt', _num(daten.reisekostenGesamt), bold: true),
                _row('Vorschuss', _num(daten.vorschuss)),
                _row(
                  daten.saldo >= 0 ? 'Auszahlung' : 'Rückzahlung',
                  _num(daten.saldo.abs()),
                  bold: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(onLayout: (_) async => pdf.save());
  }

  /// ===============================
  /// UI
  /// ===============================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reisekosten')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _field(_vorname, 'Vorname'),
          _field(_nachname, 'Nachname'),
          const Divider(),
          _dateField(_start, 'Start', () => _pickDateTime(true)),
          _dateField(_ende, 'Ende', () => _pickDateTime(false)),
          const Divider(),
          _field(_km, 'Kilometer'),
          _field(_uePreis, 'Preis pro Übernachtung'),
          _field(_vorschuss, 'Vorschuss'),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: _berechnen, child: const Text('Berechnen')),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed:
                !_isWebIOS && daten.reisekostenGesamt > 0 ? _pdf : null,
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('PDF exportieren'),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.text_snippet),
            label: const Text('Text anzeigen'),
            onPressed: daten.reisekostenGesamt > 0
                ? () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReisekostenTextSeite(daten: daten),
                      ),
                    )
                : null,
          ),
        ],
      ),
    );
  }

  /// ===============================
  /// HELFER
  /// ===============================
  Widget _field(TextEditingController c, String l) =>
      TextField(controller: c, decoration: InputDecoration(labelText: l));

  Widget _dateField(
    TextEditingController c,
    String l,
    VoidCallback onTap,
  ) =>
      GestureDetector(
        onTap: onTap,
        child: AbsorbPointer(
          child: TextField(
            controller: c,
            decoration: InputDecoration(labelText: l),
          ),
        ),
      );

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  String _num(double v) => v.toStringAsFixed(2).replaceAll('.', ',');

  pw.Widget _pdfLine(String l, String v) =>
      pw.Row(children: [pw.Text('$l '), pw.Text(v)]);

  pw.TableRow _row(String l, String r,
      {bool header = false, bool bold = false}) {
    final style = pw.TextStyle(
      fontWeight:
          header || bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    );
    return pw.TableRow(children: [
      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(l, style: style)),
      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(r, style: style)),
    ]);
  }

  pw.TableRow _sectionRow(String t) => pw.TableRow(children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(t, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        ),
        pw.Container(),
      ]);
}

/// ===============================
/// TEXTANSICHT = PDF-STRUKTUR
/// ===============================
class ReisekostenTextSeite extends StatelessWidget {
  final ReisekostenDaten daten;
  const ReisekostenTextSeite({super.key, required this.daten});

  String _num(double v) => v.toStringAsFixed(2).replaceAll('.', ',');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reisekosten – Übersicht')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const Text('Reisekostenabrechnung',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Text('Name: ${daten.vorname} ${daten.nachname}'),
            Text('Reisebeginn: ${daten.start}'),
            Text('Reiseende: ${daten.ende}'),
            const Divider(),
            const Text('I Fahrtkosten', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('Kilometerbetrag: ${_num(daten.kilometerBetrag)} €'),
            const Text('II Übernachtungskosten', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('Übernachtungen: ${_num(daten.uebernachtungskosten)} €'),
            const Text('III Verpflegungskosten', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('24h: ${_num(daten.betrag24h)} €'),
            Text('8h: ${_num(daten.betrag8h)} €'),
            const Divider(),
            Text('Gesamt: ${_num(daten.reisekostenGesamt)} €',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('Vorschuss: ${_num(daten.vorschuss)} €'),
            Text(
              daten.saldo >= 0
                  ? 'Auszahlung: ${_num(daten.saldo)} €'
                  : 'Rückzahlung: ${_num(daten.saldo.abs())} €',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

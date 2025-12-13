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

  // Verpflegung
  int tage24h = 0;
  int tage8h = 0;
  double betrag24h = 0;
  double betrag8h = 0;

  // Fahrtkosten
  double kilometer = 0;
  double kilometerBetrag = 0;

  // Übernachtung
  int uebernachtungen = 0;
  double preisProUebernachtung = 0;
  double uebernachtungskosten = 0;

  // Vorschuss / Summen
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
          labelStyle: TextStyle(color: Colors.black87),
          floatingLabelStyle: TextStyle(color: Colors.indigo),
          border: UnderlineInputBorder(),
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.black),
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

  String _ergebnis = '';

  bool get _isIphoneWeb => kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void dispose() {
    _vorname.dispose();
    _nachname.dispose();
    _start.dispose();
    _ende.dispose();
    _km.dispose();
    _uePreis.dispose();
    _vorschuss.dispose();
    super.dispose();
  }

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
  /// ÜBERNACHTUNGEN (AUTOMATISCH) – wie ursprünglich
  /// ===============================
  int _berechneUebernachtungen(DateTime start, DateTime ende) {
    final s = DateTime(start.year, start.month, start.day);
    final e = DateTime(ende.year, ende.month, ende.day);
    final diff = e.difference(s).inDays;
    return diff > 0 ? diff : 0;
  }

  /// ===============================
  /// BERECHNUNG – wie ursprünglich (8h Start/Ende + volle Tage 24h)
  /// ===============================
  void _berechnen() {
    daten.vorname = _vorname.text.trim();
    daten.nachname = _nachname.text.trim();

    if (daten.start == null || daten.ende == null) {
      setState(() => _ergebnis = 'Start oder Ende fehlt.');
      return;
    }

    final start = daten.start!;
    final ende = daten.ende!;

    if (ende.isBefore(start)) {
      setState(() => _ergebnis = 'Ende liegt vor Start.');
      return;
    }

    // ---------------- VERPFLEGUNG
    daten.tage24h = 0;
    daten.tage8h = 0;

    final sameDay = start.year == ende.year && start.month == ende.month && start.day == ende.day;

    if (sameDay) {
      if (ende.difference(start).inHours >= 8) daten.tage8h = 1;
    } else {
      // erster Tag: von Start bis 24:00
      final nextMidnight = DateTime(start.year, start.month, start.day + 1);
      if (nextMidnight.difference(start).inHours >= 8) daten.tage8h++;

      // letzter Tag: von 00:00 bis Ende
      final startOfEndDay = DateTime(ende.year, ende.month, ende.day);
      if (ende.difference(startOfEndDay).inHours >= 8) daten.tage8h++;

      // volle Tage dazwischen
      final startOfStartDay = DateTime(start.year, start.month, start.day);
      final volleTage = ende.difference(startOfStartDay).inDays - 1;
      if (volleTage > 0) daten.tage24h = volleTage;
    }

    daten.betrag24h = daten.tage24h * 28;
    daten.betrag8h = daten.tage8h * 14;

    // ---------------- KILOMETER
    daten.kilometer = double.tryParse(_km.text.replaceAll(',', '.')) ?? 0;
    daten.kilometerBetrag = daten.kilometer * 0.30;

    // ---------------- ÜBERNACHTUNG
    daten.preisProUebernachtung = double.tryParse(_uePreis.text.replaceAll(',', '.')) ?? 0;
    daten.uebernachtungen = _berechneUebernachtungen(start, ende);
    daten.uebernachtungskosten = daten.uebernachtungen * daten.preisProUebernachtung;

    // ---------------- VORSCHUSS
    daten.vorschuss = double.tryParse(_vorschuss.text.replaceAll(',', '.')) ?? 0;

    // ---------------- SUMMEN
    daten.reisekostenGesamt = daten.betrag24h + daten.betrag8h + daten.kilometerBetrag + daten.uebernachtungskosten;
    daten.saldo = daten.reisekostenGesamt - daten.vorschuss;

    setState(() {
      _ergebnis =
          'Reisekosten gesamt: ${_num(daten.reisekostenGesamt)}\n'
          'Vorschuss: ${_num(daten.vorschuss)}\n'
          '${daten.saldo >= 0 ? 'Auszahlung' : 'Rückzahlung'}: ${_num(daten.saldo.abs())}';
    });
  }

  /// ===============================
  /// PDF – ORIGINAL (Tabelle + I/II/III)
  /// ===============================
  Future<void> _pdf() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (_) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Reisekostenabrechnung',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 12),
              _pdfLine('Name und Vorname:', '${daten.vorname} ${daten.nachname}'),
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
                  _row('Kostenart', 'Rechnungs- bzw.\nPauschbetrag', header: true),
                  _sectionRow('I Fahrtkosten'),
                  _row(
                    'Kilometerpauschale (0,30 pro km) x ${daten.kilometer.toInt()}',
                    _num(daten.kilometerBetrag),
                  ),
                  _sectionRow('II Übernachtungskosten'),
                  _row(
                    'Übernachtungen x ${daten.uebernachtungen}',
                    _num(daten.uebernachtungskosten),
                  ),
                  _sectionRow('III Verpflegungskosten'),
                  _row(
                    'Bei Abwesenheit von mindestens 24 Stunden x ${daten.tage24h}',
                    _num(daten.betrag24h),
                  ),
                  _row(
                    'Bei Abwesenheit von mindestens 8 Stunden x ${daten.tage8h}',
                    _num(daten.betrag8h),
                  ),
                  _row('', ''),
                  _row('Reisekosten gesamt', _num(daten.reisekostenGesamt), bold: true),
                  _row('Vorschuss', _num(daten.vorschuss)),
                  _row(
                    daten.saldo >= 0 ? 'Auszahlung' : 'Rückzahlung',
                    _num(daten.saldo.abs()),
                    bold: true,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (_) async => pdf.save());
  }

  /// ===============================
  /// TEXT-ANSICHT – wie PDF (für iPhone/Web)
  /// ===============================
  void _openTextAnsicht() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TextUebersichtSeite(daten: daten, fmtDate: _fmtDate, numFmt: _num),
      ),
    );
  }

  /// ===============================
  /// PDF-HELFER
  /// ===============================
  pw.Widget _pdfLine(String l, String v) => pw.Row(
        children: [
          pw.SizedBox(
            width: 140,
            child: pw.Text(l, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ),
          pw.Text(v),
        ],
      );

  pw.TableRow _row(
    String l,
    String r, {
    bool header = false,
    bool bold = false,
  }) {
    final style = pw.TextStyle(
      fontSize: header ? 11 : 9,
      fontWeight: header || bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    );
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(l, style: style),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(r, style: style),
        ),
      ],
    );
  }

  pw.TableRow _sectionRow(String title) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(
            title,
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.Container(),
      ],
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  String _num(double v) => v.toStringAsFixed(2).replaceAll('.', ',');

  InputDecoration _dec(String label) => InputDecoration(labelText: label);

  TextField _field(
    TextEditingController c,
    String label, {
    TextInputType? keyboardType,
  }) =>
      TextField(
        controller: c,
        style: const TextStyle(color: Colors.black),
        cursorColor: Colors.indigo,
        keyboardType: keyboardType,
        textInputAction: TextInputAction.next,
        decoration: _dec(label),
      );

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: const Text('Reisekosten')),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            _field(_vorname, 'Vorname'),
            _field(_nachname, 'Nachname'),

            const Divider(),

            GestureDetector(
              onTap: () => _pickDateTime(true),
              child: AbsorbPointer(child: _field(_start, 'Start')),
            ),
            GestureDetector(
              onTap: () => _pickDateTime(false),
              child: AbsorbPointer(child: _field(_ende, 'Ende')),
            ),

            const Divider(),

            _field(_km, 'Kilometer', keyboardType: const TextInputType.numberWithOptions(decimal: true)),
            _field(_uePreis, 'Preis pro Übernachtung', keyboardType: const TextInputType.numberWithOptions(decimal: true)),
            _field(_vorschuss, 'Vorschuss', keyboardType: const TextInputType.numberWithOptions(decimal: true)),

            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _berechnen,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(fontSize: 16),
              ),
              child: const Text('Berechnen'),
            ),

            const SizedBox(height: 16),

            // PDF: auf iPhone-Web deaktiviert, sonst wie gehabt
            ElevatedButton.icon(
              onPressed: (!_isIphoneWeb && daten.reisekostenGesamt > 0) ? _pdf : null,
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('PDF exportieren'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),

            const SizedBox(height: 16),

            // Text anzeigen: nur sinnvoll wenn berechnet wurde
            ElevatedButton.icon(
              onPressed: daten.reisekostenGesamt > 0 ? _openTextAnsicht : null,
              icon: const Icon(Icons.text_snippet),
              label: const Text('Text anzeigen'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),

            if (_ergebnis.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _ergebnis,
                  style: const TextStyle(fontSize: 15),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// ===============================
/// TEXT-ÜBERSICHT – wie PDF (inkl. I/II/III + Tabelle)
/// ===============================
class TextUebersichtSeite extends StatelessWidget {
  final ReisekostenDaten daten;
  final String Function(DateTime) fmtDate;
  final String Function(double) numFmt;

  const TextUebersichtSeite({
    super.key,
    required this.daten,
    required this.fmtDate,
    required this.numFmt,
  });

  TableRow _tRow(String l, String r, {bool header = false, bool bold = false}) {
    final style = TextStyle(
      fontSize: header ? 14 : 13,
      fontWeight: header || bold ? FontWeight.w700 : FontWeight.w400,
    );

    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.all(10),
          child: Text(l, style: style),
        ),
        Padding(
          padding: const EdgeInsets.all(10),
          child: Text(r, style: style, textAlign: TextAlign.right),
        ),
      ],
    );
  }

  TableRow _section(String title) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.all(10),
          child: Text(
            title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox.shrink(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reisekosten – Übersicht')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Reisekostenabrechnung',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),

          Text('Name und Vorname: ${daten.vorname} ${daten.nachname}', style: const TextStyle(fontSize: 14)),
          Text('Reisebeginn: ${fmtDate(daten.start!)}', style: const TextStyle(fontSize: 14)),
          Text('Reiseende:  ${fmtDate(daten.ende!)}', style: const TextStyle(fontSize: 14)),

          const SizedBox(height: 16),

          Table(
            border: TableBorder.all(color: Colors.black54),
            columnWidths: const {
              0: FlexColumnWidth(3.2),
              1: FlexColumnWidth(1.4),
            },
            children: [
              _tRow('Kostenart', 'Rechnungs- bzw.\nPauschbetrag', header: true),

              _section('I Fahrtkosten'),
              _tRow(
                'Kilometerpauschale (0,30 pro km) x ${daten.kilometer.toInt()}',
                numFmt(daten.kilometerBetrag),
              ),

              _section('II Übernachtungskosten'),
              _tRow('Übernachtungen x ${daten.uebernachtungen}', numFmt(daten.uebernachtungskosten)),

              _section('III Verpflegungskosten'),
              _tRow('Bei Abwesenheit von mindestens 24 Stunden x ${daten.tage24h}', numFmt(daten.betrag24h)),
              _tRow('Bei Abwesenheit von mindestens 8 Stunden x ${daten.tage8h}', numFmt(daten.betrag8h)),

              _tRow('', ''),

              _tRow('Reisekosten gesamt', numFmt(daten.reisekostenGesamt), bold: true),
              _tRow('Vorschuss', numFmt(daten.vorschuss)),
              _tRow(daten.saldo >= 0 ? 'Auszahlung' : 'Rückzahlung', numFmt(daten.saldo.abs()), bold: true),
            ],
          ),
        ],
      ),
    );
  }
}

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
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ReisekostenSeite(),
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
  /// ÜBERNACHTUNGEN (AUTOMATISCH)
  /// ===============================
  int _berechneUebernachtungen(DateTime start, DateTime ende) {
    final s = DateTime(start.year, start.month, start.day);
    final e = DateTime(ende.year, ende.month, ende.day);
    final diff = e.difference(s).inDays;
    return diff > 0 ? diff : 0;
  }

  /// ===============================
  /// BERECHNUNG
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

    if (start.year == ende.year &&
        start.month == ende.month &&
        start.day == ende.day) {
      if (ende.difference(start).inHours >= 8) daten.tage8h = 1;
    } else {
      if (DateTime(
            start.year,
            start.month,
            start.day + 1,
          ).difference(start).inHours >=
          8)
        daten.tage8h++;

      if (ende.difference(DateTime(ende.year, ende.month, ende.day)).inHours >=
          8)
        daten.tage8h++;

      final volleTage =
          ende.difference(DateTime(start.year, start.month, start.day)).inDays -
          1;
      if (volleTage > 0) daten.tage24h = volleTage;
    }

    daten.betrag24h = daten.tage24h * 28;
    daten.betrag8h = daten.tage8h * 14;

    // ---------------- KILOMETER
    final km = double.tryParse(_km.text.replaceAll(',', '.')) ?? 0;
    daten.kilometer = km;
    daten.kilometerBetrag = km * 0.30;

    // ---------------- ÜBERNACHTUNG
    final preis = double.tryParse(_uePreis.text.replaceAll(',', '.')) ?? 0;
    daten.uebernachtungen = _berechneUebernachtungen(start, ende);
    daten.preisProUebernachtung = preis;
    daten.uebernachtungskosten = daten.uebernachtungen * preis;

    // ---------------- VORSCHUSS
    daten.vorschuss =
        double.tryParse(_vorschuss.text.replaceAll(',', '.')) ?? 0;

    // ---------------- SUMMEN
    daten.reisekostenGesamt =
        daten.betrag24h +
        daten.betrag8h +
        daten.kilometerBetrag +
        daten.uebernachtungskosten;

    daten.saldo = daten.reisekostenGesamt - daten.vorschuss;

    setState(() {
      _ergebnis =
          'Reisekosten gesamt: ${_num(daten.reisekostenGesamt)}\n'
          'Vorschuss: ${_num(daten.vorschuss)}\n'
          '${daten.saldo >= 0 ? 'Auszahlung' : 'Rückzahlung'}: ${_num(daten.saldo.abs())}';
    });
  }

  /// ===============================
  /// PDF
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
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 12),

              _pdfLine(
                'Name und Vorname:',
                '${daten.vorname} ${daten.nachname}',
              ),
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
                  _row(
                    'Kostenart',
                    'Rechnungs- bzw.\nPauschbetrag',
                    header: true,
                  ),

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

                  _row(
                    'Reisekosten gesamt',
                    _num(daten.reisekostenGesamt),
                    bold: true,
                  ),
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
  /// HELFER
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
            style: pw.TextStyle(
              fontSize: 9, // 👈 kleiner als Tabellenkopf
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        pw.Container(),
      ],
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  String _num(double v) => v.toStringAsFixed(2).replaceAll('.', ',');

  /// ===============================
  /// UI
  /// ===============================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reisekosten')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(
              controller: _vorname,
              decoration: const InputDecoration(labelText: 'Vorname'),
            ),
            TextField(
              controller: _nachname,
              decoration: const InputDecoration(labelText: 'Nachname'),
            ),

            const Divider(),

            GestureDetector(
              onTap: () => _pickDateTime(true),
              child: AbsorbPointer(
                child: TextField(
                  controller: _start,
                  decoration: const InputDecoration(labelText: 'Start'),
                ),
              ),
            ),
            GestureDetector(
              onTap: () => _pickDateTime(false),
              child: AbsorbPointer(
                child: TextField(
                  controller: _ende,
                  decoration: const InputDecoration(labelText: 'Ende'),
                ),
              ),
            ),

            const Divider(),

            TextField(
              controller: _km,
              decoration: const InputDecoration(labelText: 'Kilometer'),
            ),
            TextField(
              controller: _uePreis,
              decoration: const InputDecoration(
                labelText: 'Preis pro Übernachtung',
              ),
            ),
            TextField(
              controller: _vorschuss,
              decoration: const InputDecoration(labelText: 'Vorschuss'),
            ),

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

            ElevatedButton.icon(
              onPressed: daten.reisekostenGesamt > 0 ? _pdf : null,
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('PDF exportieren'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

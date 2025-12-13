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
      ),
      home: const ReisekostenSeite(),
    );
  }
}

/// ===============================
/// HAUPTSEITE
/// ===============================
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

  bool get _isIphone =>
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

  int _berechneUebernachtungen(DateTime start, DateTime ende) {
    final s = DateTime(start.year, start.month, start.day);
    final e = DateTime(ende.year, ende.month, ende.day);
    return e.difference(s).inDays.clamp(0, 365);
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

    daten.tage24h = 0;
    daten.tage8h = 0;

    final diffHours = ende.difference(start).inHours;

    if (diffHours >= 24) {
      daten.tage24h = diffHours ~/ 24;
      if (diffHours % 24 >= 8) daten.tage8h = 1;
    } else if (diffHours >= 8) {
      daten.tage8h = 1;
    }

    daten.betrag24h = daten.tage24h * 28;
    daten.betrag8h = daten.tage8h * 14;

    daten.kilometer = double.tryParse(_km.text.replaceAll(',', '.')) ?? 0;
    daten.kilometerBetrag = daten.kilometer * 0.30;

    daten.preisProUebernachtung =
        double.tryParse(_uePreis.text.replaceAll(',', '.')) ?? 0;
    daten.uebernachtungen = _berechneUebernachtungen(start, ende);
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
              pw.SizedBox(height: 16),

              pw.Text('Name: ${daten.vorname} ${daten.nachname}'),
              pw.Text('Reisebeginn: ${_fmtDate(daten.start!)}'),
              pw.Text('Reiseende: ${_fmtDate(daten.ende!)}'),

              pw.SizedBox(height: 16),

              pw.Text('Kilometer: ${daten.kilometer}'),
              pw.Text('Kilometerbetrag: ${_num(daten.kilometerBetrag)} €'),

              pw.SizedBox(height: 8),

              pw.Text(
                  'Übernachtungen: ${daten.uebernachtungen} → ${_num(daten.uebernachtungskosten)} €'),

              pw.SizedBox(height: 8),

              pw.Text(
                  'Verpflegung 24h: ${daten.tage24h} → ${_num(daten.betrag24h)} €'),
              pw.Text(
                  'Verpflegung 8h: ${daten.tage8h} → ${_num(daten.betrag8h)} €'),

              pw.SizedBox(height: 16),

              pw.Text(
                'Gesamt: ${_num(daten.reisekostenGesamt)} €',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.Text('Vorschuss: ${_num(daten.vorschuss)} €'),
              pw.Text(
                '${daten.saldo >= 0 ? 'Auszahlung' : 'Rückzahlung'}: ${_num(daten.saldo.abs())} €',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
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
  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  String _num(double v) => v.toStringAsFixed(2).replaceAll('.', ',');

  Widget _field(TextEditingController c, String label,
      {TextInputType type = TextInputType.text}) {
    return Container(
      color: Colors.white, // 🔥 iOS Safari Fix
      child: TextField(
        controller: c,
        keyboardType: type,
        style: const TextStyle(color: Colors.black),
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  /// ===============================
  /// UI
  /// ===============================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: const Text('Reisekosten')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          keyboardDismissBehavior:
              ScrollViewKeyboardDismissBehavior.onDrag,
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

            _field(_km, 'Kilometer', type: TextInputType.number),
            _field(_uePreis, 'Preis pro Übernachtung',
                type: TextInputType.number),
            _field(_vorschuss, 'Vorschuss',
                type: TextInputType.number),

            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _berechnen,
              child: const Text('Berechnen'),
            ),

            const SizedBox(height: 16),

            ElevatedButton.icon(
              onPressed:
                  !_isIphone && daten.reisekostenGesamt > 0 ? _pdf : null,
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('PDF exportieren'),
            ),

            if (_isIphone && _ergebnis.isNotEmpty) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.text_snippet),
                label: const Text('Text anzeigen'),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          ReisekostenTextSeite(daten: daten),
                    ),
                  );
                },
              ),
            ],

            if (_ergebnis.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_ergebnis),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// ===============================
/// TEXT-ANSICHT (wie PDF)
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
            Text('Reisekostenabrechnung',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),

            Text('Name: ${daten.vorname} ${daten.nachname}'),
            Text('Reisebeginn: ${daten.start}'),
            Text('Reiseende: ${daten.ende}'),

            const Divider(height: 32),

            Text('Kilometer: ${daten.kilometer}'),
            Text('Kilometerbetrag: ${_num(daten.kilometerBetrag)} €'),

            const SizedBox(height: 12),

            Text(
                'Übernachtungen: ${daten.uebernachtungen} → ${_num(daten.uebernachtungskosten)} €'),

            const SizedBox(height: 12),

            Text(
                'Verpflegung 24h: ${daten.tage24h} → ${_num(daten.betrag24h)} €'),
            Text(
                'Verpflegung 8h: ${daten.tage8h} → ${_num(daten.betrag8h)} €'),

            const Divider(height: 32),

            Text('Gesamt: ${_num(daten.reisekostenGesamt)} €',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('Vorschuss: ${_num(daten.vorschuss)} €'),
            Text(
              '${daten.saldo >= 0 ? 'Auszahlung' : 'Rückzahlung'}: ${_num(daten.saldo.abs())} €',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

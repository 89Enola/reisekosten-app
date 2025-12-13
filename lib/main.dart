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
          labelStyle: TextStyle(color: Colors.black87),
          floatingLabelStyle: TextStyle(color: Colors.indigo),
        ),
        textTheme: const TextTheme(bodyMedium: TextStyle(color: Colors.black)),
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

  bool get _isIphone => kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

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
  /// PDF (unverändert)
  /// ===============================
  Future<void> _pdf() async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(pageFormat: PdfPageFormat.a4, build: (_) => pw.Text(_ergebnis)),
    );
    await Printing.layoutPdf(onLayout: (_) async => pdf.save());
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  String _num(double v) => v.toStringAsFixed(2).replaceAll('.', ',');

  InputDecoration _dec(String label) => InputDecoration(labelText: label);

  TextField _field(TextEditingController c, String label) => TextField(
    controller: c,
    style: const TextStyle(color: Colors.black),
    cursorColor: Colors.indigo,
    decoration: _dec(label),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: const Text('Reisekosten')),
      body: SafeArea(
        child: MediaQuery.removeViewInsets(
          context: context,
          removeBottom: false,
          child: ListView(
            padding: const EdgeInsets.all(16),
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
              _field(_km, 'Kilometer'),
              _field(_uePreis, 'Preis pro Übernachtung'),
              _field(_vorschuss, 'Vorschuss'),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _berechnen,
                child: const Text('Berechnen'),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: !_isIphone && daten.reisekostenGesamt > 0
                    ? _pdf
                    : null,
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('PDF exportieren'),
              ),
              if (_isIphone && _ergebnis.isNotEmpty) ...[
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.text_snippet),
                  label: const Text('Text anzeigen'),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => Padding(
                        padding: const EdgeInsets.all(16),
                        child: SingleChildScrollView(
                          child: Text(
                            _ergebnis,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

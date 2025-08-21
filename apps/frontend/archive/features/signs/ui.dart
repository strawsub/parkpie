import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'controllers.dart';
import 'models.dart';

class SignsDemoPage extends ConsumerStatefulWidget {
  const SignsDemoPage({super.key});
  @override
  ConsumerState<SignsDemoPage> createState() => _SignsDemoPageState();
}

class _SignsDemoPageState extends ConsumerState<SignsDemoPage> {
  final _text = TextEditingController(text: '2P Mon–Fri 8am–6pm');
  final _lat  = TextEditingController(text: '-37.8136');
  final _lng  = TextEditingController(text: '144.9631');
  final _meters = TextEditingController(text: '500');

  List<SignView> _near = [];
  SignView? _created;
  String? _error;

  Future<void> _callHealth() async {
    setState(() => _error = null);
    final h = await ref.read(healthProvider.future);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Health: ok=${h.ok}  DB=${h.dbVersion.split(' ').first}')),
    );
  }

  Future<void> _callPostgis() async {
    setState(() => _error = null);
    final wkt = await ref.read(postgisProvider.future);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PostGIS WKT: $wkt')));
  }

  Future<void> _createSign() async {
    setState(() => _error = null);
    try {
      final req = SignCreateRequest(
        text: _text.text,
        lat: double.parse(_lat.text),
        lng: double.parse(_lng.text),
      );
      final created = await ref.read(createSignProvider(req).future);
      setState(() => _created = created);
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _loadNear() async {
    setState(() => _error = null);
    try {
      final lat = double.parse(_lat.text);
      final lng = double.parse(_lng.text);
      final meters = double.parse(_meters.text);
      final res = await ref.read(
        nearSignsProvider((lat: lat, lng: lng, meters: meters)).future,
      );
      setState(() => _near = res);
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final pad = const EdgeInsets.symmetric(horizontal: 16, vertical: 8);
    return Scaffold(
      appBar: AppBar(title: const Text('ParkPie Demo')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Backend health'),
            trailing: FilledButton(onPressed: _callHealth, child: const Text('GET /health')),
          ),
          ListTile(
            title: const Text('PostGIS check'),
            trailing: FilledButton(onPressed: _callPostgis, child: const Text('GET /health/postgis')),
          ),
          const Divider(),
          Padding(
            padding: pad,
            child: TextField(controller: _text, decoration: const InputDecoration(labelText: 'Sign text')),
          ),
          Row(children: [
            Expanded(child: Padding(padding: pad, child: TextField(controller: _lat, decoration: const InputDecoration(labelText: 'Lat (-90..90)')))),
            Expanded(child: Padding(padding: pad, child: TextField(controller: _lng, decoration: const InputDecoration(labelText: 'Lng (-180..180)')))),
          ]),
          Padding(
            padding: pad,
            child: FilledButton.icon(
              onPressed: _createSign,
              icon: const Icon(Icons.add),
              label: const Text('POST /signs (create)'),
            ),
          ),
          if (_created != null)
            Padding(
              padding: pad,
              child: Text('Created: id=${_created!.id}  "${_created!.text}"  (${_created!.lat}, ${_created!.lng})'),
            ),
          const Divider(),
          Padding(
            padding: pad,
            child: Row(children: [
              Expanded(child: TextField(controller: _meters, decoration: const InputDecoration(labelText: 'Radius meters'))),
              const SizedBox(width: 12),
              FilledButton(onPressed: _loadNear, child: const Text('GET /signs/near')),
            ]),
          ),
          if (_near.isNotEmpty)
            Padding(
              padding: pad,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _near.map((s) => Text('• [${s.id}] ${s.text}  (${s.lat}, ${s.lng})')).toList(),
              ),
            ),
          if (_error != null)
            Padding(padding: pad, child: Text(_error!, style: const TextStyle(color: Colors.red))),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

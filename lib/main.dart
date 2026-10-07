import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import 'services/ble_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GuinchoMissionApp());
}

class GuinchoMissionApp extends StatelessWidget {
  const GuinchoMissionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Guincho Inteligente • Missão 14',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF3F7F7),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF20C6C8),
        ),
      ),
      home: const Mission14Page(),
    );
  }
}

enum AppMode {
  test,
  crane,
}

class Mission14Page extends StatefulWidget {
  const Mission14Page({super.key});

  @override
  State<Mission14Page> createState() => _Mission14PageState();
}

class _Mission14PageState extends State<Mission14Page> {
  static const teal = Color(0xFF20C6C8);
  static const orange = Color(0xFFFF7A00);
  static const red = Color(0xFFD74242);
  static const green = Color(0xFF169B7B);
  static const requiredLabels = <String>[
    'PUNHO',
    'MAO_ABERTA',
    'JOINHA',
    'ESQUERDA',
    'DIREITA',
    'NENHUM',
  ];

  final modelController = TextEditingController();
  final ble = BleService();

  InAppWebViewController? webController;

  AppMode mode = AppMode.test;

  bool webReady = false;
  bool loadingModel = false;
  bool modelReady = false;
  bool espConnected = false;
  bool connectingEsp = false;

  String modelStatus = 'Nenhum modelo carregado';
  String gesture = 'NENHUM';
  double confidence = 0;
  String action = 'PARADO';

  String previousGesture = '';
  int consecutiveCount = 0;
  String lastSentCommand = 'P';

  @override
  void initState() {
    super.initState();
    _requestCameraPermission();
  }

  Future<void> _requestCameraPermission() async {
    await Permission.camera.request();
  }

  Future<void> _requestBluetoothPermissions() async {
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();
  }

  String _normalizeModelUrl(String raw) {
    var value = raw.trim();
    if (value.isEmpty) return '';

    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      value = 'https://$value';
    }

    value = value.replaceFirst(RegExp(r'/model\.json.*$', caseSensitive: false), '/');
    value = value.replaceFirst(RegExp(r'/metadata\.json.*$', caseSensitive: false), '/');

    if (!value.endsWith('/')) value += '/';
    return value;
  }

  Future<void> _loadModel() async {
    final url = _normalizeModelUrl(modelController.text);

    if (url.isEmpty) {
      _snack('Cole o link compartilhável do Teachable Machine.');
      return;
    }

    if (!webReady || webController == null) {
      _snack('A câmera ainda está iniciando. Tente novamente em alguns segundos.');
      return;
    }

    final cameraStatus = await Permission.camera.request();
    if (!cameraStatus.isGranted) {
      _snack('Permita o acesso à câmera para testar o modelo.');
      return;
    }

    setState(() {
      loadingModel = true;
      modelReady = false;
      modelStatus = 'Carregando modelo...';
      gesture = 'NENHUM';
      confidence = 0;
      action = 'PARADO';
    });

    previousGesture = '';
    consecutiveCount = 0;

    await webController!.evaluateJavascript(
      source: 'window.loadClubRobotModel(${jsonEncode(url)});',
    );
  }

  Future<void> _openTeachableMachine() async {
    final uri = Uri.parse('https://teachablemachine.withgoogle.com/train/image');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _snack('Não foi possível abrir o Teachable Machine.');
    }
  }

  Future<void> _connectEsp32() async {
    if (connectingEsp) return;

    await _requestBluetoothPermissions();

    setState(() => connectingEsp = true);

    try {
      final name = await ble.connectToGuincho();

      if (!mounted) return;
      setState(() {
        espConnected = true;
        connectingEsp = false;
      });
      _snack('$name conectado!');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        espConnected = false;
        connectingEsp = false;
        mode = AppMode.test;
      });
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _disconnectEsp32() async {
    await _sendCommand('P', force: true);
    await ble.disconnect();

    if (!mounted) return;
    setState(() {
      espConnected = false;
      mode = AppMode.test;
      action = 'PARADO';
    });
  }

  Future<void> _setMode(AppMode newMode) async {
    if (newMode == AppMode.crane) {
      if (!modelReady) {
        _snack('Carregue um modelo válido antes de controlar o guincho.');
        return;
      }

      if (!espConnected) {
        _snack('Conecte o ESP32 antes de ativar o modo guincho.');
        return;
      }

      previousGesture = '';
      consecutiveCount = 0;
      lastSentCommand = 'P';
    } else {
      await _sendCommand('P', force: true);
      previousGesture = '';
      consecutiveCount = 0;
      if (mounted) setState(() => action = 'PARADO');
    }

    if (mounted) setState(() => mode = newMode);
  }

  Future<void> _handlePrediction(Map<String, dynamic> data) async {
    final label = (data['label'] ?? 'NENHUM').toString().trim().toUpperCase();
    final score = (data['confidence'] as num?)?.toDouble() ?? 0.0;

    if (!mounted) return;

    setState(() {
      gesture = label;
      confidence = score;
    });

    // No modo teste, apenas mostramos o que a IA está vendo.
    if (mode == AppMode.test) {
      setState(() => action = 'TESTANDO IA');
      return;
    }

    // Segurança 1: baixa confiança = parar.
    if (score < 0.85) {
      _resetGestureCounter();
      setState(() => action = 'PARADO • BAIXA CONFIANÇA');
      await _sendCommand('P');
      return;
    }

    // Segurança 2: NENHUM e MÃO ABERTA param imediatamente.
    if (label == 'NENHUM' || label == 'MAO_ABERTA') {
      _resetGestureCounter();
      setState(() => action = 'PARADO');
      await _sendCommand('P');
      return;
    }

    if (!requiredLabels.contains(label)) {
      _resetGestureCounter();
      setState(() => action = 'PARADO • GESTO INVÁLIDO');
      await _sendCommand('P');
      return;
    }

    // Movimentos precisam de 2 leituras iguais consecutivas.
    if (label == previousGesture) {
      consecutiveCount += 1;
    } else {
      previousGesture = label;
      consecutiveCount = 1;
      setState(() => action = 'AGUARDANDO CONFIRMAÇÃO');
      return;
    }

    if (consecutiveCount < 2) return;

    switch (label) {
      case 'PUNHO':
        setState(() => action = 'SUBINDO');
        await _sendCommand('S');
        break;
      case 'JOINHA':
        setState(() => action = 'DESCENDO');
        await _sendCommand('D');
        break;
      case 'ESQUERDA':
        setState(() => action = 'ESQUERDA');
        await _sendCommand('E');
        break;
      case 'DIREITA':
        setState(() => action = 'DIREITA');
        await _sendCommand('R');
        break;
    }

    consecutiveCount = 0;
  }

  void _resetGestureCounter() {
    previousGesture = '';
    consecutiveCount = 0;
  }

  Future<void> _sendCommand(String command, {bool force = false}) async {
    if (!espConnected || !ble.isConnected) return;

    if (!force && lastSentCommand == command) return;

    try {
      await ble.send(command);
      lastSentCommand = command;
    } catch (e) {
      if (!mounted) return;
      setState(() {
        espConnected = false;
        mode = AppMode.test;
        action = 'PARADO';
      });
      _snack('A conexão com o ESP32 foi perdida.');
    }
  }

  Future<void> _emergencyStop() async {
    _resetGestureCounter();
    setState(() => action = 'PARADO • EMERGÊNCIA');
    await _sendCommand('P', force: true);
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    modelController.dispose();
    ble.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(),
              const SizedBox(height: 20),
              _missionCard(),
              const SizedBox(height: 18),
              _modelCard(),
              const SizedBox(height: 18),
              _espCard(),
              const SizedBox(height: 18),
              _metrics(),
              const SizedBox(height: 18),
              _cameraCard(),
              const SizedBox(height: 18),
              _modeCard(),
              const SizedBox(height: 18),
              _actionCard(),
              const SizedBox(height: 18),
              _stopButton(),
              const SizedBox(height: 14),
              _legendCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Column(
      children: [
        Image.asset(
          'assets/images/LOGO.png',
          height: 74,
          errorBuilder: (_, __, ___) => const Icon(
            Icons.smart_toy_outlined,
            size: 62,
            color: teal,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'GUINCHO INTELIGENTE',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.w900,
            color: Color(0xFF1F2222),
          ),
        ),
        const SizedBox(height: 3),
        const Text(
          'Missão 14 • Junior • Minha própria IA',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: Color(0xFF8A9292),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _missionCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('🧠', style: TextStyle(fontSize: 30)),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  '1. Ensine a sua IA',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'No Teachable Machine, crie as 6 classes, tire exemplos dos gestos, treine o modelo e gere o link compartilhável.',
            style: TextStyle(
              fontSize: 15,
              height: 1.35,
              color: Color(0xFF676F6F),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _openTeachableMachine,
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('ABRIR TEACHABLE MACHINE'),
            style: FilledButton.styleFrom(
              backgroundColor: teal,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ],
      ),
    );
  }

  Widget _modelCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('🤖', style: TextStyle(fontSize: 30)),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  '2. Coloque sua IA no app',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: modelController,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: 'Link do seu modelo',
              hintText: 'https://teachablemachine.withgoogle.com/models/...',
              filled: true,
              fillColor: const Color(0xFFF5F8F8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: loadingModel ? null : _loadModel,
            icon: loadingModel
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.cloud_download_rounded),
            label: Text(
              loadingModel ? 'CARREGANDO...' : 'CARREGAR MODELO',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: orange,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
            ),
          ),
          const SizedBox(height: 12),
          _statusLine(
            modelReady ? Icons.check_circle : Icons.info_outline,
            modelStatus,
            modelReady ? green : const Color(0xFF7D8585),
          ),
        ],
      ),
    );
  }

  Widget _espCard() {
    final bg = espConnected
        ? const Color(0xFFE4F8F2)
        : const Color(0xFFFFEAEA);
    final fg = espConnected ? green : red;

    return InkWell(
      borderRadius: BorderRadius.circular(26),
      onTap: espConnected ? _disconnectEsp32 : _connectEsp32,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Row(
          children: [
            Icon(
              espConnected
                  ? Icons.bluetooth_connected_rounded
                  : Icons.bluetooth_disabled_rounded,
              color: fg,
              size: 30,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                connectingEsp
                    ? 'PROCURANDO ESP32...'
                    : espConnected
                        ? 'ESP32 CONECTADO • TOQUE PARA DESCONECTAR'
                        : 'CONECTAR AO ESP32',
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metrics() {
    return Row(
      children: [
        Expanded(
          child: _metricCard(
            _gestureEmoji(gesture),
            'Gesto',
            gesture,
            orange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _metricCard(
            '🎯',
            'Confiança',
            '${(confidence * 100).round()}%',
            teal,
          ),
        ),
      ],
    );
  }

  Widget _cameraCard() {
    return Container(
      height: 300,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFEAF4F4),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 16,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: FutureBuilder<String>(
        future: rootBundle.loadString('assets/web/classifier.html'),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          return InAppWebView(
            initialData: InAppWebViewInitialData(
              data: snapshot.data!,
              baseUrl: WebUri('https://localhost/'),
              historyUrl: WebUri('https://localhost/'),
            ),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              mediaPlaybackRequiresUserGesture: false,
              allowsInlineMediaPlayback: true,
              transparentBackground: true,
              disableVerticalScroll: true,
              disableHorizontalScroll: true,
            ),
            onPermissionRequest: (controller, request) async {
              final status = await Permission.camera.request();

              return PermissionResponse(
                resources: request.resources,
                action: status.isGranted
                    ? PermissionResponseAction.GRANT
                    : PermissionResponseAction.DENY,
              );
            },
            onWebViewCreated: (controller) {
              webController = controller;

              controller.addJavaScriptHandler(
                handlerName: 'webReady',
                callback: (args) {
                  if (mounted) setState(() => webReady = true);
                  return {'ok': true};
                },
              );

              controller.addJavaScriptHandler(
                handlerName: 'modelStatus',
                callback: (args) {
                  if (args.isEmpty) return null;

                  final data =
                      jsonDecode(args.first.toString()) as Map<String, dynamic>;

                  final ok = data['ok'] == true;

                  if (!mounted) return null;

                  if (ok) {
                    final labels = ((data['labels'] as List?) ?? [])
                        .map((e) => e.toString())
                        .toList();

                    setState(() {
                      modelReady = true;
                      loadingModel = false;
                      modelStatus =
                          'Modelo válido! ${labels.length} classes encontradas.';
                    });
                  } else {
                    final reason = data['reason']?.toString() ?? 'erro';

                    if (reason == 'missing_labels') {
                      final missing = ((data['missing'] as List?) ?? [])
                          .join(', ');

                      setState(() {
                        modelReady = false;
                        loadingModel = false;
                        modelStatus =
                            'Faltam classes no modelo: $missing';
                      });
                    } else {
                      setState(() {
                        modelReady = false;
                        loadingModel = false;
                        modelStatus =
                            'Não foi possível carregar esse modelo.';
                      });
                    }

                    mode = AppMode.test;
                  }

                  return {'received': true};
                },
              );

              controller.addJavaScriptHandler(
                handlerName: 'prediction',
                callback: (args) {
                  if (args.isEmpty) return null;

                  final data =
                      jsonDecode(args.first.toString()) as Map<String, dynamic>;

                  _handlePrediction(data);
                  return {'received': true};
                },
              );

              controller.addJavaScriptHandler(
                handlerName: 'classifierError',
                callback: (args) {
                  if (mounted) {
                    setState(() => modelStatus =
                        'A IA encontrou um problema durante o teste.');
                  }
                  return null;
                },
              );

              // A página pode ter enviado webReady antes de o handler existir.
              Future.delayed(const Duration(milliseconds: 500), () {
                if (mounted) setState(() => webReady = true);
              });
            },
          );
        },
      ),
    );
  }

  Widget _modeCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '3. Escolha o modo',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          SegmentedButton<AppMode>(
            segments: const [
              ButtonSegment(
                value: AppMode.test,
                icon: Icon(Icons.science_outlined),
                label: Text('TESTAR IA'),
              ),
              ButtonSegment(
                value: AppMode.crane,
                icon: Icon(Icons.precision_manufacturing_outlined),
                label: Text('CONTROLAR'),
              ),
            ],
            selected: {mode},
            onSelectionChanged: (values) {
              _setMode(values.first);
            },
          ),
          const SizedBox(height: 10),
          Text(
            mode == AppMode.test
                ? 'A IA reconhece os gestos, mas não movimenta o guincho.'
                : 'Os gestos confirmados são enviados ao ESP32.',
            style: const TextStyle(
              color: Color(0xFF777F7F),
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionCard() {
    return _card(
      child: Row(
        children: [
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              color: const Color(0xFFF0F5F4),
              borderRadius: BorderRadius.circular(20),
            ),
            alignment: Alignment.center,
            child: const Text('🏗️', style: TextStyle(fontSize: 32)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ação Atual',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  action,
                  style: TextStyle(
                    color: action.startsWith('PARADO')
                        ? const Color(0xFF8B9292)
                        : teal,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stopButton() {
    return FilledButton.icon(
      onPressed: _emergencyStop,
      icon: const Icon(Icons.stop_circle_outlined, size: 28),
      label: const Text(
        'PARADA DE EMERGÊNCIA',
        style: TextStyle(fontWeight: FontWeight.w900),
      ),
      style: FilledButton.styleFrom(
        backgroundColor: red,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(58),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
      ),
    );
  }

  Widget _legendCard() {
    return _card(
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Gestos da missão',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          SizedBox(height: 10),
          Text('✊ PUNHO → Subir'),
          Text('🖐️ MAO_ABERTA → Parar'),
          Text('👍 JOINHA → Descer'),
          Text('👈 ESQUERDA → Mover para esquerda'),
          Text('👉 DIREITA → Mover para direita'),
          Text('👀 NENHUM → Parar'),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 16,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _metricCard(
    String emoji,
    String title,
    String value,
    Color valueColor,
  ) {
    return Container(
      minHeight: 155,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 35)),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusLine(IconData icon, String text, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }

  String _gestureEmoji(String value) {
    switch (value) {
      case 'PUNHO':
        return '✊';
      case 'MAO_ABERTA':
        return '🖐️';
      case 'JOINHA':
        return '👍';
      case 'ESQUERDA':
        return '👈';
      case 'DIREITA':
        return '👉';
      default:
        return '👀';
    }
  }
}

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'services/ble_service.dart';

void main() => runApp(const RoletaApp());

class RoletaApp extends StatelessWidget {
  const RoletaApp({super.key});
  static const teal = Color(0xFF20C6C8);
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Roleta da Sorte • ClubRobot',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true, scaffoldBackgroundColor: const Color(0xFFF3F7F7), colorScheme: ColorScheme.fromSeed(seedColor: teal)),
    home: const RoletaHomePage(),
  );
}

class Challenge {
  const Challenge(this.emoji, this.title, this.instruction);
  final String emoji, title, instruction;
}
class Category {
  const Category(this.id, this.name, this.label, this.color, this.emoji, this.challenges);
  final String id, name, label, emoji;
  final Color color;
  final List<Challenge> challenges;
}

const categories = <Category>[
  Category('roxo_escuro','Bichos Malucos','ROXO ESCURO',Color(0xFF5E35B1),'🐾',[
    Challenge('🐒','Macaco maluquinho','Imite um macaco por 20 segundos!'),
    Challenge('🐧','Pinguim passeador','Caminhe como um pinguim.'),
    Challenge('🦁','Leão poderoso','Faça o rugido mais poderoso de leão!'),
    Challenge('🐸','Sapo saltitante','Dê três pulinhos de sapo.'),
    Challenge('🐍','Cobra dançarina','Mexa o corpo como uma cobrinha.'),
  ]),
  Category('roxo_claro','Roleta das Caretas','ROXO CLARO',Color(0xFFCE93D8),'😜',[
    Challenge('😲','Surpresa total','Faça a cara de quem viu algo incrível!'),
    Challenge('🍋','Limão azedo','Finja que acabou de provar um limão.'),
    Challenge('😴','Sono pesado','Faça a careta de quem está morrendo de sono.'),
    Challenge('🤪','Careta maluca','Invente uma careta que ninguém fez ainda.'),
    Challenge('😎','Superestrela','Faça sua pose mais famosa.'),
  ]),
  Category('azul','Passinho Robótico','AZUL',Color(0xFF1976D2),'🤖',[
    Challenge('🤖','Robô enferrujado','Dance como um robô que está sem óleo.'),
    Challenge('🦾','Braços mecânicos','Mexa os braços como um robô por 20 segundos.'),
    Challenge('🚀','Decolagem','Finja que é um robô decolando para o espaço.'),
    Challenge('⚙️','Modo lento','Faça três movimentos de robô bem devagar.'),
    Challenge('💃','Dança do futuro','Invente um passinho robótico.'),
  ]),
  Category('verde','Caça às Cores','VERDE',Color(0xFF2E7D32),'🔎',[
    Challenge('🟦','Caça azul','Encontre um objeto azul por perto.'),
    Challenge('🔴','Algo redondo','Encontre um objeto redondo.'),
    Challenge('📚','Pequeno explorador','Encontre algo que tenha letras.'),
    Challenge('🌿','Natureza','Aponte para algo que lembre a natureza.'),
    Challenge('⭐','Algo especial','Encontre um objeto que você gosta muito.'),
  ]),
  Category('amarelo_a','Cérebro Turbo','AMARELO A',Color(0xFFF9A825),'🧠',[
    Challenge('➕','Conta rápida','Quanto é 3 + 4?'),
    Challenge('🐾','Charada animal','Quem mia e gosta de dormir em caixas?'),
    Challenge('🔢','Número secreto','Conte de 1 até 10 bem rapidinho.'),
    Challenge('🍎','Frutas','Fale o nome de três frutas.'),
    Challenge('🌞','Adivinha','O que aparece no céu durante o dia e ilumina tudo?'),
  ]),
  Category('laranja','Desafio Maluco','LARANJA',Color(0xFFEF6C00),'🎉',[
    Challenge('👏','Palmas turbo','Bata palmas cinco vezes.'),
    Challenge('🌀','Giro divertido','Dê uma volta devagar no próprio lugar, se houver espaço.'),
    Challenge('🦩','Equilíbrio','Tente ficar em um pé por cinco segundos.'),
    Challenge('🐢','Câmera lenta','Atravesse um pequeno espaço em câmera lenta.'),
    Challenge('🙌','Estátua','Fique parado como uma estátua por cinco segundos.'),
  ]),
  Category('amarelo_b','Mestre das Palavras','AMARELO B',Color(0xFFFFC928),'💬',[
    Challenge('🐱','Rima com gato','Diga uma palavra que rime com gato.'),
    Challenge('🍓','Palavras de comida','Fale três comidas de que você gosta.'),
    Challenge('🔠','Letra M','Diga três palavras que começam com M.'),
    Challenge('🎈','Complete a frase','Complete: “Se eu pudesse voar, eu...”'),
    Challenge('🐶','Vozes engraçadas','Diga “bom dia” com voz de robô.'),
  ]),
  Category('vermelho','Desafio Relâmpago','VERMELHO',Color(0xFFD74242),'⏱️',[
    Challenge('👏','Palmas relâmpago','Bata palmas cinco vezes antes do tempo acabar.'),
    Challenge('🦶','Pés ligeiros','Marche no lugar contando até dez.'),
    Challenge('😄','Sorriso gigante','Mostre seu maior sorriso!'),
    Challenge('🧍','Estátua relâmpago','Faça uma pose e fique parado por cinco segundos.'),
    Challenge('🌈','Cores na cabeça','Fale três cores diferentes.'),
  ]),
];

class RoletaHomePage extends StatefulWidget {
  const RoletaHomePage({super.key});
  @override
  State<RoletaHomePage> createState() => _RoletaHomePageState();
}
class _RoletaHomePageState extends State<RoletaHomePage> {
  static const teal = Color(0xFF20C6C8), orange = Color(0xFFFF7A00);
  final _random = Random();
  final _ble = BleService();
  Category? category;
  Challenge? challenge;
  Timer? timer;
  int seconds = 20, completed = 0;
  bool running = false, connecting = false, connected = false;
  String connectionStatus = 'ESP32 não conectado';

  @override
  void dispose() {
    timer?.cancel();
    _ble.dispose();
    super.dispose();
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(text), behavior: SnackBarBehavior.floating));
  }

  Future<void> _connect() async {
    if (connecting || connected) return;
    setState(() { connecting = true; connectionStatus = 'Procurando ESP32...'; });
    try {
      await [Permission.bluetoothScan, Permission.bluetoothConnect].request();
      final name = await _ble.connect();
      if (!mounted) return;
      setState(() { connected = true; connecting = false; connectionStatus = '$name conectado'; });
      _snack('ESP32 conectado! O LED vai acompanhar os desafios.');
    } catch (e) {
      if (!mounted) return;
      setState(() { connected = false; connecting = false; connectionStatus = 'ESP32 não conectado'; });
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _disconnect() async {
    timer?.cancel();
    if (_ble.isConnected) {
      try { await _ble.send('STOP'); } catch (_) {}
      await _ble.disconnect();
    }
    if (!mounted) return;
    setState(() { connected = false; connecting = false; connectionStatus = 'ESP32 não conectado'; running = false; seconds = 20; });
  }

  void _choose(Category chosen) {
    if (running) { _snack('Termine o desafio atual antes de escolher outra cor.'); return; }
    final list = chosen.challenges;
    var next = list[_random.nextInt(list.length)];
    if (list.length > 1 && challenge?.title == next.title) next = list[(list.indexOf(next) + 1) % list.length];
    setState(() { category = chosen; challenge = next; seconds = 20; });
  }

  Future<void> _start() async {
    if (challenge == null || running) return;
    setState(() { running = true; seconds = 20; });
    if (connected && _ble.isConnected) {
      try { await _ble.send('START'); } catch (_) { _snack('O LED não respondeu. O cronômetro continua no app.'); }
    }
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (!mounted) { t.cancel(); return; }
      if (seconds <= 1) { t.cancel(); await _finish(false); }
      else { setState(() => seconds--); }
    });
  }

  Future<void> _finish(bool didComplete) async {
    timer?.cancel();
    if (connected && _ble.isConnected) {
      try { await _ble.send('STOP'); } catch (_) {}
    }
    if (!mounted) return;
    setState(() { running = false; seconds = 20; if (didComplete) completed++; });
    _snack(didComplete ? 'Mandou bem! Desafio concluído! 🎉' : 'Tempo encerrado! Vamos para o próximo?');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _header(), const SizedBox(height: 18), _introCard(), const SizedBox(height: 16),
        _connectionCard(), const SizedBox(height: 18), const Text('1. Qual cor saiu na roleta?',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4), const Text('Escolha uma das oito cores para sortear uma missão.',
          style: TextStyle(fontSize: 14, color: Color(0xFF737D7D))),
        const SizedBox(height: 10), _grid(), const SizedBox(height: 18),
        if (challenge != null) _challengeCard(), const SizedBox(height: 12),
        Text('Desafios concluídos: $completed', textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: Color(0xFF7A8585), fontWeight: FontWeight.w700)),
        const SizedBox(height: 6), const Text('ClubRobot • Aprender brincando!', textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: teal, fontWeight: FontWeight.w900)),
      ]),
    )),
  );

  Widget _header() => Column(children: [
    Image.asset('assets/images/LOGO.png', height: 66,
      errorBuilder: (_, __, ___) => const Icon(Icons.smart_toy_outlined, size: 60, color: teal)),
    const SizedBox(height: 8),
    const Text('ROLETA DA SORTE', textAlign: TextAlign.center,
      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF1F2222), letterSpacing: .3)),
    const SizedBox(height: 3),
    const Text('Missão 12 • Junior • Gire, escolha e divirta-se!', textAlign: TextAlign.center,
      style: TextStyle(fontSize: 14, color: Color(0xFF7A8585), fontWeight: FontWeight.w600)),
  ]);

  Widget _card({required Widget child, Color color = Colors.white}) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(22),
      boxShadow: const [BoxShadow(color: Color(0x0D142828), blurRadius: 14, offset: Offset(0, 5))]),
    child: child,
  );

  Widget _introCard() => _card(child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text('🎡', style: TextStyle(fontSize: 38)), SizedBox(width: 12),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Sua vez de girar!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
      SizedBox(height: 6),
      Text('Gire a roleta física, toque na cor que saiu e descubra o desafio surpresa.',
        style: TextStyle(fontSize: 15, height: 1.35, color: Color(0xFF676F6F))),
    ])),
  ]));

  Widget _connectionCard() => _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      const Icon(Icons.bluetooth_rounded, color: teal, size: 26), const SizedBox(width: 8),
      const Expanded(child: Text('Circuito ClubRobot', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
      Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: connected ? const Color(0xFFE0F5EE) : const Color(0xFFF1F3F3), borderRadius: BorderRadius.circular(20)),
        child: Text(connected ? 'CONECTADO' : 'OPCIONAL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900,
          color: connected ? const Color(0xFF168466) : const Color(0xFF727B7B)))),
    ]),
    const SizedBox(height: 8), Text(connectionStatus, style: const TextStyle(color: Color(0xFF6D7777), fontSize: 14)),
    const SizedBox(height: 10), SizedBox(width: double.infinity, child: connected
      ? OutlinedButton.icon(onPressed: _disconnect, icon: const Icon(Icons.bluetooth_disabled), label: const Text('DESCONECTAR ESP32'))
      : FilledButton.icon(onPressed: connecting ? null : _connect,
        icon: connecting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.bluetooth_searching),
        label: Text(connecting ? 'PROCURANDO...' : 'CONECTAR ESP32'),
        style: FilledButton.styleFrom(backgroundColor: teal, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(46)))),
    const SizedBox(height: 4), const Text('Sem o ESP32, o app também funciona: os desafios e o cronômetro ficam no celular.',
      style: TextStyle(fontSize: 12, color: Color(0xFF8A9292), height: 1.3)),
  ]));

  Widget _grid() => GridView.builder(
    shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: categories.length,
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.18),
    itemBuilder: (context, i) {
      final item = categories[i], isSelected = category?.id == categories[i].id;
      final darkText = item.id == 'roxo_claro' || item.id == 'amarelo_a' || item.id == 'amarelo_b';
      final textColor = darkText ? const Color(0xFF282323) : Colors.white;
      return Material(color: item.color, borderRadius: BorderRadius.circular(20),
        child: InkWell(borderRadius: BorderRadius.circular(20), onTap: running ? null : () => _choose(item),
          child: Container(padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isSelected ? teal : Colors.transparent, width: 4)),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(item.emoji, style: const TextStyle(fontSize: 27)), const SizedBox(height: 4),
              Text(item.label, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: textColor)),
              const SizedBox(height: 3), Text(item.name, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor)),
              if (isSelected) Padding(padding: const EdgeInsets.only(top: 2), child: Icon(Icons.check_circle, color: textColor, size: 15)),
            ]),
          ),
        ),
      );
    },
  );

  Widget _challengeCard() {
    final chosen = category!, task = challenge!;
    return _card(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        const Expanded(child: Text('2. Seu desafio é...', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
        if (completed > 0) Text('🏆 $completed', style: const TextStyle(fontWeight: FontWeight.w800)),
      ]),
      const SizedBox(height: 14),
      Container(padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: chosen.color.withValues(alpha: .12), borderRadius: BorderRadius.circular(18)),
        child: Column(children: [
          Text(task.emoji, style: const TextStyle(fontSize: 66)), const SizedBox(height: 8),
          Text(task.title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8), Text(task.instruction, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, height: 1.35, color: Color(0xFF4F5A5A))),
        ]),
      ),
      const SizedBox(height: 14),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.timer_outlined, color: running ? orange : teal, size: 24), const SizedBox(width: 8),
        Text(running ? '$seconds s' : '20 segundos', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
      ]),
      const SizedBox(height: 8),
      ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: running ? seconds / 20 : 0,
        minHeight: 8, backgroundColor: const Color(0xFFE8EEEE), color: running ? orange : teal)),
      const SizedBox(height: 14),
      if (!running) ...[
        FilledButton.icon(onPressed: _start, icon: const Icon(Icons.play_arrow_rounded), label: const Text('COMEÇAR DESAFIO'),
          style: FilledButton.styleFrom(backgroundColor: orange, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(52))),
        const SizedBox(height: 8),
        OutlinedButton.icon(onPressed: () => _choose(chosen), icon: const Icon(Icons.shuffle_rounded), label: const Text('SORTEAR OUTRO DESAFIO')),
        const SizedBox(height: 8),
        TextButton.icon(onPressed: () => setState(() { category = null; challenge = null; }),
          icon: const Icon(Icons.refresh_rounded), label: const Text('ESCOLHER OUTRA COR')),
      ] else ...[
        FilledButton.icon(onPressed: () => _finish(true), icon: const Icon(Icons.check_circle_outline), label: const Text('CONSEGUI!'),
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF169B7B), foregroundColor: Colors.white, minimumSize: const Size.fromHeight(52))),
        const SizedBox(height: 8),
        OutlinedButton.icon(onPressed: () => _finish(false), icon: const Icon(Icons.stop_circle_outlined), label: const Text('ENCERRAR DESAFIO')),
      ],
    ]));
  }
}

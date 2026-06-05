import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: TelaComPlanoDeFundo(),
    );
  }
}

class TelaComPlanoDeFundo extends StatefulWidget {
  @override
  _TelaComPlanoDeFundoState createState() => _TelaComPlanoDeFundoState();
}

class _TelaComPlanoDeFundoState extends State<TelaComPlanoDeFundo> {
  final TextEditingController _controller = TextEditingController();
  final FlutterTts flutterTts = FlutterTts();

  bool mostrarTodas = true;
  String? letraSelecionada;
  List<Map<String, String>> resultados = [];
  List<Map<String, String>> favoritos = [];
  bool carregando = false;

  /// true = busca em português
  /// false = busca em Asuriní
  bool buscaEmPortugues = true;

  final Map<String, String> pronunciaPersonalizada = {
    'KWÉ': 'kué',
  };

  final letras =
  'A B C D E F G H I J K L M N O P Q R S T U V W X Y Z'.split(' ');

  @override
  void initState() {
    super.initState();
    carregarFavoritos();
    carregarPreferenciaIdioma();
  }

  String normalizarParaTts(String texto) {
    if (texto.isEmpty) return texto;

    String t = texto;

    pronunciaPersonalizada.forEach((chave, valor) {
      t = t.replaceAll(
        RegExp(
          r'\b' + RegExp.escape(chave) + r'\b',
          caseSensitive: false,
        ),
        valor,
      );
    });

    return t.toLowerCase().trim();
  }

  Future<void> carregarPreferenciaIdioma() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      buscaEmPortugues = prefs.getBool('buscaEmPortugues') ?? true;
    });
  }

  Future<void> salvarPreferenciaIdioma() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('buscaEmPortugues', buscaEmPortugues);
  }

  String getCollectionName() {
    return buscaEmPortugues ? 'Dicionario' : 'Asurini';
  }

  String getCampoBusca() {
    return buscaEmPortugues ? 'portugues' : 'asurini';
  }

  String getCampoResultado() {
    return 'traducao';
  }

  void alternarIdiomaBusca() {
    setState(() {
      buscaEmPortugues = !buscaEmPortugues;
      letraSelecionada = null;
      resultados = [];
      _controller.clear();
    });

    salvarPreferenciaIdioma();
  }

  Future<void> carregarFavoritos() async {
    final prefs = await SharedPreferences.getInstance();
    final favs = prefs.getStringList('favoritos') ?? [];

    setState(() {
      favoritos = favs
          .map((f) => Map<String, String>.from(json.decode(f)))
          .toList();
    });
  }

  Future<void> salvarFavoritos() async {
    final prefs = await SharedPreferences.getInstance();
    final favs = favoritos.map((f) => json.encode(f)).toList();

    await prefs.setStringList('favoritos', favs);
  }

  void alternarFavorito(Map<String, String> palavra) async {
    final jaFavoritado = favoritos.any(
          (fav) =>
      fav['palavra'] == palavra['palavra'] &&
          fav['traducao'] == palavra['traducao'],
    );

    setState(() {
      if (jaFavoritado) {
        favoritos.removeWhere(
              (f) =>
          f['palavra'] == palavra['palavra'] &&
              f['traducao'] == palavra['traducao'],
        );
      } else {
        favoritos.add(palavra);
      }
    });

    await salvarFavoritos();
  }

  bool ehFavorito(Map<String, String> palavra) {
    return favoritos.any(
          (fav) =>
      fav['palavra'] == palavra['palavra'] &&
          fav['traducao'] == palavra['traducao'],
    );
  }

  Future<void> onBuscarPressed(String texto) async {
    if (texto.trim().isEmpty) return;

    setState(() {
      carregando = true;
      letraSelecionada = null;
      resultados = [];
    });

    try {
      final collection = getCollectionName();
      final campoBusca = getCampoBusca();
      final campoResultado = getCampoResultado();
      final textoBusca = texto.trim().toLowerCase();

      final snapshot = await FirebaseFirestore.instance
          .collection(collection)
          .where(campoBusca, isGreaterThanOrEqualTo: textoBusca)
          .where(campoBusca, isLessThanOrEqualTo: '$textoBusca\uf8ff')
          .orderBy(campoBusca)
          .limit(50)
          .get();

      final List<Map<String, String>> lista = snapshot.docs.map((doc) {
        final dados = doc.data() as Map<String, dynamic>;

        return {
          'palavra': (dados[campoBusca] ?? '').toString(),
          'traducao': (dados[campoResultado] ?? '').toString(),
        };
      }).toList();

      if (!mounted) return;

      setState(() {
        resultados = lista;
        carregando = false;
      });
    } catch (e, st) {
      print('Erro ao buscar texto: $e\n$st');

      if (mounted) {
        setState(() {
          carregando = false;
        });
      }
    }
  }

  Future<void> onLetraPressed(String letra) async {
    setState(() {
      letraSelecionada = letra;
      carregando = true;
      resultados = [];
    });

    try {
      final proxima = String.fromCharCode(
        letra.toUpperCase().codeUnitAt(0) + 1,
      );

      final collection = getCollectionName();
      final campoBusca = getCampoBusca();
      final campoResultado = getCampoResultado();

      final snapshot = await FirebaseFirestore.instance
          .collection(collection)
          .where(campoBusca, isGreaterThanOrEqualTo: letra.toLowerCase())
          .where(campoBusca, isLessThan: proxima.toLowerCase())
          .orderBy(campoBusca)
          .limit(50)
          .get();

      final List<Map<String, String>> lista = snapshot.docs.map((doc) {
        final dados = doc.data() as Map<String, dynamic>;

        return {
          'palavra': (dados[campoBusca] ?? '').toString(),
          'traducao': (dados[campoResultado] ?? '').toString(),
        };
      }).toList();

      if (!mounted) return;

      setState(() {
        resultados = lista;
        carregando = false;
      });
    } catch (e, st) {
      print('Erro ao buscar por letra: $e\n$st');

      if (mounted) {
        setState(() {
          carregando = false;
        });
      }
    }
  }

  Future<List<Map<String, String>>> suggestionsFor(String pattern) async {
    if (pattern.trim().isEmpty) return [];

    final collection = getCollectionName();
    final campoBusca = getCampoBusca();
    final campoResultado = getCampoResultado();
    final textoBusca = pattern.trim().toLowerCase();

    final snapshot = await FirebaseFirestore.instance
        .collection(collection)
        .where(campoBusca, isGreaterThanOrEqualTo: textoBusca)
        .where(campoBusca, isLessThanOrEqualTo: '$textoBusca\uf8ff')
        .orderBy(campoBusca)
        .limit(10)
        .get();

    return snapshot.docs.map((doc) {
      final dados = doc.data() as Map<String, dynamic>;

      return {
        'palavra': (dados[campoBusca] ?? '').toString(),
        'traducao': (dados[campoResultado] ?? '').toString(),
      };
    }).toList();
  }

  Future<void> falarTexto(String texto) async {
    await flutterTts.setLanguage('pt-BR');
    await flutterTts.setPitch(1.0);
    await flutterTts.setSpeechRate(0.7);

    final saida = normalizarParaTts(texto);
    await flutterTts.speak(saida);
  }

  Widget construirListaResultados(List<Map<String, String>> lista) {
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: lista.length,
      itemBuilder: (context, index) {
        final item = lista[index];
        final favorito = ehFavorito(item);

        final palavraPrincipal = item['palavra'] ?? '';
        final traducao = item['traducao'] ?? '';

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 7.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '•',
                style: TextStyle(
                  fontSize: 20,
                  color: Colors.brown[800],
                  height: 1.5,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            palavraPrincipal.toUpperCase(),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                              color: Color(0xFF315B2D),
                              letterSpacing: 1.6,
                            ),
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(
                            Icons.volume_up,
                            color: Color(0xFF6B3A27),
                          ),
                          onPressed: () => falarTexto(palavraPrincipal),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: Icon(
                            favorito ? Icons.star : Icons.star_border,
                            color: favorito
                                ? Colors.amber
                                : const Color(0xFF7B6A5A),
                          ),
                          onPressed: () => alternarFavorito(item),
                        ),
                      ],
                    ),
                    Text(
                      traducao,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF6B6E4F),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/fundo.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final h = constraints.maxHeight;

              return Stack(
                children: [
                  Positioned(
                    top: h * 0.115,
                    left: w * 0.17,
                    right: w * 0.17,
                    child: _campoBuscaModelo(h),
                  ),
                  Positioned(
                    top: h * 0.118,
                    right: w * 0.065,
                    child: _botaoAlternarIdiomaModelo(),
                  ),
                  Positioned(
                    top: h * 0.435,
                    left: w * 0.12,
                    right: w * 0.12,
                    child: _areaAbasEConteudoModelo(w, h),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _campoBuscaModelo(double h) {
    final double alturaBusca = (h * 0.052).clamp(48.0, 62.0).toDouble();

    return Container(
      height: alturaBusca,
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E8).withOpacity(0.56),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(
          color: const Color(0xFF6B3A27),
          width: 1.4,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          const Icon(
            Icons.search,
            color: Color(0xFF2D1B10),
            size: 27,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TypeAheadField<Map<String, String>>(
              suggestionsCallback: suggestionsFor,
              itemBuilder: (context, suggestion) {
                return ListTile(
                  title: Text(suggestion['palavra'] ?? ''),
                  subtitle: Text(suggestion['traducao'] ?? ''),
                );
              },
              onSelected: (suggestion) {
                _controller.text = suggestion['palavra'] ?? '';
                onBuscarPressed(_controller.text);
              },
              controller: _controller,
              builder: (context, controller, focusNode) {
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  style: const TextStyle(
                    color: Color(0xFF2D1B10),
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    hintText: buscaEmPortugues
                        ? 'Digite em português...'
                        : 'Digite em Asuriní...',
                    hintStyle: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 16,
                    ),
                  ),
                  onSubmitted: (value) {
                    FocusScope.of(context).unfocus();
                    onBuscarPressed(value);
                  },
                );
              },
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.send_rounded,
              color: Color(0xFF5A241A),
              size: 29,
            ),
            onPressed: () {
              FocusScope.of(context).unfocus();
              onBuscarPressed(_controller.text);
            },
          ),
        ],
      ),
    );
  }

  Widget _botaoAlternarIdiomaModelo() {
    return Semantics(
      button: true,
      label: buscaEmPortugues
          ? 'Busca em português. Toque para buscar em Asuriní.'
          : 'Busca em Asuriní. Toque para buscar em português.',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: alternarIdiomaBusca,
          borderRadius: BorderRadius.circular(50),
          child: Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7E8).withOpacity(0.72),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF6B3A27),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: buscaEmPortugues
                ? ClipOval(
              child: Image.asset(
                'assets/brasil.png',
                width: 28,
                height: 28,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Text(
                    '🇧🇷',
                    style: TextStyle(fontSize: 22),
                  );
                },
              ),
            )
                : Image.asset(
              'assets/pena.png',
              width: 28,
              height: 28,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const Text(
                  '🪶',
                  style: TextStyle(fontSize: 24),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _areaAbasEConteudoModelo(double w, double h) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _abaModelo('Todas', true),
            _abaModelo(
              'Favoritas',
              false,
              icone: Icons.star,
            ),
          ],
        ),
        SizedBox(height: h * 0.024),
        SizedBox(
          height: h * 0.300,
          child: mostrarTodas
              ? _conteudoTodasModelo(w, h)
              : favoritos.isEmpty
              ? const Center(
            child: Text(
              'Nenhuma palavra favoritada',
              style: TextStyle(
                color: Color(0xFF3A2A1E),
                fontSize: 16,
              ),
            ),
          )
              : construirListaResultados(favoritos),
        ),
      ],
    );
  }

  Widget _abaModelo(
      String titulo,
      bool todas, {
        IconData? icone,
      }) {
    final ativa = mostrarTodas == todas;

    return GestureDetector(
      onTap: () {
        setState(() {
          mostrarTodas = todas;
          letraSelecionada = null;
          resultados = [];
        });
      },
      child: Column(
        children: [
          Row(
            children: [
              if (icone != null) ...[
                Icon(
                  icone,
                  color: const Color(0xFF3A2A1E),
                  size: 23,
                ),
                const SizedBox(width: 8),
              ],
              Text(
                titulo,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: ativa
                      ? const Color(0xFF315B2D)
                      : const Color(0xFF3A2A1E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 3,
            width: titulo == 'Todas' ? 82 : 108,
            decoration: BoxDecoration(
              color: ativa ? const Color(0xFF315B2D) : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _conteudoTodasModelo(double w, double h) {
    if (carregando) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(
            Color(0xFF6B3A27),
          ),
        ),
      );
    }

    if (resultados.isNotEmpty) {
      return construirListaResultados(resultados);
    }

    if (letraSelecionada != null) {
      return const Center(
        child: Text(
          'Nenhuma palavra encontrada para esta letra',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF3A2A1E),
            fontSize: 16,
          ),
        ),
      );
    }

    return _gradeLetrasModelo(w, h);
  }

  Widget _gradeLetrasModelo(double w, double h) {
    return GridView.builder(
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: letras.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        crossAxisSpacing: 9,
        mainAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemBuilder: (context, index) {
        final letra = letras[index];
        final letraVisualmenteSelecionada = letraSelecionada ?? 'A';
        final selecionada = letraVisualmenteSelecionada == letra;

        return GestureDetector(
          onTap: () => onLetraPressed(letra),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selecionada
                  ? const Color(0xFF315B2D)
                  : const Color(0xFFFFF1D9).withOpacity(0.78),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: selecionada
                    ? const Color(0xFF315B2D)
                    : const Color(0xFFE2C9A5),
                width: 1.2,
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final tamanhoFonte = constraints.maxWidth * 0.45;

                return Text(
                  letra,
                  style: TextStyle(
                    fontSize: tamanhoFonte,
                    fontWeight: FontWeight.bold,
                    color: selecionada
                        ? Colors.white
                        : const Color(0xFF2D241B),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
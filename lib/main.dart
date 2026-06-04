import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: TelaComPlanoDeFundo());
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

  /// true = busca em português (usa coleção 'Dicionario')
  /// false = busca em Asurini (usa coleção 'Assurini')
  bool buscaEmPortugues = true;

  final Map<String, String> pronunciaPersonalizada = {
    'KWÉ': 'kué',
  };

  String normalizarParaTts(String texto) {
    if (texto.isEmpty) return texto;
    String t = texto;
    pronunciaPersonalizada.forEach((chave, valor) {
      t = t.replaceAll(RegExp(r'\b' + RegExp.escape(chave) + r'\b', caseSensitive: false), valor);
    });
    t = t.toLowerCase();
    // ajuste genérico (mantive simples)
    return t.trim();
  }

  final letras = 'A B C D E F G H I J K L M N O P Q R S T U V W X Y Z'.split(' ');

  @override
  void initState() {
    super.initState();
    carregarFavoritos();
    carregarPreferenciaIdioma();
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

  // helpers para nomes corretos conforme coleção
  String getCollectionName() => buscaEmPortugues ? 'Dicionario' : 'Asurini';

  // campo buscado (o campo que contém a palavra digitada)
  String getCampoBusca() => buscaEmPortugues ? 'portugues' : (buscaEmPortugues ? 'portugues' : 'asurini');

  // campo que contém a tradução (em ambos casos 'traducao' segundo sua estrutura)
  String getCampoResultado() => 'traducao';

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
      favoritos = favs.map((f) => Map<String, String>.from(json.decode(f))).toList();
    });
  }

  Future<void> salvarFavoritos() async {
    final prefs = await SharedPreferences.getInstance();
    final favs = favoritos.map((f) => json.encode(f)).toList();
    await prefs.setStringList('favoritos', favs);
  }

  void alternarFavorito(Map<String, String> palavra) async {
    final jaFavoritado = favoritos.any((fav) => fav['palavra'] == palavra['palavra'] && fav['traducao'] == palavra['traducao']);
    setState(() {
      if (jaFavoritado) {
        favoritos.removeWhere((f) => f['palavra'] == palavra['palavra'] && f['traducao'] == palavra['traducao']);
      } else {
        favoritos.add(palavra);
      }
    });
    await salvarFavoritos();
  }

  bool ehFavorito(Map<String, String> palavra) {
    return favoritos.any((fav) => fav['palavra'] == palavra['palavra'] && fav['traducao'] == palavra['traducao']);
  }

  // ======= BUSCA POR TEXTO =======
  void onBuscarPressed(String texto) async {
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

      final snapshot = await FirebaseFirestore.instance
          .collection(collection)
          .where(campoBusca, isGreaterThanOrEqualTo: texto.toLowerCase())
          .where(campoBusca, isLessThanOrEqualTo: texto.toLowerCase() + '\uf8ff')
          .orderBy(campoBusca)
          .limit(50)
          .get();

      final List<Map<String, String>> lista = snapshot.docs.map((doc) {
        final dados = doc.data() as Map<String, dynamic>;
        // mapeamos sempre para { 'palavra': ..., 'traducao': ... }
        // onde 'palavra' é o campo buscado (portugues ou asurini) e 'traducao' sempre 'traducao'
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
      if (mounted) setState(() => carregando = false);
    }
  }

  // ======= BUSCA POR LETRA =======
  void onLetraPressed(String letra) async {
    setState(() {
      letraSelecionada = letra;
      carregando = true;
      resultados = [];
    });

    try {
      final proxima = String.fromCharCode(letra.toUpperCase().codeUnitAt(0) + 1);
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
      if (mounted) setState(() => carregando = false);
    }
  }

  // ======= TypeAhead suggestions =======
  Future<List<Map<String, String>>> suggestionsFor(String pattern) async {
    if (pattern.isEmpty) return [];
    final collection = getCollectionName();
    final campoBusca = getCampoBusca();
    final campoResultado = getCampoResultado();

    final snapshot = await FirebaseFirestore.instance
        .collection(collection)
        .where(campoBusca, isGreaterThanOrEqualTo: pattern.toLowerCase())
        .where(campoBusca, isLessThanOrEqualTo: pattern.toLowerCase() + '\uf8ff')
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

  // ======= TTS =======
  Future<void> falarTexto(String texto) async {
    await flutterTts.setLanguage("pt-BR");
    await flutterTts.setPitch(1.0);
    await flutterTts.setSpeechRate(0.7);
    final saida = normalizarParaTts(texto);
    await flutterTts.speak(saida);
  }

  // ======= LISTA =======
  Widget construirListaResultados(List<Map<String, String>> lista) {
    return ListView.builder(
      itemCount: lista.length,
      itemBuilder: (context, index) {
        final item = lista[index];
        final favorito = ehFavorito(item);

        // palavraPrincipal e traducao dependem do idioma:
        // - se buscaEmPortugues == true: palavraPrincipal = item['palavra'] (português), traducao = item['traducao'] (asurini)
        // - se false: palavraPrincipal = item['palavra'] (asurini, pois mapeamos 'palavra' ao campo buscado), traducao = item['traducao'] (pt)
        final palavraPrincipal = item['palavra'] ?? '';
        final traducao = item['traducao'] ?? '';

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('•', style: TextStyle(fontSize: 20, color: Colors.brown[800], height: 1.5)),
              SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            palavraPrincipal.toUpperCase(),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Color(0xFF4B5D40),
                              letterSpacing: 2.0,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.volume_up, color: Colors.brown),
                          onPressed: () => falarTexto(palavraPrincipal),
                        ),
                        IconButton(
                          icon: Icon(favorito ? Icons.star : Icons.star_border, color: favorito ? Colors.amber : Colors.grey),
                          onPressed: () => alternarFavorito(item),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      traducao,
                      style: TextStyle(fontSize: 14, color: Color(0xFF7A8A66), fontStyle: FontStyle.italic),
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

  // ======= UI =======
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Container(
        decoration: BoxDecoration(image: DecorationImage(image: AssetImage("assets/fundo.png"), fit: BoxFit.cover)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 90, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // campo de busca
              Container(
                decoration: BoxDecoration(color: Color(0xFFF2E4C7), borderRadius: BorderRadius.circular(20)),
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    SizedBox(width: 8),
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
                        },
                        controller: _controller,
                        builder: (context, controller, focusNode) {
                          return TextField(
                            controller: controller,
                            focusNode: focusNode,
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: buscaEmPortugues ? 'Digite em português...' : 'Digite em Asurini...',
                              hintStyle: TextStyle(color: Colors.grey),
                            ),
                          );
                        },
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.send, color: Colors.brown),
                      onPressed: () {
                        FocusScope.of(context).unfocus();
                        onBuscarPressed(_controller.text);
                      },
                    ),
                  ],
                ),
              ),

              SizedBox(height: 170),

              // abas
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [abaSelecao('Todas', true), abaSelecao('Favoritas', false)]),

              SizedBox(height: 16),

              // conteúdo principal
              Expanded(
                child: mostrarTodas
                    ? construirConteudoTodas()
                    : (favoritos.isEmpty ? Center(child: Text('Nenhuma palavra favoritada', style: TextStyle(color: Colors.white))) : construirListaResultados(favoritos)),
              ),

              // botão trocar idioma
              Center(
                child: Container(
                  margin: EdgeInsets.only(bottom: 20),
                  child: ElevatedButton(
                    onPressed: alternarIdiomaBusca,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.brown, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [Text(buscaEmPortugues ? '🏹' : '🇧🇷', style: TextStyle(fontSize: 22)), SizedBox(width: 12), Text(buscaEmPortugues ? 'Buscar em Asurini' : 'Buscar em Português', style: TextStyle(fontSize: 16))]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget abaSelecao(String titulo, bool todas) {
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
          Text(titulo, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: todas ? Colors.black : Colors.grey[700])),
          Container(height: 2, width: 40, color: ativa ? Colors.brown : Colors.transparent, margin: EdgeInsets.only(top: 4)),
        ],
      ),
    );
  }

  Widget construirConteudoTodas() {
    if (carregando) {
      return Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.brown)));
    } else if (resultados.isNotEmpty) {
      return construirListaResultados(resultados);
    } else if (letraSelecionada != null) {
      return Center(child: Text('Nenhuma palavra encontrada para esta letra', style: TextStyle(color: Colors.white)));
    } else {
      return Column(
        children: [
          Wrap(
            spacing: 0,
            runSpacing: -5,
            children: letras.map((letra) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: TextButton(
                  onPressed: () => onLetraPressed(letra),
                  style: TextButton.styleFrom(padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4), minimumSize: Size(20, 20), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  child: Text(letra, style: TextStyle(fontSize: 20, color: Colors.brown[800], fontWeight: FontWeight.bold)),
                ),
              );
            }).toList(),
          ),
          SizedBox(height: 20),
        ],
      );
    }
  }
}


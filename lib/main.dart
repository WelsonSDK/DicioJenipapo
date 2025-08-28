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
      return MaterialApp(
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
  
    final letras = 'A B C D E F G H I J K L M N O P Q R S T U V W X Y Z'.split(' ');
  
    @override
    void initState() {
      super.initState();
      carregarFavoritos();
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
      final jaFavoritado = favoritos.any((fav) => fav['palavra'] == palavra['palavra']);
      setState(() {
        if (jaFavoritado) {
          favoritos.removeWhere((f) => f['palavra'] == palavra['palavra']);
        } else {
          favoritos.add(palavra);
        }
      });
      await salvarFavoritos();
    }
  
    bool ehFavorito(Map<String, String> palavra) {
      return favoritos.any((fav) => fav['palavra'] == palavra['palavra']);
    }
  
    void onBuscarPressed(String texto) async {
      if (texto.trim().isEmpty) return;
  
      setState(() {
        carregando = true;
        letraSelecionada = null;
        resultados = [];
      });
  
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('Dicionario')
            .limit(200)
            .get();
  
        final listaFiltrada = snapshot.docs
            .map((doc) => {
          'palavra': doc['portugues']?.toString() ?? '',
          'traducao': doc['traducao']?.toString() ?? '',
        })
            .where((item) =>
            item['palavra']!.toLowerCase().contains(texto.toLowerCase()))
            .toList();
  
        if (!mounted) return;
  
        setState(() {
          resultados = listaFiltrada;
          carregando = false;
        });
      } catch (e) {
        print('Erro ao buscar palavras: $e');
        setState(() {
          carregando = false;
        });
      }
    }
  
    void onLetraPressed(String letra) async {
      setState(() {
        letraSelecionada = letra;
        carregando = true;
        resultados = [];
      });
  
      try {
        String proximaLetra =
        String.fromCharCode(letra.toUpperCase().codeUnitAt(0) + 1);
        final snapshot = await FirebaseFirestore.instance
            .collection('Dicionario')
            .where('portugues', isGreaterThanOrEqualTo: letra.toLowerCase())
            .where('portugues', isLessThan: proximaLetra.toLowerCase())
            .get();
  
        final palavras = snapshot.docs.map((doc) {
          final dados = doc.data() as Map<String, dynamic>;
          return {
            'palavra': dados['portugues']?.toString() ?? '',
            'traducao': dados['traducao']?.toString() ?? '',
          };
        }).toList();
  
        if (!mounted) return;
  
        setState(() {
          resultados = palavras;
          carregando = false;
        });
      } catch (e) {
        print("Erro ao buscar do Firestore: $e");
        setState(() {
          carregando = false;
        });
      }
    }
  
    Future<void> falarTexto(String texto) async {
      await flutterTts.setLanguage("pt-BR");
      await flutterTts.setPitch(1.0);
      await flutterTts.speak(texto);
    }
  
    Widget construirListaResultados(List<Map<String, String>> lista) {
      return ListView.builder(
        itemCount: lista.length,
        itemBuilder: (context, index) {
          final item = lista[index];
          final favorito = ehFavorito(item);
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
                              item['traducao']!.toUpperCase(),
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
                            onPressed: () => falarTexto(item['traducao'] ?? ''),
                          ),
                          IconButton(
                            icon: Icon(
                              favorito ? Icons.star : Icons.star_border,
                              color: favorito ? Colors.amber : Colors.grey,
                            ),
                            onPressed: () => alternarFavorito(item),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(
                        item['palavra']!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF7A8A66),
                          fontStyle: FontStyle.italic,
                          letterSpacing: 1.0,
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
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage("assets/fundo.png"),
              fit: BoxFit.cover,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 185, 20, 80),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Color(0xFFF2E4C7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      SizedBox(width: 8),
                      Expanded(
                        child: TypeAheadField<Map<String, String>>(
                          suggestionsCallback: (pattern) async {
                            if (pattern.isEmpty) return [];
                            final snapshot = await FirebaseFirestore.instance
                                .collection('Dicionario')
                                .limit(200)
                                .get();
  
                            final resultadosFiltrados = snapshot.docs
                                .map((doc) => {
                              'palavra': doc['portugues']?.toString() ?? '',
                              'traducao': doc['traducao']?.toString() ?? '',
                            })
                                .where((item) => item['palavra']!
                                .toLowerCase()
                                .contains(pattern.toLowerCase()))
                                .toList();
  
                            return resultadosFiltrados.take(10).toList();
                          },
                          itemBuilder: (context, suggestion) {
                            return ListTile(title: Text(suggestion['palavra']!));
                          },
                          onSelected: (suggestion) {
                            _controller.text = suggestion['palavra']!;
                          },
                          controller: _controller,
                          builder: (context, controller, focusNode) {
                            return TextField(
                              controller: controller,
                              focusNode: focusNode,
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                hintText: 'Digite para pesquisar...',
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
                SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    abaSelecao('Todas', true),
                    abaSelecao('Favoritas', false),
                  ],
                ),
                SizedBox(height: 16),
                Expanded(
                  child: mostrarTodas
                      ? construirConteudoTodas()
                      : favoritos.isEmpty
                      ? Center(child: Text('Nenhuma palavra favoritada', style: TextStyle(color: Colors.white)))
                      : construirListaResultados(favoritos),
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
            Text(
              titulo,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: todas ? Colors.black : Colors.grey[700],
              ),
            ),
            Container(
              height: 2,
              width: 40,
              color: ativa ? Colors.brown : Colors.transparent,
              margin: EdgeInsets.only(top: 4),
            ),
          ],
        ),
      );
    }
  
    Widget construirConteudoTodas() {
      if (carregando) {
        return Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.brown),
          ),
        );
      } else if (resultados.isNotEmpty) {
        return construirListaResultados(resultados);
      } else if (letraSelecionada != null) {
        return Center(
          child: Text('Nenhuma palavra encontrada para esta letra', style: TextStyle(color: Colors.white)),
        );
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
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      minimumSize: Size(20, 20),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      letra,
                      style: TextStyle(
                        fontSize: 20,
                        color: Colors.brown[800],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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

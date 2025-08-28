import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Upload para Firestore',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const UploadScreen(),
    );
  }
}

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  // Lista de palavras para enviar
  final List<Map<String, String>> palavras = [
    {'portugues': 'água', 'traducao': "y'ũ"},
    {'portugues': 'fogo', 'traducao': 'tatá'},
    {'portugues': 'terra', 'traducao': 'yxã'},
    {'portugues': 'sol', 'traducao': 'kuarasy'},
    {'portugues': 'lua', 'traducao': 'jaxy'},
    {'portugues': 'árvore', 'traducao': 'ybyrá'},
  ];

  bool enviando = false;
  String mensagem = '';

  Future<void> enviarPalavras() async {
    setState(() {
      enviando = true;
      mensagem = '';
    });

    try {
      final batch = FirebaseFirestore.instance.batch();
      final colecao = FirebaseFirestore.instance.collection('Dicionario');

      for (var palavra in palavras) {
        final doc = colecao.doc(palavra['portugues']!.toLowerCase());
        batch.set(doc, {
          'portugues': palavra['portugues'],
          'traducao': palavra['traducao'],
          'data': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      setState(() {
        mensagem = '${palavras.length} palavras enviadas com sucesso!';
      });
    } catch (e) {
      setState(() {
        mensagem = 'Erro ao enviar: $e';
      });
    } finally {
      setState(() {
        enviando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enviar Palavras'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: enviando ? null : enviarPalavras,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              ),
              child: enviando
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text('Enviar ${palavras.length} palavras'),
            ),
            const SizedBox(height: 20),
            if (mensagem.isNotEmpty)
              Text(
                mensagem,
                style: TextStyle(
                  color: mensagem.contains('Erro') ? Colors.red : Colors.green,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
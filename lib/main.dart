import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(NoteApp());
}

class NoteApp extends StatelessWidget {
  const NoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Note App',
      theme: ThemeData.dark(),
      home: NoteListScreen(),
    );
  }
}

class NoteListScreen extends StatefulWidget {
  const NoteListScreen({super.key});

  @override
  _NoteListScreenState createState() => _NoteListScreenState();
}

class _NoteListScreenState extends State<NoteListScreen> {
  List<Map<String, String>> notes = [];
  final Uuid uuid = Uuid();

  Future<Directory> _getNotesDirectory() async {
    Directory? baseDirectory = await getExternalStorageDirectory(); // Get external storage directory with null check
    if (baseDirectory == null) {
      throw Exception("Cannot access external storage");
    }

    Directory notesDir = Directory('${baseDirectory.path}/Documents/notes'); // Create documents path (Android 10+ compatible)
    if (!await notesDir.exists()) { // Handle Android scoped storage permissions
      try {
        await notesDir.create(recursive: true);
      } catch (e) {
        print("Error creating directory: $e");
        return await getApplicationDocumentsDirectory(); // Fallback to app-specific documents directory
      }
    }

    return notesDir;
  }

  void _checkPermissions() async {
    if (await Permission.storage.request().isGranted) {
      print("Storage permission granted");
    } else {
      print("Storage permission denied");
    }
  }

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _loadNotes();
  }

  void _loadNotes() async {
    final notesDir = await _getNotesDirectory();
    List<FileSystemEntity> files = notesDir.listSync();
    List<Map<String, String>> loadedNotes = [];

    for (FileSystemEntity file in files) {
      if (file is File) {
        try {
          String fileContent = await file.readAsString();
          Map<String, dynamic> noteData = json.decode(fileContent);
          loadedNotes.add({
            'id': file.path.split('/').last,
            'title': noteData['title'] ?? '',
            'content': noteData['content'] ?? '',
          });
        } catch (e) {
          print('Error reading file ${file.path}: $e');
        }
      }
    }

    setState(() {
      notes = loadedNotes;
    });
  }

  void _addNote() async {
    final newNote = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NoteEditScreen(),
      ),
    );

    if (newNote != null && newNote['title']!.isNotEmpty) {
      final notesDir = await _getNotesDirectory();
      String id = uuid.v4();
      String fileName = '$id.json';
      File noteFile = File('${notesDir.path}/$fileName');
      await noteFile.writeAsString(json.encode({
        'title': newNote['title'],
        'content': newNote['content'],
      }));
      setState(() {
        notes.add({
          'id': fileName,
          'title': newNote['title']!,
          'content': newNote['content']!,
        });
      });
    }
  }

  void _editNote(int index) async {
    final updatedNote = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NoteEditScreen(
          note: notes[index],
        ),
      ),
    );

    if (updatedNote != null && updatedNote['title']!.isNotEmpty) {
      final notesDir = await _getNotesDirectory();
      String fileName = notes[index]['id']!;
      File noteFile = File('${notesDir.path}/$fileName');
      await noteFile.writeAsString(json.encode({
        'title': updatedNote['title'],
        'content': updatedNote['content'],
      }));
      setState(() {
        notes[index] = {
          'id': fileName,
          'title': updatedNote['title']!,
          'content': updatedNote['content']!,
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Notes'),
      ),
      body: ListView.builder(
        itemCount: notes.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(notes[index]['title']!),
            onTap: () => _editNote(index),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNote,
        child: Icon(Icons.add),
      ),
    );
  }
}

class NoteEditScreen extends StatefulWidget {
  final Map<String, String>? note;

  const NoteEditScreen({super.key, this.note});

  @override
  _NoteEditScreenState createState() => _NoteEditScreenState();
}

class _NoteEditScreenState extends State<NoteEditScreen> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?['title'] ?? '');
    _contentController = TextEditingController(text: widget.note?['content'] ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.note == null ? 'New Note' : 'Edit Note'),
        actions: [
          IconButton(
            icon: Icon(Icons.save),
            onPressed: () {
              Navigator.pop(context, {
                'title': _titleController.text,
                'content': _contentController.text,
              });
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: 'Title',
                hintStyle: TextStyle(color: Colors.grey),
                border: InputBorder.none,
              ),
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Expanded(
              child: TextField(
                controller: _contentController,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                decoration: InputDecoration(
                  hintText: 'Write your note here...',
                  hintStyle: TextStyle(color: Colors.grey),
                  border: InputBorder.none,
                ),
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
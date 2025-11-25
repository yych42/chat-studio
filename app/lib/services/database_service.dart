import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/conversation.dart';
import '../models/project.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;
  static bool _initialized = false;

  factory DatabaseService() {
    return _instance;
  }

  DatabaseService._internal();

  Future<void> _initWebDatabase() async {
    if (!_initialized && kIsWeb) {
      // Initialize web database factory
      databaseFactory = databaseFactoryFfiWeb;
      _initialized = true;
    }
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    await _initWebDatabase();

    String path = kIsWeb
        ? 'chat_app.db'
        : join(await getDatabasesPath(), 'chat_app.db');

    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Create projects table
    await db.execute('''
      CREATE TABLE projects (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    // Create conversations table with projectId
    await db.execute('''
      CREATE TABLE conversations (
        id TEXT PRIMARY KEY,
        projectId TEXT NOT NULL,
        messages TEXT NOT NULL,
        state TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        FOREIGN KEY (projectId) REFERENCES projects (id) ON DELETE CASCADE
      )
    ''');

    // Create a default project for new installations
    final now = DateTime.now().toIso8601String();
    await db.insert('projects', {
      'id': 'default',
      'name': 'Default Project',
      'createdAt': now,
      'updatedAt': now,
    });
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Create projects table
      await db.execute('''
        CREATE TABLE projects (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          createdAt TEXT NOT NULL,
          updatedAt TEXT NOT NULL
        )
      ''');

      // Create a default project
      final now = DateTime.now().toIso8601String();
      await db.insert('projects', {
        'id': 'default',
        'name': 'Default Project',
        'createdAt': now,
        'updatedAt': now,
      });

      // Add projectId column to conversations table
      await db.execute('''
        ALTER TABLE conversations ADD COLUMN projectId TEXT DEFAULT 'default' NOT NULL
      ''');
    }
  }

  Future<List<Conversation>> getAllConversations() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'conversations',
      orderBy: 'updatedAt DESC',
    );

    return maps.map((map) {
      return Conversation.fromJson({
        'id': map['id'],
        'projectId': map['projectId'],
        'messages': jsonDecode(map['messages']),
        'state': jsonDecode(map['state']),
        'createdAt': map['createdAt'],
        'updatedAt': map['updatedAt'],
      });
    }).toList();
  }

  Future<Conversation?> getConversation(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'conversations',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isEmpty) return null;

    final map = maps.first;
    return Conversation.fromJson({
      'id': map['id'],
      'projectId': map['projectId'],
      'messages': jsonDecode(map['messages']),
      'state': jsonDecode(map['state']),
      'createdAt': map['createdAt'],
      'updatedAt': map['updatedAt'],
    });
  }

  Future<void> createConversation(Conversation conversation) async {
    final db = await database;
    await db.insert(
      'conversations',
      {
        'id': conversation.id,
        'projectId': conversation.projectId,
        'messages': jsonEncode(conversation.messages.map((m) => m.toJson()).toList()),
        'state': jsonEncode(conversation.state.toJson()),
        'createdAt': conversation.createdAt.toIso8601String(),
        'updatedAt': conversation.updatedAt.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateConversation(Conversation conversation) async {
    final db = await database;
    final updatedConversation = conversation.copyWith(
      updatedAt: DateTime.now(),
    );

    await db.update(
      'conversations',
      {
        'id': updatedConversation.id,
        'projectId': updatedConversation.projectId,
        'messages': jsonEncode(updatedConversation.messages.map((m) => m.toJson()).toList()),
        'state': jsonEncode(updatedConversation.state.toJson()),
        'createdAt': updatedConversation.createdAt.toIso8601String(),
        'updatedAt': updatedConversation.updatedAt.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [updatedConversation.id],
    );
  }

  Future<void> deleteConversation(String id) async {
    final db = await database;
    await db.delete(
      'conversations',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> clearAllConversations() async {
    final db = await database;
    await db.delete('conversations');
  }

  Future<void> importConversations(List<Conversation> conversations) async {
    for (var conversation in conversations) {
      await createConversation(conversation);
    }
  }

  Future<List<Conversation>> getFilteredConversations({String? statusFilter}) async {
    final allConversations = await getAllConversations();

    if (statusFilter == null || statusFilter == 'all') {
      return allConversations;
    }

    return allConversations.where((c) => c.state.status == statusFilter).toList();
  }

  Future<List<Conversation>> getSortedConversations({
    String? statusFilter,
    String sortBy = 'date',
    bool ascending = false,
  }) async {
    var conversations = await getFilteredConversations(statusFilter: statusFilter);

    if (sortBy == 'date') {
      conversations.sort((a, b) {
        int comparison = a.updatedAt.compareTo(b.updatedAt);
        return ascending ? comparison : -comparison;
      });
    } else if (sortBy == 'messageCount') {
      conversations.sort((a, b) {
        int comparison = a.messages.length.compareTo(b.messages.length);
        return ascending ? comparison : -comparison;
      });
    }

    return conversations;
  }

  // Project CRUD operations

  Future<List<Project>> getAllProjects() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'projects',
      orderBy: 'name ASC',
    );

    return maps.map((map) => Project.fromMap(map)).toList();
  }

  Future<Project?> getProject(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'projects',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isEmpty) return null;
    return Project.fromMap(maps.first);
  }

  Future<void> createProject(Project project) async {
    final db = await database;
    await db.insert(
      'projects',
      project.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateProject(Project project) async {
    final db = await database;
    final updatedProject = project.copyWith(
      updatedAt: DateTime.now(),
    );

    await db.update(
      'projects',
      updatedProject.toMap(),
      where: 'id = ?',
      whereArgs: [updatedProject.id],
    );
  }

  Future<void> deleteProject(String id) async {
    final db = await database;
    // Conversations will be automatically deleted due to CASCADE
    await db.delete(
      'projects',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Conversation>> getConversationsByProject(String projectId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'conversations',
      where: 'projectId = ?',
      whereArgs: [projectId],
      orderBy: 'updatedAt DESC',
    );

    return maps.map((map) {
      return Conversation.fromJson({
        'id': map['id'],
        'projectId': map['projectId'],
        'messages': jsonDecode(map['messages']),
        'state': jsonDecode(map['state']),
        'createdAt': map['createdAt'],
        'updatedAt': map['updatedAt'],
      });
    }).toList();
  }
}

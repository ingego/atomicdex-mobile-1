import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:komodo_dex/blocs/wallet_bloc.dart';
import 'package:komodo_dex/model/article.dart';
import 'package:komodo_dex/model/coin.dart';
import 'package:komodo_dex/model/wallet.dart';
import 'package:komodo_dex/model/wallet_security_settings.dart';
import 'package:komodo_dex/utils/log.dart';
import 'package:komodo_dex/utils/utils.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class Db {
  static Database _db;
  static bool _initInvoked = false;

  static Future<Database> get db async {
    // Protect the database from being opened and initialized multiple times.
    if (_initInvoked) {
      await pauseUntil(() => _db != null);
      return _db;
    }

    _initInvoked = true;
    _db = await _initDB();
    return _db;
  }

  static Future<Database> _initDB() async {
    final Directory documentsDirectory = await applicationDocumentsDirectory;
    final String path = join(documentsDirectory.path, 'AtomicDEX.db');
    final db = await openDatabase(
      path,
      version: 2,
      onOpen: (Database db) {},
      onCreate: (Database db, int version) async {
        Log('database:35', 'initDB, onCreate version $version');
        await db.execute('''
      CREATE TABLE ArticlesSaved (
          id TEXT PRIMARY KEY,
          media TEXT,
          title TEXT,
          header TEXT,
          body TEXT,
          keywords TEXT,
          isSavedArticle BIT,
          creationDate TEXT,
          author TEXT,
          v INTEGER
        )
      ''');
        await db.execute('''
      CREATE TABLE Wallet (
          id TEXT PRIMARY KEY,
          name TEXT,
          is_passphrase_saved BIT,
          log_out_on_exit BIT,
          activate_pin_protection BIT,
          is_pin_created BIT,
          created_pin TEXT,
          activate_bio_protection BIT,
          enable_camo BIT,
          is_camo_pin_created BIT,
          camo_pin TEXT,
          is_camo_active BIT,
          camo_fraction INTEGER,
          camo_balance TEXT,
          camo_session_started_at INTEGER
        )
      ''');
        await db.execute('''
      CREATE TABLE CurrentWallet (
          id TEXT PRIMARY KEY,
          name TEXT,
          is_passphrase_saved BIT,
          log_out_on_exit BIT,
          activate_pin_protection BIT,
          is_pin_created BIT,
          created_pin TEXT,
          activate_bio_protection BIT,
          enable_camo BIT,
          is_camo_pin_created BIT,
          camo_pin TEXT,
          is_camo_active BIT,
          camo_fraction INTEGER,
          camo_balance TEXT,
          camo_session_started_at INTEGER
        )
      ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        Log('database',
            'initDB, onUpgrade, oldVersion: $oldVersion newVersion: $newVersion');
        if (newVersion >= 2) {
          Log('database', 'initDB, onUpgrade, upgrading to version 2');
          // MRC: I could have simply added the new fields to the table,
          // but I'm opting to recreating the tables
          // The sqlite docs recommend doings a transation and doing things in a specific order
          // See https://www.sqlite.org/lang_altertable.html for info
          try {
            final batch = db.batch();

            batch.execute('''
      CREATE TABLE new_Wallet (
          id TEXT PRIMARY KEY,
          name TEXT,
          is_passphrase_saved BIT,
          log_out_on_exit BIT,
          activate_pin_protection BIT,
          is_pin_created BIT,
          created_pin TEXT,
          activate_bio_protection BIT,
          enable_camo BIT,
          is_camo_pin_created BIT,
          camo_pin TEXT,
          is_camo_active BIT,
          camo_fraction INTEGER,
          camo_balance TEXT,
          camo_session_started_at INTEGER
        )
      ''');
            batch.execute('''
      CREATE TABLE new_CurrentWallet (
          id TEXT PRIMARY KEY,
          name TEXT,
          is_passphrase_saved BIT,
          log_out_on_exit BIT,
          activate_pin_protection BIT,
          is_pin_created BIT,
          created_pin TEXT,
          activate_bio_protection BIT,
          enable_camo BIT,
          is_camo_pin_created BIT,
          camo_pin TEXT,
          is_camo_active BIT,
          camo_fraction INTEGER,
          camo_balance TEXT,
          camo_session_started_at INTEGER
        )
      ''');
            batch.execute('''
      INSERT INTO
      new_Wallet(id, name)
      SELECT id, name
      FROM Wallet
      ''');
            batch.execute('''
      INSERT INTO new_CurrentWallet(id, name)
      SELECT id, name
      FROM CurrentWallet
      ''');
            batch.execute('DROP TABLE Wallet');
            batch.execute('DROP TABLE CurrentWallet');
            batch.execute('ALTER TABLE new_Wallet RENAME TO Wallet');
            batch.execute(
                'ALTER TABLE new_CurrentWallet RENAME TO CurrentWallet');
            batch.commit();
            Log('database',
                'initDB, onUpgrade, upgraded database to version 2 successfully');
          } catch (e) {
            Log('database',
                'initDB, onUpgrade, unable to upgrade database to version 2, error ${e.toString()}');
          }
        }
      },
    );

    // Drop tables no longer in use.
    await db.execute('DROP TABLE IF EXISTS CoinsDefault');
    await db.execute('DROP TABLE IF EXISTS CoinsConfig');
    await db.execute('DROP TABLE IF EXISTS TxNotes');

    // We're temporarily using a part of the CoinsActivated table but going to drop it in the future.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS CoinsActivated (
        name TEXT PRIMARY KEY,
        abbr TEXT
      )
    ''');

    // id is the tx_hash for transactions and the swap id for swaps
    await db.execute('''
      CREATE TABLE IF NOT EXISTS Notes (
        id TEXT PRIMARY KEY,
        note TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS WalletSnapshot (
        wallet_id TEXT PRIMARY KEY,
        snapshot TEXT
      )
    ''');

    return db;
  }

  static Future<int> saveArticle(Article newArticle) async {
    final Database db = await Db.db;

    final Map<String, dynamic> row = <String, dynamic>{
      'id': newArticle.id,
      'title': newArticle.title,
      'media': json.encode(newArticle.media),
      'header': newArticle.header,
      'body': newArticle.body,
      'keywords': newArticle.keywords,
      'isSavedArticle': newArticle.isSavedArticle,
      'creationDate': newArticle.creationDate.toString(),
      'author': newArticle.author ?? 'KomodoPlatform',
      'v': newArticle.v
    };

    return await db.insert('ArticlesSaved ', row);
  }

  static Future<List<Article>> getAllArticlesSaved() async {
    final Database db = await Db.db;

    // Query the table for All The Article.
    final List<Map<String, dynamic>> maps = await db.query('ArticlesSaved');
    Log('database:105', maps.length);
    // Convert the List<Map<String, dynamic> into a List<Article>.
    return List<Article>.generate(maps.length, (int i) {
      return Article(
        id: maps[i]['id'],
        media: List<String>.from(json.decode(maps[i]['media'])),
        title: maps[i]['title'],
        header: maps[i]['header'],
        body: maps[i]['body'],
        keywords: maps[i]['keywords'],
        author: maps[i]['author'],
        isSavedArticle: maps[i]['isSavedArticle'] == 1,
        creationDate: DateTime.parse(maps[i]['creationDate']),
        v: maps[i]['v'],
      );
    });
  }

  static Future<void> deleteArticle(Article article) async {
    final Database db = await Db.db;

    // Remove the Article from the Database
    await db.delete(
      'ArticlesSaved',
      // Use a `where` clause to delete a specific article
      where: 'id = ?',
      // Pass the Article's id through as a whereArg to prevent SQL injection
      whereArgs: <dynamic>[article.id],
    );
  }

  static Future<void> deleteAllArticles() async {
    final Database db = await Db.db;
    await db.rawDelete('DELETE FROM ArticlesSaved');
  }

  static Future<int> saveWallet(Wallet newWallet) async {
    final Database db = await Db.db;

    final Map<String, dynamic> row = <String, dynamic>{
      'id': newWallet.id,
      'name': newWallet.name,
    };

    return await db.insert('Wallet ', row);
  }

  static Future<List<Wallet>> getAllWallet() async {
    final Database db = await Db.db;

    // Query the table for All The Article.
    final List<Map<String, dynamic>> maps = await db.query('Wallet');
    Log('database:157', maps.length);
    // Convert the List<Map<String, dynamic> into a List<Dog>.
    return List<Wallet>.generate(maps.length, (int i) {
      return Wallet(
        id: maps[i]['id'],
        name: maps[i]['name'],
      );
    });
  }

  Future<void> deleteAllWallets() async {
    final Database db = await Db.db;
    await db.rawDelete('DELETE FROM Wallet');
  }

  static Future<void> deleteWallet(Wallet wallet) async {
    Log('database:173', 'deleteWallet] id: ${wallet.id}');
    final Database db = await Db.db;
    await db.delete('Wallet', where: 'id = ?', whereArgs: <dynamic>[wallet.id]);
  }

  static Future<int> saveCurrentWallet(Wallet currentWallet) async {
    await deleteCurrentWallet();
    walletBloc.setCurrentWallet(currentWallet);
    final Database db = await Db.db;

    final Map<String, dynamic> row = <String, dynamic>{
      'id': currentWallet.id,
      'name': currentWallet.name,
    };

    return await db.insert('CurrentWallet ', row);
  }

  static Future<Wallet> getCurrentWallet() async {
    final Database db = await Db.db;

    final List<Map<String, dynamic>> maps = await db.query('CurrentWallet');

    final List<Wallet> wallets = List<Wallet>.generate(maps.length, (int i) {
      return Wallet(
        id: maps[i]['id'],
        name: maps[i]['name'],
      );
    });
    if (wallets.isEmpty) {
      return null;
    } else {
      return wallets[0];
    }
  }

  static Future<void> deleteCurrentWallet() async {
    final Database db = await Db.db;
    await db.rawDelete('DELETE FROM CurrentWallet');
  }

  static final Set<String> _active = {};
  static bool _activeFromDb = false;

  static Future<Set<String>> get activeCoins async {
    if (_active.isNotEmpty && _activeFromDb) return _active;

    final Database db = await Db.db;
    for (final row in await db.rawQuery('SELECT abbr FROM CoinsActivated')) {
      final String ticker = row['abbr'];
      if (ticker != null) _active.add(ticker);
    }
    _activeFromDb = true;
    if (_active.isNotEmpty) return _active;

    final known = await coins;

    // Search for coins with 'isDefault' flag
    Iterable<String> defaultCoins = known.values
        .where((Coin coin) => coin.isDefault == true)
        .map<String>((Coin coin) => coin.abbr);

    // If no 'isDefault' coins provided, use the first two coins by default
    if (defaultCoins.isEmpty) defaultCoins = known.keys.take(2);

    _active.addAll(defaultCoins);

    return _active;
  }

  /// Add the coin to the list of activated coins.
  static Future<void> coinActive(Coin coin) async {
    _active.add(coin.abbr);
    final Database db = await Db.db;
    await db.insert('CoinsActivated',
        <String, dynamic>{'name': coin.name, 'abbr': coin.abbr},
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  /// Remove the coin from the list of activated coins.
  static Future<void> coinInactive(String ticker) async {
    Log('database:246', 'coinInactive] $ticker');
    _active.remove(ticker);
    final Database db = await Db.db;
    await db.delete('CoinsActivated',
        where: 'abbr = ?', whereArgs: <dynamic>[ticker]);
  }

  static Future<void> deleteNote(String id) async {
    final Database db = await Db.db;

    return await db.delete('Notes', where: 'id = ?', whereArgs: <String>[id]);
  }

  static Future<int> saveNote(String id, String note) async {
    final Database db = await Db.db;

    final r = await db
        .rawQuery('SELECT COUNT(*) FROM Notes WHERE id = ?', <String>[id]);
    final count = Sqflite.firstIntValue(r);

    if (count == 0) {
      final Map<String, dynamic> row = <String, dynamic>{
        'id': id,
        'note': note,
      };

      return await db.insert('Notes', row);
    } else {
      final Map<String, dynamic> row = <String, dynamic>{
        'note': note,
      };
      return await db
          .update('Notes', row, where: 'id = ?', whereArgs: <String>[id]);
    }
  }

  static Future<String> getNote(String id) async {
    final Database db = await Db.db;

    final List<Map<String, dynamic>> maps =
        await db.query('Notes', where: 'id = ?', whereArgs: <String>[id]);

    final List<String> notes = List<String>.generate(maps.length, (int i) {
      return maps[i]['note'];
    });
    if (notes.isEmpty) {
      return null;
    } else {
      return notes[0];
    }
  }

  static Future<Map<String, String>> getAllNotes() async {
    final Database db = await Db.db;

    final List<Map<String, dynamic>> maps = await db.query('Notes');
    Log('database:312', maps.length);

    final Map<String, String> r = {for (var m in maps) m['id']: m['note']};

    return r;
  }

  static Future<void> addAllNotes(Map<String, String> allNotes) async {
    //final Database db = await Db.db;

    allNotes.forEach((k, v) async {
      await saveNote(k, v);
    });
  }

  static Future<void> saveWalletSnapshot(String jsonStr) async {
    final Wallet wallet = await getCurrentWallet();
    if (wallet == null) return;

    final Database db = await Db.db;
    try {
      await db.insert('WalletSnapshot',
          <String, dynamic>{'wallet_id': wallet.id, 'snapshot': jsonStr},
          conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (_) {}
  }

  static Future<String> getWalletSnapshot() async {
    final Wallet wallet = await getCurrentWallet();
    if (wallet == null) return null;

    final Database db = await Db.db;
    List<Map<String, dynamic>> maps;
    try {
      maps = await db.query('WalletSnapshot');
    } catch (_) {}
    if (maps == null) return null;

    final Map<String, dynamic> entry = maps.firstWhere(
      (item) => item['wallet_id'] == wallet.id,
      orElse: () => null,
    );

    if (entry == null) return null;
    return entry['snapshot'];
  }

  static Future<WalletSecuritySettings>
      getCurrentWalletSecuritySettings() async {
    final Database db = await Db.db;

    final List<Map<String, dynamic>> maps = await db.query('CurrentWallet');

    final List<WalletSecuritySettings> walletsSecuritySettings =
        List<WalletSecuritySettings>.generate(maps.length, (int i) {
      return WalletSecuritySettings(
        isPassphraseSaved: maps[i]['is_passphrase_saved'] ?? false,
        logOutOnExit: maps[i]['log_out_on_exit'] ?? false,
        activatePinProtection: maps[i]['activate_pin_protection'] ?? false,
        isPinCreated: maps[i]['is_pin_created'] ?? false,
        createdPin: maps[i]['created_pin'],
        activateBioProtection: maps[i]['activate_pin_protection'] ?? false,
        enableCamo: maps[i]['enable_camo'] ?? false,
        isCamoPinCreated: maps[i]['is_camo_pin_created'] ?? false,
        camoPin: maps[i]['camo_pin'],
        isCamoActive: maps[i]['is_camo_active'] ?? false,
        camoFraction: maps[i]['camo_fraction'],
        camoBalance: maps[i]['camo_balance'],
        camoSessionStartedAt: maps[i]['camo_session_started_at'],
      );
    });
    if (walletsSecuritySettings.isEmpty) {
      return null;
    } else {
      return walletsSecuritySettings[0];
    }
  }

  static Future<void> updateWalletSecuritySettings(
      WalletSecuritySettings walletSecuritySettings,
      {bool allWallets = false}) async {
    final Database db = await Db.db;

    Wallet currenWallet = await getCurrentWallet();

    final batch = db.batch();

    final updateMap = {
      'is_passphrase_saved': walletSecuritySettings.isPassphraseSaved,
      'log_out_on_exit': walletSecuritySettings.logOutOnExit,
      'activate_pin_protection': walletSecuritySettings.activatePinProtection,
      'is_pin_created': walletSecuritySettings.isPinCreated,
      'created_pin': walletSecuritySettings.createdPin,
      'activate_bio_protection': walletSecuritySettings.activateBioProtection,
      'enable_camo': walletSecuritySettings.enableCamo,
      'is_camo_pin_created': walletSecuritySettings.isCamoPinCreated,
      'camo_pin': walletSecuritySettings.camoPin,
      'is_camo_active': walletSecuritySettings.isCamoActive,
      'camo_fraction': walletSecuritySettings.camoFraction,
      'camo_balance': walletSecuritySettings.camoBalance,
      'camo_session_started_at': walletSecuritySettings.camoSessionStartedAt,
    };

    await db.update(
      'Wallet',
      updateMap,
      where: allWallets ? null : 'id = ?',
      whereArgs: allWallets ? null : [currenWallet.id],
    );
    await db.update(
      'CurrentWallet',
      updateMap,
      where: allWallets ? null : 'id = ?',
      whereArgs: allWallets ? null : [currenWallet.id],
    );

    batch.commit();
  }
}

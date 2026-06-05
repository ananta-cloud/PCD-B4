import 'dart:developer';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:bcrypt/bcrypt.dart'; 
import 'package:hive_flutter/hive_flutter.dart';

class MongoService {
  static Db? _db;
  static const String receiptsCollection = "receipts";
  static const String usersCollection = "users";

  // Variabel untuk menyimpan ID dan Email user yang sedang login
  static String? currentUserId;
  static String? currentUserEmail;

  /// Fungsi untuk menghubungkan aplikasi ke MongoDB
  static Future<void> connect() async {
    try {
      final mongoUri = dotenv.env['MONGO_URL'] ?? dotenv.env['MONGO_URI'];
      
      if (mongoUri == null || mongoUri.isEmpty) {
        log("⚠️ MONGO_URI tidak ditemukan di .env, skip koneksi MongoDB");
        return;
      }

      _db = await Db.create(mongoUri);
      await _db!.open();
      log("✅ Berhasil terkoneksi ke MongoDB!");
    } catch (e) {
      log("⚠️ Gagal terkoneksi ke MongoDB: $e");
      _db = null; // Pastikan _db null agar getCollection() tidak crash
    }
  }

  /// Cek apakah koneksi MongoDB aktif
  static bool get isConnected => _db != null && (_db!.isConnected);

  /// Fungsi ini yang sebelumnya hilang (mengambil koleksi dari database)
  static DbCollection getCollection(String name) {
    if (_db == null || !_db!.isConnected) {
      throw Exception("Tidak ada koneksi ke MongoDB. Pastikan internet tersambung.");
    }
    return _db!.collection(name);
  }

  // ==================== AUTHENTICATION ====================

  static Future<bool> registerUser(String email, String password) async {
    try {
      // Coba reconnect kalau belum tersambung
      if (!isConnected) await connect();

      var collection = getCollection(usersCollection);
      
      // Cek apakah email sudah ada
      var existingUser = await collection.findOne(where.eq('email', email));
      if (existingUser != null) {
        log("❌ Email sudah terdaftar");
        return false;
      }

      // 1. Lakukan Hashing pada Password menggunakan BCrypt
      final String hashedPassword = BCrypt.hashpw(password, BCrypt.gensalt());

      // 2. Simpan password yang sudah di-hash
      await collection.insert({
        'email': email,
        'password': hashedPassword, 
        'createdAt': DateTime.now(),
      });
      
      log("✅ Registrasi berhasil");
      return true;
    } catch (e) {
      log("❌ Gagal registrasi: $e");
      return false;
    }
  }

  static Future<bool> loginUser(String email, String password) async {
    try {
      if (!isConnected) await connect();

      var collection = getCollection(usersCollection);
      var user = await collection.findOne(where.eq('email', email));

      if (user == null) {
        log("❌ User tidak ditemukan");
        return false;
      }

      final String storedHashedPassword = user['password'];
      final bool isPasswordCorrect = BCrypt.checkpw(password, storedHashedPassword);

      if (isPasswordCorrect) {
        currentUserId = user['_id'].toHexString();
        currentUserEmail = user['email'];
        
        var sessionBox = await Hive.openBox('session');
        await sessionBox.put('userId', currentUserId);
        await sessionBox.put('email', currentUserEmail);

        log("✅ Login berhasil! ID: $currentUserId");
        return true;
      } else {
        log("❌ Password salah");
        return false;
      }
    } catch (e) {
      log("❌ Gagal login: $e");
      return false;
    }
  }

  static Future<void> logout() async {
    var sessionBox = await Hive.openBox('session');
    await sessionBox.delete('userId');
    await sessionBox.delete('email');

    currentUserId = null;
    currentUserEmail = null;
    log("✅ User berhasil logout");
  }
  // ==================== RECEIPTS ====================

  /// Fungsi untuk menyimpan struk baru ke MongoDB
  static Future<bool> insertReceipt(
    String storeName,
    double totalAmount,
  ) async {
    if (currentUserId == null) {
      log("❌ User belum login!");
      return false;
    }

    try {
      var collection = getCollection(receiptsCollection);
      await collection.insert({
        'userId': currentUserId, // Mengaitkan struk dengan user yang login
        'storeName': storeName,
        'totalAmount': totalAmount,
        'scanDate': DateTime.now(),
        'isSynced': true,
      });
      log("✅ Berhasil menyimpan receipt ke MongoDB!");
      return true;
    } catch (e) {
      log("❌ Gagal menyimpan receipt: $e");
      return false;
    }
  }

  /// Fungsi mengambil riwayat (History) KHUSUS untuk user yang sedang login
  static Future<List<Map<String, dynamic>>> getReceiptHistory() async {
    if (currentUserId == null) return []; // Jika belum login, kembalikan kosong

    try {
      var collection = getCollection(receiptsCollection);
      // Ambil data dimana userId = user yang login, lalu urutkan dari tanggal terbaru
      return await collection
          .find(
            where
                .eq('userId', currentUserId)
                .sortBy('scanDate', descending: true),
          )
          .toList();
    } catch (e) {
      log("❌ Gagal mengambil history receipt: $e");
      return [];
    }
  }
}
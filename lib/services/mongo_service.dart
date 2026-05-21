import 'dart:developer';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class MongoService {
  static Db? _db;
  static const String receiptsCollection = "receipts";
  static const String usersCollection = "users";

  // Variabel untuk menyimpan ID dan Email user yang sedang login sementara
  static String? currentUserId;
  static String? currentUserEmail;

  static Future<void> connect() async {
    try {
      final mongoUri = dotenv.env['MONGO_URI'];
      if (mongoUri == null || mongoUri.isEmpty) {
        throw Exception("MONGO_URI tidak ditemukan");
      }

      _db = await Db.create(mongoUri);
      await _db!.open();
      log("✅ Berhasil terkoneksi ke MongoDB!");
    } catch (e) {
      log("❌ Gagal terkoneksi: $e");
      rethrow;
    }
  }

  static DbCollection getCollection(String name) => _db!.collection(name);

  // ==================== AUTHENTICATION ====================

  static Future<bool> registerUser(String email, String password) async {
    try {
      var collection = getCollection(usersCollection);
      
      // Cek apakah email sudah ada
      var existingUser = await collection.findOne(where.eq('email', email));
      if (existingUser != null) {
        log("❌ Email sudah terdaftar!");
        return false;
      }

      // Insert user baru ke MongoDB
      await collection.insert({
        'email': email,
        'password': password, // PERINGATAN: Di tahap produksi, ini wajib di-hash!
      });
      return true;
    } catch (e) {
      log("❌ Gagal register: $e");
      return false;
    }
  }

  static Future<bool> loginUser(String email, String password) async {
    try {
      var collection = getCollection(usersCollection);
      
      // Cari user berdasarkan email dan password
      var user = await collection.findOne(where.eq('email', email).eq('password', password));
      
      if (user != null) {
        // Simpan ObjectId MongoDB dan email ke memori lokal
        currentUserId = user['_id'].toString(); 
        currentUserEmail = user['email']; 
        
        log("✅ Login berhasil!");
        return true;
      } else {
        log("❌ Email atau password salah");
        return false;
      }
    } catch (e) {
      log("❌ Gagal login: $e");
      return false;
    }
  }

  // ==================== RECEIPTS (HISTORY) ====================

  /// Fungsi MENYIMPAN struk baru ke MongoDB
  /// Panggil ini SETELAH kamu berhasil memproses hasil scan (OCR)
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
        'scanDate': DateTime.now(), // Simpan tanggal saat ini
        'isSynced': true,
      });
      log("✅ Berhasil menyimpan receipt ke MongoDB!");
      return true;
    } catch (e) {
      log("❌ Gagal menyimpan receipt: $e");
      return false;
    }
  }

  /// Fungsi MENGAMBIL riwayat (History) KHUSUS untuk user yang sedang login
  static Future<List<Map<String, dynamic>>> getReceiptHistory() async {
    if (currentUserId == null) return []; // Jika belum login, kembalikan kosong

    try {
      var collection = getCollection(receiptsCollection);
      // Ambil data dimana userId = user yang login, lalu urutkan tanggal terbaru
      return await collection
          .find(
            where
                .eq('userId', currentUserId)
                .sortBy('scanDate', descending: true),
          )
          .toList();
    } catch (e) {
      log("❌ Gagal mengambil riwayat: $e");
      return [];
    }
  }
}
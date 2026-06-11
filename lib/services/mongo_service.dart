import 'dart:developer';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/receipt.dart';
import '../repositories/receipt_repository.dart';

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
      throw Exception(
        "Tidak ada koneksi ke MongoDB. Pastikan internet tersambung.",
      );
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
      final bool isPasswordCorrect = BCrypt.checkpw(
        password,
        storedHashedPassword,
      );

      if (isPasswordCorrect) {
        currentUserId = user['_id'].toHexString();
        currentUserEmail = user['email'];

        var sessionBox = await Hive.openBox('session');
        await sessionBox.put('userId', currentUserId);
        await sessionBox.put('email', currentUserEmail);

        // ── TAMBAHAN: Tarik data dari MongoDB ke Hive lokal ──
        await syncReceiptsFromMongo();
        // ─────────────────────────────────────────────────────

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

  static Future<bool> insertReceipt(
    double totalAmount, // <-- Hanya menyisakan totalAmount
  ) async {
    if (currentUserId == null) {
      log("❌ User belum login!");
      return false;
    }

    try {
      var collection = getCollection(receiptsCollection);
      await collection.insert({
        'userId': currentUserId,
        // 'storeName': storeName, <-- BARI INI DIHAPUS
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

  static Future<bool> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    try {
      if (currentUserId == null) return false;

      var collection = getCollection(usersCollection);
      // Cari user berdasarkan ID yang sedang aktif
      var user = await collection.findOne(
        where.id(ObjectId.parse(currentUserId!)),
      );

      if (user == null) return false;

      // 1. Verifikasi password lama
      final String storedHashedPassword = user['password'];
      final bool isPasswordCorrect = BCrypt.checkpw(
        currentPassword,
        storedHashedPassword,
      );

      if (!isPasswordCorrect) {
        log("❌ Password lama salah");
        return false;
      }

      // 2. Hash password baru
      final String newHashedPassword = BCrypt.hashpw(
        newPassword,
        BCrypt.gensalt(),
      );

      // 3. Update ke database
      await collection.update(
        where.id(ObjectId.parse(currentUserId!)),
        modify.set('password', newHashedPassword),
      );

      log("✅ Password berhasil diubah");
      return true;
    } catch (e) {
      log("❌ Gagal ganti password: $e");
      return false;
    }
  }

  static Future<void> syncReceiptsFromMongo() async {
    if (currentUserId == null) return;

    try {
      if (!isConnected) await connect();

      final collection = getCollection(receiptsCollection);
      final docs = await collection
          .find(where.eq('userId', currentUserId))
          .toList();

      for (final doc in docs) {
        final id = doc['_id'].toHexString();
        final receipt = Receipt(
          id: id,
          userId: doc['userId'] as String,
          totalAmount: (doc['totalAmount'] as num).toDouble(),
          confidenceScore: 1.0, // tidak ada di MongoDB, default 1.0
          scannedAt: doc['scanDate'] is DateTime
              ? doc['scanDate'] as DateTime
              : DateTime.parse(doc['scanDate'].toString()),
          isSynced: doc['isSynced'] as bool? ?? true,
        );

        // Hanya simpan jika belum ada di Hive
        if (ReceiptRepository.getById(id) == null) {
          await ReceiptRepository.addReceipt(receipt);
        }
      }

      log("✅ Sync dari MongoDB selesai: ${docs.length} receipts");
    } catch (e) {
      log("❌ Gagal sync dari MongoDB: $e");
    }
  }

  static Future<void> restoreSession() async {
    final sessionBox = await Hive.openBox('session');
    final savedUserId = sessionBox.get('userId');
    final savedEmail = sessionBox.get('email');

    if (savedUserId != null) {
      currentUserId = savedUserId;
      currentUserEmail = savedEmail;
      log("✅ Session restored: $currentUserId");

      // ── TAMBAHAN: Sync ulang saat app restart ──
      await syncReceiptsFromMongo();
      // ──────────────────────────────────────────
    }
  }

  /// Sinkronisasi data dari MongoDB Cloud ke Hive Local
  static Future<void> syncFromMongo() async {
    if (currentUserId == null) return;

    try {
      if (!isConnected) await connect();

      var collection = getCollection(receiptsCollection);

      // Ambil semua data milik user dari MongoDB
      final docs = await collection
          .find(where.eq('userId', currentUserId))
          .toList();

      for (final doc in docs) {
        final id = doc['_id'].toHexString();

        // Cek apakah data sudah ada di Hive (lokal) agar tidak duplikat
        if (ReceiptRepository.getById(id) == null) {
          final receipt = Receipt(
            id: id,
            userId: doc['userId'] as String,
            totalAmount: (doc['totalAmount'] as num).toDouble(),
            confidenceScore: 1.0, // Default confidence
            // Menangani scanDate baik berupa DateTime object atau String
            scannedAt: doc['scanDate'] is DateTime
                ? doc['scanDate'] as DateTime
                : DateTime.parse(doc['scanDate'].toString()),
            isSynced: true,
            imagePath: doc['imagePath'] as String?,
          );

          // Simpan ke Hive
          await ReceiptRepository.addReceipt(receipt);
          log("📥 Synced receipt: $id");
        }
      }
      log("✅ Sync dari MongoDB selesai: ${docs.length} receipts");
    } catch (e) {
      log("❌ Gagal sync dari MongoDB: $e");
    }
  }
}

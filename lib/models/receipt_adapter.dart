import 'package:hive/hive.dart';
import 'receipt.dart';

/// Manual Hive TypeAdapter untuk Receipt.
///
/// Serialisasi field Receipt ke binary tanpa code generation.
/// typeId: 0 — harus unik per model.
class ReceiptAdapter extends TypeAdapter<Receipt> {
  @override
  int get typeId => 0;

  @override
  Receipt read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      final key = reader.readByte();
      final value = reader.read();
      fields[key] = value;
    }

    return Receipt(
      id: fields[0] as String,
      userId: fields[1] as String,
      totalAmount: fields[2] as double,
      confidenceScore: fields[3] as double,
      scannedAt: DateTime.fromMillisecondsSinceEpoch(fields[4] as int),
      isSynced: fields[5] as bool,
      merchantName: fields[6] as String?,
      imagePath: fields[7] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Receipt obj) {
    writer.writeByte(8); // jumlah field
    // Field 0: id
    writer.writeByte(0);
    writer.write(obj.id);
    // Field 1: userId
    writer.writeByte(1);
    writer.write(obj.userId);
    // Field 2: totalAmount
    writer.writeByte(2);
    writer.write(obj.totalAmount);
    // Field 3: confidenceScore
    writer.writeByte(3);
    writer.write(obj.confidenceScore);
    // Field 4: scannedAt (simpan sebagai int milliseconds)
    writer.writeByte(4);
    writer.write(obj.scannedAt.millisecondsSinceEpoch);
    // Field 5: isSynced
    writer.writeByte(5);
    writer.write(obj.isSynced);
    // Field 6: merchantName
    writer.writeByte(6);
    writer.write(obj.merchantName);
    // Field 7: imagePath
    writer.writeByte(7);
    writer.write(obj.imagePath);
  }
}

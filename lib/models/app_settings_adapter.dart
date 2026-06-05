import 'package:hive/hive.dart';
import 'app_settings.dart';

/// Manual Hive TypeAdapter untuk AppSettings.
/// typeId: 2 — harus unik per model.
class AppSettingsAdapter extends TypeAdapter<AppSettings> {
  @override
  int get typeId => 2;

  @override
  AppSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      final key = reader.readByte();
      final value = reader.read();
      fields[key] = value;
    }

    return AppSettings(
      id: fields[0] as String,
      isDarkMode: fields[1] as bool,
      enableNotifications: fields[2] as bool,
      enableAutoSync: fields[3] as bool,
      language: fields[4] as String,
      confidenceThreshold: fields[5] as double,
      maxReceiptsLocal: fields[6] as int,
      createdAt: DateTime.fromMillisecondsSinceEpoch(fields[7] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(fields[8] as int),
    );
  }

  @override
  void write(BinaryWriter writer, AppSettings obj) {
    writer.writeByte(9); // jumlah field

    // Field 0: id
    writer.writeByte(0);
    writer.write(obj.id);

    // Field 1: isDarkMode
    writer.writeByte(1);
    writer.write(obj.isDarkMode);

    // Field 2: enableNotifications
    writer.writeByte(2);
    writer.write(obj.enableNotifications);

    // Field 3: enableAutoSync
    writer.writeByte(3);
    writer.write(obj.enableAutoSync);

    // Field 4: language
    writer.writeByte(4);
    writer.write(obj.language);

    // Field 5: confidenceThreshold
    writer.writeByte(5);
    writer.write(obj.confidenceThreshold);

    // Field 6: maxReceiptsLocal
    writer.writeByte(6);
    writer.write(obj.maxReceiptsLocal);

    // Field 7: createdAt
    writer.writeByte(7);
    writer.write(obj.createdAt.millisecondsSinceEpoch);

    // Field 8: updatedAt
    writer.writeByte(8);
    writer.write(obj.updatedAt.millisecondsSinceEpoch);
  }
}

import 'package:hive/hive.dart';
import 'user.dart';

/// Manual Hive TypeAdapter untuk User.
/// typeId: 1 — harus unik per model (0 digunakan untuk Receipt).
class UserAdapter extends TypeAdapter<User> {
  @override
  int get typeId => 1;

  @override
  User read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      final key = reader.readByte();
      final value = reader.read();
      fields[key] = value;
    }

    return User(
      id: fields[0] as String,
      email: fields[1] as String,
      name: fields[2] as String,
      photoUrl: fields[3] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(fields[4] as int),
      lastLoginAt: fields[5] != null
          ? DateTime.fromMillisecondsSinceEpoch(fields[5] as int)
          : null,
      isLoggedIn: fields[6] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, User obj) {
    writer.writeByte(7); // jumlah field

    // Field 0: id
    writer.writeByte(0);
    writer.write(obj.id);

    // Field 1: email
    writer.writeByte(1);
    writer.write(obj.email);

    // Field 2: name
    writer.writeByte(2);
    writer.write(obj.name);

    // Field 3: photoUrl
    writer.writeByte(3);
    writer.write(obj.photoUrl);

    // Field 4: createdAt
    writer.writeByte(4);
    writer.write(obj.createdAt.millisecondsSinceEpoch);

    // Field 5: lastLoginAt
    writer.writeByte(5);
    writer.write(obj.lastLoginAt?.millisecondsSinceEpoch);

    // Field 6: isLoggedIn
    writer.writeByte(6);
    writer.write(obj.isLoggedIn);
  }
}

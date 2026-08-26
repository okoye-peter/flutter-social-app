import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';

class RegistrationModel extends Equatable {
  final String name;
  final String username;
  final String email;
  final String phoneNumber;
  final String password;
  final Uint8List? avatarBytes;
  final String? avatarFileName;

  const RegistrationModel({
    required this.name,
    required this.username,
    required this.email,
    required this.phoneNumber,
    required this.password,
    this.avatarBytes,
    this.avatarFileName,
  });

  FormData toFormData() {
    return FormData.fromMap({
      'name': name,
      'username': username,
      'email': email,
      'phoneNumber': phoneNumber,
      'password': password,
      if (avatarBytes != null)
        'image': MultipartFile.fromBytes(
          avatarBytes!,
          filename: avatarFileName ?? 'avatar.jpg',
        ),
    });
  }

  @override
  List<Object?> get props => [
    name,
    username,
    email,
    phoneNumber,
    password,
    avatarBytes,
    avatarFileName,
  ];
}

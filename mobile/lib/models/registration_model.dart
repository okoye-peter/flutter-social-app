import 'package:equatable/equatable.dart';

class RegistrationModel extends Equatable {
  final String name;
  final String email;
  final String phoneNumber;
  final String password;

  const RegistrationModel({
    required this.name,
    required this.email,
    required this.phoneNumber,
    required this.password,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name, 
      'email': email,
      'phoneNumber': phoneNumber,
      'password': password,
    };
  }

  @override
  List<String> get props => [name, email, phoneNumber, password];
}

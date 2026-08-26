// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:equatable/equatable.dart';

class UserModel extends Equatable {
  final String id;
  final String name;
  final String username;
  final String email;
  final String phoneNumber;
  final String image;
  final String fcmToken;
  final String aboutMe;
  final String lastSeen;
  final String createdAt;
  final bool isOnline;
  final List<String> friendsIds;
  final List<String> friendRequestsIds;
  final List<String> sentFriendRequestsIds;

  const UserModel({
    required this.id,
    required this.name,
    required this.username,
    required this.email,
    required this.phoneNumber,
    required this.image,
    required this.fcmToken,
    required this.aboutMe,
    required this.lastSeen,
    required this.createdAt,
    required this.isOnline,
    required this.friendsIds,
    required this.friendRequestsIds,
    required this.sentFriendRequestsIds,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      phoneNumber: json['phoneNumber'] ?? '',
      image: json['image'] ?? '',
      fcmToken: json['fcmToken'] ?? '',
      aboutMe: json['aboutMe'] ?? '',
      lastSeen: json['lastSeen'] ?? '',
      createdAt: json['createdAt'] ?? '',
      isOnline: json['isOnline'] ?? false,
      friendsIds: List<String>.from(json['friendsIds'] ?? []),
      friendRequestsIds: List<String>.from(json['friendRequestsIds'] ?? []),
      sentFriendRequestsIds: List<String>.from(
        json['sentFriendRequestsIds'] ?? [],
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'username': username,
      'email': email,
      'phoneNumber': phoneNumber,
      'image': image,
      'fcmToken': fcmToken,
      'aboutMe': aboutMe,
      'lastSeen': lastSeen,
      'createdAt': createdAt,
      'isOnline': isOnline,
      'friendsIds': friendsIds,
      'friendRequestsIds': friendRequestsIds,
      'sentFriendRequestsIds': sentFriendRequestsIds,
    };
  }

  UserModel copyWith({
    String? newId,
    String? newName,
    String? newUsername,
    String? newEmail,
    String? newPhoneNumber,
    String? newImage,
    String? newFcmToken,
    String? newAboutMe,
    String? newLastSeen,
    String? newCreatedAt,
    bool? newIsOnline,
    List<String>? newFriendsIds,
    List<String>? newFriendRequestsIds,
    List<String>? newSentFriendRequestsIds,
  }) {
    return UserModel(
      id: newId ?? id,
      name: newName ?? name,
      username: newUsername ?? username,
      email: newEmail?? email,
      phoneNumber: newPhoneNumber ?? phoneNumber,
      image: newImage ?? image,
      fcmToken: newFcmToken ?? fcmToken,
      aboutMe: newAboutMe ?? aboutMe,
      lastSeen: newLastSeen ?? lastSeen,
      createdAt: newCreatedAt ?? createdAt,
      isOnline: newIsOnline ?? isOnline,
      friendsIds: newFriendsIds ?? friendsIds,
      friendRequestsIds: newFriendRequestsIds ?? friendRequestsIds,
      sentFriendRequestsIds: newSentFriendRequestsIds ?? sentFriendRequestsIds,
    );
  }

  @override
  List<Object> get props => [
    id,
    name,
    username,
    email,
    phoneNumber,
    image,
    fcmToken,
    aboutMe,
    lastSeen,
    createdAt,
    isOnline,
    friendsIds,
    friendRequestsIds,
    sentFriendRequestsIds,
  ];

  String get getInitials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '';
    final first = parts[0][0];
    final second = parts.length > 1 ? parts[1][0] : '';
    return (first + second).toUpperCase();
  }
}

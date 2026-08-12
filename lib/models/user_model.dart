// ignore_for_file: public_member_api_docs, sort_constructors_first
class UserModel {
  String id;
  String name;
  String phoneNumber;
  String image;
  String token;
  String aboutMe;
  String lastSeen;
  String createdAt;
  bool isOnline;
  List<String> friendsIds;
  List<String> friendRequestsIds;
  List<String> sentFriendRequestsIds;

  UserModel({
    required this.id,
    required this.name,
    required this.phoneNumber,
    required this.image,
    required this.token,
    required this.aboutMe,
    required this.lastSeen,
    required this.createdAt,
    required this.isOnline,
    required this.friendsIds,
    required this.friendRequestsIds,
    required this.sentFriendRequestsIds,
  });

  UserModel fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      phoneNumber: json['phone_number'] ?? '',
      image: json['image'] ?? '',
      token: json['token'] ?? '',
      aboutMe: json['about_me'] ?? '',
      lastSeen: json['last_seen'] ?? '',
      createdAt: json['created_at'] ?? '',
      isOnline: json['is_online'] ?? false,
      friendsIds: List<String>.from(json['friends_ids'] ?? []),
      friendRequestsIds: List<String>.from(json['friend_requests_ids'] ?? []),
      sentFriendRequestsIds: List<String>.from(json['sent_friend_requests_ids']  ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id, 
      'name': name,
      'phone_number': phoneNumber,
      'image': image,
      'token': token,
      'about_me': aboutMe,
      'last_seen': lastSeen,
      'created_at': createdAt,
      'is_online': isOnline,
      'friends_ids': friendsIds,
      'friend_requests_ids': friendRequestsIds,
      'sent_friend_requests_ids': sentFriendRequestsIds,
    };
  }
}

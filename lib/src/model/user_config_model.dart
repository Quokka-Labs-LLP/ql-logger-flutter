class UserConfig {
  final String? userId;
  final String? userName;

  UserConfig({this.userId, this.userName});

  factory UserConfig.fromJson(Map<String, dynamic> json) {
    return UserConfig(
      userId: json["userId"],
      userName: json["userName"],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "userId": userId,
      "userName": userName,
    };
  }
}

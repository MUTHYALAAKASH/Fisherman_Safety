class UserModel {
  final String fullName;
  final String mobileNumber;
  final String? email;
  final String role;
  final String? profileImageUrl;
  final String? boatName;
  final String? registrationNumber;
  final String? harborLocation;

  UserModel({
    required this.fullName,
    required this.mobileNumber,
    this.email,
    required this.role,
    this.profileImageUrl,
    this.boatName,
    this.registrationNumber,
    this.harborLocation,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      fullName: json['fullName'] ?? '',
      mobileNumber: json['mobileNumber'] ?? '',
      email: json['email'],
      role: json['role'] ?? 'FISHERMAN',
      profileImageUrl: json['profileImageUrl'],
      boatName: json['boatName'],
      registrationNumber: json['registrationNumber'],
      harborLocation: json['harborLocation'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fullName': fullName,
      'mobileNumber': mobileNumber,
      'email': email,
      'role': role,
      'profileImageUrl': profileImageUrl,
      'boatName': boatName,
      'registrationNumber': registrationNumber,
      'harborLocation': harborLocation,
    };
  }
}

class LocalContact {
  final String id;
  final String name;
  final String phone;
  final String? email;
  final String? photoUrl;
  final String? address;
  final String? company;
  final String? jobTitle;
  final String? notes;
  final String? nickname;
  final DateTime? birthday;
  final DateTime createdAt;

  LocalContact({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.photoUrl,
    this.address,
    this.company,
    this.jobTitle,
    this.notes,
    this.nickname,
    this.birthday,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'phone': phone,
    'email': email,
    'photoUrl': photoUrl,
    'address': address,
    'company': company,
    'jobTitle': jobTitle,
    'notes': notes,
    'nickname': nickname,
    'birthday': birthday?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
  };

  factory LocalContact.fromMap(Map<String, dynamic> map) => LocalContact(
    id: map['id'] ?? '',
    name: map['name'] ?? '',
    phone: map['phone'] ?? '',
    email: map['email'],
    photoUrl: map['photoUrl'],
    address: map['address'],
    company: map['company'],
    jobTitle: map['jobTitle'],
    notes: map['notes'],
    nickname: map['nickname'],
    birthday: map['birthday'] != null
        ? DateTime.tryParse(map['birthday'])
        : null,
    createdAt: map['createdAt'] != null
        ? DateTime.tryParse(map['createdAt']) ?? DateTime.now()
        : DateTime.now(),
  );

  LocalContact copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? photoUrl,
    String? address,
    String? company,
    String? jobTitle,
    String? notes,
    String? nickname,
    DateTime? birthday,
    DateTime? createdAt,
  }) => LocalContact(
    id: id ?? this.id,
    name: name ?? this.name,
    phone: phone ?? this.phone,
    email: email ?? this.email,
    photoUrl: photoUrl ?? this.photoUrl,
    address: address ?? this.address,
    company: company ?? this.company,
    jobTitle: jobTitle ?? this.jobTitle,
    notes: notes ?? this.notes,
    nickname: nickname ?? this.nickname,
    birthday: birthday ?? this.birthday,
    createdAt: createdAt ?? this.createdAt,
  );
}

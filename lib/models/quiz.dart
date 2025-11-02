class Quiz {
  final String quisthion;
  final List<String> opthion;
  final int corectindexanswar;

  Quiz({
    required this.quisthion,
    required this.opthion,
    required this.corectindexanswar,
  });

  Map<String, dynamic> toJson() => {
    'quistion': quisthion,
    'opthion': opthion,
    'corectindexanswar': corectindexanswar,
  };
  factory Quiz.fromJson(Map<String, dynamic> json) => Quiz(
    quisthion: json['quisthion'],
    opthion: List<String>.from(json['opthion']),
    corectindexanswar: json['corectindexanswar'],
  );
}

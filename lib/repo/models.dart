class AlarmModal {
  String time; // e.g. "08:30"
  String period; // "AM" or "PM"
  String title;
  String audiopath;
  bool isActive;
  String repeatType; // "Once", "Repeat Days"
  List<String> repeatDays; // e.g. ["Mon", "Tue"]

  AlarmModal({
    required this.time,
    required this.period,
    required this.title,
    required this.audiopath,
    this.isActive = true,
    this.repeatType = "Once",
    List<String>? repeatDays,
  }) : repeatDays = repeatDays ?? [];

  Map<String, dynamic> toJson() => {
    'time': time,
    'period': period,
    'title': title,
    'isActive': isActive,
    'audiopath': audiopath,
    'repeatType': repeatType,
    'repeatDays': repeatDays,
  };

  factory AlarmModal.fromJson(Map<String, dynamic> json) => AlarmModal(
    time: json['time'] as String,
    period: json['period'] as String,
    title: json['title'] as String,
    isActive: json['isActive'] as bool? ?? true,
    audiopath: json['audiopath'] as String? ?? "",
    repeatType: json['repeatType'] as String? ?? "Once",
    repeatDays:
        (json['repeatDays'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList() ??
        [],
  );
}

class Remainder {
  String name;
  int durationSeconds; // represented as seconds (e.g. 600 for 10 minutes)
  String repeat; // "Once", "Until Stopped", "Repeat X times"
  int repeatCount; // Number of repeats if repeat is "Repeat X times"
  bool isActive;
  String audiopath;

  Remainder({
    required this.name,
    required this.durationSeconds,
    required this.repeat,
    this.repeatCount = 1,
    this.isActive = false,
    required this.audiopath,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'durationSeconds': durationSeconds,
    'repeat': repeat,
    'repeatCount': repeatCount,
    'isActive': isActive,
    'audiopath': audiopath,
  };

  factory Remainder.fromJson(Map<String, dynamic> json) {
    int durationSecs = 600;
    if (json['durationSeconds'] != null) {
      durationSecs = json['durationSeconds'] as int;
    }

    final reps = json['repeatCount'] as int? ?? 1;

    return Remainder(
      name: json['name'] as String,
      durationSeconds: durationSecs,
      repeat: json['repeat'] as String? ?? "Once",
      repeatCount: reps,
      isActive: json['isActive'] as bool? ?? false,
      audiopath: json['audiopath'] as String,
    );
  }
}

class Settingalarm {
  bool vibrate;
  bool loopAudio;
  double volume; // 0.0 to 1.0
  int fadeDurationSeconds; // Fade-in duration in seconds (0 = no fade)
  int snoozeDurationMinutes; // Snooze duration in minutes
  bool ascendingVolume; // Gradually increase volume

  Settingalarm({
    required this.vibrate,
    this.loopAudio = true,
    this.volume = 1.0,
    this.fadeDurationSeconds = 1,
    this.snoozeDurationMinutes = 5,
    this.ascendingVolume = false,
  });

  Map<String, dynamic> toJson() => {
    'vibrate': vibrate,
    'loopAudio': loopAudio,
    'volume': volume,
    'fadeDurationSeconds': fadeDurationSeconds,
    'snoozeDurationMinutes': snoozeDurationMinutes,
    'ascendingVolume': ascendingVolume,
  };

  factory Settingalarm.fromJson(Map<String, dynamic> json) => Settingalarm(
    vibrate: json['vibrate'] as bool? ?? true,
    loopAudio: json['loopAudio'] as bool? ?? true,
    volume: (json['volume'] as num?)?.toDouble() ?? 1.0,
    fadeDurationSeconds: json['fadeDurationSeconds'] as int? ?? 1,
    snoozeDurationMinutes: json['snoozeDurationMinutes'] as int? ?? 5,
    ascendingVolume: json['ascendingVolume'] as bool? ?? false,
  );
}

class TaskItem {
  final String id;
  final String text;
  final bool isChecked;

  TaskItem({
    required this.id,
    required this.text,
    required this.isChecked,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'isChecked': isChecked,
  };

  factory TaskItem.fromJson(Map<String, dynamic> json) => TaskItem(
    id: json['id'] as String? ?? '',
    text: json['text'] as String? ?? '',
    isChecked: json['isChecked'] as bool? ?? false,
  );

  TaskItem copyWith({
    String? id,
    String? text,
    bool? isChecked,
  }) {
    return TaskItem(
      id: id ?? this.id,
      text: text ?? this.text,
      isChecked: isChecked ?? this.isChecked,
    );
  }
}

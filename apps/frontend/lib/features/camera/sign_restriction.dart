class SignRestriction {
  final int dayOfWeek;
  final String startTime;
  final String endTime;
  final int? maximumStayMinutes;

  SignRestriction({
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.maximumStayMinutes,
  });

  factory SignRestriction.fromJson(Map<String, dynamic> json) {
    return SignRestriction(
      dayOfWeek: json['day_of_week'] as int,
      startTime: json['start_time'] as String,
      endTime: json['end_time'] as String,
      maximumStayMinutes: json['maximum_stay_minutes'] == null
          ? null
          : (json['maximum_stay_minutes'] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'day_of_week': dayOfWeek,
      'start_time': startTime,
      'end_time': endTime,
      'maximum_stay_minutes': maximumStayMinutes,
    };
  }

  String get dayLabel {
    const names = {
      1: 'Monday',
      2: 'Tuesday',
      3: 'Wednesday',
      4: 'Thursday',
      5: 'Friday',
      6: 'Saturday',
      7: 'Sunday',
    };
    return names[dayOfWeek] ?? 'Day $dayOfWeek';
  }
}

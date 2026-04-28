import 'package:taste_spot/core/utils/app_time.dart';

class SwipeHistoryModel {
  final String userId;
  final String restaurantId;
  final DateTime swipedAt;

  const SwipeHistoryModel({
    required this.userId,
    required this.restaurantId,
    required this.swipedAt,
  });

  factory SwipeHistoryModel.fromJson(Map<String, dynamic> json) {
    return SwipeHistoryModel(
      userId: json['user_id'] as String,
      restaurantId: json['restaurant_id'] as String,
      swipedAt: AppTime.parseUtc(json['swiped_at']) ?? AppTime.nowUtc(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'restaurant_id': restaurantId,
      'swiped_at': swipedAt.toIso8601String(),
    };
  }
}

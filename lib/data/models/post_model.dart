class PostModel {
  final String id;
  final String userId;
  final String? restaurantId;
  final String imageUrl;
  final double aspectRatio;
  final String title; // caption
  final String authorName;
  final String authorAvatar;
  final int likes;
  final int saveCount;
  final String? location;
  final String restaurantName;
  final String restaurantCuisine;
  final DateTime? createdAt;

  const PostModel({
    required this.id,
    required this.userId,
    this.restaurantId,
    required this.imageUrl,
    required this.aspectRatio,
    required this.title,
    required this.authorName,
    required this.authorAvatar,
    required this.likes,
    this.saveCount = 0,
    this.location,
    this.restaurantName = '',
    this.restaurantCuisine = '',
    this.createdAt,
  });

  /// Maps a Supabase `Post` row with joined `User` + `Restaurant`.
  factory PostModel.fromJson(Map<String, dynamic> json) {
    // Supabase returns the joined User under the FK name when disambiguated
    final user = (json['User!Post_user_Id_fkey'] ?? json['User'])
        as Map<String, dynamic>?;
    final authorName = (user?['name'] as String?) ?? 'Unknown';

    final restaurant = json['Restaurant'] as Map<String, dynamic>?;
    final restaurantName = (restaurant?['restaurant_name'] as String?) ?? '';
    final restaurantCuisine = (restaurant?['categoryCuisine'] as String?) ?? '';
    final restaurantId = restaurant?['restaurant_Id'] as String?;

    final createdAtRaw = json['created_At'] as String?;

    return PostModel(
      id: json['post_Id'] as String,
      userId: (user?['user_Id'] as String?) ?? '',
      restaurantId: restaurantId,
      // Images stored as bytes in Post_Image — PostCard handles empty gracefully.
      imageUrl: '',
      aspectRatio: 1.3,
      title: (json['caption'] as String?) ?? '',
      authorName: authorName,
      authorAvatar: '',
      likes: (json['likeCount'] as num?)?.toInt() ?? 0,
      saveCount: (json['saveCount'] as num?)?.toInt() ?? 0,
      restaurantName: restaurantName,
      restaurantCuisine: restaurantCuisine,
      createdAt:
          createdAtRaw != null ? DateTime.tryParse(createdAtRaw) : null,
    );
  }
}

// ─── Mock data (UI previews only) ────────────────────────────────────────────
const List<PostModel> mockPosts = [
  PostModel(
    id: '1',
    userId: 'mock-user-1',
    imageUrl: 'https://picsum.photos/seed/ramen1/400/520',
    aspectRatio: 1.3,
    title: 'Hidden gem ramen spot you must try 🍜',
    authorName: 'foodie_sarah',
    authorAvatar: 'https://i.pravatar.cc/150?img=1',
    likes: 1204,
    saveCount: 389,
    location: 'Tokyo, Japan',
    restaurantName: 'Ichiran Ramen Shibuya',
  ),
  PostModel(
    id: '2',
    userId: 'mock-user-2',
    imageUrl: 'https://picsum.photos/seed/cafe2/400/440',
    aspectRatio: 1.1,
    title: 'Aesthetic matcha latte art ☕️',
    authorName: 'matcha.moments',
    authorAvatar: 'https://i.pravatar.cc/150?img=2',
    likes: 876,
    saveCount: 214,
    location: 'Kyoto, Japan',
    restaurantName: 'Nakamura Tokichi Uji',
  ),
  PostModel(
    id: '3',
    userId: 'mock-user-3',
    imageUrl: 'https://picsum.photos/seed/travel3/400/560',
    aspectRatio: 1.4,
    title: 'Golden hour at the rooftop bar 🌅',
    authorName: 'travel.with.me',
    authorAvatar: 'https://i.pravatar.cc/150?img=3',
    likes: 3412,
    saveCount: 902,
    location: 'Bali, Indonesia',
    restaurantName: 'Ku De Ta Seminyak',
  ),
  PostModel(
    id: '4',
    userId: 'mock-user-4',
    imageUrl: 'https://picsum.photos/seed/food4/400/480',
    aspectRatio: 1.2,
    title: 'Best truffle pasta in town 🍝',
    authorName: 'pasta.lover',
    authorAvatar: 'https://i.pravatar.cc/150?img=4',
    likes: 654,
    saveCount: 178,
    location: 'Milan, Italy',
    restaurantName: 'Trattoria Milanese',
  ),
  PostModel(
    id: '5',
    userId: 'mock-user-5',
    imageUrl: 'https://picsum.photos/seed/dessert5/400/540',
    aspectRatio: 1.35,
    title: 'Strawberry mochi ice cream 🍓',
    authorName: 'sweetooth_jen',
    authorAvatar: 'https://i.pravatar.cc/150?img=5',
    likes: 2891,
    saveCount: 743,
    restaurantName: 'Mochi Sweets Harajuku',
  ),
  PostModel(
    id: '6',
    userId: 'mock-user-6',
    imageUrl: 'https://picsum.photos/seed/brunch6/400/460',
    aspectRatio: 1.15,
    title: 'Sunday brunch vibes 🥞🥂',
    authorName: 'brunch_club',
    authorAvatar: 'https://i.pravatar.cc/150?img=6',
    likes: 421,
    saveCount: 99,
    location: 'New York, USA',
    restaurantName: "Bubby's Tribeca",
  ),
  PostModel(
    id: '7',
    userId: 'mock-user-7',
    imageUrl: 'https://picsum.photos/seed/sushi7/400/580',
    aspectRatio: 1.45,
    title: 'Omakase course — worth every penny 🍣',
    authorName: 'sushi.chronicles',
    authorAvatar: 'https://i.pravatar.cc/150?img=7',
    likes: 5203,
    saveCount: 1482,
    location: 'Osaka, Japan',
    restaurantName: 'Sushi Saito Osaka',
  ),
  PostModel(
    id: '8',
    userId: 'mock-user-8',
    imageUrl: 'https://picsum.photos/seed/coffee8/400/450',
    aspectRatio: 1.12,
    title: 'Pour-over perfection ☕',
    authorName: 'third.wave.coffee',
    authorAvatar: 'https://i.pravatar.cc/150?img=8',
    likes: 998,
    saveCount: 267,
    location: 'Seoul, Korea',
    restaurantName: 'Fritz Coffee Company',
  ),
  PostModel(
    id: '9',
    userId: 'mock-user-9',
    imageUrl: 'https://picsum.photos/seed/pizza9/400/500',
    aspectRatio: 1.25,
    title: 'Wood-fired margherita pizza 🍕🔥',
    authorName: 'napoli_vibes',
    authorAvatar: 'https://i.pravatar.cc/150?img=9',
    likes: 1783,
    saveCount: 511,
    location: 'Naples, Italy',
    restaurantName: "L'Antica Pizzeria da Michele",
  ),
  PostModel(
    id: '10',
    userId: 'mock-user-10',
    imageUrl: 'https://picsum.photos/seed/dimsum10/400/520',
    aspectRatio: 1.3,
    title: 'Dim sum Sunday with the fam 🥟❤️',
    authorName: 'yum.cha.daily',
    authorAvatar: 'https://i.pravatar.cc/150?img=10',
    likes: 2340,
    saveCount: 628,
    location: 'Hong Kong',
    restaurantName: 'Tim Ho Wan',
  ),
];

#!/usr/bin/env python3
"""Generate presentable TasteSpot demo seed SQL.

The script reads exported Supabase row dumps from MOCK/database as reference
data, then writes INSERT-only demo rows to MOCK/generated_demo_seed.sql.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta
from pathlib import Path
import random
import re
import uuid


ROOT = Path(__file__).resolve().parent
DATABASE_DIR = ROOT / "database"
OUTPUT_FILE = ROOT / "generated_demo_seed.sql"
RNG = random.Random(20260428)
BASE_TIME = datetime(2026, 4, 28, 12, 0, 0)
POST_COUNT = 50


@dataclass(frozen=True)
class DemoUser:
    user_id: str
    name: str
    username: str
    bio: str
    created_at: datetime


@dataclass(frozen=True)
class Restaurant:
    restaurant_id: str
    name: str
    cuisine_id: str | None
    cuisine: str


@dataclass
class DemoPost:
    post_id: str
    user_id: str
    restaurant_id: str
    title: str
    caption: str
    created_at: datetime
    theme: str
    hashtags: list[str]
    image_urls: list[str]
    like_count: int = 0
    save_count: int = 0


THEME_DATA = {
    "sushi": {
        "keywords": ["sushi", "japanese", "omakase"],
        "titles": [
            "Creamy Salmon Mentai Don",
            "Fresh Sushi Lunch Set",
            "Omakase Night Worth Booking",
            "Torched Salmon Sushi Fix",
            "Japanese Dinner Done Right",
        ],
        "captions": [
            "Rich, creamy, and perfectly torched. The salmon was fresh and the rice stayed warm till the last bite.",
            "Clean flavours, neat plating, and a lunch set that felt worth the queue.",
            "Tiny counter, fresh cuts, and that quiet Japanese dinner mood I was craving.",
            "The mentai was smoky without being too heavy. Easy recommendation for sushi nights.",
        ],
        "hashtags": ["sushi", "japanese", "dinner", "foodie"],
        "images": [
            "https://images.unsplash.com/photo-1579871494447-9811cf80d66c?q=80&w=1200",
            "https://images.unsplash.com/photo-1553621042-f6e147245754?q=80&w=1200",
            "https://images.unsplash.com/photo-1617196034796-73dfa7b1fd56?q=80&w=1200",
        ],
    },
    "cafe": {
        "keywords": ["cafe", "coffee", "brunch"],
        "titles": [
            "Hidden Cafe Worth Visiting",
            "Cozy Brunch Spot",
            "Flat White and Slow Morning",
            "Weekend Cafe Corner",
            "Coffee Break With Cake",
        ],
        "captions": [
            "Cozy corner, strong latte, and enough natural light to make brunch feel slower.",
            "The coffee had a clean finish and the cake was soft without being too sweet.",
            "Good music, friendly staff, and a brunch plate that actually filled me up.",
            "Bookmarking this cafe for work sessions and lazy weekend catchups.",
        ],
        "hashtags": ["cafe", "coffee", "brunch", "dessert"],
        "images": [
            "https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?q=80&w=1200",
            "https://images.unsplash.com/photo-1554118811-1e0d58224f24?q=80&w=1200",
            "https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?q=80&w=1200",
        ],
    },
    "burger": {
        "keywords": ["burger", "hamburger", "western", "grill"],
        "titles": [
            "Crispy Chicken Burger Stack",
            "Late Night Burger Craving",
            "Double Cheeseburger Done Properly",
            "Messy Burger Supper",
            "Fries and Burger Combo",
        ],
        "captions": [
            "Juicy patty, crispy fries, and extra sauce. Exactly the kind of supper craving I wanted.",
            "The bun held up well and the chicken stayed crunchy all the way through.",
            "A little messy, very satisfying, and worth ordering with extra fries.",
            "Good char on the patty and a sauce that made the whole stack work.",
        ],
        "hashtags": ["burger", "western", "supper", "foodie"],
        "images": [
            "https://images.unsplash.com/photo-1568901346375-23c9450c58cd?q=80&w=1200",
            "https://images.unsplash.com/photo-1550547660-d9450f859349?q=80&w=1200",
            "https://images.unsplash.com/photo-1571091718767-18b5b1457add?q=80&w=1200",
        ],
    },
    "nasi lemak": {
        "keywords": ["malaysian", "malay", "local", "halal"],
        "titles": [
            "Classic Nasi Lemak Fix",
            "Ayam Goreng and Sambal Hit",
            "Local Breakfast Plate",
            "Nasi Lemak Worth Waking Up For",
            "Sambal With A Proper Kick",
        ],
        "captions": [
            "Crispy anchovies, sambal with a kick, and tender ayam goreng. Simple but so satisfying.",
            "The rice was fragrant and the sambal leaned spicy in the best way.",
            "This is the kind of local plate that makes a normal morning better.",
            "Crunchy, spicy, and generous enough to keep me full till late afternoon.",
        ],
        "hashtags": ["nasilemak", "malaysian", "localfood", "halal"],
        "images": [
            "https://images.unsplash.com/photo-1626777552726-4a6b54c97e46?q=80&w=1200",
            "https://images.unsplash.com/photo-1604908176997-125f25cc6f3d?q=80&w=1200",
            "https://images.unsplash.com/photo-1565299585323-38d6b0865b47?q=80&w=1200",
        ],
    },
    "dessert": {
        "keywords": ["dessert", "cake", "matcha", "cafe"],
        "titles": [
            "Matcha Latte and Burnt Cheesecake",
            "Dessert Plate For Sharing",
            "Cake Slice Worth Saving",
            "Sweet Afternoon Treat",
            "Creamy Dessert Stop",
        ],
        "captions": [
            "The burnt cheesecake was creamy in the centre and the matcha latte balanced the sweetness nicely.",
            "Not too sweet, nicely chilled, and perfect for splitting after dinner.",
            "This cake alone is enough reason to come back with friends.",
            "Soft texture, clean flavours, and a dessert counter that looked dangerous.",
        ],
        "hashtags": ["dessert", "cake", "matcha", "cafe"],
        "images": [
            "https://images.unsplash.com/photo-1488477181946-6428a0291777?q=80&w=1200",
            "https://images.unsplash.com/photo-1578985545062-69928b1d9587?q=80&w=1200",
            "https://images.unsplash.com/photo-1563729784474-d77dbb933a9e?q=80&w=1200",
        ],
    },
    "korean": {
        "keywords": ["korean", "kimchi", "fried chicken"],
        "titles": [
            "Korean Fried Chicken Night",
            "Kimchi Rice and Crispy Chicken",
            "K-Food Dinner Spread",
            "Spicy Korean Supper",
            "Cheesy Tteokbokki Craving",
        ],
        "captions": [
            "Crispy chicken, sticky glaze, and enough heat to keep the table quiet for a minute.",
            "Loved the kimchi rice and the fried chicken stayed crunchy under the sauce.",
            "Big portions, bold flavours, and a good pick for sharing with friends.",
            "The tteokbokki was chewy, spicy, and exactly what I wanted after work.",
        ],
        "hashtags": ["korean", "friedchicken", "spicy", "supper"],
        "images": [
            "https://images.unsplash.com/photo-1626082927389-6cd097cdc6ec?q=80&w=1200",
            "https://images.unsplash.com/photo-1590301157890-4810ed352733?q=80&w=1200",
            "https://images.unsplash.com/photo-1583224964978-2257b960c3d3?q=80&w=1200",
        ],
    },
    "thai": {
        "keywords": ["thai", "tom yum", "basil"],
        "titles": [
            "Spicy Thai Basil Rice",
            "Tom Yum Dinner Bowl",
            "Thai Food With Heat",
            "Crispy Egg Basil Chicken",
            "Sour Spicy Thai Fix",
        ],
        "captions": [
            "Fragrant basil, spicy minced chicken, and a crispy egg on top. The heat builds nicely.",
            "Tom yum was sour, spicy, and loaded enough to feel like a full meal.",
            "A proper Thai craving plate with enough chilli to wake me up.",
            "The basil chicken had great wok flavour and the egg made it better.",
        ],
        "hashtags": ["thai", "spicy", "dinner", "foodie"],
        "images": [
            "https://images.unsplash.com/photo-1562565652-a0d8f0c59eb4?q=80&w=1200",
            "https://images.unsplash.com/photo-1574484284002-952d92456975?q=80&w=1200",
            "https://images.unsplash.com/photo-1569562211093-4ed0d0758f12?q=80&w=1200",
        ],
    },
    "noodles": {
        "keywords": ["noodle", "ramen", "chinese noodle", "laksa"],
        "titles": [
            "Best Supper Noodles",
            "Late Night Ramen Craving",
            "Dry Noodles With Extra Chilli",
            "Comfort Bowl After Work",
            "Soup Noodles On A Rainy Day",
        ],
        "captions": [
            "Springy noodles, rich broth, and just enough chilli oil to make it addictive.",
            "This bowl hit the spot after a long day. Warm, savoury, and properly comforting.",
            "The noodles had a good bite and the sauce clung to every strand.",
            "Simple supper bowl, quick service, and a broth I would come back for.",
        ],
        "hashtags": ["noodles", "ramen", "supper", "spicy"],
        "images": [
            "https://images.unsplash.com/photo-1569718212165-3a8278d5f624?q=80&w=1200",
            "https://images.unsplash.com/photo-1612929633738-8fe44f7ec841?q=80&w=1200",
            "https://images.unsplash.com/photo-1552611052-33e04de081de?q=80&w=1200",
        ],
    },
    "pasta": {
        "keywords": ["italian", "pasta", "western"],
        "titles": [
            "Creamy Pasta Dinner",
            "Pesto Pasta Worth Sharing",
            "Italian Night Out",
            "Seafood Pasta Plate",
            "Comforting Carbonara Bowl",
        ],
        "captions": [
            "Creamy without feeling too heavy, with enough parmesan to make the whole plate work.",
            "The pasta was cooked just right and the sauce had a nice savoury finish.",
            "Good spot for a calmer dinner when you still want something filling.",
            "Seafood was fresh, pasta had bite, and the portion was generous.",
        ],
        "hashtags": ["pasta", "western", "dinner", "foodie"],
        "images": [
            "https://images.unsplash.com/photo-1621996346565-e3dbc646d9a9?q=80&w=1200",
            "https://images.unsplash.com/photo-1473093295043-cdd812d0e601?q=80&w=1200",
            "https://images.unsplash.com/photo-1551183053-bf91a1d81141?q=80&w=1200",
        ],
    },
    "chicken rice": {
        "keywords": ["chicken", "malaysian", "chinese", "halal"],
        "titles": [
            "Chicken Rice Lunch Win",
            "Roast Chicken Rice Plate",
            "Comfort Lunch Favourite",
            "Tender Chicken and Garlic Rice",
            "Quick Chicken Rice Stop",
        ],
        "captions": [
            "Tender chicken, fragrant rice, and chilli sauce that made the whole plate brighter.",
            "Fast lunch, clean flavours, and the roast skin had a nice bite.",
            "One of those simple plates that works when you do not want to think too much.",
            "The rice was garlicky, the chicken was juicy, and the soup was warm.",
        ],
        "hashtags": ["chickenrice", "malaysian", "localfood", "lunch"],
        "images": [
            "https://images.unsplash.com/photo-1604908176997-125f25cc6f3d?q=80&w=1200",
            "https://images.unsplash.com/photo-1532550907401-a500c9a57435?q=80&w=1200",
            "https://images.unsplash.com/photo-1598515214211-89d3c73ae83b?q=80&w=1200",
        ],
    },
}

COMMENT_TEMPLATES = [
    "This looks so good!",
    "Need to try this place soon.",
    "The portion looks worth it.",
    "Adding this to my food list.",
    "That sauce looks amazing.",
    "Perfect supper spot.",
    "The plating is really nice.",
    "I love this cafe vibe.",
    "This looks like a great weekend spot.",
    "The price looks pretty reasonable.",
    "I would order this with extra chilli.",
    "Saving this for my next food run.",
]

DEMO_USERS = [
    ("Chloe Tan", "chloe_eats", "Cafe hopping around KL."),
    ("Ryan Lim", "ryan_nomnom", "Always searching for good noodles."),
    ("Maya Wong", "maya_munch", "Dessert and brunch lover."),
    ("Adam Lee", "adam_bites", "Burger and western food fan."),
    ("Sara Ng", "sara_spicy", "Loves spicy food and Thai dishes."),
    ("Daniel Ho", "daniel_sushi", "Japanese food explorer."),
    ("Nina Koh", "nina_kfood", "Korean food and street snacks."),
    ("Marcus Teo", "marcus_local", "Local Malaysian food hunter."),
    ("Emily Chan", "emily_cafe", "Coffee, cakes, and cozy corners."),
    ("Jason Yap", "jason_supper", "Supper spots and late-night eats."),
]


def read_rows(filename: str) -> list[dict[str, object]]:
    path = DATABASE_DIR / filename
    if not path.exists():
        return []
    text = path.read_text(encoding="utf-8")
    return parse_insert_rows(text)


def parse_insert_rows(sql: str) -> list[dict[str, object]]:
    match = re.search(r"INSERT\s+INTO\s+.+?\((.*?)\)\s+VALUES\s+", sql, re.I | re.S)
    if not match:
        return []
    columns = [clean_identifier(part.strip()) for part in split_columns(match.group(1))]
    values_start = match.end()
    values_end = sql.rfind(";")
    value_text = sql[values_start:values_end if values_end != -1 else len(sql)]
    tuples = parse_value_tuples(value_text)
    return [dict(zip(columns, row)) for row in tuples if len(row) == len(columns)]


def split_columns(text: str) -> list[str]:
    return [part.strip() for part in text.split(",")]


def clean_identifier(value: str) -> str:
    return value.strip().strip('"')


def parse_value_tuples(text: str) -> list[list[object]]:
    rows: list[list[object]] = []
    i = 0
    while i < len(text):
        if text[i] != "(":
            i += 1
            continue
        row, i = parse_tuple(text, i + 1)
        rows.append(row)
    return rows


def parse_tuple(text: str, i: int) -> tuple[list[object], int]:
    values: list[object] = []
    token: list[str] = []
    in_string = False

    while i < len(text):
        ch = text[i]
        if in_string:
            if ch == "'":
                if i + 1 < len(text) and text[i + 1] == "'":
                    token.append("'")
                    i += 2
                    continue
                in_string = False
                i += 1
                continue
            token.append(ch)
            i += 1
            continue

        if ch == "'":
            in_string = True
            i += 1
            continue
        if ch == ",":
            values.append(convert_token("".join(token)))
            token = []
            i += 1
            continue
        if ch == ")":
            values.append(convert_token("".join(token)))
            return values, i + 1

        token.append(ch)
        i += 1

    return values, i


def convert_token(token: str) -> object:
    value = token.strip()
    if value.lower() == "null":
        return None
    if value.lower() == "true":
        return True
    if value.lower() == "false":
        return False
    if value == "":
        return ""
    return value


def new_uuid() -> str:
    return str(uuid.uuid4())


def sql_value(value: object) -> str:
    if value is None:
        return "NULL"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, int):
        return str(value)
    if isinstance(value, datetime):
        return quote(value.strftime("%Y-%m-%d %H:%M:%S.%f"))
    return quote(str(value))


def quote(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


def insert_sql(table: str, columns: list[str], rows: list[list[object]], conflict: str) -> str:
    if not rows:
        return ""
    rendered_rows = []
    for row in rows:
        rendered_rows.append("  (" + ", ".join(sql_value(value) for value in row) + ")")
    column_sql = ", ".join(quote_identifier(column) for column in columns)
    return (
        f'INSERT INTO public.{table} ({column_sql}) VALUES\n'
        + ",\n".join(rendered_rows)
        + f"\n{conflict};\n"
    )


def quote_identifier(identifier: str) -> str:
    if identifier.islower() and re.fullmatch(r"[a-z_][a-z0-9_]*", identifier):
        return identifier
    return f'"{identifier}"'


def unique_username(base: str, existing: set[str]) -> str:
    candidate = base
    suffix = 2
    while candidate.lower() in existing:
        candidate = f"{base}{suffix}"
        suffix += 1
    existing.add(candidate.lower())
    return candidate


def make_users(existing_usernames: set[str]) -> list[DemoUser]:
    users = []
    for i, (name, username, bio) in enumerate(DEMO_USERS):
        created_at = BASE_TIME - timedelta(days=22 - i, hours=RNG.randint(0, 8))
        users.append(
            DemoUser(
                user_id=new_uuid(),
                name=name,
                username=unique_username(username, existing_usernames),
                bio=bio,
                created_at=created_at,
            )
        )
    return users


def load_restaurants(cuisine_by_id: dict[str, str]) -> list[Restaurant]:
    rows = read_rows("Restaurant_rows (4).sql")
    restaurants = []
    for row in rows:
        if row.get("isDisabled") is True:
            continue
        restaurant_id = str(row.get("restaurant_Id") or "")
        name = str(row.get("restaurant_name") or "").strip()
        if not restaurant_id or not name:
            continue
        cuisine_id = row.get("main_cuisine_id")
        cuisine_id_text = str(cuisine_id) if cuisine_id else None
        restaurants.append(
            Restaurant(
                restaurant_id=restaurant_id,
                name=name,
                cuisine_id=cuisine_id_text,
                cuisine=cuisine_by_id.get(cuisine_id_text or "", ""),
            )
        )
    if not restaurants:
        raise RuntimeError("No usable restaurants found in MOCK/database/Restaurant_rows (4).sql")
    return restaurants


def pick_restaurant(theme: str, restaurants: list[Restaurant], used_counts: dict[str, int]) -> Restaurant:
    keywords = THEME_DATA[theme]["keywords"]
    matches = [
        restaurant
        for restaurant in restaurants
        if any(keyword.lower() in restaurant.name.lower() for keyword in keywords)
        or any(keyword.lower() in restaurant.cuisine.lower() for keyword in keywords)
    ]
    pool = matches or restaurants
    pool = sorted(pool, key=lambda r: (used_counts.get(r.restaurant_id, 0), r.name))
    top = pool[: max(3, min(12, len(pool)))]
    choice = RNG.choice(top)
    used_counts[choice.restaurant_id] = used_counts.get(choice.restaurant_id, 0) + 1
    return choice


def created_time(index: int) -> datetime:
    if index < 8:
        return BASE_TIME - timedelta(hours=RNG.randint(1, 18), minutes=RNG.randint(0, 59))
    if index < 18:
        return BASE_TIME - timedelta(days=1, hours=RNG.randint(0, 23), minutes=RNG.randint(0, 59))
    if index < 36:
        return BASE_TIME - timedelta(days=RNG.randint(2, 7), hours=RNG.randint(0, 23))
    return BASE_TIME - timedelta(days=RNG.randint(8, 30), hours=RNG.randint(0, 23))


def make_posts(users: list[DemoUser], restaurants: list[Restaurant]) -> list[DemoPost]:
    themes = list(THEME_DATA)
    used_counts: dict[str, int] = {}
    posts = []
    for i in range(POST_COUNT):
        theme = themes[i % len(themes)]
        data = THEME_DATA[theme]
        user = users[i % len(users)]
        restaurant = pick_restaurant(theme, restaurants, used_counts)
        title = data["titles"][(i // len(themes)) % len(data["titles"])]
        caption = data["captions"][i % len(data["captions"])]
        tags = list(dict.fromkeys(data["hashtags"] + ["foodie"]))[:4]
        if i % 3 == 0:
            caption = f"{caption} #{tags[0]} #{tags[1]}"
        image_count = 1 + (1 if i % 4 == 0 else 0) + (1 if i % 17 == 0 else 0)
        image_urls = [data["images"][(i + n) % len(data["images"])] for n in range(image_count)]
        posts.append(
            DemoPost(
                post_id=new_uuid(),
                user_id=user.user_id,
                restaurant_id=restaurant.restaurant_id,
                title=title,
                caption=caption,
                created_at=created_time(i),
                theme=theme,
                hashtags=tags,
                image_urls=image_urls,
            )
        )
    posts.sort(key=lambda post: post.created_at, reverse=True)
    return posts


def target_like_count(index: int) -> int:
    if index < 12:
        return RNG.randint(6, 9)
    if index < 40:
        return RNG.randint(2, 5)
    return RNG.randint(0, 2)


def target_save_count(index: int) -> int:
    if index < 10:
        return RNG.randint(4, 8)
    if index < 40:
        return RNG.randint(1, 3)
    return RNG.randint(0, 1)


def target_comment_count(index: int) -> int:
    if index < 12:
        return RNG.randint(3, 6)
    if index < 40:
        return RNG.randint(1, 3)
    return RNG.randint(0, 1)


def choose_interaction_users(post: DemoPost, users: list[DemoUser], count: int) -> list[DemoUser]:
    candidates = [user for user in users if user.user_id != post.user_id]
    RNG.shuffle(candidates)
    if count > len(candidates):
        candidates.append(next(user for user in users if user.user_id == post.user_id))
    return candidates[:count]


def after(post_time: datetime, max_days: int = 5) -> datetime:
    return post_time + timedelta(
        hours=RNG.randint(1, max(2, max_days * 24)),
        minutes=RNG.randint(0, 59),
        seconds=RNG.randint(0, 59),
    )


def build_seed() -> tuple[str, dict[str, int]]:
    existing_users = read_rows("User_rows (1).sql")
    existing_usernames = {
        str(row.get("username")).lower()
        for row in existing_users
        if row.get("username") is not None
    }

    cuisine_rows = read_rows("Cuisine_rows.sql")
    cuisine_by_id = {
        str(row.get("type_id")): str(row.get("desc") or "")
        for row in cuisine_rows
        if row.get("type_id") is not None
    }

    hashtag_rows = read_rows("hashtag_rows.sql")
    hashtag_ids = {
        str(row.get("name")).lower(): str(row.get("hashtag_id"))
        for row in hashtag_rows
        if row.get("name") is not None and row.get("hashtag_id") is not None
    }

    users = make_users(existing_usernames)
    restaurants = load_restaurants(cuisine_by_id)
    posts = make_posts(users, restaurants)

    needed_hashtags = sorted({tag for post in posts for tag in post.hashtags})
    new_hashtags = []
    for tag in needed_hashtags:
        if tag.lower() not in hashtag_ids:
            hashtag_ids[tag.lower()] = new_uuid()
            new_hashtags.append((hashtag_ids[tag.lower()], tag.lower()))

    likes = []
    comments = []
    collections = []
    collection_items = []
    post_hashtags = []
    post_images = []

    collection_by_user: dict[str, str] = {}
    for user in users:
        collection_id = new_uuid()
        collection_by_user[user.user_id] = collection_id
        collections.append(
            [
                collection_id,
                user.user_id,
                "Saved Posts",
                "Default saved posts collection",
                False,
                user.created_at + timedelta(minutes=15),
                "POST",
                True,
            ]
        )

    for index, post in enumerate(posts):
        like_users = choose_interaction_users(post, users, target_like_count(index))
        save_users = choose_interaction_users(post, users, target_save_count(index))
        comment_users = choose_interaction_users(post, users, target_comment_count(index))
        post.like_count = len(like_users)
        post.save_count = len(save_users)

        for image_url in post.image_urls:
            post_images.append([new_uuid(), post.post_id, image_url])

        for tag in post.hashtags:
            post_hashtags.append([post.post_id, hashtag_ids[tag.lower()]])

        for user in like_users:
            likes.append([post.post_id, user.user_id, after(post.created_at, max_days=3)])

        for user in comment_users:
            comments.append(
                [
                    new_uuid(),
                    post.post_id,
                    user.user_id,
                    RNG.choice(COMMENT_TEMPLATES),
                    after(post.created_at, max_days=4),
                    False,
                ]
            )

        for user in save_users:
            collection_items.append(
                [
                    new_uuid(),
                    collection_by_user[user.user_id],
                    None,
                    post.post_id,
                    after(post.created_at, max_days=6),
                ]
            )

    user_rows = [
        [user.user_id, user.name, user.bio, user.created_at, "", "user", user.username]
        for user in users
    ]
    post_rows = [
        [
            post.post_id,
            post.user_id,
            post.restaurant_id,
            post.caption,
            post.created_at,
            None,
            post.like_count,
            post.save_count,
            False,
            post.title,
            False,
            False,
            None,
            True,
        ]
        for post in posts
    ]
    hashtag_rows_out = [[hashtag_id, name] for hashtag_id, name in new_hashtags]

    chunks = [
        "-- Generated TasteSpot demo seed data.",
        "-- INSERT-only file. Review before running in Supabase SQL Editor.",
        "BEGIN;\n",
        insert_sql(
            '"User"',
            ["user_Id", "name", "bio", "created_At", "password", "role", "username"],
            user_rows,
            'ON CONFLICT ("user_Id") DO NOTHING',
        ),
        insert_sql(
            "hashtag",
            ["hashtag_id", "name"],
            hashtag_rows_out,
            'ON CONFLICT ("hashtag_id") DO NOTHING',
        ),
        insert_sql(
            '"Post"',
            [
                "post_Id",
                "user_Id",
                "restaurant_Id",
                "caption",
                "created_At",
                "updated_At",
                "likeCount",
                "saveCount",
                "isRemoved",
                "title",
                "isBlocked",
                "isPending",
                "restaurant_approval_id",
                "visible_to_owner",
            ],
            post_rows,
            'ON CONFLICT ("post_Id") DO NOTHING',
        ),
        insert_sql(
            '"Post_Image"',
            ["image_Id", "post_Id", "image_url"],
            post_images,
            'ON CONFLICT ("image_Id") DO NOTHING',
        ),
        insert_sql(
            "post_hashtag",
            ["post_Id", "hashtag_id"],
            post_hashtags,
            "ON CONFLICT DO NOTHING",
        ),
        insert_sql(
            '"Likes"',
            ["post_Id", "user_Id", "created_At"],
            likes,
            "ON CONFLICT DO NOTHING",
        ),
        insert_sql(
            '"Comment"',
            ["comment_Id", "post_Id", "user_Id", "content", "created_At", "isBlocked"],
            comments,
            'ON CONFLICT ("comment_Id") DO NOTHING',
        ),
        insert_sql(
            "collections",
            [
                "collection_Id",
                "user_Id",
                "name",
                "description",
                "is_public",
                "created_At",
                "collection_type",
                "is_default",
            ],
            collections,
            'ON CONFLICT ("collection_Id") DO NOTHING',
        ),
        insert_sql(
            "collections_item",
            ["item_Id", "collection_Id", "restaurant_id", "post_id", "savedAt"],
            collection_items,
            'ON CONFLICT ("item_Id") DO NOTHING',
        ),
        "COMMIT;\n",
    ]

    summary = {
        "users": len(users),
        "posts": len(posts),
        "post_images": len(post_images),
        "hashtags": len(new_hashtags),
        "likes": len(likes),
        "comments": len(comments),
        "collections": len(collections),
        "saved_posts": len(collection_items),
    }
    return "\n".join(chunk for chunk in chunks if chunk), summary


def main() -> None:
    sql, summary = build_seed()
    OUTPUT_FILE.write_text(sql, encoding="utf-8")

    print(f"Generated users: {summary['users']}")
    print(f"Generated posts: {summary['posts']}")
    print(f"Generated post images: {summary['post_images']}")
    print(f"Generated hashtags: {summary['hashtags']}")
    print(f"Generated likes: {summary['likes']}")
    print(f"Generated comments: {summary['comments']}")
    print(f"Generated collections: {summary['collections']}")
    print(f"Generated saved posts: {summary['saved_posts']}")
    print(f"Output: {OUTPUT_FILE.name}")


if __name__ == "__main__":
    main()

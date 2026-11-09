create schema if not exists scenora;

revoke all on schema scenora from public, anon, authenticated;

create table scenora.users (
  id text primary key,
  username text not null unique,
  email text not null unique,
  display_name text not null,
  bio text not null default '',
  location text not null default '',
  avatar_url text,
  cover_url text,
  password_salt text not null,
  password_hash text not null,
  account_status text not null default 'active'
    check (account_status in ('active', 'disabled')),
  created_at timestamptz not null,
  updated_at timestamptz not null
);

create table scenora.sessions (
  id text primary key,
  user_id text not null references scenora.users(id) on delete cascade,
  access_hash text not null unique,
  refresh_hash text not null unique,
  access_expires_at timestamptz not null,
  refresh_expires_at timestamptz not null
);

create table scenora.movies (
  id text primary key,
  title text not null,
  year integer,
  genre text,
  overview text,
  tmdb_rating numeric,
  poster_path text,
  backdrop_path text
);

create table scenora.reviews (
  id text primary key,
  user_id text not null references scenora.users(id) on delete cascade,
  movie_id text not null references scenora.movies(id) on delete restrict,
  rating integer not null check (rating between 1 and 5),
  text text not null check (char_length(text) between 1 and 2000),
  contains_spoiler boolean not null default false,
  image_urls jsonb not null default '[]'::jsonb
    check (jsonb_typeof(image_urls) = 'array'),
  created_at timestamptz not null,
  updated_at timestamptz not null
);

create table scenora.likes (
  id text primary key,
  review_id text not null references scenora.reviews(id) on delete cascade,
  user_id text not null references scenora.users(id) on delete cascade,
  created_at timestamptz not null,
  unique (review_id, user_id)
);

create table scenora.comments (
  id text primary key,
  review_id text not null references scenora.reviews(id) on delete cascade,
  user_id text not null references scenora.users(id) on delete cascade,
  text text not null check (char_length(text) between 1 and 1000),
  parent_comment_id text references scenora.comments(id) on delete set null,
  created_at timestamptz not null,
  updated_at timestamptz not null
);

create table scenora.follows (
  id text primary key,
  follower_id text not null references scenora.users(id) on delete cascade,
  following_id text not null references scenora.users(id) on delete cascade,
  created_at timestamptz not null,
  check (follower_id <> following_id),
  unique (follower_id, following_id)
);

create table scenora.watchlist (
  id text primary key,
  user_id text not null references scenora.users(id) on delete cascade,
  movie_id text not null references scenora.movies(id) on delete cascade,
  created_at timestamptz not null,
  unique (user_id, movie_id)
);

create table scenora.messages (
  id text primary key,
  user_id text not null references scenora.users(id) on delete cascade,
  text text not null check (char_length(text) between 1 and 500),
  created_at timestamptz not null
);

create index sessions_user_id_idx on scenora.sessions(user_id);
create index sessions_access_hash_idx on scenora.sessions(access_hash);
create index sessions_refresh_hash_idx on scenora.sessions(refresh_hash);
create index reviews_user_created_idx on scenora.reviews(user_id, created_at desc);
create index reviews_movie_created_idx on scenora.reviews(movie_id, created_at desc);
create index likes_review_id_idx on scenora.likes(review_id);
create index comments_review_created_idx on scenora.comments(review_id, created_at);
create index follows_following_id_idx on scenora.follows(following_id);
create index watchlist_user_id_idx on scenora.watchlist(user_id);
create index messages_created_at_idx on scenora.messages(created_at);

alter table scenora.users enable row level security;
alter table scenora.sessions enable row level security;
alter table scenora.movies enable row level security;
alter table scenora.reviews enable row level security;
alter table scenora.likes enable row level security;
alter table scenora.comments enable row level security;
alter table scenora.follows enable row level security;
alter table scenora.watchlist enable row level security;
alter table scenora.messages enable row level security;

revoke all on all tables in schema scenora from public, anon, authenticated;

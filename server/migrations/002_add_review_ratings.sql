create table scenora.review_ratings (
  id text primary key,
  review_id text not null references scenora.reviews(id) on delete cascade,
  user_id text not null references scenora.users(id) on delete cascade,
  rating integer not null check (rating between 1 and 5),
  created_at timestamptz not null,
  updated_at timestamptz not null,
  unique (review_id, user_id)
);

create index review_ratings_review_id_idx
  on scenora.review_ratings(review_id);
create index review_ratings_user_id_idx
  on scenora.review_ratings(user_id);

alter table scenora.review_ratings enable row level security;
revoke all on scenora.review_ratings from public, anon, authenticated;

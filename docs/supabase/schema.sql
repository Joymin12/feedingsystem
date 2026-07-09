create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text unique,
  login_id text unique,
  farm_name text not null default '새 한우 농장',
  preferred_stage text,
  is_admin boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.user_ingredients (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  ingredient_id text not null,
  created_at timestamptz not null default now(),
  unique (user_id, ingredient_id)
);

create table if not exists public.community_posts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  excerpt text not null,
  label text not null,
  created_at timestamptz not null default now()
);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (
    id,
    email,
    login_id,
    farm_name
  )
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data ->> 'login_id', new.email),
    coalesce(new.raw_user_meta_data ->> 'farm_name', '새 한우 농장')
  )
  on conflict (id) do update
  set
    email = excluded.email,
    login_id = coalesce(public.profiles.login_id, excluded.login_id),
    farm_name = coalesce(public.profiles.farm_name, excluded.farm_name);

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

alter table public.profiles enable row level security;
alter table public.user_ingredients enable row level security;
alter table public.community_posts enable row level security;

drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own"
on public.profiles
for select
to authenticated
using (auth.uid() = id);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
on public.profiles
for update
to authenticated
using (auth.uid() = id)
with check (auth.uid() = id);

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own"
on public.profiles
for insert
to authenticated
with check (auth.uid() = id);

drop policy if exists "user_ingredients_select_own" on public.user_ingredients;
create policy "user_ingredients_select_own"
on public.user_ingredients
for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists "user_ingredients_insert_own" on public.user_ingredients;
create policy "user_ingredients_insert_own"
on public.user_ingredients
for insert
to authenticated
with check (auth.uid() = user_id);

drop policy if exists "user_ingredients_delete_own" on public.user_ingredients;
create policy "user_ingredients_delete_own"
on public.user_ingredients
for delete
to authenticated
using (auth.uid() = user_id);

drop policy if exists "community_posts_read_all" on public.community_posts;
create policy "community_posts_read_all"
on public.community_posts
for select
to anon, authenticated
using (true);

drop policy if exists "community_posts_insert_own" on public.community_posts;
create policy "community_posts_insert_own"
on public.community_posts
for insert
to authenticated
with check (auth.uid() = user_id);

drop policy if exists "community_posts_delete_owner_or_admin" on public.community_posts;
create policy "community_posts_delete_owner_or_admin"
on public.community_posts
for delete
to authenticated
using (
  auth.uid() = user_id
  or exists (
    select 1
    from public.profiles
    where profiles.id = auth.uid()
      and profiles.is_admin = true
  )
);

create index if not exists idx_user_ingredients_user_id on public.user_ingredients(user_id);
create index if not exists idx_community_posts_created_at on public.community_posts(created_at desc);

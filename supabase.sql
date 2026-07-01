-- ============================================================
-- SubHlídač — databázové schéma pro Supabase
-- Spusť celé najednou v Supabase Dashboard → SQL Editor → New query
-- ============================================================

-- Tabulka s nastavením účtu (plán, měsíční limit)
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  premium boolean not null default false,
  monthly_budget numeric,
  created_at timestamptz not null default now()
);

-- Tabulka s předplatnými
create table if not exists public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  price numeric not null check (price >= 0),
  cycle text not null check (cycle in ('monthly','quarterly','yearly','weekly')),
  category text not null,
  next_renewal date not null,
  last_used date,
  notes text,
  created_at timestamptz not null default now()
);

create index if not exists subscriptions_user_id_idx on public.subscriptions(user_id);

-- ============================================================
-- Row Level Security — každý uživatel vidí a upravuje jen svoje řádky
-- ============================================================
alter table public.profiles enable row level security;
alter table public.subscriptions enable row level security;

drop policy if exists "profiles_select_own" on public.profiles;
drop policy if exists "profiles_update_own" on public.profiles;
drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_select_own" on public.profiles for select using (auth.uid() = id);
create policy "profiles_update_own" on public.profiles for update using (auth.uid() = id);
create policy "profiles_insert_own" on public.profiles for insert with check (auth.uid() = id);

drop policy if exists "subs_select_own" on public.subscriptions;
drop policy if exists "subs_insert_own" on public.subscriptions;
drop policy if exists "subs_update_own" on public.subscriptions;
drop policy if exists "subs_delete_own" on public.subscriptions;
create policy "subs_select_own" on public.subscriptions for select using (auth.uid() = user_id);
create policy "subs_insert_own" on public.subscriptions for insert with check (auth.uid() = user_id);
create policy "subs_update_own" on public.subscriptions for update using (auth.uid() = user_id);
create policy "subs_delete_own" on public.subscriptions for delete using (auth.uid() = user_id);

-- ============================================================
-- Při registraci nového uživatele mu automaticky založ profil
-- ============================================================
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id) values (new.id)
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();
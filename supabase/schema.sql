-- Schéma Supabase pour la partie sociale de l'appli Course.
-- À coller dans Supabase > SQL Editor, puis "Run". Le script peut être relancé.

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

create table if not exists public.profiles (
  id uuid primary key references auth.users on delete cascade,
  username text unique not null check (username ~ '^[a-z0-9_]{3,20}$'),
  display_name text not null default '',
  created_at timestamptz not null default now()
);

-- Demande d'ami : requester -> addressee, acceptée par addressee.
create table if not exists public.friendships (
  requester uuid not null references public.profiles on delete cascade,
  addressee uuid not null references public.profiles on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'accepted')),
  created_at timestamptz not null default now(),
  primary key (requester, addressee),
  check (requester <> addressee)
);

create table if not exists public.groups (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 60),
  owner uuid not null default auth.uid() references public.profiles on delete cascade,
  invite_code text unique not null default upper(substr(md5(random()::text), 1, 8)),
  created_at timestamptz not null default now()
);

create table if not exists public.group_members (
  group_id uuid not null references public.groups on delete cascade,
  user_id uuid not null references public.profiles on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (group_id, user_id)
);

-- Résumé d'une course partagée (pas le tracé GPS : il reste sur le téléphone).
create table if not exists public.shared_runs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references public.profiles on delete cascade,
  local_id integer not null,
  started_at timestamptz not null,
  distance_m real not null check (distance_m >= 0),
  moving_s integer not null check (moving_s >= 0),
  elev_gain_m real not null default 0,
  calories real not null default 0,
  created_at timestamptz not null default now(),
  unique (user_id, local_id)
);

create index if not exists shared_runs_user_started on public.shared_runs (user_id, started_at desc);
create index if not exists friendships_addressee on public.friendships (addressee);
create index if not exists group_members_user on public.group_members (user_id);

-- ---------------------------------------------------------------------------
-- Fonctions d'aide (security definer pour éviter la récursion des règles RLS)
-- ---------------------------------------------------------------------------

create or replace function public.are_friends(a uuid, b uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from friendships
    where status = 'accepted'
      and ((requester = a and addressee = b) or (requester = b and addressee = a))
  );
$$;

create or replace function public.is_group_member(g uuid, u uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from group_members where group_id = g and user_id = u);
$$;

create or replace function public.share_group(a uuid, b uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from group_members m1
    join group_members m2 on m1.group_id = m2.group_id
    where m1.user_id = a and m2.user_id = b
  );
$$;

-- Le créateur d'un groupe en devient automatiquement membre.
create or replace function public.add_owner_as_member()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into group_members (group_id, user_id) values (new.id, new.owner)
  on conflict do nothing;
  return new;
end;
$$;

drop trigger if exists groups_add_owner on public.groups;
create trigger groups_add_owner after insert on public.groups
  for each row execute function public.add_owner_as_member();

-- Rejoindre un groupe avec son code d'invitation.
create or replace function public.join_group(code text)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  gid uuid;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  select id into gid from groups where invite_code = upper(trim(code));
  if gid is null then
    raise exception 'Code invalide';
  end if;
  insert into group_members (group_id, user_id) values (gid, auth.uid())
  on conflict do nothing;
  return gid;
end;
$$;

-- Classement d'un groupe depuis une date (réservé aux membres).
create or replace function public.group_leaderboard(g uuid, since timestamptz)
returns table (
  user_id uuid, username text, display_name text,
  runs bigint, distance_m double precision, moving_s bigint, elev_gain_m double precision
)
language sql stable security definer set search_path = public as $$
  select p.id, p.username, p.display_name,
         count(r.id), coalesce(sum(r.distance_m), 0), coalesce(sum(r.moving_s), 0),
         coalesce(sum(r.elev_gain_m), 0)
  from group_members m
  join profiles p on p.id = m.user_id
  left join shared_runs r on r.user_id = m.user_id and r.started_at >= since
  where m.group_id = g and public.is_group_member(g, auth.uid())
  group by p.id, p.username, p.display_name
  order by 5 desc;
$$;

-- ---------------------------------------------------------------------------
-- Sécurité : Row Level Security
-- ---------------------------------------------------------------------------

alter table public.profiles enable row level security;
alter table public.friendships enable row level security;
alter table public.groups enable row level security;
alter table public.group_members enable row level security;
alter table public.shared_runs enable row level security;

-- Profils : visibles par tout utilisateur connecté (pour la recherche d'amis),
-- modifiables uniquement par leur propriétaire.
drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles for select to authenticated using (true);
drop policy if exists profiles_insert on public.profiles;
create policy profiles_insert on public.profiles for insert to authenticated with check (id = auth.uid());
drop policy if exists profiles_update on public.profiles;
create policy profiles_update on public.profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

-- Amitiés : visibles et supprimables par les deux personnes, créées en attente
-- par le demandeur, acceptées uniquement par le destinataire.
drop policy if exists friendships_select on public.friendships;
create policy friendships_select on public.friendships for select to authenticated
  using (auth.uid() in (requester, addressee));
drop policy if exists friendships_insert on public.friendships;
create policy friendships_insert on public.friendships for insert to authenticated
  with check (requester = auth.uid() and status = 'pending');
drop policy if exists friendships_accept on public.friendships;
create policy friendships_accept on public.friendships for update to authenticated
  using (addressee = auth.uid()) with check (addressee = auth.uid() and status = 'accepted');
drop policy if exists friendships_delete on public.friendships;
create policy friendships_delete on public.friendships for delete to authenticated
  using (auth.uid() in (requester, addressee));

-- Groupes : visibles par leurs membres, gérés par leur créateur.
drop policy if exists groups_select on public.groups;
create policy groups_select on public.groups for select to authenticated
  using (owner = auth.uid() or public.is_group_member(id, auth.uid()));
drop policy if exists groups_insert on public.groups;
create policy groups_insert on public.groups for insert to authenticated with check (owner = auth.uid());
drop policy if exists groups_update on public.groups;
create policy groups_update on public.groups for update to authenticated
  using (owner = auth.uid()) with check (owner = auth.uid());
drop policy if exists groups_delete on public.groups;
create policy groups_delete on public.groups for delete to authenticated using (owner = auth.uid());

-- Membres : visibles par les membres du groupe. On rejoint via join_group(),
-- on peut quitter un groupe, et le créateur peut retirer quelqu'un.
drop policy if exists members_select on public.group_members;
create policy members_select on public.group_members for select to authenticated
  using (public.is_group_member(group_id, auth.uid()));
drop policy if exists members_delete on public.group_members;
create policy members_delete on public.group_members for delete to authenticated
  using (
    user_id = auth.uid()
    or exists (select 1 from public.groups g where g.id = group_id and g.owner = auth.uid())
  );

-- Courses partagées : visibles par soi, ses amis et les membres de ses groupes.
drop policy if exists runs_select on public.shared_runs;
create policy runs_select on public.shared_runs for select to authenticated
  using (
    user_id = auth.uid()
    or public.are_friends(user_id, auth.uid())
    or public.share_group(user_id, auth.uid())
  );
drop policy if exists runs_insert on public.shared_runs;
create policy runs_insert on public.shared_runs for insert to authenticated with check (user_id = auth.uid());
drop policy if exists runs_update on public.shared_runs;
create policy runs_update on public.shared_runs for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists runs_delete on public.shared_runs;
create policy runs_delete on public.shared_runs for delete to authenticated using (user_id = auth.uid());

-- Les fonctions d'aide ne doivent être appelées que par des utilisateurs connectés.
revoke execute on function public.join_group(text) from anon, public;
grant execute on function public.join_group(text) to authenticated;
revoke execute on function public.group_leaderboard(uuid, timestamptz) from anon, public;
grant execute on function public.group_leaderboard(uuid, timestamptz) to authenticated;

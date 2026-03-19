-- ===== Family v1 Database Design (Supabase / PostgreSQL) =====
-- 目标：
-- 1. Family 作为租户边界
-- 2. 业务权限落在 family_members.role
-- 3. 只有家庭活跃成员可以加入订单并参与点菜
--
-- 说明：
-- - 本脚本面向 fresh project 初始化执行
-- - 已登录家庭成员可直接通过 RLS 访问其有权限的数据

create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;

-- ===== Token helpers =====

create or replace function public.generate_join_code()
returns text
language sql
set search_path = public, extensions
as $$
  select upper(substr(encode(extensions.gen_random_bytes(6), 'hex'), 1, 10));
$$;

create or replace function public.generate_share_token()
returns text
language sql
set search_path = public, extensions
as $$
  select translate(
    replace(encode(extensions.gen_random_bytes(24), 'base64'), '=', ''),
    '/+',
    '_-'
  );
$$;

-- ===== Enum types =====

create type public.family_role as enum ('owner', 'admin', 'member');
create type public.family_member_status as enum ('active', 'removed');
create type public.order_status as enum ('ordering', 'placed', 'finished');
create type public.item_status as enum ('waiting', 'cooking', 'done');

-- ===== Tables =====

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text not null unique,
  avatar_url text,
  is_admin boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.families (
  id uuid primary key default extensions.gen_random_uuid(),
  name text not null,
  created_by uuid not null references public.profiles(id),
  join_code text not null unique default public.generate_join_code(),
  join_code_rotated_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  archived_at timestamptz
);

create table public.family_members (
  id uuid primary key default extensions.gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role public.family_role not null,
  status public.family_member_status not null default 'active',
  joined_at timestamptz not null default now(),
  removed_at timestamptz,
  invited_by uuid references public.profiles(id),
  unique (family_id, user_id)
);

create table public.dishes (
  id uuid primary key default extensions.gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  name text not null,
  category text not null,
  image_url text,
  ingredients jsonb not null default '[]',
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  archived_at timestamptz,
  unique (family_id, name)
);

create table public.orders (
  id uuid primary key default extensions.gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete restrict,
  status public.order_status not null default 'ordering',
  share_token text not null unique default public.generate_share_token(),
  created_by uuid not null references public.profiles(id),
  current_round int not null default 1 check (current_round > 0),
  created_at timestamptz not null default now(),
  placed_at timestamptz,
  finished_at timestamptz
);

create table public.order_members (
  id uuid primary key default extensions.gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  user_id uuid not null references public.profiles(id),
  joined_at timestamptz not null default now()
);

create table public.order_items (
  id uuid primary key default extensions.gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  dish_id uuid not null references public.dishes(id),
  added_by_member_id uuid references public.order_members(id),
  quantity int not null default 1 check (quantity > 0),
  status public.item_status not null default 'waiting',
  order_round int not null default 1 check (order_round > 0),
  created_at timestamptz not null default now()
);

-- ===== Indexes =====

create index family_members_user_active_idx
  on public.family_members (user_id)
  where status = 'active';

create index family_members_family_active_idx
  on public.family_members (family_id)
  where status = 'active';

create index dishes_family_idx on public.dishes (family_id);
create index dishes_family_category_idx on public.dishes (family_id, category);
create index orders_family_idx on public.orders (family_id);
create index orders_status_idx on public.orders (status);
create unique index order_members_order_user_unique_idx
  on public.order_members (order_id, user_id);
create index order_members_order_idx on public.order_members (order_id);
create index order_members_user_idx on public.order_members (user_id);
create index order_items_order_idx on public.order_items (order_id);
create index order_items_dish_idx on public.order_items (dish_id);

-- ===== Helper functions =====

create or replace function public.is_platform_admin()
returns boolean
language sql
stable
security definer
set search_path = public, extensions
as $$
  select coalesce(
    (
      select p.is_admin
      from public.profiles p
      where p.id = auth.uid()
    ),
    false
  );
$$;

create or replace function public.is_active_family_member(target_family_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, extensions
as $$
  select exists (
    select 1
    from public.family_members fm
    where fm.family_id = target_family_id
      and fm.user_id = auth.uid()
      and fm.status = 'active'
  );
$$;

create or replace function public.family_role_of(target_family_id uuid)
returns public.family_role
language sql
stable
security definer
set search_path = public, extensions
as $$
  select fm.role
  from public.family_members fm
  where fm.family_id = target_family_id
    and fm.user_id = auth.uid()
    and fm.status = 'active'
  limit 1;
$$;

create or replace function public.is_family_admin(target_family_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, extensions
as $$
  select
    public.is_platform_admin()
    or exists (
      select 1
      from public.family_members fm
      where fm.family_id = target_family_id
        and fm.user_id = auth.uid()
        and fm.status = 'active'
        and fm.role in ('owner', 'admin')
    );
$$;

create or replace function public.can_view_profile(target_profile_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, extensions
as $$
  select
    auth.uid() = target_profile_id
    or public.is_platform_admin()
    or exists (
      select 1
      from public.family_members mine
      join public.family_members target
        on target.family_id = mine.family_id
      where mine.user_id = auth.uid()
        and mine.status = 'active'
        and target.user_id = target_profile_id
        and target.status = 'active'
    );
$$;

create or replace function public.order_family_id(target_order_id uuid)
returns uuid
language sql
stable
security definer
set search_path = public, extensions
as $$
  select o.family_id
  from public.orders o
  where o.id = target_order_id;
$$;

create or replace function public.is_current_user_order_member(
  target_order_id uuid,
  target_order_member_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public, extensions
as $$
  select exists (
    select 1
    from public.order_members om
    where om.id = target_order_member_id
      and om.order_id = target_order_id
      and om.user_id = auth.uid()
  );
$$;

-- ===== Triggers =====

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
set search_path = public, extensions
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.ensure_order_created_by_family_member()
returns trigger
language plpgsql
set search_path = public, extensions
as $$
begin
  if not exists (
    select 1
    from public.family_members fm
    where fm.family_id = new.family_id
      and fm.user_id = new.created_by
      and fm.status = 'active'
  ) then
    raise exception 'Order creator must be an active family member';
  end if;

  return new;
end;
$$;

create or replace function public.check_one_active_order()
returns trigger
language plpgsql
set search_path = public, extensions
as $$
begin
  if new.user_id is null then
    return new;
  end if;

  if exists (
    select 1
    from public.orders current_order
    where current_order.id = new.order_id
      and current_order.status != 'finished'
  ) then
    if exists (
      select 1
      from public.order_members om
      join public.orders o on o.id = om.order_id
      where om.user_id = new.user_id
        and o.status != 'finished'
        and om.id != new.id
    ) then
      raise exception 'User already in an active order';
    end if;
  end if;

  return new;
end;
$$;

create or replace function public.ensure_order_item_scope()
returns trigger
language plpgsql
set search_path = public, extensions
as $$
declare
  v_order_family_id uuid;
  v_dish_family_id uuid;
  v_member_order_id uuid;
begin
  select o.family_id
  into v_order_family_id
  from public.orders o
  where o.id = new.order_id;

  if v_order_family_id is null then
    raise exception 'Order not found';
  end if;

  select d.family_id
  into v_dish_family_id
  from public.dishes d
  where d.id = new.dish_id
    and d.archived_at is null;

  if v_dish_family_id is null then
    raise exception 'Dish not found or archived';
  end if;

  if v_dish_family_id != v_order_family_id then
    raise exception 'Dish must belong to the same family as the order';
  end if;

  if new.added_by_member_id is not null then
    select om.order_id
    into v_member_order_id
    from public.order_members om
    where om.id = new.added_by_member_id;

    if v_member_order_id is null or v_member_order_id != new.order_id then
      raise exception 'added_by_member_id must belong to the same order';
    end if;
  end if;

  return new;
end;
$$;

create trigger trg_dishes_touch_updated_at
  before update on public.dishes
  for each row execute function public.touch_updated_at();

create trigger trg_orders_creator_is_member
  before insert or update on public.orders
  for each row execute function public.ensure_order_created_by_family_member();

create trigger trg_order_members_one_active_order
  before insert or update on public.order_members
  for each row execute function public.check_one_active_order();

create trigger trg_order_items_scope
  before insert or update on public.order_items
  for each row execute function public.ensure_order_item_scope();

-- ===== RPC functions =====

create or replace function public.create_family_with_owner(p_name text)
returns table (
  family_id uuid,
  family_name text,
  join_code text,
  member_id uuid,
  member_role public.family_role
)
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_family public.families%rowtype;
  v_member public.family_members%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if coalesce(btrim(p_name), '') = '' then
    raise exception 'Family name is required';
  end if;

  insert into public.families (name, created_by)
  values (btrim(p_name), auth.uid())
  returning * into v_family;

  insert into public.family_members (family_id, user_id, role, invited_by)
  values (v_family.id, auth.uid(), 'owner', auth.uid())
  returning * into v_member;

  return query
  select
    v_family.id,
    v_family.name,
    v_family.join_code,
    v_member.id,
    v_member.role;
end;
$$;

create or replace function public.join_family_by_code(p_code text)
returns table (
  family_id uuid,
  family_name text,
  join_code text,
  member_id uuid,
  member_role public.family_role,
  member_status public.family_member_status
)
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_family public.families%rowtype;
  v_member public.family_members%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  select *
  into v_family
  from public.families f
  where f.join_code = upper(btrim(p_code))
    and f.archived_at is null
  limit 1;

  if v_family.id is null then
    raise exception 'Invalid family join code';
  end if;

  select *
  into v_member
  from public.family_members fm
  where fm.family_id = v_family.id
    and fm.user_id = auth.uid()
  limit 1;

  if v_member.id is null then
    insert into public.family_members (family_id, user_id, role, invited_by)
    values (v_family.id, auth.uid(), 'member', auth.uid())
    returning * into v_member;
  elsif v_member.status = 'removed' then
    update public.family_members
    set status = 'active',
        role = 'member',
        joined_at = now(),
        removed_at = null
    where id = v_member.id
    returning * into v_member;
  else
    raise exception 'User is already an active family member';
  end if;

  return query
  select
    v_family.id,
    v_family.name,
    v_family.join_code,
    v_member.id,
    v_member.role,
    v_member.status;
end;
$$;

create or replace function public.rotate_family_join_code(p_family_id uuid)
returns text
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_new_code text;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if not public.is_family_admin(p_family_id) then
    raise exception 'Only family owner/admin can rotate family join code';
  end if;

  v_new_code := public.generate_join_code();

  update public.families
  set join_code = v_new_code,
      join_code_rotated_at = now()
  where id = p_family_id;

  return v_new_code;
end;
$$;

create or replace function public.update_family_member_role(
  p_family_id uuid,
  p_target_member_id uuid,
  p_new_role public.family_role
)
returns table (
  member_id uuid,
  family_id uuid,
  user_id uuid,
  role public.family_role,
  status public.family_member_status
)
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_actor public.family_members%rowtype;
  v_target public.family_members%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if p_new_role not in ('admin', 'member') then
    raise exception 'Only admin/member roles can be assigned';
  end if;

  select *
  into v_actor
  from public.family_members fm
  where fm.family_id = p_family_id
    and fm.user_id = auth.uid()
    and fm.status = 'active'
  limit 1;

  if v_actor.id is null or v_actor.role != 'owner' then
    raise exception 'Only family owner can update member role';
  end if;

  select *
  into v_target
  from public.family_members fm
  where fm.id = p_target_member_id
    and fm.family_id = p_family_id
    and fm.status = 'active'
  limit 1;

  if v_target.id is null then
    raise exception 'Target member not found';
  end if;

  if v_target.role = 'owner' then
    raise exception 'Owner role cannot be changed';
  end if;

  update public.family_members
  set role = p_new_role
  where id = v_target.id
  returning
    id,
    family_id,
    user_id,
    role,
    status
  into member_id, family_id, user_id, role, status;

  return next;
end;
$$;

create or replace function public.remove_family_member(
  p_family_id uuid,
  p_target_member_id uuid
)
returns table (
  member_id uuid,
  family_id uuid,
  user_id uuid,
  role public.family_role,
  status public.family_member_status,
  removed_at timestamptz
)
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_actor public.family_members%rowtype;
  v_target public.family_members%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  select *
  into v_actor
  from public.family_members fm
  where fm.family_id = p_family_id
    and fm.user_id = auth.uid()
    and fm.status = 'active'
  limit 1;

  if v_actor.id is null then
    raise exception 'Current user is not an active family member';
  end if;

  select *
  into v_target
  from public.family_members fm
  where fm.id = p_target_member_id
    and fm.family_id = p_family_id
    and fm.status = 'active'
  limit 1;

  if v_target.id is null then
    raise exception 'Target member not found';
  end if;

  if v_target.role = 'owner' then
    raise exception 'Owner cannot be removed';
  end if;

  if v_target.user_id = auth.uid() then
    raise exception 'Use leave_family() to remove yourself';
  end if;

  if v_actor.role = 'owner' then
    null;
  elsif v_actor.role = 'admin' and v_target.role = 'member' then
    null;
  else
    raise exception 'Insufficient permission to remove this member';
  end if;

  update public.family_members
  set status = 'removed',
      removed_at = now()
  where id = v_target.id
  returning
    id,
    family_id,
    user_id,
    role,
    status,
    removed_at
  into member_id, family_id, user_id, role, status, removed_at;

  return next;
end;
$$;

create or replace function public.leave_family(p_family_id uuid)
returns table (
  member_id uuid,
  family_id uuid,
  user_id uuid,
  role public.family_role,
  status public.family_member_status,
  removed_at timestamptz
)
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_member public.family_members%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  select *
  into v_member
  from public.family_members fm
  where fm.family_id = p_family_id
    and fm.user_id = auth.uid()
    and fm.status = 'active'
  limit 1;

  if v_member.id is null then
    raise exception 'Current user is not an active family member';
  end if;

  if v_member.role = 'owner' then
    raise exception 'Owner cannot leave family in v1';
  end if;

  update public.family_members
  set status = 'removed',
      removed_at = now()
  where id = v_member.id
  returning
    id,
    family_id,
    user_id,
    role,
    status,
    removed_at
  into member_id, family_id, user_id, role, status, removed_at;

  return next;
end;
$$;

create or replace function public.create_order_for_family(p_family_id uuid)
returns table (
  order_id uuid,
  family_id uuid,
  share_token text,
  order_member_id uuid
)
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_order public.orders%rowtype;
  v_member public.order_members%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if not public.is_active_family_member(p_family_id) then
    raise exception 'Only active family members can create an order';
  end if;

  insert into public.orders (family_id, created_by)
  values (p_family_id, auth.uid())
  returning * into v_order;

  insert into public.order_members (order_id, user_id)
  values (v_order.id, auth.uid())
  returning * into v_member;

  return query
  select
    v_order.id,
    v_order.family_id,
    v_order.share_token,
    v_member.id;
end;
$$;

create or replace function public.join_order_by_share_token(p_token text)
returns table (
  order_id uuid,
  family_id uuid,
  order_member_id uuid
)
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_order public.orders%rowtype;
  v_existing_member public.order_members%rowtype;
  v_member public.order_members%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  select *
  into v_order
  from public.orders o
  where o.share_token = btrim(p_token)
    and o.status != 'finished'
  limit 1;

  if v_order.id is null then
    raise exception 'Invalid or expired order share token';
  end if;

  if not public.is_active_family_member(v_order.family_id) then
    raise exception 'Current user must belong to the order family';
  end if;

  select *
  into v_existing_member
  from public.order_members om
  where om.order_id = v_order.id
    and om.user_id = auth.uid()
  limit 1;

  if v_existing_member.id is not null then
    return query
    select
      v_order.id,
      v_order.family_id,
      v_existing_member.id;
    return;
  end if;

  insert into public.order_members (order_id, user_id)
  values (v_order.id, auth.uid())
  returning * into v_member;

  return query
  select
    v_order.id,
    v_order.family_id,
    v_member.id;
end;
$$;

-- ===== RLS =====

alter table public.profiles enable row level security;
alter table public.families enable row level security;
alter table public.family_members enable row level security;
alter table public.dishes enable row level security;
alter table public.orders enable row level security;
alter table public.order_members enable row level security;
alter table public.order_items enable row level security;

-- profiles
create policy "profiles_select_self_or_shared_family"
  on public.profiles
  for select
  to authenticated
  using (public.can_view_profile(id));

create policy "profiles_insert_own"
  on public.profiles
  for insert
  to authenticated
  with check (id = auth.uid());

create policy "profiles_update_own_or_platform_admin"
  on public.profiles
  for update
  to authenticated
  using (id = auth.uid() or public.is_platform_admin())
  with check (
    public.is_platform_admin()
    or (
      id = auth.uid()
      and is_admin = public.is_platform_admin()
    )
  );

-- families
create policy "families_select_active_members"
  on public.families
  for select
  to authenticated
  using (
    public.is_platform_admin()
    or public.is_active_family_member(id)
  );

-- family_members
create policy "family_members_select_same_family"
  on public.family_members
  for select
  to authenticated
  using (
    public.is_platform_admin()
    or public.is_active_family_member(family_id)
  );

-- dishes
create policy "dishes_select_same_family"
  on public.dishes
  for select
  to authenticated
  using (
    public.is_platform_admin()
    or (
      archived_at is null
      and public.is_active_family_member(family_id)
    )
  );

create policy "dishes_insert_family_admin"
  on public.dishes
  for insert
  to authenticated
  with check (
    created_by = auth.uid()
    and public.is_family_admin(family_id)
  );

create policy "dishes_update_family_admin"
  on public.dishes
  for update
  to authenticated
  using (public.is_family_admin(family_id))
  with check (public.is_family_admin(family_id));

create policy "dishes_delete_family_admin"
  on public.dishes
  for delete
  to authenticated
  using (public.is_family_admin(family_id));

-- orders
create policy "orders_select_same_family"
  on public.orders
  for select
  to authenticated
  using (
    public.is_platform_admin()
    or public.is_active_family_member(family_id)
  );

create policy "orders_update_family_admin"
  on public.orders
  for update
  to authenticated
  using (public.is_family_admin(family_id))
  with check (public.is_family_admin(family_id));

-- order_members
create policy "order_members_select_same_family"
  on public.order_members
  for select
  to authenticated
  using (
    public.is_platform_admin()
    or public.is_active_family_member(public.order_family_id(order_id))
  );

-- order_items
create policy "order_items_select_same_family"
  on public.order_items
  for select
  to authenticated
  using (
    public.is_platform_admin()
    or public.is_active_family_member(public.order_family_id(order_id))
  );

create policy "order_items_insert_family_members"
  on public.order_items
  for insert
  to authenticated
  with check (
    public.is_active_family_member(public.order_family_id(order_id))
    and exists (
      select 1
      from public.orders o
      where o.id = order_id
        and o.status != 'finished'
    )
    and public.is_current_user_order_member(order_id, added_by_member_id)
  );

create policy "order_items_update_family_admin"
  on public.order_items
  for update
  to authenticated
  using (
    public.is_family_admin(public.order_family_id(order_id))
  )
  with check (
    public.is_family_admin(public.order_family_id(order_id))
  );

create policy "order_items_delete_owner_before_placed_or_family_admin"
  on public.order_items
  for delete
  to authenticated
  using (
    public.is_family_admin(public.order_family_id(order_id))
    or (
      exists (
        select 1
        from public.orders o
        where o.id = order_id
          and o.status = 'ordering'
      )
      and public.is_current_user_order_member(order_id, added_by_member_id)
    )
  );

-- ===== Grants =====

grant usage on schema public to authenticated;
grant select, insert, update, delete on all tables in schema public to authenticated;
grant usage, select on all sequences in schema public to authenticated;

grant execute on function public.create_family_with_owner(text) to authenticated;
grant execute on function public.join_family_by_code(text) to authenticated;
grant execute on function public.rotate_family_join_code(uuid) to authenticated;
grant execute on function public.update_family_member_role(uuid, uuid, public.family_role) to authenticated;
grant execute on function public.remove_family_member(uuid, uuid) to authenticated;
grant execute on function public.leave_family(uuid) to authenticated;
grant execute on function public.create_order_for_family(uuid) to authenticated;
grant execute on function public.join_order_by_share_token(text) to authenticated;

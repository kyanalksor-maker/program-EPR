create extension if not exists "pgcrypto";

create type public.order_status as enum (
  'entered',
  'checked',
  'approved',
  'shipped',
  'completed',
  'returned'
);

create table if not exists public.roles (
  id uuid primary key default gen_random_uuid(),
  role_name text not null unique,
  created_at timestamptz not null default now()
);

create table if not exists public.permissions (
  code text primary key,
  description text not null
);

create table if not exists public.role_permissions (
  role_id uuid not null references public.roles(id) on delete cascade,
  permission_code text not null references public.permissions(code) on delete cascade,
  primary key (role_id, permission_code)
);

create table if not exists public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null,
  email text not null unique,
  username text unique,
  role_id uuid not null references public.roles(id),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  last_active timestamptz
);

create table if not exists public.user_permissions (
  user_id uuid not null references public.users(id) on delete cascade,
  permission_code text not null references public.permissions(code) on delete cascade,
  primary key (user_id, permission_code)
);

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  sku text not null unique,
  category text not null,
  purchase_price numeric(12,2) not null check (purchase_price >= 0),
  sale_price numeric(12,2) not null check (sale_price >= purchase_price),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.inventory (
  product_id uuid primary key references public.products(id) on delete cascade,
  stock integer not null default 0 check (stock >= 0),
  min_stock integer not null default 0 check (min_stock >= 0),
  updated_at timestamptz not null default now(),
  updated_by uuid references public.users(id)
);

create table if not exists public.inventory_transactions (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id),
  quantity_delta integer not null,
  reason text not null,
  source_type text not null,
  source_id uuid,
  created_by uuid not null references public.users(id),
  created_at timestamptz not null default now()
);

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  customer_name text not null,
  customer_phone text not null,
  order_date timestamptz not null default now(),
  order_notes text,
  status public.order_status not null default 'entered',
  total_cost numeric(14,2) not null default 0,
  total_revenue numeric(14,2) not null default 0,
  profit numeric(14,2) not null default 0,
  created_by uuid not null references public.users(id),
  created_by_name text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  product_id uuid not null references public.products(id),
  product_name text not null,
  quantity integer not null check (quantity > 0),
  purchase_price numeric(12,2) not null,
  sale_price numeric(12,2) not null,
  profit numeric(14,2) not null
);

create table if not exists public.order_status_history (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  status public.order_status not null,
  changed_by uuid not null references public.users(id),
  changed_by_name text not null,
  changed_at timestamptz not null default now(),
  note text
);

create table if not exists public.returns (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  reason text,
  created_by uuid not null references public.users(id),
  created_at timestamptz not null default now()
);

create table if not exists public.return_items (
  id uuid primary key default gen_random_uuid(),
  return_id uuid not null references public.returns(id) on delete cascade,
  order_item_id uuid not null references public.order_items(id) on delete cascade,
  quantity integer not null check (quantity > 0)
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  title text not null,
  message text not null,
  type text not null default 'workflow',
  read boolean not null default false,
  reference_id text,
  created_at timestamptz not null default now()
);

create table if not exists public.activity_logs (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid not null references public.users(id),
  actor_name text not null,
  action text not null,
  entity_type text not null,
  entity_id text,
  metadata jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_orders_status on public.orders(status);
create index if not exists idx_orders_created_by on public.orders(created_by);
create index if not exists idx_order_items_order_id on public.order_items(order_id);
create index if not exists idx_history_order_id on public.order_status_history(order_id);
create index if not exists idx_notifications_user_id on public.notifications(user_id);
create index if not exists idx_inventory_stock on public.inventory(stock, min_stock);
create index if not exists idx_activity_logs_actor_id on public.activity_logs(actor_id);

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_users_updated_at on public.users;
create trigger trg_users_updated_at
before update on public.users
for each row execute procedure public.touch_updated_at();

drop trigger if exists trg_products_updated_at on public.products;
create trigger trg_products_updated_at
before update on public.products
for each row execute procedure public.touch_updated_at();

drop trigger if exists trg_orders_updated_at on public.orders;
create trigger trg_orders_updated_at
before update on public.orders
for each row execute procedure public.touch_updated_at();

create or replace view public.v_users_with_permissions as
with effective_permissions as (
  select
    u.id as user_id,
    rp.permission_code
  from public.users u
  join public.role_permissions rp on rp.role_id = u.role_id
  union
  select
    up.user_id,
    up.permission_code
  from public.user_permissions up
)
select
  u.id,
  u.name,
  u.email,
  u.username,
  u.role_id,
  r.role_name,
  u.is_active,
  u.created_at,
  u.updated_at,
  u.last_active,
  coalesce(array_agg(distinct ep.permission_code) filter (where ep.permission_code is not null), '{}') as permissions
from public.users u
join public.roles r on r.id = u.role_id
left join effective_permissions ep on ep.user_id = u.id
group by u.id, r.role_name;

create or replace view public.v_products as
select
  p.id,
  p.name,
  p.sku,
  p.category,
  p.purchase_price,
  p.sale_price,
  p.is_active,
  i.stock,
  i.min_stock
from public.products p
join public.inventory i on i.product_id = p.id
where p.is_active = true;

create or replace function public.current_role_name()
returns text
language sql
stable
as $$
  select role_name
  from public.v_users_with_permissions
  where id = auth.uid()
$$;

create or replace function public.current_user_is_active()
returns boolean
language sql
stable
as $$
  select coalesce(is_active, false)
  from public.v_users_with_permissions
  where id = auth.uid()
$$;

create or replace function public.has_permission(permission_code text)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.v_users_with_permissions v
    where v.id = auth.uid()
      and v.is_active = true
      and (
        v.role_name = 'Admin'
        or permission_code = any(v.permissions)
      )
  )
$$;

create or replace function public.is_admin()
returns boolean
language sql
stable
as $$
  select public.current_role_name() = 'Admin'
$$;

create or replace function public.require_active_user()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if not public.current_user_is_active() then
    raise exception 'Inactive users cannot access the system';
  end if;
end;
$$;

create or replace function public.write_activity_log(
  p_actor_id uuid,
  p_action text,
  p_entity_type text,
  p_entity_id text default null,
  p_metadata jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor_name text;
begin
  select name into v_actor_name
  from public.users
  where id = p_actor_id;

  insert into public.activity_logs (
    actor_id,
    actor_name,
    action,
    entity_type,
    entity_id,
    metadata
  )
  values (
    p_actor_id,
    coalesce(v_actor_name, 'Unknown User'),
    p_action,
    p_entity_type,
    p_entity_id,
    p_metadata
  );
end;
$$;

create or replace function public.notify_roles(
  p_role_names text[],
  p_title text,
  p_message text,
  p_reference_id text default null,
  p_type text default 'workflow'
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.notifications (user_id, title, message, type, reference_id)
  select u.id, p_title, p_message, p_type, p_reference_id
  from public.users u
  join public.roles r on r.id = u.role_id
  where r.role_name = any(p_role_names)
    and u.is_active = true
    and u.id <> auth.uid();
end;
$$;

create or replace function public.record_user_login()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.require_active_user();

  update public.users
  set last_active = now()
  where id = auth.uid();

  perform public.write_activity_log(
    auth.uid(),
    'user_login',
    'auth',
    auth.uid()::text,
    '{}'::jsonb
  );
end;
$$;

create or replace function public.create_order(
  p_customer_name text,
  p_customer_phone text,
  p_order_notes text,
  p_items jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order_id uuid := gen_random_uuid();
  v_actor public.v_users_with_permissions%rowtype;
  v_item jsonb;
  v_product record;
  v_quantity integer;
  v_total_cost numeric(14,2) := 0;
  v_total_revenue numeric(14,2) := 0;
  v_total_profit numeric(14,2) := 0;
begin
  perform public.require_active_user();

  if not public.has_permission('orders_create') then
    raise exception 'Missing permission orders_create';
  end if;

  select * into v_actor
  from public.v_users_with_permissions
  where id = auth.uid();

  insert into public.orders (
    id,
    customer_name,
    customer_phone,
    order_notes,
    status,
    created_by,
    created_by_name
  )
  values (
    v_order_id,
    p_customer_name,
    p_customer_phone,
    nullif(p_order_notes, ''),
    'entered',
    auth.uid(),
    v_actor.name
  );

  for v_item in select * from jsonb_array_elements(p_items)
  loop
    v_quantity := (v_item ->> 'quantity')::integer;
    if v_quantity <= 0 then
      raise exception 'Order quantity must be greater than zero';
    end if;

    select
      p.id,
      p.name,
      p.purchase_price,
      p.sale_price
    into v_product
    from public.products p
    where p.id = (v_item ->> 'product_id')::uuid
      and p.is_active = true;

    if v_product.id is null then
      raise exception 'Invalid product in order payload';
    end if;

    insert into public.order_items (
      order_id,
      product_id,
      product_name,
      quantity,
      purchase_price,
      sale_price,
      profit
    )
    values (
      v_order_id,
      v_product.id,
      v_product.name,
      v_quantity,
      v_product.purchase_price,
      v_product.sale_price,
      (v_product.sale_price - v_product.purchase_price) * v_quantity
    );

    v_total_cost := v_total_cost + (v_product.purchase_price * v_quantity);
    v_total_revenue := v_total_revenue + (v_product.sale_price * v_quantity);
    v_total_profit := v_total_profit + ((v_product.sale_price - v_product.purchase_price) * v_quantity);
  end loop;

  update public.orders
  set
    total_cost = v_total_cost,
    total_revenue = v_total_revenue,
    profit = v_total_profit
  where id = v_order_id;

  insert into public.order_status_history (
    order_id,
    status,
    changed_by,
    changed_by_name,
    note
  )
  values (
    v_order_id,
    'entered',
    auth.uid(),
    v_actor.name,
    'Order created'
  );

  perform public.notify_roles(
    array['Order Reviewer', 'Admin'],
    'Order entered',
    'A new order is awaiting review.',
    v_order_id::text,
    'workflow'
  );

  perform public.write_activity_log(
    auth.uid(),
    'order_created',
    'order',
    v_order_id::text,
    jsonb_build_object('status', 'entered')
  );

  return v_order_id;
end;
$$;

create or replace function public.update_order(
  p_order_id uuid,
  p_customer_name text,
  p_customer_phone text,
  p_order_notes text,
  p_items jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.orders%rowtype;
  v_item jsonb;
  v_product record;
  v_quantity integer;
  v_total_cost numeric(14,2) := 0;
  v_total_revenue numeric(14,2) := 0;
  v_total_profit numeric(14,2) := 0;
begin
  perform public.require_active_user();

  if not public.has_permission('orders_edit') then
    raise exception 'Missing permission orders_edit';
  end if;

  select * into v_order
  from public.orders
  where id = p_order_id;

  if v_order.id is null then
    raise exception 'Order not found';
  end if;

  if v_order.status <> 'entered' and not public.is_admin() then
    raise exception 'Only entered orders can be edited';
  end if;

  delete from public.order_items where order_id = p_order_id;

  for v_item in select * from jsonb_array_elements(p_items)
  loop
    v_quantity := (v_item ->> 'quantity')::integer;
    if v_quantity <= 0 then
      raise exception 'Order quantity must be greater than zero';
    end if;

    select
      p.id,
      p.name,
      p.purchase_price,
      p.sale_price
    into v_product
    from public.products p
    where p.id = (v_item ->> 'product_id')::uuid
      and p.is_active = true;

    if v_product.id is null then
      raise exception 'Invalid product in order payload';
    end if;

    insert into public.order_items (
      order_id,
      product_id,
      product_name,
      quantity,
      purchase_price,
      sale_price,
      profit
    )
    values (
      p_order_id,
      v_product.id,
      v_product.name,
      v_quantity,
      v_product.purchase_price,
      v_product.sale_price,
      (v_product.sale_price - v_product.purchase_price) * v_quantity
    );

    v_total_cost := v_total_cost + (v_product.purchase_price * v_quantity);
    v_total_revenue := v_total_revenue + (v_product.sale_price * v_quantity);
    v_total_profit := v_total_profit + ((v_product.sale_price - v_product.purchase_price) * v_quantity);
  end loop;

  update public.orders
  set
    customer_name = p_customer_name,
    customer_phone = p_customer_phone,
    order_notes = nullif(p_order_notes, ''),
    total_cost = v_total_cost,
    total_revenue = v_total_revenue,
    profit = v_total_profit
  where id = p_order_id;

  perform public.write_activity_log(
    auth.uid(),
    'order_updated',
    'order',
    p_order_id::text,
    jsonb_build_object('status', v_order.status)
  );
end;
$$;

create or replace function public.apply_inventory_delta(
  p_order_id uuid,
  p_reason text,
  p_quantity_sign integer
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_item record;
  v_inventory record;
  v_delta integer;
begin
  for v_item in
    select product_id, quantity, product_name
    from public.order_items
    where order_id = p_order_id
  loop
    v_delta := v_item.quantity * p_quantity_sign;

    select *
    into v_inventory
    from public.inventory
    where product_id = v_item.product_id
    for update;

    if v_inventory.product_id is null then
      raise exception 'Inventory missing for product %', v_item.product_name;
    end if;

    if (v_inventory.stock + v_delta) < 0 then
      raise exception 'Insufficient stock for product %', v_item.product_name;
    end if;

    update public.inventory
    set
      stock = stock + v_delta,
      updated_at = now(),
      updated_by = auth.uid()
    where product_id = v_item.product_id;

    insert into public.inventory_transactions (
      product_id,
      quantity_delta,
      reason,
      source_type,
      source_id,
      created_by
    )
    values (
      v_item.product_id,
      v_delta,
      p_reason,
      'order',
      p_order_id,
      auth.uid()
    );
  end loop;
end;
$$;

create or replace function public.transition_order(
  p_order_id uuid,
  p_next_status public.order_status,
  p_note text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.orders%rowtype;
  v_actor_name text;
  v_return_id uuid;
begin
  perform public.require_active_user();

  select * into v_order
  from public.orders
  where id = p_order_id
  for update;

  if v_order.id is null then
    raise exception 'Order not found';
  end if;

  select name into v_actor_name
  from public.users
  where id = auth.uid();

  if v_order.status = 'entered' and p_next_status = 'checked' then
    if not public.has_permission('orders_approve') then
      raise exception 'Missing permission orders_approve';
    end if;
  elsif v_order.status = 'checked' and p_next_status = 'approved' then
    if not public.has_permission('orders_approve') then
      raise exception 'Missing permission orders_approve';
    end if;
  elsif v_order.status = 'approved' and p_next_status = 'shipped' then
    if not public.has_permission('orders_ship') then
      raise exception 'Missing permission orders_ship';
    end if;
    perform public.apply_inventory_delta(p_order_id, 'order_shipped', -1);
  elsif v_order.status = 'shipped' and p_next_status = 'completed' then
    if not public.has_permission('orders_ship') then
      raise exception 'Missing permission orders_ship';
    end if;
  elsif v_order.status = 'completed' and p_next_status = 'returned' then
    if not public.has_permission('orders_ship') then
      raise exception 'Missing permission orders_ship';
    end if;
    perform public.apply_inventory_delta(p_order_id, 'order_returned', 1);

    insert into public.returns (order_id, reason, created_by)
    values (p_order_id, coalesce(nullif(p_note, ''), 'Order return'), auth.uid())
    returning id into v_return_id;

    insert into public.return_items (return_id, order_item_id, quantity)
    select v_return_id, oi.id, oi.quantity
    from public.order_items oi
    where oi.order_id = p_order_id;
  else
    raise exception 'Invalid transition from % to %', v_order.status, p_next_status;
  end if;

  update public.orders
  set status = p_next_status
  where id = p_order_id;

  insert into public.order_status_history (
    order_id,
    status,
    changed_by,
    changed_by_name,
    note
  )
  values (
    p_order_id,
    p_next_status,
    auth.uid(),
    v_actor_name,
    p_note
  );

  perform public.notify_roles(
    case
      when p_next_status in ('entered', 'checked', 'approved') then array['Order Reviewer', 'Admin']
      when p_next_status in ('shipped', 'completed') then array['Shipping User', 'Admin']
      else array['Admin']
    end,
    'Order status changed',
    format('Order %s moved to %s', p_order_id::text, upper(p_next_status::text)),
    p_order_id::text,
    'workflow'
  );

  perform public.write_activity_log(
    auth.uid(),
    'order_transition',
    'order',
    p_order_id::text,
    jsonb_build_object('from', v_order.status, 'to', p_next_status)
  );
end;
$$;

create or replace function public.override_order_status(
  p_order_id uuid,
  p_next_status public.order_status,
  p_note text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.orders%rowtype;
  v_actor_name text;
  v_prev_deducted boolean;
  v_next_deducted boolean;
begin
  perform public.require_active_user();

  if not public.has_permission('orders_override') then
    raise exception 'Missing permission orders_override';
  end if;

  select * into v_order
  from public.orders
  where id = p_order_id
  for update;

  if v_order.id is null then
    raise exception 'Order not found';
  end if;

  select name into v_actor_name
  from public.users
  where id = auth.uid();

  v_prev_deducted := v_order.status in ('shipped', 'completed');
  v_next_deducted := p_next_status in ('shipped', 'completed');

  if (not v_prev_deducted) and v_next_deducted then
    perform public.apply_inventory_delta(p_order_id, 'admin_override_ship', -1);
  elsif v_prev_deducted and (not v_next_deducted) then
    perform public.apply_inventory_delta(p_order_id, 'admin_override_restore', 1);
  end if;

  if p_next_status = 'returned' and v_order.status <> 'returned' then
    insert into public.returns (order_id, reason, created_by)
    values (p_order_id, coalesce(nullif(p_note, ''), 'Admin override return'), auth.uid());
  end if;

  update public.orders
  set status = p_next_status
  where id = p_order_id;

  insert into public.order_status_history (
    order_id,
    status,
    changed_by,
    changed_by_name,
    note
  )
  values (
    p_order_id,
    p_next_status,
    auth.uid(),
    v_actor_name,
    coalesce(nullif(p_note, ''), 'Admin override')
  );

  perform public.write_activity_log(
    auth.uid(),
    'order_override',
    'order',
    p_order_id::text,
    jsonb_build_object('from', v_order.status, 'to', p_next_status)
  );
end;
$$;

create or replace function public.delete_order(p_order_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.orders%rowtype;
begin
  perform public.require_active_user();

  if not public.has_permission('orders_delete') then
    raise exception 'Missing permission orders_delete';
  end if;

  select * into v_order
  from public.orders
  where id = p_order_id;

  if v_order.id is null then
    raise exception 'Order not found';
  end if;

  if v_order.status in ('shipped', 'completed', 'returned') and not public.is_admin() then
    raise exception 'Only admins can delete fulfilled orders';
  end if;

  perform public.write_activity_log(
    auth.uid(),
    'order_deleted',
    'order',
    p_order_id::text,
    jsonb_build_object('status', v_order.status)
  );

  delete from public.orders
  where id = p_order_id;
end;
$$;

create or replace function public.upsert_product(
  p_product_id uuid,
  p_name text,
  p_sku text,
  p_category text,
  p_purchase_price numeric,
  p_sale_price numeric,
  p_stock integer,
  p_min_stock integer
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_product_id uuid := coalesce(p_product_id, gen_random_uuid());
  v_exists boolean;
begin
  perform public.require_active_user();

  select exists(select 1 from public.products where id = v_product_id) into v_exists;

  if v_exists and not public.has_permission('products_edit') then
    raise exception 'Missing permission products_edit';
  end if;

  if not v_exists and not public.has_permission('products_create') then
    raise exception 'Missing permission products_create';
  end if;

  if v_exists then
    update public.products
    set
      name = p_name,
      sku = p_sku,
      category = p_category,
      purchase_price = p_purchase_price,
      sale_price = p_sale_price
    where id = v_product_id;

    update public.inventory
    set
      stock = p_stock,
      min_stock = p_min_stock,
      updated_at = now(),
      updated_by = auth.uid()
    where product_id = v_product_id;
  else
    insert into public.products (
      id,
      name,
      sku,
      category,
      purchase_price,
      sale_price
    )
    values (
      v_product_id,
      p_name,
      p_sku,
      p_category,
      p_purchase_price,
      p_sale_price
    );

    insert into public.inventory (
      product_id,
      stock,
      min_stock,
      updated_by
    )
    values (
      v_product_id,
      p_stock,
      p_min_stock,
      auth.uid()
    );
  end if;

  perform public.write_activity_log(
    auth.uid(),
    case when v_exists then 'product_updated' else 'product_created' end,
    'product',
    v_product_id::text,
    jsonb_build_object('sku', p_sku)
  );

  return v_product_id;
end;
$$;

create or replace function public.delete_product(p_product_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.require_active_user();

  if not public.has_permission('products_delete') then
    raise exception 'Missing permission products_delete';
  end if;

  update public.products
  set is_active = false
  where id = p_product_id;

  perform public.write_activity_log(
    auth.uid(),
    'product_deleted',
    'product',
    p_product_id::text,
    '{}'::jsonb
  );
end;
$$;

create or replace function public.adjust_inventory(
  p_product_id uuid,
  p_quantity_delta integer,
  p_reason text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_inventory public.inventory%rowtype;
begin
  perform public.require_active_user();

  if not public.has_permission('inventory_edit') then
    raise exception 'Missing permission inventory_edit';
  end if;

  select * into v_inventory
  from public.inventory
  where product_id = p_product_id
  for update;

  if v_inventory.product_id is null then
    raise exception 'Inventory record not found';
  end if;

  if (v_inventory.stock + p_quantity_delta) < 0 then
    raise exception 'Inventory cannot become negative';
  end if;

  update public.inventory
  set
    stock = stock + p_quantity_delta,
    updated_at = now(),
    updated_by = auth.uid()
  where product_id = p_product_id;

  insert into public.inventory_transactions (
    product_id,
    quantity_delta,
    reason,
    source_type,
    created_by
  )
  values (
    p_product_id,
    p_quantity_delta,
    p_reason,
    'manual_adjustment',
    auth.uid()
  );

  perform public.write_activity_log(
    auth.uid(),
    'inventory_adjusted',
    'inventory',
    p_product_id::text,
    jsonb_build_object('delta', p_quantity_delta, 'reason', p_reason)
  );
end;
$$;

create or replace function public.mark_notification_read(p_notification_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.notifications
  set read = true
  where id = p_notification_id
    and user_id = auth.uid();
end;
$$;

alter table public.roles enable row level security;
alter table public.permissions enable row level security;
alter table public.role_permissions enable row level security;
alter table public.users enable row level security;
alter table public.user_permissions enable row level security;
alter table public.products enable row level security;
alter table public.inventory enable row level security;
alter table public.inventory_transactions enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.order_status_history enable row level security;
alter table public.returns enable row level security;
alter table public.return_items enable row level security;
alter table public.notifications enable row level security;
alter table public.activity_logs enable row level security;

create policy "roles readable by authenticated users"
on public.roles
for select
to authenticated
using (public.current_user_is_active());

create policy "permissions readable by authenticated users"
on public.permissions
for select
to authenticated
using (public.current_user_is_active());

create policy "role permissions readable by authenticated users"
on public.role_permissions
for select
to authenticated
using (public.current_user_is_active());

create policy "users visible to self or permissioned staff"
on public.users
for select
to authenticated
using (
  public.current_user_is_active()
  and (
    id = auth.uid()
    or public.has_permission('users_view')
    or public.is_admin()
  )
);

create policy "user permissions visible to self or permissioned staff"
on public.user_permissions
for select
to authenticated
using (
  public.current_user_is_active()
  and (
    user_id = auth.uid()
    or public.has_permission('users_view')
    or public.is_admin()
  )
);

create policy "products visible to authorized staff"
on public.products
for select
to authenticated
using (
  public.current_user_is_active()
  and is_active = true
  and (
    public.has_permission('products_view')
    or public.has_permission('inventory_view')
    or public.has_permission('orders_create')
    or public.has_permission('orders_view')
    or public.is_admin()
  )
);

create policy "inventory visible to authorized staff"
on public.inventory
for select
to authenticated
using (
  public.current_user_is_active()
  and (
    public.has_permission('inventory_view')
    or public.has_permission('products_view')
    or public.has_permission('orders_create')
    or public.has_permission('orders_view')
    or public.is_admin()
  )
);

create policy "inventory transactions visible to inventory staff"
on public.inventory_transactions
for select
to authenticated
using (
  public.current_user_is_active()
  and (
    public.has_permission('inventory_view')
    or public.is_admin()
  )
);

create policy "orders visible to order staff"
on public.orders
for select
to authenticated
using (
  public.current_user_is_active()
  and (
    public.has_permission('orders_view')
    or public.has_permission('orders_create')
    or public.has_permission('orders_approve')
    or public.has_permission('orders_ship')
    or public.has_permission('dashboard_view')
    or public.is_admin()
  )
);

create policy "order items visible to order staff"
on public.order_items
for select
to authenticated
using (
  exists (
    select 1
    from public.orders o
    where o.id = order_id
      and (
        public.has_permission('orders_view')
        or public.has_permission('orders_create')
        or public.has_permission('orders_approve')
        or public.has_permission('orders_ship')
        or public.has_permission('dashboard_view')
        or public.is_admin()
      )
  )
);

create policy "order history visible to order staff"
on public.order_status_history
for select
to authenticated
using (
  exists (
    select 1
    from public.orders o
    where o.id = order_id
      and (
        public.has_permission('orders_view')
        or public.has_permission('orders_create')
        or public.has_permission('orders_approve')
        or public.has_permission('orders_ship')
        or public.has_permission('dashboard_view')
        or public.is_admin()
      )
  )
);

create policy "returns visible to order staff"
on public.returns
for select
to authenticated
using (
  public.current_user_is_active()
  and (
    public.has_permission('orders_view')
    or public.has_permission('orders_ship')
    or public.is_admin()
  )
);

create policy "return items visible to order staff"
on public.return_items
for select
to authenticated
using (
  public.current_user_is_active()
  and (
    public.has_permission('orders_view')
    or public.has_permission('orders_ship')
    or public.is_admin()
  )
);

create policy "notifications visible to owners"
on public.notifications
for select
to authenticated
using (
  public.current_user_is_active()
  and (
    user_id = auth.uid()
    or public.is_admin()
  )
);

create policy "notifications update by owner"
on public.notifications
for update
to authenticated
using (
  public.current_user_is_active()
  and user_id = auth.uid()
)
with check (user_id = auth.uid());

create policy "activity logs visible to admins and audit staff"
on public.activity_logs
for select
to authenticated
using (
  public.current_user_is_active()
  and (
    public.has_permission('activity_logs_view')
    or public.is_admin()
  )
);

insert into public.permissions (code, description)
values
  ('orders_view', 'View orders'),
  ('orders_create', 'Create orders'),
  ('orders_edit', 'Edit orders'),
  ('orders_delete', 'Delete orders'),
  ('orders_approve', 'Check and approve orders'),
  ('orders_ship', 'Ship and complete orders'),
  ('orders_override', 'Override order status'),
  ('inventory_view', 'View inventory'),
  ('inventory_edit', 'Adjust inventory'),
  ('products_view', 'View products'),
  ('products_create', 'Create products'),
  ('products_edit', 'Edit products'),
  ('products_delete', 'Delete products'),
  ('reports_view', 'View reports'),
  ('users_view', 'View users'),
  ('users_create', 'Create users'),
  ('users_edit', 'Edit users'),
  ('users_delete', 'Delete users'),
  ('users_assign_permissions', 'Assign permissions'),
  ('dashboard_view', 'View dashboard'),
  ('notifications_view', 'View notifications'),
  ('activity_logs_view', 'View activity logs')
on conflict (code) do update
set description = excluded.description;

insert into public.roles (role_name)
values
  ('Order Entry User'),
  ('Order Reviewer'),
  ('Shipping User'),
  ('Admin')
on conflict (role_name) do nothing;

insert into public.role_permissions (role_id, permission_code)
select r.id, permission_code
from public.roles r
join (
  values
    ('Order Entry User', 'dashboard_view'),
    ('Order Entry User', 'notifications_view'),
    ('Order Entry User', 'orders_create'),
    ('Order Entry User', 'orders_view'),
    ('Order Entry User', 'products_view'),
    ('Order Entry User', 'inventory_view'),
    ('Order Reviewer', 'dashboard_view'),
    ('Order Reviewer', 'notifications_view'),
    ('Order Reviewer', 'orders_view'),
    ('Order Reviewer', 'orders_edit'),
    ('Order Reviewer', 'orders_approve'),
    ('Order Reviewer', 'products_view'),
    ('Order Reviewer', 'inventory_view'),
    ('Order Reviewer', 'reports_view'),
    ('Shipping User', 'dashboard_view'),
    ('Shipping User', 'notifications_view'),
    ('Shipping User', 'orders_view'),
    ('Shipping User', 'orders_ship'),
    ('Shipping User', 'inventory_view'),
    ('Shipping User', 'inventory_edit'),
    ('Shipping User', 'products_view'),
    ('Shipping User', 'reports_view'),
    ('Admin', 'dashboard_view'),
    ('Admin', 'notifications_view'),
    ('Admin', 'orders_view'),
    ('Admin', 'orders_create'),
    ('Admin', 'orders_edit'),
    ('Admin', 'orders_delete'),
    ('Admin', 'orders_approve'),
    ('Admin', 'orders_ship'),
    ('Admin', 'orders_override'),
    ('Admin', 'inventory_view'),
    ('Admin', 'inventory_edit'),
    ('Admin', 'products_view'),
    ('Admin', 'products_create'),
    ('Admin', 'products_edit'),
    ('Admin', 'products_delete'),
    ('Admin', 'reports_view'),
    ('Admin', 'users_view'),
    ('Admin', 'users_create'),
    ('Admin', 'users_edit'),
    ('Admin', 'users_delete'),
    ('Admin', 'users_assign_permissions'),
    ('Admin', 'activity_logs_view')
) as seed(role_name, permission_code)
  on seed.role_name = r.role_name
on conflict do nothing;

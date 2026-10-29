-- REDMOOT: tablas de consultas para visitas, publicaciones y contacto.
-- Ejecutar una vez desde Supabase > SQL Editor.
create extension if not exists pgcrypto;

create table if not exists public.appointments (
  id uuid primary key default gen_random_uuid(),
  property text not null,
  name text not null,
  email text not null,
  phone text not null,
  date date not null,
  time_slot text not null,
  status text not null default 'pending' check (status in ('pending','confirmed','cancelled')),
  created_at timestamptz not null default now()
);

-- Permite actualizar un proyecto REDMOOT que ya tuviera la tabla creada.
alter table public.appointments add column if not exists time_slot text;
update public.appointments set time_slot = 'Por coordinar' where time_slot is null;
alter table public.appointments alter column time_slot set not null;
alter table public.appointments add column if not exists status text not null default 'pending';

create table if not exists public.admin_users (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

-- Usuario administrador REDMOOT (debe existir previamente en Supabase Auth del mismo proyecto).
insert into public.admin_users (user_id)
values ('eccc1615-3791-405f-a866-9a2a62f0ea2e')
on conflict (user_id) do nothing;

create table if not exists public.properties (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  title text not null,
  type text not null,
  operation text not null check (operation in ('Venta','Alquiler')),
  location text not null,
  address text not null,
  price bigint not null check (price >= 0),
  area numeric not null default 0,
  rooms integer not null default 0,
  beds integer not null default 0,
  baths integer not null default 0,
  image text not null,
  tag text not null default 'NUEVA',
  description text not null default '',
  features text[] not null default '{}',
  published boolean not null default false,
  created_at timestamptz not null default now()
);

-- Bucket público para fotos; la carga, edición y eliminación están limitadas a admin_users.
insert into storage.buckets (id, name, public)
values ('property-images','property-images',true)
on conflict (id) do update set public = true;

-- Propiedades de muestra para que el catálogo aparezca al conectar Supabase.
insert into public.properties (slug,title,type,operation,location,address,price,area,rooms,beds,baths,image,tag,description,features,published)
values
  ('luz-de-tarde','Luz de tarde','Departamento','Venta','Granada','Granada · Cali',480000000,86,3,2,2,'photo-1600607687939-ce8a6c25118c','DESTACADA','Un refugio contemporáneo en el corazón de Granada. Grandes ventanales y luz natural durante todo el día.','{"Balcón con vista urbana","Cocina abierta equipada","Parqueadero cubierto","Portería y vigilancia 24 h"}',true),
  ('casa-en-calma','Casa en calma','Casa','Venta','Pance','Pance · Cali',1250000000,210,5,3,3,'photo-1600566753086-00f18fb6b3ea','NUEVA','Una casa amplia rodeada de verde en Pance, con jardín privado y espacios para compartir.','{"Jardín y terraza privados","Cocina integral","Estudio independiente","Conjunto cerrado con piscina"}',true),
  ('aire-de-ciudad','Aire de ciudad','Departamento','Alquiler','San Fernando','San Fernando · Cali',3200000,64,2,1,1,'photo-1600607687920-4e2a09cf159d','EN ALQUILER','Un apartamento luminoso a pasos de cafés, parques y la vida cultural de San Fernando.','{"Balcón privado","Cocina equipada","Admite mascotas","Cerca de transporte y parques"}',true),
  ('patio-propio','Patio propio','PH','Venta','El Peñón','El Peñón · Cali',680000000,98,4,2,2,'photo-1600607687644-c7171b42498f','OPORTUNIDAD','Un PH con carácter y patio propio en uno de los barrios más queridos de Cali.','{"Patio privado","Espacio de trabajo","Cocina remodelada","Cerca del Bulevar del Río"}',true)
on conflict (slug) do nothing;

create table if not exists public.property_inquiries (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  email text not null,
  phone text not null,
  location text not null,
  type text not null,
  operation text not null,
  price text,
  photo_url text,
  details text,
  status text not null default 'pending' check (status in ('pending','contacted','published','rejected')),
  created_at timestamptz not null default now()
);

create table if not exists public.contact_inquiries (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  email text not null,
  details text not null,
  created_at timestamptz not null default now()
);

alter table public.appointments enable row level security;
alter table public.property_inquiries enable row level security;
alter table public.contact_inquiries enable row level security;
alter table public.admin_users enable row level security;
alter table public.properties enable row level security;

-- El sitio puede crear consultas. La lectura queda solo para el equipo desde el panel de Supabase.
drop policy if exists "Public can request appointments" on public.appointments;
create policy "Public can request appointments" on public.appointments
  for insert to anon, authenticated with check (true);
drop policy if exists "Public can send property inquiries" on public.property_inquiries;
create policy "Public can send property inquiries" on public.property_inquiries
  for insert to anon, authenticated with check (status = 'pending');
drop policy if exists "Public can send contact inquiries" on public.contact_inquiries;
create policy "Public can send contact inquiries" on public.contact_inquiries
  for insert to anon, authenticated with check (true);

drop policy if exists "Admins can view their own membership" on public.admin_users;
create policy "Admins can view their own membership" on public.admin_users
  for select to authenticated using (user_id = auth.uid());

drop policy if exists "Anyone can view published properties" on public.properties;
create policy "Anyone can view published properties" on public.properties
  for select to anon, authenticated using (published = true or exists (
    select 1 from public.admin_users where user_id = auth.uid()
  ));
drop policy if exists "Admins can insert properties" on public.properties;
create policy "Admins can insert properties" on public.properties
  for insert to authenticated with check (exists (select 1 from public.admin_users where user_id = auth.uid()));
drop policy if exists "Admins can update properties" on public.properties;
create policy "Admins can update properties" on public.properties
  for update to authenticated using (exists (select 1 from public.admin_users where user_id = auth.uid()))
  with check (exists (select 1 from public.admin_users where user_id = auth.uid()));
drop policy if exists "Admins can delete properties" on public.properties;
create policy "Admins can delete properties" on public.properties
  for delete to authenticated using (exists (select 1 from public.admin_users where user_id = auth.uid()));

drop policy if exists "Admins can view appointments" on public.appointments;
create policy "Admins can view appointments" on public.appointments
  for select to authenticated using (exists (select 1 from public.admin_users where user_id = auth.uid()));
drop policy if exists "Admins can update appointments" on public.appointments;
create policy "Admins can update appointments" on public.appointments
  for update to authenticated using (exists (select 1 from public.admin_users where user_id = auth.uid()))
  with check (exists (select 1 from public.admin_users where user_id = auth.uid()));

drop policy if exists "Admins can view property inquiries" on public.property_inquiries;
create policy "Admins can view property inquiries" on public.property_inquiries
  for select to authenticated using (exists (select 1 from public.admin_users where user_id = auth.uid()));
drop policy if exists "Admins can update property inquiries" on public.property_inquiries;
create policy "Admins can update property inquiries" on public.property_inquiries
  for update to authenticated using (exists (select 1 from public.admin_users where user_id = auth.uid()))
  with check (exists (select 1 from public.admin_users where user_id = auth.uid()));

drop policy if exists "Admins can view contact inquiries" on public.contact_inquiries;
create policy "Admins can view contact inquiries" on public.contact_inquiries
  for select to authenticated using (exists (select 1 from public.admin_users where user_id = auth.uid()));

drop policy if exists "Anyone can view property images" on storage.objects;
create policy "Anyone can view property images" on storage.objects
  for select to anon, authenticated using (bucket_id = 'property-images');
drop policy if exists "Admins can upload property images" on storage.objects;
create policy "Admins can upload property images" on storage.objects
  for insert to authenticated with check (bucket_id = 'property-images' and exists (
    select 1 from public.admin_users where user_id = auth.uid()
  ));
drop policy if exists "Admins can update property images" on storage.objects;
create policy "Admins can update property images" on storage.objects
  for update to authenticated using (bucket_id = 'property-images' and exists (
    select 1 from public.admin_users where user_id = auth.uid()
  )) with check (bucket_id = 'property-images' and exists (
    select 1 from public.admin_users where user_id = auth.uid()
  ));
drop policy if exists "Admins can delete property images" on storage.objects;
create policy "Admins can delete property images" on storage.objects
  for delete to authenticated using (bucket_id = 'property-images' and exists (
    select 1 from public.admin_users where user_id = auth.uid()
  ));

-- Privilegios de API; RLS limita qué filas puede tocar cada rol.
grant select on public.properties to anon, authenticated;
grant insert on public.appointments, public.property_inquiries, public.contact_inquiries to anon, authenticated;
grant select on public.admin_users to anon, authenticated;
grant insert, update, delete on public.properties to authenticated;
grant select, update on public.appointments, public.property_inquiries to authenticated;
grant select on public.contact_inquiries to authenticated;

-- No agregues políticas de lectura pública para estos datos personales.

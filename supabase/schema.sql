create extension if not exists pgcrypto;

create table if not exists public.saved_recipes (
    id uuid primary key default gen_random_uuid(),
    recipe jsonb not null,
    analysis_payload jsonb,
    image_data text,
    saved_at timestamptz not null default timezone('utc', now()),
    created_at timestamptz not null default timezone('utc', now())
);

alter table public.saved_recipes enable row level security;

do $$
begin
    if not exists (
        select 1
        from pg_policies
        where schemaname = 'public'
          and tablename = 'saved_recipes'
          and policyname = 'prototype read access'
    ) then
        create policy "prototype read access"
        on public.saved_recipes
        for select
        using (true);
    end if;

    if not exists (
        select 1
        from pg_policies
        where schemaname = 'public'
          and tablename = 'saved_recipes'
          and policyname = 'prototype insert access'
    ) then
        create policy "prototype insert access"
        on public.saved_recipes
        for insert
        with check (true);
    end if;
end
$$;

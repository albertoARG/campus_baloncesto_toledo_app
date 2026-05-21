create table if not exists public.fcm_tokens (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users(id) on delete cascade,
  token text not null,
  platform text not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  unique(user_id, token)
);

-- RLS policies
alter table public.fcm_tokens enable row level security;

create policy "Users can insert their own tokens"
on public.fcm_tokens for insert
to authenticated
with check (auth.uid() = user_id);

create policy "Users can view their own tokens"
on public.fcm_tokens for select
to authenticated
using (auth.uid() = user_id);

create policy "Admins can view all tokens"
on public.fcm_tokens for select
to authenticated
using (
  exists (
    select 1 from public.users
    where users.id = auth.uid() and users.role = 'admin'
  )
);

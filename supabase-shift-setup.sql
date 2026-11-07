-- 輪班班表 - Supabase 資料表設定
-- 使用方法：登入 https://supabase.com → 左側 SQL Editor → 貼上全部 → Run

-- 班表設定表（每個人的輪班規則）
create table if not exists public.shift_config (
  id text primary key,
  pattern text not null default '',
  start_date text not null default ''
);

-- 備註表（日期 → 備註內容）
create table if not exists public.shift_notes (
  date_key text primary key,
  note text not null default '',
  updated_at bigint not null default 0
);

alter table public.shift_config enable row level security;
alter table public.shift_notes enable row level security;

drop policy if exists "allow all" on public.shift_config;
create policy "allow all" on public.shift_config
  for all using (true) with check (true);

drop policy if exists "allow all" on public.shift_notes;
create policy "allow all" on public.shift_notes
  for all using (true) with check (true);

-- 啟用即時同步（若已存在會顯示錯誤，可忽略）
do $$
begin
  alter publication supabase_realtime add table public.shift_config;
exception when others then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.shift_notes;
exception when others then null;
end $$;

-- =====================================================================
-- v2：每人獨立的「班表空間」（2026-11 起前端改用以下兩張表，上面兩張為舊版）
-- 每台裝置隨機產生一組長碼 (ws)，前端以請求標頭 x-shift-ws 帶入；
-- RLS 只允許讀寫與標頭相同 ws 的資料 → 彼此看不到。
-- =====================================================================
create or replace function public.shift_req_ws() returns text
language sql stable as $$
  select coalesce(nullif(current_setting('request.headers', true), '')::json->>'x-shift-ws', '')
$$;

create table if not exists public.shift_profiles (
  ws text not null check (length(ws) >= 24),
  id text not null,
  name text not null default '',
  p1_name text not null default '',
  p1_pattern text not null default '',
  p1_start text not null default '',
  p2_name text not null default '',
  p2_pattern text not null default '',
  p2_start text not null default '',
  sort bigint not null default 0,
  updated_at bigint not null default 0,
  primary key (ws, id)
);

create table if not exists public.shift_ws_notes (
  ws text not null check (length(ws) >= 24),
  profile_id text not null,
  date_key text not null,
  note text not null default '',
  updated_at bigint not null default 0,
  primary key (ws, profile_id, date_key)
);

alter table public.shift_profiles enable row level security;
alter table public.shift_ws_notes enable row level security;

drop policy if exists "own workspace" on public.shift_profiles;
create policy "own workspace" on public.shift_profiles
  for all to anon, authenticated
  using (ws = public.shift_req_ws()) with check (ws = public.shift_req_ws());

drop policy if exists "own workspace" on public.shift_ws_notes;
create policy "own workspace" on public.shift_ws_notes
  for all to anon, authenticated
  using (ws = public.shift_req_ws()) with check (ws = public.shift_req_ws());

grant select, insert, update, delete on public.shift_profiles, public.shift_ws_notes to anon, authenticated;

-- v2.1：每組使用者的自訂設定（例如共同休假標記）
alter table public.shift_profiles add column if not exists extra jsonb not null default '{}'::jsonb;

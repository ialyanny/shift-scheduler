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

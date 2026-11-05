-- Dragonslayer flag for the online leaderboard.
-- Applied to the live database on Nov 4, 2026.
-- Project: piayoqekmrhqfuhhvexg
--
-- This is the schema that is live, in the order it was applied: the lb
-- functions first, then the public wrappers the game calls.
-- lb.submit_score keeps its 5-argument form. The 6-argument overload adds
-- p_dragon_slayer. get_leaderboard and get_my_rank return dragon_slayer on
-- each row.
--
-- The client sends p_device_id, p_name, p_form, p_score, p_survival_ms, and
-- p_dragon_slayer when the run killed the Great Dragon. If an old server
-- answers PGRST202, the client posts the same score again without the flag.

-- Dragonslayer flag for the online leaderboard (schema lb).
-- Real tables: lb.best_all (one best row per device+form) and
-- lb.best_daily (one best row per device+form+UTC day).

alter table lb.best_all   add column if not exists dragon_slayer boolean not null default false;
alter table lb.best_daily add column if not exists dragon_slayer boolean not null default false;

-- 6-argument overload. The 5-argument submit_score is left untouched, so old
-- clients keep working. This one runs the normal submit, then flags only the
-- best rows this run created or replaced (new_best_all / new_best_daily).
-- The flag is only ever set to true here, and the 5-arg upsert never writes
-- the column, so a row that earned the title keeps it (OR semantics).
create or replace function lb.submit_score(
  p_device_id uuid,
  p_name text,
  p_form text,
  p_score integer,
  p_survival_ms integer,
  p_dragon_slayer boolean
) returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_res jsonb;
begin
  v_res := lb.submit_score(p_device_id, p_name, p_form, p_score, p_survival_ms);
  if coalesce(p_dragon_slayer, false) and coalesce((v_res->>'ok')::boolean, false) then
    if coalesce((v_res->>'new_best_all')::boolean, false) then
      update lb.best_all set dragon_slayer = true
       where device_id = p_device_id and form = v_res->>'form';
    end if;
    if coalesce((v_res->>'new_best_daily')::boolean, false) then
      update lb.best_daily set dragon_slayer = true
       where device_id = p_device_id and form = v_res->>'form' and day = (v_res->>'day')::date;
    end if;
  end if;
  return v_res || jsonb_build_object('dragon_slayer', coalesce(p_dragon_slayer, false));
end $function$;

revoke all on function lb.submit_score(uuid,text,text,integer,integer,boolean) from public;
grant execute on function lb.submit_score(uuid,text,text,integer,integer,boolean) to anon, authenticated;

-- Return types change, so these are dropped and recreated (same bodies plus dragon_slayer).
drop function if exists lb.get_leaderboard(text,text,integer,uuid);
drop function if exists lb.get_my_rank(uuid,text,text);
drop function if exists lb.board(text,text);

create function lb.board(p_form text, p_period text)
 returns table(device_id uuid, name text, score integer, form text, survival_ms integer, achieved_at timestamp with time zone, rank bigint, dragon_slayer boolean)
 language sql
 stable security definer
 set search_path to ''
as $function$
  with src as (
    select a.device_id, a.form, a.score, a.survival_ms, a.achieved_at, a.dragon_slayer from lb.best_all a
      where coalesce(p_period,'all') = 'all'
    union all
    select d.device_id, d.form, d.score, d.survival_ms, d.achieved_at, d.dragon_slayer from lb.best_daily d
      where p_period = 'daily' and d.day = (now() at time zone 'utc')::date
  ), filtered as (
    select * from src where p_form is null or src.form = lower(p_form)
  ), per_device as (
    select distinct on (f.device_id) f.* from filtered f
    order by f.device_id, f.score desc, f.achieved_at asc
  )
  select p.device_id, pl.name, p.score, p.form, p.survival_ms, p.achieved_at,
         rank() over (order by p.score desc) as rank, p.dragon_slayer
  from per_device p join lb.players pl on pl.device_id = p.device_id;
$function$;

create function lb.get_leaderboard(p_form text, p_period text, p_limit integer, p_device_id uuid)
 returns table(rank bigint, name text, score integer, form text, survival_ms integer, is_me boolean, dragon_slayer boolean)
 language sql
 stable security definer
 set search_path to ''
as $function$
  select b.rank, b.name, b.score, b.form, b.survival_ms, (p_device_id is not null and b.device_id = p_device_id), b.dragon_slayer
  from lb.board(p_form, p_period) b
  order by b.score desc, b.achieved_at asc
  limit least(greatest(coalesce(p_limit,50),1),100);
$function$;

create function lb.get_my_rank(p_device_id uuid, p_form text, p_period text)
 returns table(rank bigint, total bigint, name text, score integer, form text, survival_ms integer, dragon_slayer boolean)
 language sql
 stable security definer
 set search_path to ''
as $function$
  with b as (select * from lb.board(p_form, p_period))
  select b.rank, (select count(*) from b), b.name, b.score, b.form, b.survival_ms, b.dragon_slayer
  from b where b.device_id = p_device_id;
$function$;

revoke all on function lb.board(text,text) from public, anon, authenticated;
revoke all on function lb.get_leaderboard(text,text,integer,uuid) from public;
revoke all on function lb.get_my_rank(uuid,text,text) from public;
grant execute on function lb.get_leaderboard(text,text,integer,uuid) to anon, authenticated;
grant execute on function lb.get_my_rank(uuid,text,text) to anon, authenticated;

notify pgrst, 'reload schema';

-- The client calls the public.* wrappers. Widen them to carry dragon_slayer.
drop function if exists public.get_leaderboard(text,text,integer,uuid);
create function public.get_leaderboard(p_form text default null::text, p_period text default 'all'::text, p_limit integer default 50, p_device_id uuid default null::uuid)
 returns table(rank bigint, name text, score integer, form text, survival_ms integer, is_me boolean, dragon_slayer boolean)
 language sql
 stable
 set search_path to ''
as $function$
  select * from lb.get_leaderboard(p_form, p_period, p_limit, p_device_id);
$function$;

drop function if exists public.get_my_rank(uuid,text,text);
create function public.get_my_rank(p_device_id uuid, p_form text default null::text, p_period text default 'all'::text)
 returns table(rank bigint, total bigint, name text, score integer, form text, survival_ms integer, dragon_slayer boolean)
 language sql
 stable
 set search_path to ''
as $function$
  select * from lb.get_my_rank(p_device_id, p_form, p_period);
$function$;

create or replace function public.submit_score(p_device_id uuid, p_name text, p_form text, p_score integer, p_survival_ms integer, p_dragon_slayer boolean)
 returns jsonb
 language sql
 set search_path to ''
as $function$
  select lb.submit_score(p_device_id, p_name, p_form, p_score, p_survival_ms, p_dragon_slayer);
$function$;

revoke all on function public.get_leaderboard(text,text,integer,uuid) from public;
revoke all on function public.get_my_rank(uuid,text,text) from public;
revoke all on function public.submit_score(uuid,text,text,integer,integer,boolean) from public;
grant execute on function public.get_leaderboard(text,text,integer,uuid) to anon, authenticated, service_role;
grant execute on function public.get_my_rank(uuid,text,text) to anon, authenticated, service_role;
grant execute on function public.submit_score(uuid,text,text,integer,integer,boolean) to anon, authenticated, service_role;

notify pgrst, 'reload schema';

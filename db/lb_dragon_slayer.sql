-- Dragonslayer flag for schema lb.
-- Do NOT apply this to the live database until it has been reviewed.
-- Project: piayoqekmrhqfuhhvexg
--
-- The game posts p_dragon_slayer only when the run killed the Great Dragon.
-- If this overload is not deployed yet, PostgREST returns PGRST202 and the
-- client posts the same score again without the flag, so old servers keep
-- accepting runs.
--
-- Confirm the scores table name and the 5-argument submit_score signature
-- before running. The names below match the client's JSON keys.

alter table lb.runs add column if not exists dragon_slayer boolean not null default false;

-- 6-argument overload. It keeps the existing submit, then stamps the row
-- that belongs to this device when the run was a dragonslayer.
-- get_leaderboard / get_my_rank must select dragon_slayer onto each row.
-- The client treats a missing key as false.

create or replace function lb.submit_score(
	p_device_id text,
	p_name text,
	p_form text,
	p_score integer,
	p_survival_ms integer,
	p_dragon_slayer boolean
) returns json
language plpgsql
security definer
as $$
declare
	result json;
begin
	result := lb.submit_score(p_device_id, p_name, p_form, p_score, p_survival_ms);
	if p_dragon_slayer then
		update lb.runs
		set dragon_slayer = true
		where device_id = p_device_id;
	end if;
	return result;
end;
$$;

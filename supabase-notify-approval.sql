-- Emails the subscriber when their deallagi_subscribers.status flips to
-- 'active' (approved) — the field checked at login (chkInfo.status==='pending'
-- in index.html) that unlocks the account. The app's own UI already promises
-- this ("You will be notified by email once activated.", index.html:285) but
-- no code anywhere ever sent it — this closes that gap.
-- Uses the same shared Cloudflare Worker email relay already used by
-- sportbook/derasar-boli (telegram-notify.unigoods2026.workers.dev,
-- action:"sendEmail") — no new API key/secret needed.
-- Matches on either casing since existing rows show both 'active' and
-- 'ACTIVE' from manual approvals in Supabase Studio.
-- This project (unlike the one derasar-boli/sportbook run on) didn't have
-- pg_net enabled yet - needed for net.http_post below.

create extension if not exists pg_net with schema extensions;

create or replace function dl_notify_approval() returns trigger
language plpgsql
security definer
set search_path = deallagi, public
as $$
begin
  if lower(NEW.status) = 'active' and lower(coalesce(OLD.status, '')) <> 'active' then
    if NEW.email is not null then
      perform net.http_post(
        url := 'https://telegram-notify.unigoods2026.workers.dev/',
        headers := '{"Content-Type":"application/json"}'::jsonb,
        body := jsonb_build_object(
          'action', 'sendEmail',
          'to', NEW.email,
          'subject', 'Your DealLagi account is active',
          'html', '<p>Hi ' || coalesce(NEW.name, '') || ',</p>'
            || '<p>Your account on <b>DealLagi</b> has been approved and is now active. You can log in and start using the app:</p>'
            || '<p><a href="https://vkv-coder.github.io/DealLagi/">https://vkv-coder.github.io/DealLagi/</a></p>'
            || '<p style="font-size:13px;color:#666;">Questions? Contact vkv-coder.support@gmail.com</p>'
        )
      );
    end if;
  end if;
  return NEW;
end;
$$;

drop trigger if exists deallagi_subscribers_notify_approval on deallagi.deallagi_subscribers;
create trigger deallagi_subscribers_notify_approval
after update on deallagi.deallagi_subscribers
for each row execute function dl_notify_approval();

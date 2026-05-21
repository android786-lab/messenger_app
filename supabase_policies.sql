-- Run in Supabase SQL Editor after creating buckets (all PUBLIC for CDN URLs,
-- or use signed URLs with RLS — below: authenticated upload, public read).

-- Buckets: profile-images, chat-images, voice-messages, chat-files, video-messages

-- Example: allow authenticated users to upload to their folder
-- Adjust paths to match app upload paths (userId/chatId prefixes)

create policy "Public read profile images"
on storage.objects for select
using (bucket_id = 'profile-images');

create policy "Auth upload profile images"
on storage.objects for insert
with check (
  bucket_id = 'profile-images'
  and auth.role() = 'authenticated'
);

create policy "Public read chat images"
on storage.objects for select
using (bucket_id = 'chat-images');

create policy "Auth upload chat images"
on storage.objects for insert
with check (
  bucket_id = 'chat-images'
  and auth.role() = 'authenticated'
);

create policy "Public read voice"
on storage.objects for select
using (bucket_id = 'voice-messages');

create policy "Auth upload voice"
on storage.objects for insert
with check (
  bucket_id = 'voice-messages'
  and auth.role() = 'authenticated'
);

create policy "Public read files"
on storage.objects for select
using (bucket_id = 'chat-files');

create policy "Auth upload files"
on storage.objects for insert
with check (
  bucket_id = 'chat-files'
  and auth.role() = 'authenticated'
);

create policy "Public read video"
on storage.objects for select
using (bucket_id = 'video-messages');

create policy "Auth upload video"
on storage.objects for insert
with check (
  bucket_id = 'video-messages'
  and auth.role() = 'authenticated'
);

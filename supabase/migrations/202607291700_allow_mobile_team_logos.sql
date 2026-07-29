update storage.buckets
set file_size_limit = 1048576,
    allowed_mime_types = array['image/webp', 'image/jpeg']
where id = 'team-logos';

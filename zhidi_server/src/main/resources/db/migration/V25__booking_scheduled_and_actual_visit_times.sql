ALTER TABLE bookings
  ADD COLUMN scheduled_visit_at DATETIME(6) NULL AFTER on_site_at;

UPDATE bookings b
JOIN visit_proposals p ON p.booking_id = b.id
SET b.scheduled_visit_at = p.proposed_time
WHERE b.scheduled_visit_at IS NULL
  AND p.status = 'ACCEPTED'
  AND p.id = (
    SELECT accepted.id
    FROM visit_proposals accepted
    WHERE accepted.booking_id = b.id
      AND accepted.status = 'ACCEPTED'
    ORDER BY accepted.created_at DESC
    LIMIT 1
  );

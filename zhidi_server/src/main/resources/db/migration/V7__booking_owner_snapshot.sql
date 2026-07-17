ALTER TABLE bookings
  ADD COLUMN owner_name VARCHAR(80) NULL AFTER owner_user_id,
  ADD COLUMN owner_phone VARCHAR(32) NULL AFTER owner_name;

UPDATE bookings b
JOIN users u ON u.id = b.owner_user_id
LEFT JOIN owner_profiles op ON op.user_id = b.owner_user_id
SET b.owner_name = COALESCE(NULLIF(TRIM(op.name), ''), '业主'),
    b.owner_phone = u.phone;

ALTER TABLE bookings
  MODIFY COLUMN owner_name VARCHAR(80) NOT NULL,
  MODIFY COLUMN owner_phone VARCHAR(32) NOT NULL;

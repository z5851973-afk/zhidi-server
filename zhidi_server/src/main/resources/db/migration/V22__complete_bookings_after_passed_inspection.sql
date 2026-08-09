ALTER TABLE bookings DROP CHECK ck_bookings_status;
ALTER TABLE bookings ADD CONSTRAINT ck_bookings_status CHECK (status IN (
  'PENDING', 'ACCEPTED', 'VISIT_PROPOSED', 'VISIT_SCHEDULED',
  'ARRIVAL_PENDING', 'ON_SITE', 'QUOTE_PENDING', 'READY_TO_START',
  'REJECTED', 'CANCELLED', 'NOT_SELECTED', 'HIRED', 'COMPLETED'
));

UPDATE bookings b
SET b.status = 'COMPLETED', b.updated_at = NOW(6)
WHERE b.status = 'HIRED'
  AND EXISTS (
    SELECT 1
    FROM inspection_nodes n
    WHERE n.booking_id = b.id
      AND n.status = 'PASSED'
      AND n.name LIKE CONCAT(
        CASE LOWER(TRIM(b.trade))
          WHEN 'demolition' THEN '拆除'
          WHEN 'plumbing' THEN '水电'
          WHEN 'masonry' THEN '泥瓦'
          WHEN 'waterproof' THEN '防水'
          WHEN 'carpentry' THEN '木工'
          WHEN 'painting' THEN '油漆'
          WHEN 'installation' THEN '安装'
          WHEN 'cleaning' THEN '保洁'
          ELSE REPLACE(REPLACE(TRIM(b.trade), '师傅', ''), '验收', '')
        END,
        '%'
      )
  )
  AND NOT EXISTS (
    SELECT 1
    FROM inspection_nodes n
    WHERE n.booking_id = b.id
      AND n.status <> 'PASSED'
      AND n.name LIKE CONCAT(
        CASE LOWER(TRIM(b.trade))
          WHEN 'demolition' THEN '拆除'
          WHEN 'plumbing' THEN '水电'
          WHEN 'masonry' THEN '泥瓦'
          WHEN 'waterproof' THEN '防水'
          WHEN 'carpentry' THEN '木工'
          WHEN 'painting' THEN '油漆'
          WHEN 'installation' THEN '安装'
          WHEN 'cleaning' THEN '保洁'
          ELSE REPLACE(REPLACE(TRIM(b.trade), '师傅', ''), '验收', '')
        END,
        '%'
      )
  );

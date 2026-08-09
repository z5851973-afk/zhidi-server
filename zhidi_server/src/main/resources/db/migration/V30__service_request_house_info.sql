ALTER TABLE service_requests
  ADD COLUMN area_sqm DECIMAL(8,2) NULL,
  ADD COLUMN bedroom_count SMALLINT NULL,
  ADD COLUMN living_room_count SMALLINT NULL,
  ADD COLUMN kitchen_count SMALLINT NULL,
  ADD COLUMN bathroom_count SMALLINT NULL;

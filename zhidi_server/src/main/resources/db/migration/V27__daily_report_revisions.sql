ALTER TABLE daily_reports
    DROP INDEX uk_daily_reports_booking_date,
    ADD COLUMN report_revision INT NOT NULL DEFAULT 1 AFTER report_date,
    ADD CONSTRAINT uk_daily_reports_booking_date_revision
        UNIQUE KEY (booking_id, report_date, report_revision);

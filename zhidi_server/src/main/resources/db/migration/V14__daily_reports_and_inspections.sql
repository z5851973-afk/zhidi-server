CREATE TABLE daily_reports (
    id BINARY(16) PRIMARY KEY,
    booking_id BINARY(16) NOT NULL,
    worker_user_id BINARY(16) NOT NULL,
    report_date DATE NOT NULL,
    content TEXT NOT NULL,
    photos JSON NULL,
    created_at DATETIME(6) NOT NULL,
    updated_at DATETIME(6) NOT NULL,
    CONSTRAINT fk_daily_reports_booking FOREIGN KEY (booking_id) REFERENCES bookings(id),
    CONSTRAINT uk_daily_reports_booking_date UNIQUE KEY (booking_id, report_date)
);

CREATE TABLE inspection_nodes (
    id BINARY(16) PRIMARY KEY,
    booking_id BINARY(16) NOT NULL,
    name VARCHAR(100) NOT NULL,
    description TEXT NULL,
    status VARCHAR(32) NOT NULL DEFAULT 'PENDING',
    sort_order INT NOT NULL DEFAULT 0,
    created_at DATETIME(6) NOT NULL,
    updated_at DATETIME(6) NOT NULL,
    CONSTRAINT fk_inspection_nodes_booking FOREIGN KEY (booking_id) REFERENCES bookings(id)
);

ALTER TABLE inspection_nodes ADD CONSTRAINT ck_inspection_nodes_status
    CHECK (status IN ('PENDING', 'INSPECTING', 'PASSED', 'FAILED'));

CREATE TABLE inspection_records (
    id BINARY(16) PRIMARY KEY,
    node_id BINARY(16) NOT NULL,
    inspector_user_id BINARY(16) NOT NULL,
    result VARCHAR(16) NOT NULL,
    comment TEXT NULL,
    photos JSON NULL,
    version INT NOT NULL DEFAULT 1,
    created_at DATETIME(6) NOT NULL,
    CONSTRAINT fk_inspection_records_node FOREIGN KEY (node_id) REFERENCES inspection_nodes(id),
    CONSTRAINT ck_inspection_records_result CHECK (result IN ('PASS', 'FAIL'))
);

ALTER TABLE service_requests
  ADD COLUMN reopened_request_id BINARY(16) NULL,
  ADD CONSTRAINT uq_service_requests_reopened_request
    UNIQUE (reopened_request_id),
  ADD CONSTRAINT fk_service_requests_reopened_request
    FOREIGN KEY (reopened_request_id) REFERENCES service_requests(id)
    ON DELETE SET NULL;

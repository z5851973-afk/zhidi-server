CREATE TABLE sms_verification_codes (
  id BINARY(16) PRIMARY KEY,
  phone VARCHAR(20) NOT NULL,
  code_hash CHAR(64) NOT NULL,
  request_ip VARCHAR(45) NOT NULL,
  issued_at DATETIME(6) NOT NULL,
  expires_at DATETIME(6) NOT NULL,
  failed_attempts INT NOT NULL DEFAULT 0,
  invalidated_at DATETIME(6) NULL,
  consumed_at DATETIME(6) NULL,
  version BIGINT NOT NULL DEFAULT 0,
  created_at DATETIME(6) NOT NULL,
  updated_at DATETIME(6) NOT NULL,
  INDEX idx_sms_phone_issued (phone, issued_at),
  INDEX idx_sms_ip_issued (request_ip, issued_at),
  INDEX idx_sms_phone_active (phone, expires_at, consumed_at, invalidated_at)
);

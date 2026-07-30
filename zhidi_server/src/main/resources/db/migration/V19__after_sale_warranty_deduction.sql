-- V19: link after-sales processing to warranty retention deductions

ALTER TABLE after_sales
    ADD COLUMN warranty_retention_id BINARY(16) NULL,
    ADD COLUMN warranty_deduction_amount DECIMAL(12,2) NULL COMMENT '平台处理售后时从质保金扣减的金额',
    ADD CONSTRAINT fk_after_sales_warranty_retention
        FOREIGN KEY (warranty_retention_id) REFERENCES warranty_retentions(id);

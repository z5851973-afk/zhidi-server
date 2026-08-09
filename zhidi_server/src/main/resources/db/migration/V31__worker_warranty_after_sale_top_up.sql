-- V31: every after-sale warranty deduction must have one exact top-up obligation.
-- Paid-order contributions keep their existing source columns; after-sale top-ups
-- use after_sale_id and therefore do not invent payment or booking identifiers.

ALTER TABLE worker_warranty_contributions
    MODIFY COLUMN payment_order_id BINARY(16) NULL,
    MODIFY COLUMN booking_id BINARY(16) NULL,
    ADD COLUMN after_sale_id BINARY(16) NULL AFTER booking_id,
    ADD CONSTRAINT uq_worker_warranty_contribution_after_sale
        UNIQUE (after_sale_id),
    ADD CONSTRAINT fk_worker_warranty_contribution_after_sale
        FOREIGN KEY (after_sale_id) REFERENCES after_sales(id),
    ADD CONSTRAINT chk_worker_warranty_contribution_source
        CHECK (
            (payment_order_id IS NOT NULL AND booking_id IS NOT NULL
                AND after_sale_id IS NULL)
            OR
            (payment_order_id IS NULL AND booking_id IS NULL
                AND after_sale_id IS NOT NULL)
        );

-- V21: align legacy offline payment orders with the 10% owner service fee.
--
-- Before the service-fee rule was introduced, an offline payment order stored
-- the quote total in `amount`, left `platform_fee` at zero, and already kept
-- 10% of the quote as warranty retention by setting worker_settlement to 90%.
-- Only rows matching that exact legacy fingerprint are adjusted. New orders
-- already have a non-zero platform fee and are therefore untouched.

UPDATE payment_orders
SET platform_fee = ROUND(amount * 0.10, 2),
    amount = ROUND(amount * 1.10, 2)
WHERE payment_method = 'OFFLINE'
  AND platform_fee = 0
  AND amount > 0
  AND worker_settlement = ROUND(amount * 0.90, 2);

ALTER TABLE payment_orders
    MODIFY COLUMN amount DECIMAL(12,2) NOT NULL
        COMMENT '业主应付总额=报价清单总价+平台服务费',
    MODIFY COLUMN platform_fee DECIMAL(12,2) NOT NULL DEFAULT 0
        COMMENT '平台服务费=报价清单总价的10%',
    MODIFY COLUMN worker_settlement DECIMAL(12,2) NOT NULL DEFAULT 0
        COMMENT '工人可结算金额=报价清单总价的90%';

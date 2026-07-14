package com.zhidi.server.audit;

import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface OperationLogRepository extends JpaRepository<OperationLog, UUID> {
}

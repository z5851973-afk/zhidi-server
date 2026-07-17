package com.zhidi.server.dailyreport;

import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface DailyReportRepository extends JpaRepository<DailyReport, UUID> {

	List<DailyReport> findByBookingIdOrderByCreatedAtDesc(UUID bookingId);

	List<DailyReport> findByWorkerUserIdOrderByCreatedAtDesc(UUID workerUserId);
}

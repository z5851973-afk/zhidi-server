package com.zhidi.server.dailyreport;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface DailyReportRepository extends JpaRepository<DailyReport, UUID> {

	List<DailyReport> findByBookingIdOrderByReportDateDesc(UUID bookingId);

	Optional<DailyReport> findByBookingIdAndReportDate(UUID bookingId, LocalDate reportDate);
}

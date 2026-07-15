package com.zhidi.server.worker;

import com.zhidi.server.common.persistence.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import java.math.BigDecimal;
import java.util.Objects;
import java.util.UUID;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

@Entity
@Table(name = "worker_profiles")
public class WorkerProfile extends BaseEntity {

	@JdbcTypeCode(SqlTypes.BINARY)
	@Column(name = "user_id", nullable = false, unique = true, updatable = false,
		columnDefinition = "BINARY(16)")
	private UUID userId;

	@Column(length = 80)
	private String name;

	@Column(name = "service_city", nullable = false, length = 80)
	private String serviceCity;

	@Column(name = "primary_trade", length = 40)
	private String primaryTrade;

	@Column(name = "experience_years")
	private Integer experienceYears;

	@Column(name = "daily_rate", precision = 7, scale = 2)
	private BigDecimal dailyRate;

	@Column(length = 500)
	private String bio;

	protected WorkerProfile() {
	}

	private WorkerProfile(UUID userId, String name, String serviceCity,
			String primaryTrade, Integer experienceYears, BigDecimal dailyRate,
			String bio) {
		this.userId = Objects.requireNonNull(userId);
		this.name = name;
		this.serviceCity = Objects.requireNonNull(serviceCity);
		this.primaryTrade = primaryTrade;
		this.experienceYears = experienceYears;
		this.dailyRate = dailyRate;
		this.bio = bio;
	}

	public static WorkerProfile create(UUID userId, String name, String serviceCity,
			String primaryTrade, Integer experienceYears, BigDecimal dailyRate,
			String bio) {
		return new WorkerProfile(userId, name, serviceCity, primaryTrade, experienceYears,
			dailyRate, bio);
	}

	public UUID getUserId() {
		return userId;
	}

	public String getName() {
		return name;
	}

	public String getServiceCity() {
		return serviceCity;
	}

	public String getPrimaryTrade() {
		return primaryTrade;
	}

	public Integer getExperienceYears() {
		return experienceYears;
	}

	public BigDecimal getDailyRate() {
		return dailyRate;
	}

	public String getBio() {
		return bio;
	}

	public void update(String name, String serviceCity, String primaryTrade,
			Integer experienceYears, BigDecimal dailyRate, String bio) {
		this.name = name;
		this.serviceCity = Objects.requireNonNull(serviceCity);
		this.primaryTrade = primaryTrade;
		this.experienceYears = experienceYears;
		this.dailyRate = dailyRate;
		this.bio = bio;
	}
}

package com.zhidi.server.owner;

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
@Table(name = "owner_profiles")
public class OwnerProfile extends BaseEntity {

	@JdbcTypeCode(SqlTypes.BINARY)
	@Column(name = "user_id", nullable = false, unique = true, updatable = false,
		columnDefinition = "BINARY(16)")
	private UUID userId;

	@Column(length = 80)
	private String name;

	@Column(nullable = false, length = 80)
	private String city;

	@Column(name = "decoration_type", length = 40)
	private String decorationType;

	@Column(length = 255)
	private String address;

	@Column(precision = 7, scale = 2)
	private BigDecimal area;

	@Column(name = "avatar_url", length = 500)
	private String avatarUrl;

	@Column(length = 20)
	private String gender;

	protected OwnerProfile() {
	}

	private OwnerProfile(UUID userId, String name, String city, String decorationType,
			String address, BigDecimal area, String avatarUrl, String gender) {
		this.userId = Objects.requireNonNull(userId);
		this.name = name;
		this.city = Objects.requireNonNull(city);
		this.decorationType = decorationType;
		this.address = address;
		this.area = area;
		this.avatarUrl = avatarUrl;
		this.gender = gender;
	}

	public static OwnerProfile create(UUID userId, String name, String city,
			String decorationType, String address, BigDecimal area) {
		return create(userId, name, city, decorationType, address, area, null, null);
	}

	public static OwnerProfile create(UUID userId, String name, String city,
			String decorationType, String address, BigDecimal area,
			String avatarUrl, String gender) {
		return new OwnerProfile(userId, name, city, decorationType, address, area,
			avatarUrl, gender);
	}

	public UUID getUserId() {
		return userId;
	}

	public String getName() {
		return name;
	}

	public String getCity() {
		return city;
	}

	public String getDecorationType() {
		return decorationType;
	}

	public String getAddress() {
		return address;
	}

	public BigDecimal getArea() {
		return area;
	}

	public String getAvatarUrl() {
		return avatarUrl;
	}

	public String getGender() {
		return gender;
	}

	public void update(String name, String city, String decorationType, String address,
			BigDecimal area, String avatarUrl, String gender) {
		this.name = name;
		this.city = Objects.requireNonNull(city);
		this.decorationType = decorationType;
		this.address = address;
		this.area = area;
		this.avatarUrl = avatarUrl;
		this.gender = gender;
	}
}

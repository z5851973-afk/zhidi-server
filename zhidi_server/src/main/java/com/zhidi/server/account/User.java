package com.zhidi.server.account;

import com.zhidi.server.common.persistence.BaseEntity;
import jakarta.persistence.CollectionTable;
import jakarta.persistence.Column;
import jakarta.persistence.ElementCollection;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.Table;
import java.util.EnumSet;
import java.util.Set;
import java.util.regex.Pattern;
import org.springframework.util.StringUtils;

@Entity
@Table(name = "users")
public class User extends BaseEntity {

	private static final Pattern MAINLAND_MOBILE = Pattern.compile("1[3-9]\\d{9}");

	@Column(nullable = false, unique = true, length = 20)
	private String phone;

	@Enumerated(EnumType.STRING)
	@Column(nullable = false, length = 32)
	private UserStatus status;

	@ElementCollection(fetch = FetchType.EAGER)
	@CollectionTable(name = "user_roles", joinColumns = @JoinColumn(name = "user_id"))
	@Enumerated(EnumType.STRING)
	@Column(name = "role", nullable = false, length = 32)
	private Set<UserRole> roles = EnumSet.noneOf(UserRole.class);

	protected User() {
	}

	private User(String phone) {
		this.phone = normalizePhone(phone);
		this.status = UserStatus.ACTIVE;
	}

	public static User create(String phone) {
		return new User(phone);
	}

	public String getPhone() {
		return phone;
	}

	public UserStatus getStatus() {
		return status;
	}

	public Set<UserRole> getRoles() {
		return Set.copyOf(roles);
	}

	public void grantRole(UserRole role) {
		if (role == null) {
			throw new IllegalArgumentException("role must not be null");
		}
		roles.add(role);
	}

	public boolean hasRole(UserRole role) {
		return roles.contains(role);
	}

	public static String normalizePhone(String phone) {
		if (!StringUtils.hasText(phone)) {
			throw new IllegalArgumentException("phone must not be blank");
		}
		String normalized = phone.replaceAll("\\s+", "");
		if (!MAINLAND_MOBILE.matcher(normalized).matches()) {
			throw new IllegalArgumentException("phone must be an 11-digit mainland mobile number");
		}
		return normalized;
	}
}

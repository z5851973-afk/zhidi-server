package com.zhidi.server.quote;

import com.zhidi.server.common.persistence.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import java.math.BigDecimal;
import java.util.Objects;

@Entity
@Table(name = "service_catalog")
public class ServiceCatalog extends BaseEntity {

	@Column(nullable = false, length = 32)
	private String category;

	@Column(nullable = false, length = 100)
	private String name;

	@Column(nullable = false, length = 16)
	private String unit;

	@Column(name = "unit_price", nullable = false, precision = 12, scale = 2)
	private BigDecimal unitPrice;

	@Column(name = "is_material", nullable = false)
	private boolean isMaterial;

	@Column(name = "sort_order", nullable = false)
	private int sortOrder;

	protected ServiceCatalog() {
	}

	public ServiceCatalog(String category, String name, String unit,
			BigDecimal unitPrice, boolean isMaterial, int sortOrder) {
		this.category = Objects.requireNonNull(category);
		this.name = Objects.requireNonNull(name);
		this.unit = Objects.requireNonNull(unit);
		this.unitPrice = Objects.requireNonNull(unitPrice);
		this.isMaterial = isMaterial;
		this.sortOrder = sortOrder;
	}

	public String getCategory() {
		return category;
	}

	public String getName() {
		return name;
	}

	public String getUnit() {
		return unit;
	}

	public BigDecimal getUnitPrice() {
		return unitPrice;
	}

	public boolean isMaterial() {
		return isMaterial;
	}

	public int getSortOrder() {
		return sortOrder;
	}
}

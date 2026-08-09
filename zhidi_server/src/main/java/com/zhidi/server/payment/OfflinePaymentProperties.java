package com.zhidi.server.payment;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.boot.context.properties.bind.ConstructorBinding;

@ConfigurationProperties(prefix = "payment.offline")
public record OfflinePaymentProperties(
	String companyAccountName,
	String companyBankName,
	String companyBankAccount,
	String warrantyAccountName,
	String warrantyBankName,
	String warrantyBankAccount
) {
	@ConstructorBinding
	public OfflinePaymentProperties {
	}

	public OfflinePaymentProperties(String companyAccountName,
			String companyBankName, String companyBankAccount) {
		this(companyAccountName, companyBankName, companyBankAccount,
			null, null, null);
	}

	public boolean hasCompanyAccount() {
		return hasText(companyAccountName)
			&& hasText(companyBankName)
			&& hasText(companyBankAccount);
	}

	public boolean hasWarrantyAccount() {
		return hasText(warrantyAccountName)
			&& hasText(warrantyBankName)
			&& hasText(warrantyBankAccount);
	}

	private static boolean hasText(String value) {
		return value != null && !value.isBlank();
	}
}

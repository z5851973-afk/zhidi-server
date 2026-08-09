package com.zhidi.server.support;

import static org.mockito.Mockito.mock;

import com.zhidi.server.booking.VisitProposalRepository;
import com.zhidi.server.chat.ChatMessageRepository;
import com.zhidi.server.chat.ChatRoomRepository;
import com.zhidi.server.inspection.InspectionNodeRepository;
import com.zhidi.server.inspection.InspectionRecordRepository;
import com.zhidi.server.inspection.InspectionSubmissionRepository;
import com.zhidi.server.inspection.InspectionEvidenceAssetRepository;
import com.zhidi.server.notification.BusinessEventRepository;
import com.zhidi.server.notification.BusinessEventStreamRepository;
import com.zhidi.server.owner.OwnerAddressRepository;
import com.zhidi.server.payment.AfterSaleRepository;
import com.zhidi.server.payment.AfterSaleEventRepository;
import com.zhidi.server.payment.PaymentOrderRepository;
import com.zhidi.server.payment.PaymentReferenceClaimRepository;
import com.zhidi.server.payment.SettlementRepository;
import com.zhidi.server.payment.WarrantyRetentionRepository;
import com.zhidi.server.payment.WorkerWarrantyAccountRepository;
import com.zhidi.server.payment.WorkerWarrantyContributionRepository;
import com.zhidi.server.payment.WorkerWarrantyLedgerEntryRepository;
import com.zhidi.server.quote.ServiceCatalogRepository;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.jdbc.core.JdbcTemplate;

@TestConfiguration
public class RoadmapPersistenceTestConfig {

	@Bean JdbcTemplate jdbcTemplate() {
		return mock(JdbcTemplate.class);
	}

	@Bean BusinessEventRepository businessEventRepository() {
		return mock(BusinessEventRepository.class);
	}

	@Bean BusinessEventStreamRepository businessEventStreamRepository() {
		return mock(BusinessEventStreamRepository.class);
	}

	@Bean OwnerAddressRepository ownerAddressRepository() {
		return mock(OwnerAddressRepository.class);
	}

	@Bean VisitProposalRepository visitProposalRepository() {
		return mock(VisitProposalRepository.class);
	}

	@Bean ServiceCatalogRepository serviceCatalogRepository() {
		return mock(ServiceCatalogRepository.class);
	}

	@Bean InspectionNodeRepository inspectionNodeRepository() {
		return mock(InspectionNodeRepository.class);
	}

	@Bean InspectionRecordRepository inspectionRecordRepository() {
		return mock(InspectionRecordRepository.class);
	}

	@Bean InspectionSubmissionRepository inspectionSubmissionRepository() {
		return mock(InspectionSubmissionRepository.class);
	}

	@Bean InspectionEvidenceAssetRepository inspectionEvidenceAssetRepository() {
		return mock(InspectionEvidenceAssetRepository.class);
	}

	@Bean ChatRoomRepository chatRoomRepository() {
		return mock(ChatRoomRepository.class);
	}

	@Bean ChatMessageRepository chatMessageRepository() {
		return mock(ChatMessageRepository.class);
	}

	@Bean PaymentOrderRepository paymentOrderRepository() {
		return mock(PaymentOrderRepository.class);
	}

	@Bean PaymentReferenceClaimRepository paymentReferenceClaimRepository() {
		return mock(PaymentReferenceClaimRepository.class);
	}

	@Bean SettlementRepository settlementRepository() {
		return mock(SettlementRepository.class);
	}

	@Bean WarrantyRetentionRepository warrantyRetentionRepository() {
		return mock(WarrantyRetentionRepository.class);
	}

	@Bean AfterSaleRepository afterSaleRepository() {
		return mock(AfterSaleRepository.class);
	}

	@Bean AfterSaleEventRepository afterSaleEventRepository() {
		return mock(AfterSaleEventRepository.class);
	}

	@Bean WorkerWarrantyAccountRepository workerWarrantyAccountRepository() {
		return mock(WorkerWarrantyAccountRepository.class);
	}

	@Bean WorkerWarrantyContributionRepository workerWarrantyContributionRepository() {
		return mock(WorkerWarrantyContributionRepository.class);
	}

	@Bean WorkerWarrantyLedgerEntryRepository workerWarrantyLedgerEntryRepository() {
		return mock(WorkerWarrantyLedgerEntryRepository.class);
	}
}

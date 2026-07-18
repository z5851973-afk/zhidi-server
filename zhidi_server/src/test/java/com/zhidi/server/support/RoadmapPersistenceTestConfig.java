package com.zhidi.server.support;

import static org.mockito.Mockito.mock;

import com.zhidi.server.booking.VisitProposalRepository;
import com.zhidi.server.chat.ChatMessageRepository;
import com.zhidi.server.chat.ChatRoomRepository;
import com.zhidi.server.inspection.InspectionNodeRepository;
import com.zhidi.server.inspection.InspectionRecordRepository;
import com.zhidi.server.payment.AfterSaleRepository;
import com.zhidi.server.payment.PaymentOrderRepository;
import com.zhidi.server.payment.SettlementRepository;
import com.zhidi.server.quote.ServiceCatalogRepository;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;

@TestConfiguration
public class RoadmapPersistenceTestConfig {

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

	@Bean ChatRoomRepository chatRoomRepository() {
		return mock(ChatRoomRepository.class);
	}

	@Bean ChatMessageRepository chatMessageRepository() {
		return mock(ChatMessageRepository.class);
	}

	@Bean PaymentOrderRepository paymentOrderRepository() {
		return mock(PaymentOrderRepository.class);
	}

	@Bean SettlementRepository settlementRepository() {
		return mock(SettlementRepository.class);
	}

	@Bean AfterSaleRepository afterSaleRepository() {
		return mock(AfterSaleRepository.class);
	}
}

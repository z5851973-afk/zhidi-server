package com.zhidi.server.inspection;

import com.zhidi.server.booking.Booking;
import com.zhidi.server.booking.BookingRepository;
import com.zhidi.server.booking.BookingStatus;
import com.zhidi.server.common.error.BusinessException;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class InspectionService {

	private final InspectionNodeRepository nodeRepository;
	private final InspectionRecordRepository recordRepository;
	private final BookingRepository bookingRepository;

	public InspectionService(InspectionNodeRepository nodeRepository,
			InspectionRecordRepository recordRepository,
			BookingRepository bookingRepository) {
		this.nodeRepository = nodeRepository;
		this.recordRepository = recordRepository;
		this.bookingRepository = bookingRepository;
	}

	@Transactional
	public List<InspectionNodeResponse> createNodes(UUID workerUserId, UUID bookingId,
			List<CreateNodeRequest> requests) {
		Booking booking = bookingRepository.findByIdAndWorkerUserId(bookingId, workerUserId)
			.orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND,
				"BOOKING_NOT_FOUND", "预约不存在"));

		if (booking.getStatus() != BookingStatus.HIRED) {
			throw new BusinessException(HttpStatus.CONFLICT,
				"INVALID_STATUS", "只有已选定(HIRED)的预约才能创建施工节点");
		}

		List<InspectionNode> nodes = requests.stream()
			.map(req -> InspectionNode.create(bookingId, req.name(),
				req.description(), req.sortOrder()))
			.toList();

		return nodeRepository.saveAllAndFlush(nodes).stream()
			.map(InspectionNodeResponse::from)
			.toList();
	}

	@Transactional(readOnly = true)
	public List<InspectionNodeResponse> getNodes(UUID bookingId) {
		return nodeRepository.findByBookingIdOrderBySortOrderAsc(bookingId)
			.stream()
			.map(InspectionNodeResponse::from)
			.toList();
	}

	@Transactional
	public InspectionNodeResponse requestInspection(UUID workerUserId, UUID nodeId) {
		InspectionNode node = nodeRepository.findById(nodeId)
			.orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND,
				"NODE_NOT_FOUND", "施工节点不存在"));

		Booking booking = bookingRepository.findById(node.getBookingId())
			.orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND,
				"BOOKING_NOT_FOUND", "预约不存在"));

		if (!booking.getWorkerUserId().equals(workerUserId)) {
			throw new BusinessException(HttpStatus.FORBIDDEN,
				"NOT_WORKER", "只有该预约的工人才能申请验收");
		}

		if (node.getStatus() != InspectionNodeStatus.PENDING
				&& node.getStatus() != InspectionNodeStatus.FAILED) {
			throw new BusinessException(HttpStatus.CONFLICT,
				"INVALID_NODE_STATUS", "只有待验收或整改未通过的节点才能申请验收");
		}

		node.requestInspection();
		return InspectionNodeResponse.from(nodeRepository.save(node));
	}

	@Transactional
	public InspectionRecordResponse inspect(UUID inspectorUserId, UUID nodeId,
			InspectRequest request) {
		InspectionNode node = nodeRepository.findById(nodeId)
			.orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND,
				"NODE_NOT_FOUND", "施工节点不存在"));

		Booking booking = bookingRepository.findById(node.getBookingId())
			.orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND,
				"BOOKING_NOT_FOUND", "预约不存在"));

		if (!booking.getOwnerUserId().equals(inspectorUserId)) {
			throw new BusinessException(HttpStatus.FORBIDDEN,
				"NOT_OWNER", "只有业主才能执行验收");
		}

		if (node.getStatus() != InspectionNodeStatus.INSPECTING) {
			throw new BusinessException(HttpStatus.CONFLICT,
				"INVALID_NODE_STATUS", "只有验收中的节点才能执行验收操作");
		}

		int nextVersion = recordRepository.findByNodeIdOrderByVersionDesc(nodeId)
			.stream()
			.findFirst()
			.map(r -> r.getVersion() + 1)
			.orElse(1);

		InspectionRecord record = InspectionRecord.create(nodeId, inspectorUserId,
			request.result(), request.comment(), request.photos(), nextVersion);
		InspectionRecord saved = recordRepository.save(record);

		if (request.result() == InspectionResult.PASS) {
			node.markPassed();
		} else {
			node.markFailed();
		}
		nodeRepository.save(node);

		return InspectionRecordResponse.from(saved);
	}

	@Transactional(readOnly = true)
	public List<InspectionRecordResponse> getRecords(UUID nodeId) {
		return recordRepository.findByNodeIdOrderByVersionDesc(nodeId)
			.stream()
			.map(InspectionRecordResponse::from)
			.toList();
	}
}

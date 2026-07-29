package com.zhidi.server.infrastructure.sms;

import java.util.Map;

public interface SmsService {

	/** 发送由认证服务生成并持久化的同一条验证码。 */
	void sendVerificationCode(String phoneNumber, String code);

	/**
	 * 发送通知短信（预约确认、施工提醒等）
	 */
	void sendNotification(String phoneNumber, String templateId, Map<String, String> params);
}

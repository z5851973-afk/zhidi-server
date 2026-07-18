package com.zhidi.server.infrastructure.sms;

import java.util.Map;

public interface SmsService {

	/**
	 * 发送验证码短信（含限流检查）
	 * @return 发送结果，包含验证码和重试间隔
	 */
	SmsSendResult sendVerifyCode(String phoneNumber);

	/**
	 * 校验验证码
	 * @return true 表示验证码正确且未过期
	 */
	boolean verifyCode(String phoneNumber, String code);

	/**
	 * 发送通知短信（预约确认、施工提醒等）
	 */
	void sendNotification(String phoneNumber, String templateId, Map<String, String> params);
}

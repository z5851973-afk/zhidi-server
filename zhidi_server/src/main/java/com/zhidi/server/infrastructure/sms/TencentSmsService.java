package com.zhidi.server.infrastructure.sms;

import com.tencentcloudapi.common.Credential;
import com.tencentcloudapi.common.exception.TencentCloudSDKException;
import com.tencentcloudapi.sms.v20210111.SmsClient;
import com.tencentcloudapi.sms.v20210111.models.SendSmsRequest;
import com.tencentcloudapi.sms.v20210111.models.SendSmsResponse;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Service;

@Service
@ConditionalOnProperty(prefix = "tencent.sms", name = "enabled", havingValue = "true")
public class TencentSmsService implements SmsService {

	private static final Logger log = LoggerFactory.getLogger(TencentSmsService.class);
	private final SmsClient client;
	private final SmsConfig config;

	public TencentSmsService(SmsConfig config) {
		this.config = config;
		Credential credential = new Credential(config.secretId(), config.secretKey());
		this.client = new SmsClient(credential, "ap-guangzhou");
	}

	@Override
	public void sendVerificationCode(String phoneNumber, String code) {
		String templateId = config.templateIds().getOrDefault("verify-code", "");

		try {
			SendSmsRequest request = new SendSmsRequest();
			request.setSmsSdkAppId(config.appId());
			request.setSignName(config.signName());
			request.setTemplateId(templateId);
			request.setTemplateParamSet(new String[]{code});
			request.setPhoneNumberSet(new String[]{"+86" + phoneNumber});

			SendSmsResponse response = client.SendSms(request);
			log.info("SMS verify code sent to {}: status={}", phoneNumber,
				response.getSendStatusSet()[0].getCode());
		} catch (TencentCloudSDKException e) {
			log.error("SMS send failed for {}: {}", phoneNumber, e.getMessage());
			throw new SmsException("短信发送失败，请稍后重试", e);
		}

	}

	@Override
	public void sendNotification(String phoneNumber, String templateId, Map<String, String> params) {
		try {
			SendSmsRequest request = new SendSmsRequest();
			request.setSmsSdkAppId(config.appId());
			request.setSignName(config.signName());
			request.setTemplateId(templateId);
			request.setTemplateParamSet(params.values().toArray(new String[0]));
			request.setPhoneNumberSet(new String[]{"+86" + phoneNumber});

			SendSmsResponse response = client.SendSms(request);
			log.info("SMS notification sent to {}: template={} status={}", phoneNumber, templateId,
				response.getSendStatusSet()[0].getCode());
		} catch (TencentCloudSDKException e) {
			log.error("SMS notification failed for {}: {}", phoneNumber, e.getMessage());
			throw new SmsException("短信发送失败，请稍后重试", e);
		}
	}

	public static final class SmsException extends RuntimeException {
		public SmsException(String message, Throwable cause) {
			super(message, cause);
		}
	}
}

package com.zhidi.server.infrastructure.sms;

import com.tencentcloudapi.common.Credential;
import com.tencentcloudapi.common.exception.TencentCloudSDKException;
import com.tencentcloudapi.sms.v20210111.SmsClient;
import com.tencentcloudapi.sms.v20210111.models.SendSmsRequest;
import com.tencentcloudapi.sms.v20210111.models.SendSmsResponse;
import java.security.SecureRandom;
import java.time.Duration;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;

@Service
@ConditionalOnProperty(value = "tencent.sms.secret-id")
public class TencentSmsService implements SmsService {

	private static final Logger log = LoggerFactory.getLogger(TencentSmsService.class);
	private static final String REDIS_PREFIX = "sms:verify:";
	private static final String COOLDOWN_PREFIX = "sms:cooldown:";
	private static final Duration CODE_TTL = Duration.ofMinutes(5);
	private static final Duration COOLDOWN = Duration.ofSeconds(60);

	private final SmsClient client;
	private final SmsConfig config;
	private final SecureRandom random;
	private final StringRedisTemplate redis;

	public TencentSmsService(SmsConfig config, StringRedisTemplate redis) {
		this.config = config;
		this.redis = redis;
		this.random = new SecureRandom();
		Credential credential = new Credential(config.secretId(), config.secretKey());
		this.client = new SmsClient(credential, "ap-guangzhou");
	}

	@Override
	public SmsSendResult sendVerifyCode(String phoneNumber) {
		String cooldownKey = COOLDOWN_PREFIX + phoneNumber;
		String remaining = redis.opsForValue().get(cooldownKey);
		if (remaining != null) {
			long retryAfter = redis.getExpire(cooldownKey);
			return SmsSendResult.rateLimited(Math.max(1, retryAfter));
		}

		String code = "%06d".formatted(random.nextInt(1_000_000));
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

		redis.opsForValue().set(REDIS_PREFIX + phoneNumber, code, CODE_TTL);
		redis.opsForValue().set(cooldownKey, "1", COOLDOWN);
		return SmsSendResult.success(code, CODE_TTL.toSeconds(), COOLDOWN.toSeconds());
	}

	@Override
	public boolean verifyCode(String phoneNumber, String code) {
		String key = REDIS_PREFIX + phoneNumber;
		String stored = redis.opsForValue().get(key);
		return stored != null && stored.equals(code);
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

package com.zhidi.server.infrastructure.storage;

import com.qcloud.cos.COSClient;
import com.qcloud.cos.ClientConfig;
import com.qcloud.cos.auth.BasicCOSCredentials;
import com.qcloud.cos.auth.COSCredentials;
import com.qcloud.cos.exception.CosClientException;
import com.qcloud.cos.http.HttpMethodName;
import com.qcloud.cos.model.ObjectMetadata;
import com.qcloud.cos.model.PutObjectRequest;
import com.qcloud.cos.region.Region;
import java.io.ByteArrayInputStream;
import java.net.URL;
import java.time.Duration;
import java.util.Date;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Service;

@Service
@ConditionalOnProperty(value = "tencent.cos.secret-id")
public class TencentCosStorageService implements FileStorageService {

	private static final Logger log = LoggerFactory.getLogger(TencentCosStorageService.class);

	private final COSClient client;
	private final TencentCosProperties config;

	public TencentCosStorageService(TencentCosProperties config) {
		this.config = config;
		COSCredentials credentials = new BasicCOSCredentials(
			config.secretId(), config.secretKey());
		ClientConfig clientConfig = new ClientConfig(new Region(config.region()));
		this.client = new COSClient(credentials, clientConfig);
	}

	@Override
	public String upload(String objectKey, byte[] data, String contentType) {
		ObjectMetadata metadata = new ObjectMetadata();
		metadata.setContentType(contentType);
		metadata.setContentLength(data.length);

		try {
			PutObjectRequest request = new PutObjectRequest(
				config.bucket(), objectKey,
				new ByteArrayInputStream(data), metadata);
			client.putObject(request);
			log.info("COS upload success: {}", objectKey);
			return "https://" + config.bucket() + ".cos." + config.region()
				+ ".myqcloud.com/" + objectKey;
		} catch (CosClientException e) {
			log.error("COS upload failed: {}", objectKey, e);
			throw new StorageException("文件上传失败，请稍后重试", e);
		}
	}

	@Override
	public String presignUrl(String objectKey, Duration ttl) {
		try {
			Date expiration = new Date(System.currentTimeMillis() + ttl.toMillis());
			URL url = client.generatePresignedUrl(
				config.bucket(), objectKey, expiration, HttpMethodName.GET);
			return url.toString();
		} catch (CosClientException e) {
			log.error("COS presign failed: {}", objectKey, e);
			throw new StorageException("生成访问链接失败", e);
		}
	}

	@Override
	public void delete(String objectKey) {
		try {
			client.deleteObject(config.bucket(), objectKey);
			log.info("COS delete success: {}", objectKey);
		} catch (CosClientException e) {
			log.error("COS delete failed: {}", objectKey, e);
			throw new StorageException("文件删除失败", e);
		}
	}

	public static final class StorageException extends RuntimeException {
		public StorageException(String message, Throwable cause) {
			super(message, cause);
		}
	}
}

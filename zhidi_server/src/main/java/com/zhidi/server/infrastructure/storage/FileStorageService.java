package com.zhidi.server.infrastructure.storage;

import java.time.Duration;

public interface FileStorageService {

	/** 上传文件，返回公开访问 URL */
	String upload(String objectKey, byte[] data, String contentType);

	/** 生成有时效的临时访问 URL（私密文件） */
	String presignUrl(String objectKey, Duration ttl);

	/** 删除文件 */
	void delete(String objectKey);
}

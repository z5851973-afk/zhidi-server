package com.zhidi.server;

import com.zhidi.server.infrastructure.sms.SmsConfig;
import com.zhidi.server.infrastructure.storage.TencentCosProperties;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.EnableConfigurationProperties;

@SpringBootApplication
@EnableConfigurationProperties({SmsConfig.class, TencentCosProperties.class})
public class ZhidiServerApplication {

	public static void main(String[] args) {
		SpringApplication.run(ZhidiServerApplication.class, args);
	}

}

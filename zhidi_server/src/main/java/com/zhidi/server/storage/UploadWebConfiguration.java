package com.zhidi.server.storage;

import java.nio.file.Path;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.ResourceHandlerRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

@Configuration
public class UploadWebConfiguration implements WebMvcConfigurer {

	private final String resourceLocation;

	public UploadWebConfiguration(
			@Value("${zhidi.upload.root:./uploads}") String uploadRoot) {
		String location = Path.of(uploadRoot).toAbsolutePath().normalize().toUri().toString();
		this.resourceLocation = location.endsWith("/") ? location : location + "/";
	}

	@Override
	public void addResourceHandlers(ResourceHandlerRegistry registry) {
		registry.addResourceHandler("/uploads/**")
			.addResourceLocations(resourceLocation);
	}
}

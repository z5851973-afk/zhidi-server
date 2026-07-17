# 知底 Flutter App

同一个 Flutter 工程包含业主端和工匠端。本地默认启动工匠端；启动业主端时需要通过 `ZHIDI_APP_FLAVOR=owner` 指定应用类型。

## 启动本地后端

先确保 Docker Desktop 和本地 MySQL 容器正在运行，再执行：

```bash
cd /Users/liupei/Documents/zhidi/zhidi_server
MAVEN_USER_HOME=/Users/liupei/Documents/zhidi/.m2 ./mvnw spring-boot:run \
  -Dmaven.repo.local=/Users/liupei/Documents/zhidi/.m2/repository \
  -s /Users/liupei/Documents/zhidi/.m2/settings.xml
```

后端启动后可访问中文 Swagger：<http://localhost:8080/swagger-ui/index.html>。

## 启动 Android 业主端

Android 模拟器使用宿主机专用地址：

```bash
cd /Users/liupei/Documents/zhidi/zhidi_app
../flutter/bin/flutter run \
  --flavor owner \
  --dart-define=ZHIDI_APP_FLAVOR=owner \
  --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

真机调试时，把 `192.168.x.x` 换成 Mac 在同一局域网中的实际 IP：

```bash
../flutter/bin/flutter run \
  --flavor owner \
  --dart-define=ZHIDI_APP_FLAVOR=owner \
  --dart-define=API_BASE_URL=http://192.168.x.x:8080
```

本地开发环境会返回模拟短信验证码，App 自动填入后可直接登录。新手机号会自动注册为业主，已有业主会直接登录。JWT 有效期为 30 天，并保存到 Android 安全存储。

## 安全说明

- Android 明文 HTTP 仅在 `src/debug` 构建中允许。
- 正式环境的 `API_BASE_URL` 必须使用 HTTPS。
- 不要把短信验证码、JWT 或正式签名密钥写入日志和代码仓库。

## 检查与测试

```bash
HOME=$PWD/.codex-flutter-home ../flutter/bin/flutter analyze
HOME=$PWD/.codex-flutter-home ../flutter/bin/flutter test
```

# 沙盒服务与项目文件

## 功能定位
沙盒负责项目目录的创建、文件读写、模板复制与最终输出，前端预览依赖沙盒生成的文件结构。

## 本地沙盒（默认）
- 通过 `SandboxClient` 直接读写本地文件系统。
- 默认项目目录：`backend/data/projects/{userId}/{sessionId}/web`
- 默认模板目录：`backend/templates/double_line`（可通过环境变量覆盖）

## 独立沙盒服务
`backend/sandbox` 可单独部署，通过 API 实现文件管理与静态预览。

## 关键模块
- `backend/app/services/sandbox_client.py`
- `backend/sandbox/app/main.py`
- `backend/sandbox/docker-compose.yml`

## 复刻要点
- 项目路径规则必须一致，否则预览失效。
- 文件读写需保证路径安全（防止路径遍历）。
- 模板复制需确保可重复、幂等。


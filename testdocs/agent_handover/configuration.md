# 配置与环境变量

## 后端配置入口
后端配置集中在 `backend/app/core/config.py`，通过 `pydantic-settings` 从环境变量或 `.env` 读取。

### 关键配置项（需在 .env 中提供）
- **模型与外部服务密钥**：OpenAI/OpenRouter/TAL/Hunyuan/DeepDataSpace 等（避免写入仓库）。
- **Redis**：可选，用于任务管理。
- **数据库路径**：`database_path` 可覆盖默认 SQLite 路径。
- **视频/游戏 Mock 开关**：用于测试时跳过真实生成流程。

### 运行相关环境变量
- `WORKSPACE_ROOT`：项目输出根目录。
- `PROJECTS_DIR`：生成项目的输出目录。
- `TEMPLATES_DIR`：非 xproject 模式模板目录。
- `PREVIEW_BASE_URL`：预览服务的外部域名（用于事件数据修复）。

## 前端配置入口
前端配置位于 `frontend_unified/.env.*` 与 `frontend_unified/src/config`。

### 关键配置项
- `VITE_API_URL`：后端 API 地址。
- `VITE_AUTH_PROVIDER`：鉴权模式（none / sso / local）。
- SSO 参数：`frontend_unified/src/config/sso.ts`。

## 复刻要点
- 不要在代码中硬编码密钥，全部通过 `.env` 或运行时环境注入。
- 前后端 API 地址与 CORS 白名单要对齐。
- 本地预览时建议配置 `PREVIEW_BASE_URL` 为本机地址。


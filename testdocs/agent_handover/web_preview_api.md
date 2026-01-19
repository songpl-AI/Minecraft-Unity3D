# Web 预览服务

## 功能定位
提供生成项目的静态文件访问能力，用于前端 iframe 预览。

## 关键路由
- `GET /api/v1/preview/web/{userId}/{sessionId}/web/...`
- 支持 `HEAD`、`OPTIONS`

## 安全与行为
- 路径安全校验，防止目录穿越。
- 访问目录时自动返回 `index.html`。
- 支持常见静态资源 MIME 类型。

## 关键模块
- `backend/app/api/preview.py`

## 复刻要点
- 预览路径需与项目输出目录规则一致。
- CORS 与静态文件类型配置需覆盖常见前端资源。


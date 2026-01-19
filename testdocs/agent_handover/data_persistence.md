# 数据持久化与会话存储

## 数据库
- 数据库类型：SQLite
- 默认路径：`backend/data/manus.db`
- 可通过 `database_path` 环境变量覆盖

## 数据模型
### sessions 表
存储会话元数据：
- `session_id`、`title`、`status`
- `latest_message`、`latest_message_at`
- `unread_message_count`、`is_shared`
- `web_project`（生成项目的路径与预览 URL）
- `workflow_state`（XProject 工作流状态 JSON）

### events 表
存储会话内的所有 SSE 事件：
- `session_id`、`event_id`、`event_type`、`timestamp`
- `data`（JSON 字符串）

## 关键逻辑
- 启动时 `init_database()` 自动建表与索引。
- 事件数据写入由后台任务统一完成。
- 事件读取时会修复预览 URL（相对 → 绝对）。

## 关键文件
- `backend/app/core/database.py`
- `backend/app/api/sessions.py`

## 复刻要点
- 保证 `events` 表写入性能与顺序，前端 SSE 依赖事件顺序。
- 事件数据必须符合前端事件结构，否则会导致渲染异常。


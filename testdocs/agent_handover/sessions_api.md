# 会话与 SSE 接口

## 功能定位
会话层提供与前端协议一致的会话生命周期管理、事件流推送与任务终止能力，是前后端交互的核心。

## 核心端点
- `PUT /api/v1/sessions`：创建会话并初始化项目目录。
- `GET /api/v1/sessions`：获取会话列表（REST）。
- `POST /api/v1/sessions`：获取会话列表（SSE）。
- `GET /api/v1/sessions/{session_id}`：获取会话详情（含历史事件）。
- `DELETE /api/v1/sessions/{session_id}`：删除会话。
- `POST /api/v1/sessions/{session_id}/stop`：停止会话执行。
- `PATCH /api/v1/sessions/{session_id}`：重命名会话。
- `PUT /api/v1/sessions/{session_id}/cover-image`：更新封面图。
- `POST /api/v1/sessions/{session_id}/chat`：SSE 聊天主入口。
- `POST /api/v1/sessions/{session_id}/file`：读取文件（通过 Sandbox）。
- `PUT /api/v1/sessions/{session_id}/file`：保存文件（通过 Sandbox）。
- `GET /api/v1/sessions/{session_id}/generation-status`：读取生成进度（视频/游戏）。

## SSE 事件流
`/sessions/{session_id}/chat` 返回 `text/event-stream`，按事件类型推送：
- `message`、`plan`、`step`、`tool`、`decision`、`waiting`、`title`、`done`、`error`
前端根据事件类型进行分区渲染与状态更新。

## 后台任务与终止
- `BackgroundTaskManager` 负责后台任务，SSE 断开后任务仍继续。
- `AbortSignalManager` 提供停止任务的终止信号。

## 关键文件
- `backend/app/api/sessions.py`
- `backend/app/core/database.py`

## 复刻要点
- SSE 流必须支持断线重连与事件增量输出。
- `EventRepository` 中的事件结构需完全符合前端 `AgentSSEEvent`。
- 会话创建需初始化项目目录并绑定 `web_project` 路径。


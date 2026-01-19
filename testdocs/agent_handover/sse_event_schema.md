# SSE 事件格式

## 事件枚举
前端使用 `AgentSSEEvent` 定义事件结构，事件类型包括：
`tool`、`step`、`message`、`error`、`done`、`title`、`plan`、`decision`、`waiting`、`video_progress`、`game_data_progress`、`web_preview`

## 关键事件数据结构
- `message`：`{ content, role, attachments }`
- `tool`：`{ tool_call_id, name, status, function, args, content }`
- `plan`：`{ steps: StepEventData[] }`
- `decision`：`{ type, title, summary, options, status }`
- `video_progress`：视频生成进度
- `game_data_progress`：游戏资源生成进度
- `web_preview`：预览链接与描述

## 关键文件
- `frontend_unified/src/types/event.ts`
- `backend/app/api/sessions.py`
- `backend/app/services/plan_act_flow.py`

## 复刻要点
- 事件字段缺失会导致前端渲染错误。
- 新增事件类型需同时更新前后端。


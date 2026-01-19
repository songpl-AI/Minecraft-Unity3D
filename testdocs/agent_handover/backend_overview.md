# 后端总览（FastAPI + 多 Agent 工作流）

## 概述
后端提供会话管理、SSE 流式交互、项目文件生成、剧本/视频/游戏资源生成与预览服务。核心运行入口为 `backend/main.py`，在启动时完成 SQLite 初始化与 Redis 连接（可选）。

## 目录结构与职责
- `backend/main.py`：应用入口、路由注册、CORS、生命周期管理。
- `backend/app/api/`：对外 API 路由层（会话、预览、上传、视频生成等）。
- `backend/app/agent/`：核心 Agent 能力（Web 项目生成、剧本、游戏数据等）。
- `backend/app/services/`：业务流程编排（Plan-Act、StoryFlow、SandboxClient 等）。
- `backend/app/tools/`：工具层（文件操作、视频生成、TTS、决策树、上传等）。
- `backend/app/models/`：业务模型与状态（Plan、WorkflowProgress 等）。
- `backend/app/core/`：配置、数据库、Redis、异常管理。
- `backend/app/xproject/`：互动课程工作流（XProject）。
- `backend/app/services/sandbox_client.py`：沙盒服务客户端（当前为本地文件系统实现，无独立 sandbox 进程）。

## 关键能力边界
- **会话与 SSE**：统一的聊天会话模型与事件流输出（`/api/v1/sessions/*`）。
- **Web 项目生成**：Plan-Act 结合 `WebProjectAgent` 基于模板写文件。
- **剧本/互动**：StoryFlow 根据主题生成剧本与 decision-tree。
- **视频/游戏资源**：视频生成工具 + 游戏数据生成 Agent。
- **预览服务**：后端代理访问生成的项目文件。
- **沙盒**：通过 `SandboxClient` 直接操作本地文件系统（`backend/data/projects`），支持模板复制与文件读写。

## 复刻要点
- 保持 `/api/v1` 会话协议与 SSE 事件格式，前端依赖强。
- `projects` 输出目录与 `preview` 路径一致性是预览可用的核心。
- Agent 运行中需要稳定的文件读写与上传能力。

## 关键文件
- 入口与路由注册：`backend/main.py`
- 会话协议：`backend/app/api/sessions.py`
- Web 项目生成：`backend/app/services/plan_act_flow.py`
- 剧本工作流：`backend/app/services/story_flow.py`
- 沙盒客户端：`backend/app/services/sandbox_client.py`


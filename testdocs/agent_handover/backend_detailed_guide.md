# 后端详细项目说明 (Backend Detailed Guide)

## 1. 项目概述

本项目后端基于 **Python 3.10+** 和 **FastAPI** 框架构建，采用 **Agno** 框架实现多 Agent 协作系统。其核心职责是为前端提供实时对话交互（SSE）、自动化 Web 项目生成、互动视频剧本编排以及多媒体资源（视频、语音、图片）的生成服务。

## 2. 技术栈与核心依赖

| 类别 | 技术/库 | 用途 |
|------|---------|------|
| **Web 框架** | FastAPI | 高性能异步 API 服务，提供 SSE 流式响应支持 |
| **服务器** | Uvicorn | ASGI 服务器，生产环境推荐搭配 Gunicorn |
| **Agent 框架** | Agno (原 Phidata) | 驱动 Multi-Agent 系统，管理 LLM 上下文与工具调用 |
| **数据库** | SQLite (主) / Redis (选) | SQLite 存储会话与事件；Redis 用于任务队列与缓存 |
| **AI 模型** | OpenAI / Anthropic / Hunyuan | 通过 API 集成多种大模型能力 |
| **工具库** | Pillow, Rembg, MoviePy | 图像处理、抠图与视频合成 |
| **包管理** | uv (推荐) / pip | 依赖管理与虚拟环境 |

## 3. 目录结构详解

```
backend/
├── app/
│   ├── agent/              # [核心] Agent 定义层
│   │   ├── base_agent.py   # Agent 基类，封装 Agno 逻辑
│   │   ├── planning_agent.py # 规划 Agent (Plan-Act 模式)
│   │   ├── web_project_agent.py # 前端代码生成 Agent
│   │   └── ...             # 其他专用 Agent (Story, Game, etc.)
│   ├── api/                # [接口] FastAPI 路由层
│   │   ├── sessions.py     # 会话管理与 SSE 消息推送
│   │   ├── preview.py      # 静态资源代理与预览服务
│   │   └── ...             # 上传、视频生成等功能接口
│   ├── core/               # [基础] 核心配置与设施
│   │   ├── config.py       # 环境变量与应用配置
│   │   ├── database.py     # SQLite 连接与 Schema 管理
│   │   └── redis.py        # Redis 连接池
│   ├── models/             # [模型] Pydantic 数据模型
│   │   ├── schemas.py      # 通用 API 请求/响应结构
│   │   └── workflow_progress.py # 工作流状态定义
│   ├── services/           # [业务] 业务逻辑编排层
│   │   ├── manus_chat_service.py # 核心对话服务
│   │   ├── plan_act_flow.py # 规划-执行循环逻辑
│   │   ├── story_flow.py   # 互动剧本生成工作流
│   │   └── sandbox_client.py # 本地文件系统操作客户端
│   ├── tools/              # [工具] Agent 可调用的工具集
│   │   ├── file_tools.py   # 文件读写、列举、搜索
│   │   ├── video_generator_tool.py # 视频生成工具封装
│   │   └── ...             # 搜索、绘图、TTS 等工具
│   └── xproject/           # [模块] 复杂互动课程生成模块
│       ├── orchestrator/   # 协调器，管理子 Agent 协作
│       └── agents/         # 课程生成专用 Agents
├── data/                   # [存储] 运行时数据目录
│   ├── manus.db            # SQLite 数据库文件
│   └── projects/           # 用户生成的 Web 项目文件存储区
├── main.py                 # [入口] 应用启动入口
└── requirements.txt        # 依赖列表
```

## 4. 核心架构与工作流

### 4.1 会话与 SSE 消息流
后端采用 **Server-Sent Events (SSE)** 实现与前端的实时通信。
- **入口**：`POST /api/v1/sessions/{session_id}/chat`
- **流程**：
    1.  接收用户消息，存入 SQLite。
    2.  `ManusChatService` 识别意图，分发给相应的 Agent 或 Workflow。
    3.  Agent 执行过程中产生 `thinking`、`tool_call`、`message` 等事件。
    4.  所有事件通过 `StreamingResponse` 实时推送到前端，同时异步写入数据库 `events` 表以确保持久化。

### 4.2 Web 项目生成 (Plan-Act 模式)
- **核心类**：`PlanActFlow` (`app/services/plan_act_flow.py`)
- **逻辑**：
    1.  **Planning**：`PlanningAgent` 分析用户需求，生成步骤清单 (Step-by-Step Plan)。
    2.  **Acting**：`WebProjectAgent` 逐个执行步骤。
    3.  **Tool Use**：Agent 调用 `file_tools` 直接在 `data/projects/{user}/{session}/web` 目录下读写 HTML/CSS/JS 文件。
    4.  **Feedback**：每一步执行结果（如文件写入成功、报错）都会反馈给 Agent 用于自我修正。

### 4.3 互动剧本工作流 (Story Flow)
- **核心类**：`StoryFlow` (`app/services/story_flow.py`)
- **特点**：这是一个结构化的生成管线，而非单纯的自由对话。
- **阶段**：
    1.  **设定生成**：生成世界观、角色表 (Character Sheet)。
    2.  **剧本创作**：生成 Story Bible 和决策树 (Decision Tree)。
    3.  **资源生产**：并行调用图像生成 (Hunyuan/Flux)、语音合成 (TTS)、视频生成工具。
    4.  **游戏化**：生成互动小游戏逻辑并嵌入项目。

## 5. 关键服务与扩展

### 5.1 沙盒服务 (Sandbox)
当前实现为 **Local Filesystem Sandbox**。
- 代码位于 `app/services/sandbox_client.py`。
- 并不运行在 Docker 容器中，而是直接操作宿主机的 `backend/data/projects` 目录。
- **安全性提示**：在生产环境复刻时，建议将此模块替换为 Docker 容器化实现，以隔离 Agent 的文件操作权限。

### 5.2 预览服务 (Preview Proxy)
- 路由位于 `app/api/preview.py`。
- 提供对生成的静态网站 (`.html`, `.css`, `.js`) 的访问能力。
- 自动处理 MIME 类型，支持 SPA (Single Page Application) 的路由回退。

### 5.3 第三方 AI 服务集成
项目集成了多个外部 API 以增强多媒体能力（需在 `.env` 配置）：
- **Hunyuan 3D**：用于生成 3D 资产。
- **DeepDataSpace**：用于特定图像处理任务。
- **TAL MLOps**：好未来内部 AI 平台接口。

## 6. 开发与部署指南

### 6.1 环境准备
```bash
# 推荐使用 uv 管理 Python 环境
pip install uv
uv sync
# 或者使用 pip
pip install -r requirements.txt
```

### 6.2 配置文件
复制 `.env.example` 为 `.env` 并填入关键 Key：
```ini
OPENAI_API_KEY=sk-...
HUNYUAN_SECRET_ID=...
TAL_MLOPS_APP_KEY=...
```

### 6.3 启动服务
```bash
# 开发模式（带自动重载）
./start.sh
# 或
uvicorn app.main:app --reload
```

## 7. 常见问题与维护
1.  **数据库迁移**：当前使用 SQLite 自动建表，无 Alembic 迁移脚本。修改模型后需手动处理数据库文件或增加迁移逻辑。
2.  **Redis 依赖**：Redis 连接失败时系统会降级运行，但后台任务队列功能将不可用。
3.  **预览 404**：检查 `backend/data/projects` 目录下是否真实生成了文件，以及 `PREVIEW_BASE_URL` 配置是否正确。

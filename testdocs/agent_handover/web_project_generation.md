# Web 项目生成（Plan-Act）

## 功能定位
基于用户需求，自动修改模板工程，输出可预览的 Web 项目。核心使用 Plan-Act 工作流并通过工具写入文件。

## 核心流程
1. 接收用户输入（会话消息）。
2. `PlanActFlow` 创建 Agent 上下文并生成计划事件。
3. `WebProjectAgent` 读取模板、生成代码、写入文件。
4. 生成预览 URL，推送 `web_preview` / `tool` 事件。

## 关键模块
- `backend/app/services/plan_act_flow.py`
- `backend/app/agent/web_project_agent.py`
- `backend/app/tools/file_tools.py`
- `backend/app/services/sandbox_client.py`

## 关键事件
Plan-Act 会推送以下 SSE 事件：
- `plan`：步骤计划
- `tool`：文件读写、目录列表等工具事件
- `message`：最终回复
- `done`：结束

## 输入与输出
输入：用户自然语言需求  
输出：`projects/{userId}/{sessionId}/web` 目录下的可运行 Web 工程

## 复刻要点
- 工具调用必须遵循前端期望的参数结构（file / command / url）。
- 预览 URL 需与后端 `preview` 路由一致。
- 模板工程结构需要稳定，否则 Agent 输出易失效。


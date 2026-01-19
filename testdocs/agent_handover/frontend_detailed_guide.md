# 前端详细项目说明 (Frontend Detailed Guide)

## 1. 项目概述

本项目前端采用 **Vue 3** + **TypeScript** + **Vite** 技术栈构建，是一个现代化的单页应用 (SPA)。它集成了实时聊天、代码编辑器、Web 预览窗口以及多模态媒体展示功能，旨在为用户提供一个“所见即所得”的 AI 辅助开发环境。

## 2. 技术栈与核心依赖

| 类别 | 技术/库 | 用途 |
|------|---------|------|
| **核心框架** | Vue 3.3+ (Composition API) | UI 组件化开发 |
| **构建工具** | Vite 4+ | 极速开发服务器与构建打包 |
| **语言** | TypeScript | 静态类型检查，增强代码健壮性 |
| **UI 组件库** | Ant Design Vue 4 / Shadcn-vue | 基础 UI 组件 / Tailwind 风格组件 |
| **样式** | Tailwind CSS | 原子化 CSS 样式开发 |
| **编辑器** | Monaco Editor | 类似 VS Code 的代码编辑体验 |
| **通信** | @microsoft/fetch-event-source | 处理 SSE 流式响应 |
| **Markdown** | Marked | 渲染聊天中的 Markdown 内容 |
| **路由** | Vue Router 4 | 页面路由管理 |

## 3. 目录结构详解

```
frontend_unified/
├── public/                 # 静态资源 (favicon, icons)
├── src/
│   ├── api/                # [通信] API 客户端封装
│   │   ├── client.ts       # Axios 实例与拦截器
│   │   └── agent.ts        # Agent 对话相关 API
│   ├── components/         # [组件] 公共 UI 组件
│   │   ├── ui/             # Shadcn 风格基础组件 (Button, Dialog...)
│   │   ├── toolViews/      # 工具执行结果的可视化组件 (Browser, Shell)
│   │   ├── filePreviews/   # 文件预览组件 (Code, Image, Markdown)
│   │   └── MonacoEditor.vue # 代码编辑器封装
│   ├── composables/        # [逻辑] Vue Composables (Hooks)
│   │   ├── useAuth.ts      # 用户登录状态管理
│   │   ├── useChatMode.ts  # 聊天模式切换 (Auto/Step)
│   │   └── useTool.ts      # 工具调用状态管理
│   ├── config/             # [配置] 全局配置
│   │   └── sso.ts          # SSO 登录配置
│   ├── home/               # [模块] 首页 Feed 流模块 (独立性较强)
│   │   ├── pages/          # 首页、个人中心页
│   │   └── components/     # 瀑布流卡片等组件
│   ├── pages/              # [页面] 核心页面
│   │   ├── ChatPage.vue    # 主聊天界面
│   │   ├── LoginPage.vue   # 登录页
│   │   └── MainLayout.vue  # 主布局容器
│   ├── types/              # [类型] TS 类型定义
│   │   ├── message.ts      # 聊天消息类型
│   │   └── event.ts        # SSE 事件类型
│   ├── utils/              # [工具] 通用函数
│   ├── App.vue             # 根组件
│   └── main.ts             # 入口文件 (挂载 Vue, Pinia, Router)
├── .env.development        # 开发环境配置
├── vite.config.ts          # Vite 配置 (含代理设置)
└── package.json            # 依赖与脚本
```

## 4. 核心架构与功能模块

### 4.1 聊天与 SSE 事件处理
- **核心组件**：`ChatPage.vue` -> `ChatBox.vue` -> `ChatMessage.vue`
- **机制**：
    - 使用 `fetchEventSource` 连接后端 SSE 接口。
    - 监听不同类型的事件（`thinking`, `tool`, `message`）。
    - 收到事件后，实时更新 `messageList`，触发 UI 增量渲染。
    - **Markdown 渲染**：自定义 `marked` 扩展，支持代码块高亮和自定义组件嵌入。

### 4.2 工具调用可视化 (Tool Views)
当后端 Agent 调用工具时，前端会展示特定的 UI：
- **BrowserTool**：展示一个模拟的浏览器地址栏和 iframe 预览内容 (`BrowserToolView.vue`)。
- **ShellTool**：展示终端命令执行过程和输出 (`ShellToolView.vue`)。
- **FileTool**：展示文件读写操作 diff 或文件内容 (`FileToolView.vue`)。

### 4.3 实时预览系统 (Web Preview)
- **组件**：`WebPreviewPanel.vue`
- **原理**：
    - 通过 `iframe` 加载后端提供的预览 URL（如 `/api/v1/preview/...`）。
    - 利用 `postMessage` 实现父页面与 iframe 内部的通信（如页面跳转通知）。
    - 配合后端 `Sandbox`，实现代码修改后的实时刷新。

### 4.4 首页 Feed 流模块 (`src/home`)
这是从原独立项目迁移进来的模块，负责展示社区作品流。
- 包含 `WaterfallFeed` (瀑布流) 组件。
- 拥有独立的 API 请求逻辑 (`src/home/api`)，但复用根目录的 `useAuth` 进行鉴权。

## 5. 关键逻辑解析

### 5.1 认证鉴权
- 支持 **Local** (账号密码) 和 **SSO** (单点登录) 两种模式。
- 通过 `.env` 中的 `VITE_AUTH_PROVIDER` 切换。
- `useAuth.ts` 统一管理 Token 的存储（Cookie/LocalStorage）与刷新。

### 5.2 状态管理
- 本项目主要使用 **Vue Composition API (`ref`, `reactive`)** 配合 **Composables** 进行状态管理，而非重度依赖 Pinia/Vuex。
- 这种方式使得逻辑复用更加灵活，特别是在处理多个聊天会话实例时。

## 6. 开发与构建指南

### 6.1 安装与启动
```bash
cd frontend_unified
npm install
# 启动开发服务器 (默认端口 5173)
npm run dev
```

### 6.2 环境变量
- `VITE_API_URL`: 后端 API 地址（开发时通常设为 `http://localhost:8000` 或通过 Vite proxy 转发）。
- `VITE_Use_SSO`: 是否启用 SSO。

### 6.3 构建生产版本
```bash
npm run build
# 构建产物位于 dist/ 目录
```

## 7. 复刻注意事项
1.  **接口对齐**：前端对后端 SSE 事件的数据结构非常敏感，修改后端事件格式时务必同步更新 `src/types/event.ts`。
2.  **样式隔离**：`src/home` 模块的样式可能与主应用存在冲突，开发时需注意 CSS 作用域。
3.  **Monaco Editor**：代码编辑器组件体积较大，Vite 配置中已做分包处理，但在弱网环境下加载可能较慢。

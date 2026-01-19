# 前端总览（Vue 3 + Vite）

## 功能定位
前端提供会话列表、聊天界面、实时 SSE 事件渲染、工具面板与项目预览。

## 目录结构
- `frontend_unified/src/api/`：API 与 SSE 客户端
- `frontend_unified/src/pages/`：页面级组件
- `frontend_unified/src/components/`：聊天与工具 UI 组件
- `frontend_unified/src/home/`：首页 Feed 流模块（从原 frontend_home 迁移）
- `frontend_unified/src/composables/`：状态与逻辑复用
- `frontend_unified/src/types/`：事件与数据类型

## 关键入口
- 路由与应用初始化：`frontend_unified/src/main.ts`
- 聊天页：`frontend_unified/src/pages/ChatPage.vue`
- 首页：`frontend_unified/src/home/pages/HomePage.vue`（路由 `/`）

## 复刻要点
- SSE 事件结构与后端必须严格一致。
- 预览 URL 处理需与后端预览路由一致。
- 认证模式可通过环境变量切换。
- `src/home` 模块依赖根目录的 `useAuth` 与 `sso` 配置，注意路径引用。


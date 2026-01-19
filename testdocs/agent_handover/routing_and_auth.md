# 路由与认证

## 路由结构
路由集中在 `frontend_unified/src/main.ts`，采用 Hash 路由。

### 主要页面
- `/`：首页（HomeShell + Feed）
- `/chat`：会话入口（MainLayout）
- `/chat/:sessionId`：聊天页
- `/share/:sessionId`：分享页
- `/preview/:sessionId`：全屏预览
- `/login`：登录页

## 认证模式
由 `VITE_AUTH_PROVIDER` 控制：
- `none`：完全跳过鉴权
- `sso`：走 SSO 登录流程
- `local`：本地认证

## 关键模块
- `frontend_unified/src/composables/useAuth.ts`
- `frontend_unified/src/api/auth.ts`
- `frontend_unified/src/config/sso.ts`

## 复刻要点
- 认证拦截在路由守卫中处理。
- 分享页与预览页需根据权限决定是否公开。


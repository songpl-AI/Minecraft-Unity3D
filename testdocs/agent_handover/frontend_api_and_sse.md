# 前端 API 与 SSE

## API 客户端
`frontend_unified/src/api/client.ts` 提供：
- 统一请求实例（含鉴权）
- SSE 连接封装
- Token 刷新逻辑

## 会话与聊天 API
`frontend_unified/src/api/agent.ts` 负责：
- 创建/获取/删除会话
- SSE 会话列表
- SSE 聊天流
- 停止任务
- 文件查看与保存

## SSE 事件消费
聊天页通过 `createSSEConnection` 拉起流式事件，事件类型与后端保持一致。

## 关键文件
- `frontend_unified/src/api/client.ts`
- `frontend_unified/src/api/agent.ts`
- `frontend_unified/src/types/event.ts`

## 复刻要点
- SSE 断线重连逻辑很关键。
- token 刷新需对 SSE 连接生效。
- 事件类型新增需同步更新前端类型定义与渲染逻辑。


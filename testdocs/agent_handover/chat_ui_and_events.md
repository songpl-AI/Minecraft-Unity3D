# 聊天 UI 与事件流渲染

## 功能定位
聊天页负责消费 SSE 事件并渲染消息、计划步骤、工具面板与预览视图。

## 关键组件
- `ChatPage.vue`：会话主页面与事件处理
- `ChatMessage.vue`：消息渲染
- `PlanPanel.vue`：计划步骤
- `ToolPanel.vue`：工具视图
- `WebPreviewPanel.vue`：预览窗口

## 事件处理
聊天页按事件类型更新状态：
- `message`：消息气泡
- `plan`/`step`：计划与进度
- `tool`：显示工具调用
- `decision`/`waiting`：用户确认
- `video_progress`/`game_data_progress`：进度表
- `web_preview`：预览链接

## 关键文件
- `frontend_unified/src/pages/ChatPage.vue`
- `frontend_unified/src/types/event.ts`

## 复刻要点
- 事件类型扩展需同步更新组件与类型。
- 工具事件的 args 结构需与后端一致。


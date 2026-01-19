# 预览页集成

## 功能定位
将生成项目以 iframe 或独立页面方式展示，支持全屏预览与分享。

## 关键点
- 预览 URL 来自后端 `preview` 路由。
- 全屏预览页与聊天页共用预览 URL。

## 关键文件
- `frontend_unified/src/pages/FullscreenPreviewPage.vue`
- `frontend_unified/src/components/WebPreviewPanel.vue`
- `backend/app/api/preview.py`

## 复刻要点
- 预览 URL 的拼接必须与后端项目路径一致。
- 需处理跨域与资源类型的加载问题。


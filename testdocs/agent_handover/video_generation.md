# 视频生成流水线

## 功能定位
根据剧本或节点描述生成视频，并在编排中写入视频 URL。

## 核心流程
1. 创建视频生成任务
2. 轮询任务状态
3. 生成完成后获取视频 URL
4. 写回决策树节点

## 关键模块
- `backend/app/tools/video_generator_tool.py`
- `backend/app/api/video_generation.py`
- `backend/app/services/video_gen_service/*`
- `backend/app/services/story_flow.py`

## 事件与状态
前端通过 `video_progress` 事件展示生成进度。

## 复刻要点
- 提供稳定的任务创建与轮询接口。
- 生成失败需有兜底或重试策略。
- 统一的视频 URL 格式便于前端预览。


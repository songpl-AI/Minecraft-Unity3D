# 剧本与互动工作流（Story Flow）

## 功能定位
根据用户主题生成剧本、角色设定、决策树与互动内容，并在不同阶段引导用户确认。

## 关键阶段
1. `initial`：等待主题输入
2. `story_generated`：剧本生成完成，等待确认
3. `story_approved`：剧本确认完成，生成编排数据
4. `game_data_generated`：编排完成，等待确认
5. `completed`：流程完成

## 核心模块
- `backend/app/services/story_flow.py`
- `backend/app/services/story_chat_service.py`
- `backend/app/agent/story_agent.py`
- `backend/app/tools/decision_tree_tool.py`
- `backend/app/tools/character_image_tool.py`
- `backend/app/tools/intent_detector.py`

## SSE 事件
剧本流程重点事件：
- `plan`：阶段计划
- `decision`：请求用户确认
- `waiting`：等待用户确认
- `message`：流式内容
- `done`：完成

## 输出
输出到项目目录的关键文件：
- `data/story_bible.md`
- `data/decision-tree.json`
- 角色设定图与相关素材

## 复刻要点
- 意图识别必须基于当前阶段，避免流程跳跃。
- 决策树结构对视频/游戏编排至关重要。
- 预览 URL 需在事件数据中保证可访问。


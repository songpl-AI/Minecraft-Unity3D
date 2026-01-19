# 决策树与资产工具

## 功能定位
决策树负责描述剧情与视频/游戏节点编排，资产工具负责角色设定图、视频生成与资源准备。

## 关键模块
- `backend/app/tools/decision_tree_tool.py`
- `backend/app/tools/character_image_tool.py`
- `backend/app/tools/story_tools.py`
- `backend/app/agent/story_asset_agent.py`
- `backend/app/utils/oss_upload.py`

## 关键产物
- `data/decision-tree.json`
- 角色设定图与分镜图
- 节点资源链接（视频/游戏）

## 复刻要点
- 决策树结构需与前端模板保持一致。
- 资产生成需要统一风格与角色一致性。


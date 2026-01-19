# 互动课程 XProject 模块

## 功能定位
面向“多视频 + 多游戏编排”的互动课程生成流程，基于多 Agent 协作与项目写入器完成。

## 核心工作流
1. 意图解析与主题确认
2. 课程大纲生成
3. 角色设定与风格确定
4. 决策树生成与校验
5. 视频与游戏资产并行生成
6. 写入项目文件并输出预览

## 关键模块
- `backend/app/xproject/workflow.py`
- `backend/app/xproject/session_service.py`
- `backend/app/xproject/agents/*`
- `backend/app/xproject/tools/project_writer.py`
- `backend/app/xproject/tools/image_generator.py`
- `backend/app/xproject/events/*`

## 状态与恢复
- 工作流状态存入 `sessions.workflow_state`
- 大内容（outline、characters、decision-tree）存于项目文件

## 输出
项目目录结构：
- `data/outline.md`
- `data/character.json`
- `data/decision-tree.json`
- `web/`：最终前端工程

## 复刻要点
- 事件格式与前端 SSE 类型保持一致。
- workflow 恢复逻辑需要保证容错与幂等。
- project_writer 负责模板复制与文件写入，是可复刻核心。


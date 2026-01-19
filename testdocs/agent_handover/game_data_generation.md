# 游戏数据生成 Agent

## 功能定位
自动读取游戏模板 README 与 config.json，规划并生成图片与题目数据，最终写回配置。

## 关键流程
1. 读取 README 与 config.json
2. 规划任务列表（图片、数据、写入）
3. 执行图片生成与上传
4. 生成题目/文本数据
5. 更新 config.json

## 关键模块
- `backend/app/agent/game_data_agent.py`
- `backend/app/prompt/game_data.py`
- `backend/app/utils/oss_upload.py`
- `backend/app/utils/gemini_image.py`

## 任务类型
- `generate_image`：生成图片并上传
- `generate_data`：生成文本数据
- `write_config`：写入配置
- `smart_cutout`：透明背景处理（如需）

## 复刻要点
- 图片字段必须通过图片生成任务完成。
- 任务顺序必须严格遵守：图片 → 抠图 → 数据 → 写配置。
- README 规范对任务规划质量影响很大。


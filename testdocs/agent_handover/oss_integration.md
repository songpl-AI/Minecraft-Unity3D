# OSS 集成与上传

## 功能定位
提供图片与项目目录的 OSS 上传能力，并支持 OSS 目录下载与列举。

## 上传接口
### 图片上传
`POST /api/upload/image`  
用途：上传单张图片（验证类型与大小），返回 OSS URL。

### 批量图片上传
`POST /api/upload/images`  
用途：批量图片上传，返回成功与失败列表。

### 项目目录上传
`POST /api/oss/upload-project`  
用途：将指定项目的 `web` 目录上传到 OSS。

## 下载接口
`/api/oss/download/*`  
用途：列出或下载远端 OSS 目录到本地下载目录。

## 关键模块
- `backend/app/api/upload.py`
- `backend/app/api/oss_project.py`
- `backend/app/api/oss_download.py`
- `backend/app/utils/oss_upload.py`

## 第三方服务集成（Config）
除基础 OSS 外，项目还集成了以下核心 AI 服务（配置位于 `backend/app/core/config.py`）：
- **Hunyuan 3D**：腾讯混元 3D 生成服务 (`HUNYUAN_*`)。
- **DeepDataSpace**：深度数据空间服务 (`DEEPDATASPACE_*`)。
- **TAL MLOps**：好未来 AI 平台服务 (`TAL_MLOPS_*`)。

## 复刻要点
- 上传与下载需要正确配置 OSS 访问密钥（务必放在环境变量）。
- URL 与路径前缀要与前端资源访问规则一致。
- 确保上述第三方服务的 API Key 已在 `.env` 中正确配置，否则相关生成工具将失败。


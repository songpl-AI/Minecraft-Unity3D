# Unity 运行时 3D 模型加载方案技术文档

## 1. 方案背景
本项目需要在 Unity 运行时动态加载外部的 3D 模型文件（.obj 格式）。由于 Unity 原生不支持运行时直接加载 OBJ 文件，因此需要自行实现解析和加载逻辑。本方案通过 C# 脚本手动解析 OBJ 和 MTL 文件，并支持纹理贴图的自动关联。

## 2. 当前实现方案 (Prototype)

### 2.1 核心脚本
*   **RuntimeObjImporter.cs**: 核心解析类。
    *   **功能**: 解析 OBJ 文本内容，构建 Unity Mesh 对象（顶点、法线、UV、面）。
    *   **特性**: 
        *   支持 OBJ 文件解析，识别 `v`, `vt`, `vn`, `f` 指令。
        *   支持识别 `mtllib` 指令，返回关联的 MTL 文件名。
        *   坐标系转换（OBJ 右手系 -> Unity 左手系）。
*   **WebObjLoader.cs**: 加载与控制类。
    *   **功能**: 处理下载流程（HTTP/File 协议），协调 OBJ、MTL 和纹理的加载顺序。
    *   **特性**:
        *   支持 `http://`, `https://`, `file://` 协议。
        *   **全自动模式**: `OBJ` -> `MTL` -> `Texture` 自动追溯加载。
        *   **手动模式**: 允许用户强制指定贴图 URL，覆盖 MTL 设置。
        *   **本地测试支持**: 自动处理本地路径前缀，方便调试。

### 2.2 使用指南
1.  **场景设置**: 创建空物体挂载 `WebObjLoader`。
2.  **参数配置**:
    *   `Obj Url`: 模型文件地址（必填）。
    *   `Texture Url`: 贴图地址（选填，填入后将忽略 MTL 中的贴图设置）。
    *   `Auto Rotate`: 是否开启预览旋转。

### 2.3 已知局限性
*   **性能**: 纯文本解析（String Parsing）效率低，大模型（>5万顶点）会引起卡顿。
*   **功能**: 仅支持基础漫反射贴图（Diffuse Map），不支持法线、高光、透明度等高级材质效果。
*   **多材质**: 目前会将所有子网格合并为一个 Mesh，不支持多材质分离。

---

## 3. 生产环境最佳实践 (Best Practices)

在商业级项目或对性能有要求的场景中，建议采用以下方案替代当前的文本解析方案。

### 3.1 推荐方案：glTF / GLB 标准
**glTF (GL Transmission Format)** 是目前 3D 领域的“JPEG”，专为运行时高效传输和加载设计。

#### 为什么 glTF 优于 OBJ？
在 Unity 运行时加载场景下，glTF 几乎在所有方面都完胜 OBJ：

| 特性 | OBJ (文本格式) | glTF / GLB (二进制/JSON) |
| :--- | :--- | :--- |
| **加载速度** | **慢** (需逐行文本解析，高 CPU 消耗) | **极快** (二进制直接映射 GPU 内存，快 10-50 倍) |
| **文件体积** | 大，且文件分散 (obj+mtl+贴图) | 小，支持 Draco 压缩，GLB 可单文件打包 |
| **PBR 材质** | 不支持 (仅基础漫反射) | **原生支持** (金属度、粗糙度、AO) |
| **高级特性** | 不支持 | 支持骨骼动画、层级结构、多 UV、光照贴图 |
| **适用场景** | 编辑器间数据交换、简单几何体 | **运行时发布 (Runtime Delivery)**、商业项目 |

*   **优势**:
    *   **二进制格式 (GLB)**: 文件体积小，无需文本解析，加载速度极快。
    *   **标准化**: 原生支持 PBR 材质、多节点层级、骨骼动画。
    *   **生态**: Unity 有成熟的高性能加载库（如 [glTFast](https://github.com/atteneder/glTFast)）。

### 3.2 替代方案：AssetBundle
Unity 官方的资源包格式。
*   **适用场景**: 资源完全由开发团队内部控制，走 Unity 编辑器打包流程。
*   **优势**: 性能最好，兼容性最强。
*   **劣势**: 无法加载用户上传的原始模型，版本兼容性要求高。

---

## 4. OBJ 转 glTF 转换方案

为了实现最佳实践，建议搭建**后端转换服务**，将用户上传的 OBJ 自动转换为 glTF/GLB，客户端只加载转换后的文件。

### 4.1 常用命令行工具 (CLI Tools)

以下工具可部署在服务器（Node.js / Python 环境）上进行自动化转换：

#### A. obj2gltf (推荐)
由 Cesium 团队开发，基于 Node.js，专门用于将 OBJ 转换为 glTF/GLB。
*   **GitHub**: [https://github.com/CesiumGS/obj2gltf](https://github.com/CesiumGS/obj2gltf)
*   **安装**: `npm install -g obj2gltf`
*   **用法**:
    ```bash
    # 基础转换
    obj2gltf -i model.obj -o model.glb

    # 包含材质（如果 obj 和 mtl 在同一目录，通常会自动识别）
    obj2gltf -i model.obj -o model.glb --unlit
    ```

#### B. Blender (Headless Mode)
利用 Blender 强大的导入导出功能，通过命令行无头模式运行转换脚本。
*   **优势**: 兼容性最强，支持各种复杂格式（FBX, DAE, BLEND 等）转 glTF。
*   **用法**:
    ```bash
    blender --background --python convert_script.py -- model.obj output.glb
    ```

#### C. Assimp (Open Asset Import Library)
C++ 库，也有各种语言的绑定和命令行工具。
*   **优势**: 支持格式极其丰富。
*   **劣势**: 生成的 glTF 有时不如 obj2gltf 规范。

### 4.2 架构建议
1.  **上传**: 用户上传 `model.obj`, `model.mtl`, `texture.png` 到服务器。
2.  **转换**: 服务器触发 `obj2gltf` 命令，生成 `model.glb`。
3.  **下载**: Unity 客户端使用 `glTFast` 插件加载 `model.glb`。

---

## 5. 总结
*   **开发/原型阶段**: 继续使用当前的 `WebObjLoader` 脚本，无需额外依赖，快速验证。
*   **生产/发布阶段**: 强烈建议引入后端转换流程（OBJ -> GLB），并升级客户端加载器为 glTF 专用加载器，以确保性能和稳定性。

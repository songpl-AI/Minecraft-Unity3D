using System.Collections;
using System.Collections.Generic;
using UnityEngine;

/// <summary>
/// 相机飞行脚本 - 让相机持续向前飞行
/// 
/// 【设计原理】
/// - 简单的自动飞行：每帧沿相机前方移动固定距离
/// - 无输入控制：完全自动化
/// 
/// 【用途】
/// - 演示/预览模式：自动浏览地形
/// - 调试工具：快速查看远处地形生成
/// - 电影镜头：录制宣传视频
/// 
/// 【使用方法】
/// 1. 将此脚本附加到相机或任何物体
/// 2. 调整speed参数控制飞行速度
/// 3. 旋转物体改变飞行方向
/// 
/// 注意：通常不与PlayerMovement同时使用
/// </summary>
public class CamFly : MonoBehaviour
{
    [Header("飞行参数")]
    public float speed = 100;  // 飞行速度（单位/秒）

    void Start()
    {
        // 无需初始化
    }

    /// <summary>
    /// 每帧更新：持续向前移动
    /// </summary>
    void Update()
    {
        // 【持续前进】
        // transform.position: 当前位置
        // transform.forward: 物体的前方向（蓝色Z轴）
        // speed * Time.deltaTime: 每秒移动speed个单位，帧率无关
        // 
        // 运动方程：position = position + direction * speed * time
        transform.position = transform.position + transform.forward * speed * Time.deltaTime;
    }
}

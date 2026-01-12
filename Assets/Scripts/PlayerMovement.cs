using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

/// <summary>
/// 玩家移动控制器 - 处理第一人称角色的移动和跳跃
/// 
/// 【设计原理】
/// - 使用Unity的CharacterController组件，提供胶囊碰撞体和内置移动功能
/// - 物理模拟：自定义重力系统，模拟真实的下落和跳跃抛物线
/// - 地面检测：使用球形检测判断是否着地，防止空中跳跃
/// 
/// 【控制方案】
/// - WASD/方向键：平面移动
/// - 空格键：跳跃（仅在地面时有效）
/// - 移动方向基于相机朝向（transform.right和transform.forward）
/// 
/// 【物理参数说明】
/// - speed: 移动速度（单位/秒）
/// - jumpHeight: 跳跃高度（通过动能公式反算初速度）
/// - gravity: 重力加速度（负值表示向下）
/// 
/// 【架构位置】
/// Input → PlayerMovement → CharacterController → 物理系统
/// </summary>
public class PlayerMovement : MonoBehaviour
{
    [Header("移动参数")]
    public float speed = 6.0f;           // 移动速度
    public float jumpSpeed = 8.0f;       // 跳跃初速度（注：当前未使用，由jumpHeight计算）
    public float gravity = -9.8f;        // 重力加速度（约为地球重力）
    public float jumpHeight = 3f;        // 跳跃高度（米）
    
    [Header("地面检测")]
    public Transform groundCheck;        // 地面检测点（通常是玩家脚下的空物体）
    public float groundDistance = .4f;   // 检测球体半径
    public LayerMask groundMask;         // 地面层级遮罩（只检测特定层）

    // 私有变量
    private Vector3 velocity;            // 当前速度向量（主要用于Y轴的垂直速度）
    private CharacterController controller;  // 角色控制器组件引用
    private bool isGrounded;             // 是否在地面上

    /// <summary>
    /// 初始化：获取CharacterController组件
    /// </summary>
    void Start()
    {
        controller = GetComponent<CharacterController>();
    }

    /// <summary>
    /// 每帧更新：处理移动、跳跃和重力
    /// </summary>
    void Update()
    {
        // 【地面检测】使用Physics.CheckSphere进行球形检测
        // 原理：在groundCheck位置创建一个球体，检测是否与地面层碰撞
        // 优势：比射线检测更稳定，不会因为地形凹凸导致误判
        isGrounded = Physics.CheckSphere(groundCheck.position, groundDistance, groundMask);

        // 【着地处理】如果在地面且正在下落，重置垂直速度
        // 为什么是-2而不是0：保持一个小的向下力，确保持续与地面接触
        // 防止在斜坡上"漂浮"
        if(isGrounded && velocity.y < 0)
        {
            velocity.y = -2f;
        }

        // 【输入获取】
        // GetAxis返回-1到1的平滑值（带缓动）
        // Horizontal: A/D键或左/右方向键
        // Vertical: W/S键或上/下方向键
        float horizontal = Input.GetAxis("Horizontal");
        float vertical = Input.GetAxis("Vertical");

        // 【移动方向计算】
        // 基于相机朝向的相对移动（第一人称标准做法）
        // transform.right: 角色的右方向（X轴）
        // transform.forward: 角色的前方向（Z轴）
        // 组合成最终的移动方向（水平面上的向量）
        Vector3 moveDirection = transform.right * horizontal + transform.forward * vertical;

        // 【水平移动】应用移动
        // Time.deltaTime: 帧时间，确保移动速度与帧率无关
        controller.Move(moveDirection * speed * Time.deltaTime);

        // 【跳跃处理】
        // GetButtonDown: 按键按下的瞬间（单次触发，不连续）
        // 必须同时满足：1.按下跳跃键 2.在地面上
        if(Input.GetButtonDown("Jump") && isGrounded)
        {
            // 【跳跃物理公式】根据期望跳跃高度计算初速度
            // 公式推导：v² = 2gh（动能定理）
            // v = √(2 * g * h)
            // 其中：h是jumpHeight，g是gravity的绝对值
            velocity.y = Mathf.Sqrt(jumpHeight * -2 * gravity);
        }

        // 【重力应用】每帧累加重力加速度
        // 模拟真实的自由落体运动：v = v₀ + at
        // 在跳跃后，速度会逐渐减小，到达顶点后变为负值（下落）
        velocity.y += gravity * Time.deltaTime;
        
        // 【垂直移动】应用垂直速度
        // 与水平移动分开处理，方便控制跳跃和重力
        controller.Move(velocity * Time.deltaTime);
    }
}

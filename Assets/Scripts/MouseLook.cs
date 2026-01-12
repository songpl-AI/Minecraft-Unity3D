using System.Collections;
using System.Collections.Generic;
using UnityEngine;

/// <summary>
/// 鼠标视角控制器 - 实现第一人称视角的鼠标观察
/// 
/// 【设计原理】
/// - 双轴旋转系统：
///   * X轴旋转（上下看）：旋转相机，限制在-90°到90°避免翻转
///   * Y轴旋转（左右看）：旋转玩家身体，无限制
/// - 分离旋转：相机和玩家身体独立旋转，实现自然的第一人称视角
/// - 鼠标锁定：锁定光标到屏幕中心，隐藏光标，提供沉浸式体验
/// 
/// 【数学原理】
/// - 使用欧拉角（Euler Angles）进行旋转
/// - 四元数（Quaternion）存储最终旋转，避免万向节死锁
/// - 鼠标增量 * 灵敏度 * 帧时间 = 旋转角度增量
/// 
/// 【平台差异处理】
/// - 编辑器模式：更高灵敏度（400）方便调试
/// - 构建版本：较低灵敏度（180）更适合游戏体验
/// 
/// 【架构位置】
/// 鼠标输入 → MouseLook → Camera旋转 + PlayerBody旋转
/// </summary>
public class MouseLook : MonoBehaviour
{
    [Header("鼠标参数")]
    public float mouseSensitivity = 1;   // 鼠标灵敏度（会在Start中覆盖）

    [Header("引用")]
    public Transform playerBody;         // 玩家身体的Transform（用于左右旋转）

    // 私有变量
    private float xRotation = 0f;        // 累计的X轴旋转角度（上下看）
    
    /// <summary>
    /// 初始化：设置光标状态和灵敏度
    /// </summary>
    void Start()
    {
        // 【光标锁定】提供沉浸式FPS体验
        // Locked模式：光标锁定在屏幕中心，移动鼠标只产生增量，不移动光标位置
        Cursor.lockState = CursorLockMode.Locked;
        Cursor.visible = false;  // 隐藏光标图标

        // 【灵敏度设置】根据运行环境调整
        mouseSensitivity = 180;

        // 在编辑器中使用更高的灵敏度（方便快速查看场景）
        if(Application.isEditor)
            mouseSensitivity = 400;
    }

    float mx;  // 备用变量（原本可能用于FixedUpdate，当前未使用）

    /// <summary>
    /// 每帧更新：处理鼠标输入并应用旋转
    /// </summary>
    void Update()
    {
        // 【输入获取】
        // GetAxis("Mouse X/Y"): 获取鼠标移动增量（不是绝对位置）
        // * mouseSensitivity: 应用灵敏度
        // * Time.deltaTime: 帧时间补偿，使旋转速度与帧率无关
        float mouseX = Input.GetAxis("Mouse X") * mouseSensitivity * Time.deltaTime;
        float mouseY = Input.GetAxis("Mouse Y") * mouseSensitivity * Time.deltaTime;

        // 【异常输入过滤】
        // 防止极端鼠标移动（可能是：切回窗口、多显示器切换、输入设备故障）
        // 如果单帧移动超过20度，忽略此帧输入
        if(Mathf.Abs(mouseX) > 20 || Mathf.Abs(mouseY) > 20)
            return;

        // 【上下视角旋转（Pitch）】
        // 相机的X轴旋转（绕水平轴旋转）
        // 
        // 注意负号：鼠标向上移动（mouseY>0）→ 视角向上（xRotation减小）
        // 这符合FPS游戏的直觉（推鼠标远离自己=看上方）
        xRotation -= mouseY;
        
        // 【角度限制】防止视角翻转
        // -90°（看正下方）到 90°（看正上方）
        // 不限制会导致视角翻转180度（不自然）
        xRotation = Mathf.Clamp(xRotation, -90f, 90f);

        // 【应用相机旋转】
        // Quaternion.Euler: 将欧拉角转换为四元数
        // localRotation: 相对于父物体的旋转（相机相对于玩家身体）
        // (xRotation, 0, 0): 只旋转X轴，Y和Z保持为0
        transform.localRotation = Quaternion.Euler(xRotation, 0, 0);

        // 【左右视角旋转（Yaw）】
        // 玩家身体的Y轴旋转（绕垂直轴旋转）
        // 
        // Vector3.up: 世界坐标系的上方向（0,1,0）
        // Rotate: 累加旋转，而不是设置绝对角度
        // 无角度限制：可以360度自由旋转
        playerBody.Rotate(Vector3.up * mouseX);

        // 以下是废弃代码（可能是早期尝试用Rigidbody实现旋转）
        // 保留作为参考，说明为什么不用这些方法：
        // 1. Rigidbody旋转会受物理引擎影响，不适合精确的相机控制
        // 2. CharacterController + Transform.Rotate 更适合第一人称控制
        
        //playerBody.GetComponent<Rigidbody>().rotation *= Quaternion.Euler(0, mouseX, 0);
        //playerBody.GetComponent<Rigidbody>().MoveRotation *= Quaternion.Euler(0, mouseX, 0);
        //transform.localRotation = Quaternion.Euler(transform.rotation.eulerAngles.x + mouseY,0, 0);
        //playerBody.rotation = Quaternion.Euler(0,playerBody.rotation.eulerAngles.y + mouseX,0);
    }

    /// <summary>
    /// 固定时间步更新（当前未使用）
    /// 原本可能计划在物理帧中处理旋转，但最终采用了Update方案
    /// </summary>
    private void FixedUpdate()
    {
        //float mouseX = mx * mouseSensitivity * Time.fixedDeltaTime;

       // playerBody.GetComponent<Rigidbody>().MoveRotation(playerBody.GetComponent<Rigidbody>().rotation *= Quaternion.Euler(0, mouseX, 0));
    }
}

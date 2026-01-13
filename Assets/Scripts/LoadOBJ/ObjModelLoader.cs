using UnityEngine;

/// <summary>
/// 加载Resources目录下的OBJ模型并进行预览
/// </summary>
public class ObjModelLoader : MonoBehaviour
{
    [Header("配置")]
    [Tooltip("Resources目录下的模型文件名（不带扩展名）")]
    public string modelName = "decimated_1768202429";

    [Tooltip("加载后的模型缩放")]
    public Vector3 modelScale = Vector3.one;

    [Tooltip("是否自动旋转预览")]
    public bool autoRotate = true;

    [Tooltip("旋转速度")]
    public float rotateSpeed = 30f;

    private GameObject currentModel;

    void Start()
    {
        LoadModel();
    }

    void Update()
    {
        if (autoRotate && currentModel != null)
        {
            currentModel.transform.Rotate(Vector3.up * rotateSpeed * Time.deltaTime);
        }
    }

    /// <summary>
    /// 加载模型的方法
    /// </summary>
    public void LoadModel()
    {
        if (string.IsNullOrEmpty(modelName))
        {
            Debug.LogError("模型名称为空！");
            return;
        }

        // 从Resources加载
        // 注意：文件需要在Assets/Resources目录下，且加载时不需要后缀名
        GameObject modelPrefab = Resources.Load<GameObject>(modelName);

        if (modelPrefab == null)
        {
            Debug.LogError($"无法在Resources目录下找到模型: {modelName}");
            return;
        }

        // 如果之前有模型，先销毁
        if (currentModel != null)
        {
            Destroy(currentModel);
        }

        // 实例化模型
        currentModel = Instantiate(modelPrefab, transform.position, transform.rotation);
        
        // 设置父节点，方便管理
        currentModel.transform.SetParent(transform);
        currentModel.transform.localScale = modelScale;
        
        // 确保模型位置归零（相对于父节点）
        currentModel.transform.localPosition = Vector3.zero;
        
        Debug.Log($"成功加载模型: {modelName}");
    }
}

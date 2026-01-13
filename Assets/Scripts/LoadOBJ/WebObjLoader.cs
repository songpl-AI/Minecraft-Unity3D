using UnityEngine;
using UnityEngine.Networking;
using System.Collections;

public class WebObjLoader : MonoBehaviour
{
    [Header("Web Settings")]
    [Tooltip("The URL of the .obj file to download. Supports http://, https://, and file://")]
    // Local path example: "file:///Users/tal/Downloads/decimated_1768202429.obj"
    public string objUrl = "file:///Users/tal/Downloads/decimated_1768202429.obj"; 
    
    [Tooltip("Optional: URL/Path of the texture file (png/jpg). Supports file:// for local files.")]
    public string textureUrl = "";

    [Header("Display Settings")]
    public Material defaultMaterial;
    public bool autoRotate = true;
    public float rotateSpeed = 30f;
    public Vector3 modelScale = Vector3.one;

    private GameObject currentModel;

    void Start()
    {
        if (defaultMaterial == null)
        {
            // Create a simple standard material if none assigned
            defaultMaterial = new Material(Shader.Find("Standard"));
            defaultMaterial.color = Color.white;
        }
        
        // Start download automatically on start for testing
        // You can also call LoadModelFromUrl() publicly
        LoadModelFromUrl(objUrl, textureUrl);
    }

    void Update()
    {
        if (autoRotate && currentModel != null)
        {
            currentModel.transform.Rotate(Vector3.up * rotateSpeed * Time.deltaTime);
        }
    }

    public void LoadModelFromUrl(string url, string texUrl = "")
    {
        if (string.IsNullOrEmpty(url))
        {
            Debug.LogError("URL is empty!");
            return;
        }

        url = FixUrl(url);
        
        if (!string.IsNullOrEmpty(texUrl))
        {
            texUrl = FixUrl(texUrl);
        }
        
        StartCoroutine(DownloadAndLoad(url, texUrl));
    }
    
    private string FixUrl(string url)
    {
        // Smart handling for local paths:
        // If it looks like a local absolute path (starts with / on Mac/Linux or X: on Windows) 
        // and doesn't have a protocol, add file://
        if (!url.Contains("://"))
        {
            if (url.StartsWith("/") || (url.Length > 1 && url[1] == ':'))
            {
                url = "file://" + url;
                Debug.Log($"Auto-prefixed local path with file:// -> {url}");
            }
        }
        return url;
    }

    private IEnumerator DownloadAndLoad(string url, string texUrl)
    {
        Debug.Log($"Starting download from: {url}");
        
        // 1. Download OBJ
        string objContent = null;
        using (UnityWebRequest webRequest = UnityWebRequest.Get(url))
        {
            yield return webRequest.SendWebRequest();

            if (webRequest.result != UnityWebRequest.Result.Success)
            {
                Debug.LogError($"Error downloading OBJ: {webRequest.error}");
                yield break;
            }
            objContent = webRequest.downloadHandler.text;
        }

        // 2. Download Texture (if provided)
        Texture2D texture = null;
        if (!string.IsNullOrEmpty(texUrl))
        {
            Debug.Log($"Starting texture download from: {texUrl}");
            using (UnityWebRequest texRequest = UnityWebRequestTexture.GetTexture(texUrl))
            {
                yield return texRequest.SendWebRequest();

                if (texRequest.result != UnityWebRequest.Result.Success)
                {
                    Debug.LogWarning($"Error downloading Texture: {texRequest.error}");
                }
                else
                {
                    texture = DownloadHandlerTexture.GetContent(texRequest);
                }
            }
        }

        // 3. Process and Build
        try 
        {
            Debug.Log("Parsing OBJ...");
            Mesh mesh = RuntimeObjImporter.Import(objContent);
            mesh.name = "DownloadedMesh";
            
            // Create GameObject
            CreateModelObject(mesh, texture);
            Debug.Log("Model loaded successfully!");
        }
        catch (System.Exception e)
        {
            Debug.LogError($"Failed to parse OBJ: {e.Message}\n{e.StackTrace}");
        }
    }

    private void CreateModelObject(Mesh mesh, Texture2D texture)
    {
        // Cleanup old model
        if (currentModel != null)
        {
            Destroy(currentModel);
        }

        currentModel = new GameObject("WebModel");
        currentModel.transform.SetParent(transform);
        currentModel.transform.localPosition = Vector3.zero;
        currentModel.transform.localScale = modelScale;
        currentModel.transform.localRotation = Quaternion.identity;

        MeshFilter mf = currentModel.AddComponent<MeshFilter>();
        mf.mesh = mesh;

        MeshRenderer mr = currentModel.AddComponent<MeshRenderer>();
        // Create a new instance of material so we don't modify the asset
        Material mat = new Material(defaultMaterial);
        
        if (texture != null)
        {
            mat.mainTexture = texture;
            Debug.Log("Texture applied to material.");
        }
        
        mr.material = mat;
    }
}

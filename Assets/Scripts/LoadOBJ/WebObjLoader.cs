using UnityEngine;
using UnityEngine.Networking;
using System.Collections;
using System.IO;

public class WebObjLoader : MonoBehaviour
{
    [Header("Web Settings")]
    [Tooltip("The URL of the .obj file to download. Supports http://, https://, and file://")]
    // Local path example: "file:///Users/tal/Downloads/decimated_1768202429.obj"
    // Test Cube: "file:///Users/tal/Documents/AIProjects/Minecraft-Unity3D/LocalTestAssets/cube.obj"
    public string objUrl = "file:///Users/tal/Documents/AIProjects/Minecraft-Unity3D/LocalTestAssets/cube.obj"; 
    
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

        // 2. Parse OBJ and check for MTL
        LoadedObjData loadedData = null;
        try 
        {
            Debug.Log("Parsing OBJ...");
            loadedData = RuntimeObjImporter.Import(objContent);
        }
        catch (System.Exception e)
        {
            Debug.LogError($"Failed to parse OBJ: {e.Message}\n{e.StackTrace}");
            yield break;
        }

        // 3. Handle Material/Texture
        // Priority: 
        // 1. User provided textureUrl (Override)
        // 2. MTL file referenced in OBJ (if exists)
        // 3. Default white material
        
        Texture2D finalTexture = null;

        // Case A: User manually provided a texture URL
        if (!string.IsNullOrEmpty(texUrl))
        {
            Debug.Log($"Using manual texture override: {texUrl}");
            yield return DownloadTexture(texUrl, (tex) => finalTexture = tex);
        }
        // Case B: Try to load MTL if exists and no manual texture provided
        else if (!string.IsNullOrEmpty(loadedData.mtlFileName))
        {
            Debug.Log($"Found MTL reference: {loadedData.mtlFileName}");
            
            // Construct MTL URL based on OBJ URL base path
            string baseUrl = url.Substring(0, url.LastIndexOf('/') + 1);
            string mtlUrl = baseUrl + loadedData.mtlFileName;
            
            string mtlContent = null;
            using (UnityWebRequest mtlRequest = UnityWebRequest.Get(mtlUrl))
            {
                yield return mtlRequest.SendWebRequest();
                if (mtlRequest.result == UnityWebRequest.Result.Success)
                {
                    mtlContent = mtlRequest.downloadHandler.text;
                }
                else
                {
                    Debug.LogWarning($"Could not download MTL file at {mtlUrl}: {mtlRequest.error}");
                }
            }

            if (!string.IsNullOrEmpty(mtlContent))
            {
                // Simple MTL parsing to find texture map
                string textureFileName = ParseTextureFromMtl(mtlContent);
                if (!string.IsNullOrEmpty(textureFileName))
                {
                    Debug.Log($"Found texture in MTL: {textureFileName}");
                    string textureUrl = baseUrl + textureFileName;
                    yield return DownloadTexture(textureUrl, (tex) => finalTexture = tex);
                }
            }
        }

        // 4. Build Model
        CreateModelObject(loadedData.mesh, finalTexture);
        Debug.Log("Model loaded successfully!");
    }

    private IEnumerator DownloadTexture(string url, System.Action<Texture2D> onSuccess)
    {
        using (UnityWebRequest texRequest = UnityWebRequestTexture.GetTexture(url))
        {
            yield return texRequest.SendWebRequest();

            if (texRequest.result != UnityWebRequest.Result.Success)
            {
                Debug.LogWarning($"Error downloading Texture: {texRequest.error}");
            }
            else
            {
                onSuccess?.Invoke(DownloadHandlerTexture.GetContent(texRequest));
            }
        }
    }

    private string ParseTextureFromMtl(string mtlContent)
    {
        // Very basic MTL parser looking for map_Kd
        string[] lines = mtlContent.Split(new char[] { '\n', '\r' }, System.StringSplitOptions.RemoveEmptyEntries);
        foreach (string line in lines)
        {
            string l = line.Trim();
            if (l.StartsWith("map_Kd"))
            {
                string[] parts = l.Split(new char[] { ' ' }, System.StringSplitOptions.RemoveEmptyEntries);
                if (parts.Length > 1)
                {
                    return parts[1]; // Return the texture filename
                }
            }
        }
        return null;
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
        mesh.name = "DownloadedMesh";

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

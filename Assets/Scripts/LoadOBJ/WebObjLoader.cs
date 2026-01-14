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

    public string mtlUrl = "";

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
        LoadModelFromUrl(objUrl, textureUrl, mtlUrl);
    }

    void Update()
    {
        if (autoRotate && currentModel != null)
        {
            currentModel.transform.Rotate(Vector3.up * rotateSpeed * Time.deltaTime);
        }
    }

    public void LoadModelFromUrl(string url, string texUrl = "", string mtlUrl = "")
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

        if (!string.IsNullOrEmpty(mtlUrl))
        {
            mtlUrl = FixUrl(mtlUrl);
        }
        
        StartCoroutine(DownloadAndLoad(url, texUrl, mtlUrl));
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

    private IEnumerator DownloadAndLoad(string url, string texUrl, string manualMtlUrl)
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
        // 1. User provided textureUrl (Override texture)
        // 2. User provided mtlUrl (Parse for texture/color)
        // 3. MTL file referenced in OBJ (Parse for texture/color)
        
        Texture2D finalTexture = null;
        Color? finalColor = null;

        // Determine which MTL URL to use
        string targetMtlUrl = manualMtlUrl;
        if (string.IsNullOrEmpty(targetMtlUrl) && !string.IsNullOrEmpty(loadedData.mtlFileName))
        {
            // Construct MTL URL based on OBJ URL base path
            string baseUrl = url.Substring(0, url.LastIndexOf('/') + 1);
            targetMtlUrl = baseUrl + loadedData.mtlFileName;
            Debug.Log($"Found MTL reference in OBJ: {loadedData.mtlFileName} -> {targetMtlUrl}");
        }

        // If we have an MTL URL, try to download and parse it
        if (!string.IsNullOrEmpty(targetMtlUrl))
        {
            string mtlContent = null;
            using (UnityWebRequest mtlRequest = UnityWebRequest.Get(targetMtlUrl))
            {
                yield return mtlRequest.SendWebRequest();
                if (mtlRequest.result == UnityWebRequest.Result.Success)
                {
                    mtlContent = mtlRequest.downloadHandler.text;
                }
                else
                {
                    Debug.LogWarning($"Could not download MTL file at {targetMtlUrl}: {mtlRequest.error}");
                }
            }

            if (!string.IsNullOrEmpty(mtlContent))
            {
                MtlData mtlData = ParseMtl(mtlContent);
                
                // If we found a color, use it
                if (mtlData.diffuseColor.HasValue)
                {
                    finalColor = mtlData.diffuseColor.Value;
                }

                // If we found a texture map in MTL, and user didn't override it manually
                if (!string.IsNullOrEmpty(mtlData.textureFileName) && string.IsNullOrEmpty(texUrl))
                {
                    Debug.Log($"Found texture in MTL: {mtlData.textureFileName}");
                    // Assume texture is relative to MTL/OBJ
                    string baseUrl = targetMtlUrl.Substring(0, targetMtlUrl.LastIndexOf('/') + 1);
                    string textureUrl = baseUrl + mtlData.textureFileName;
                    yield return DownloadTexture(textureUrl, (tex) => finalTexture = tex);
                }
            }
        }

        // If user manually provided a texture URL, it overrides everything or fills in the gap
        if (!string.IsNullOrEmpty(texUrl))
        {
            Debug.Log($"Using manual texture override: {texUrl}");
            yield return DownloadTexture(texUrl, (tex) => finalTexture = tex);
        }

        // 4. Build Model
        CreateModelObject(loadedData.mesh, finalTexture, finalColor);
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

    private class MtlData
    {
        public string textureFileName;
        public Color? diffuseColor;
    }

    private MtlData ParseMtl(string mtlContent)
    {
        MtlData data = new MtlData();
        string[] lines = mtlContent.Split(new char[] { '\n', '\r' }, System.StringSplitOptions.RemoveEmptyEntries);
        
        foreach (string line in lines)
        {
            string l = line.Trim();
            if (l.StartsWith("map_Kd"))
            {
                string[] parts = l.Split(new char[] { ' ' }, System.StringSplitOptions.RemoveEmptyEntries);
                if (parts.Length > 1)
                {
                    data.textureFileName = parts[1];
                }
            }
            else if (l.StartsWith("Kd"))
            {
                // Format: Kd r g b (0-1 range)
                string[] parts = l.Split(new char[] { ' ' }, System.StringSplitOptions.RemoveEmptyEntries);
                if (parts.Length >= 4)
                {
                    if (float.TryParse(parts[1], System.Globalization.NumberStyles.Float, System.Globalization.CultureInfo.InvariantCulture, out float r) &&
                        float.TryParse(parts[2], System.Globalization.NumberStyles.Float, System.Globalization.CultureInfo.InvariantCulture, out float g) &&
                        float.TryParse(parts[3], System.Globalization.NumberStyles.Float, System.Globalization.CultureInfo.InvariantCulture, out float b))
                    {
                        data.diffuseColor = new Color(r, g, b);
                    }
                }
            }
        }
        return data;
    }

    private void CreateModelObject(Mesh mesh, Texture2D texture, Color? color)
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

        if (color.HasValue)
        {
            mat.color = color.Value;
            Debug.Log($"Color applied to material: {color.Value}");
        }
        
        mr.material = mat;
    }
}

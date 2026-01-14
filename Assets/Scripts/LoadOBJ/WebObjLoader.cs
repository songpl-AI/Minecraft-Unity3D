using UnityEngine;
using UnityEngine.Networking;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.IO.Compression;
using System.Linq;

public class WebObjLoader : MonoBehaviour
{
    [Header("Web Settings")]
    [Tooltip("The URL of the .zip file to download. Contains .obj, .mtl and textures. Overrides objUrl.")]
    public string zipUrl = "";

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
    [Tooltip("If true, renders both sides of the faces (Cull Off). Useful for models with inverted normals or single-plane geometry.")]
    public bool doubleSided = false;

    [Tooltip("If true, flips the V coordinate of UVs (1-v). Try toggling this if texture is upside down.")]
    public bool flipUV = false;

    [Tooltip("If true, reverses the triangle vertex order. Try toggling this if normals look inside-out or lighting is wrong.")]
    public bool flipFaces = true;

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
        
        // Priority: 1. Zip, 2. Obj
        if (!string.IsNullOrEmpty(zipUrl))
        {
            LoadModelFromZip(zipUrl);
        }
        else
        {
            LoadModelFromUrl(objUrl, textureUrl, mtlUrl);
        }
    }

    void Update()
    {
        if (autoRotate && currentModel != null)
        {
            currentModel.transform.Rotate(Vector3.up * rotateSpeed * Time.deltaTime);
        }
    }

    public void LoadModelFromZip(string url)
    {
        if (string.IsNullOrEmpty(url))
        {
            Debug.LogError("ZIP URL is empty!");
            return;
        }
        url = FixUrl(url);
        StartCoroutine(DownloadAndUnzip(url));
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

    private IEnumerator DownloadAndUnzip(string url)
    {
        Debug.Log($"Starting ZIP download from: {url}");
        
        string zipPath = Path.Combine(Application.persistentDataPath, "temp_model.zip");
        string extractPath = Path.Combine(Application.persistentDataPath, "temp_model_extracted");

        // 1. Download ZIP
        using (UnityWebRequest webRequest = UnityWebRequest.Get(url))
        {
            yield return webRequest.SendWebRequest();

            if (webRequest.result != UnityWebRequest.Result.Success)
            {
                Debug.LogError($"Error downloading ZIP: {webRequest.error}");
                yield break;
            }
            File.WriteAllBytes(zipPath, webRequest.downloadHandler.data);
        }

        // 2. Unzip
        try
        {
            if (Directory.Exists(extractPath)) Directory.Delete(extractPath, true);
            Directory.CreateDirectory(extractPath);
            
            Debug.Log("Unzipping...");
            using (FileStream zipToOpen = new FileStream(zipPath, FileMode.Open))
            {
                using (ZipArchive archive = new ZipArchive(zipToOpen, ZipArchiveMode.Read))
                {
                    foreach (ZipArchiveEntry entry in archive.Entries)
                    {
                        // Prevent path traversal
                        string destinationPath = Path.GetFullPath(Path.Combine(extractPath, entry.FullName));
                        if (destinationPath.StartsWith(extractPath, System.StringComparison.Ordinal))
                        {
                            if (string.IsNullOrEmpty(entry.Name)) 
                            {
                                Directory.CreateDirectory(destinationPath);
                            }
                            else 
                            {
                                Directory.CreateDirectory(Path.GetDirectoryName(destinationPath));
                                entry.ExtractToFile(destinationPath, true);
                            }
                        }
                    }
                }
            }
        }
        catch (System.Exception e)
        {
            Debug.LogError($"Failed to unzip: {e.Message}");
            yield break;
        }

        // 3. Find OBJ in extracted folder
        string[] objFiles = Directory.GetFiles(extractPath, "*.obj", SearchOption.AllDirectories)
            .Where(f => !Path.GetFileName(f).StartsWith("._") && !f.Contains("__MACOSX"))
            .ToArray();

        if (objFiles.Length == 0)
        {
            Debug.LogError("No .obj file found in the ZIP!");
            yield break;
        }

        string mainObjPath = objFiles[0];
        Debug.Log($"Found OBJ in ZIP: {mainObjPath}");

        // 3.1 Find MTL in extracted folder (Optional)
        string[] mtlFiles = Directory.GetFiles(extractPath, "*.mtl", SearchOption.AllDirectories);
        string mtlPath = "";
        if (mtlFiles.Length > 0)
        {
            mtlPath = mtlFiles[0];
            Debug.Log($"Found MTL in ZIP: {mtlPath}");
        }

        // 3.2 Find Texture in extracted folder (Optional)
        string[] imageExtensions = new string[] { "*.png", "*.jpg", "*.jpeg", "*.webp", "*.tga", "*.bmp" };
        string texPath = "";
        
        foreach (string ext in imageExtensions)
        {
            string[] texFiles = Directory.GetFiles(extractPath, ext, SearchOption.AllDirectories);
            if (texFiles.Length > 0)
            {
                texPath = texFiles[0];
                Debug.Log($"Found Texture in ZIP: {texPath}");
                break; // Use the first found texture
            }
        }
        
        // 4. Load using existing logic with explicit paths
        string fileUrl = "file://" + mainObjPath;
        string mtlUrl = string.IsNullOrEmpty(mtlPath) ? "" : "file://" + mtlPath;
        string texUrl = string.IsNullOrEmpty(texPath) ? "" : "file://" + texPath;
        
        if (!string.IsNullOrEmpty(mtlUrl))
        {
            LoadModelFromUrl(fileUrl, "", mtlUrl);
        }
        else
        {
            LoadModelFromUrl(fileUrl, texUrl, "");
        }
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
            Debug.Log($"Parsing OBJ... FlipUV: {flipUV}, FlipFaces: {flipFaces}");
            loadedData = RuntimeObjImporter.Import(objContent, flipUV, flipFaces);
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
        MtlData mtlData = null;
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
                mtlData = ParseMtl(mtlContent);
                
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
                    foreach (string candidateUrl in GetTextureUrlCandidates(baseUrl, mtlData.textureFileName))
                    {
                        yield return DownloadTexture(candidateUrl, (tex) => finalTexture = tex);
                        if (finalTexture != null)
                        {
                            break;
                        }
                    }
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
        CreateModelObject(loadedData.mesh, finalTexture, finalColor, mtlData);
        Debug.Log("Model loaded successfully!");
    }

    private IEnumerator DownloadTexture(string url, System.Action<Texture2D> onSuccess)
    {
        using (UnityWebRequest texRequest = UnityWebRequest.Get(url))
        {
            texRequest.downloadHandler = new DownloadHandlerBuffer();
            yield return texRequest.SendWebRequest();

            if (texRequest.result != UnityWebRequest.Result.Success)
            {
                Debug.LogWarning($"Error downloading Texture: {texRequest.error}");
            }
            else
            {
                byte[] data = texRequest.downloadHandler.data;
                Texture2D tex = new Texture2D(2, 2);
                
                if (tex.LoadImage(data))
                {
                    tex.wrapMode = TextureWrapMode.Repeat;
                    onSuccess?.Invoke(tex);
                }
                else
                {
                    Debug.LogError($"Failed to decode texture from {url}. The format might not be supported at runtime (e.g. WebP). Please try using PNG or JPG.");
                }
            }
        }
    }

    private IEnumerable<string> GetTextureUrlCandidates(string baseUrl, string textureFileName)
    {
        if (string.IsNullOrEmpty(textureFileName))
        {
            yield break;
        }

        string raw = textureFileName.Trim().Trim('"');
        string combined = baseUrl + raw;
        yield return combined;

        string extension = Path.GetExtension(raw);
        string withoutExt = string.IsNullOrEmpty(extension) ? raw : raw.Substring(0, raw.Length - extension.Length);
        string[] exts = new string[] { ".png", ".jpg", ".jpeg", ".tga", ".bmp", ".webp" };

        foreach (string ext in exts)
        {
            string candidate = baseUrl + withoutExt + ext;
            if (!string.Equals(candidate, combined, System.StringComparison.OrdinalIgnoreCase))
            {
                yield return candidate;
            }
        }
    }

    private class MtlData
    {
        public string textureFileName;
        public Color? diffuseColor;    // Kd
        public Color? ambientColor;    // Ka
        public Color? specularColor;   // Ks
        public float? shininess;       // Ns (0-1000)
        public float? alpha;           // d or Tr (0-1)
    }

    private MtlData ParseMtl(string mtlContent)
    {
        MtlData data = new MtlData();
        string[] lines = mtlContent.Split(new char[] { '\n', '\r' }, System.StringSplitOptions.RemoveEmptyEntries);
        
        foreach (string line in lines)
        {
            string l = line.Trim();
            if (string.IsNullOrEmpty(l) || l.StartsWith("#")) continue;

            string[] parts = l.Split(new char[] { ' ' }, System.StringSplitOptions.RemoveEmptyEntries);
            if (parts.Length < 2) continue;

            string key = parts[0];

            if (key == "map_Kd")
            {
                if (parts.Length > 1)
                {
                    data.textureFileName = parts[parts.Length - 1];
                }
            }
            else if (key == "Kd")
            {
                data.diffuseColor = ParseColor(parts);
            }
            else if (key == "Ka")
            {
                data.ambientColor = ParseColor(parts);
            }
            else if (key == "Ks")
            {
                data.specularColor = ParseColor(parts);
            }
            else if (key == "Ns")
            {
                if (float.TryParse(parts[1], System.Globalization.NumberStyles.Float, System.Globalization.CultureInfo.InvariantCulture, out float ns))
                {
                    data.shininess = ns;
                }
            }
            else if (key == "d")
            {
                if (float.TryParse(parts[1], System.Globalization.NumberStyles.Float, System.Globalization.CultureInfo.InvariantCulture, out float d))
                {
                    data.alpha = d;
                }
            }
            else if (key == "Tr")
            {
                if (float.TryParse(parts[1], System.Globalization.NumberStyles.Float, System.Globalization.CultureInfo.InvariantCulture, out float tr))
                {
                    data.alpha = 1.0f - tr;
                }
            }
        }
        return data;
    }

    private Color? ParseColor(string[] parts)
    {
        if (parts.Length >= 4)
        {
            if (float.TryParse(parts[1], System.Globalization.NumberStyles.Float, System.Globalization.CultureInfo.InvariantCulture, out float r) &&
                float.TryParse(parts[2], System.Globalization.NumberStyles.Float, System.Globalization.CultureInfo.InvariantCulture, out float g) &&
                float.TryParse(parts[3], System.Globalization.NumberStyles.Float, System.Globalization.CultureInfo.InvariantCulture, out float b))
            {
                return new Color(r, g, b);
            }
        }
        return null;
    }

    private void CreateModelObject(Mesh mesh, Texture2D texture, Color? color, MtlData mtlData = null)
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
        
        // Apply Texture
        if (texture != null)
        {
            mat.mainTexture = texture;
            Debug.Log("Texture applied to material.");
        }

        // Apply Diffuse Color (Kd) - if provided via argument (priority) or from MTL
        if (color.HasValue)
        {
            mat.color = color.Value;
        }
        else if (mtlData != null && mtlData.diffuseColor.HasValue)
        {
            mat.color = mtlData.diffuseColor.Value;
        }

        // Apply other MTL properties if available and if Shader supports them
        bool isTransparent = false;
        if (mtlData != null)
        {
            // Specular / Metallic / Smoothness
            if (mtlData.specularColor.HasValue)
            {
                // Simple heuristic: if specular is bright, set some metallic/smoothness
                // This is a rough approximation as OBJ uses Specular workflow and Unity Standard uses Metallic
            }

            if (mtlData.shininess.HasValue)
            {
                float smoothness = Mathf.Clamp01(mtlData.shininess.Value / 1000f);
                if (mat.HasProperty("_Glossiness")) mat.SetFloat("_Glossiness", smoothness);
                else if (mat.HasProperty("_Smoothness")) mat.SetFloat("_Smoothness", smoothness);
            }

            // Alpha / Transparency
            if (mtlData.alpha.HasValue)
            {
                float alpha = mtlData.alpha.Value;
                Debug.Log($"MTL Alpha Parsed: {alpha}");
                
                if (alpha < 0.99f)
                {
                    Color c = mat.color;
                    c.a = alpha;
                    mat.color = c;
                    isTransparent = true;
                }
            }
        }
        
        // Explicitly setup material mode to avoid residual states
        SetupMaterialMode(mat, isTransparent);
        
        mr.material = mat;
    }

    private void SetupMaterialMode(Material material, bool isTransparent)
    {
        if (isTransparent)
        {
            material.SetFloat("_Mode", 3); // Transparent
            material.SetInt("_SrcBlend", (int)UnityEngine.Rendering.BlendMode.SrcAlpha);
            material.SetInt("_DstBlend", (int)UnityEngine.Rendering.BlendMode.OneMinusSrcAlpha);
            material.SetInt("_ZWrite", 0);
            material.DisableKeyword("_ALPHATEST_ON");
            material.EnableKeyword("_ALPHABLEND_ON");
            material.DisableKeyword("_ALPHAPREMULTIPLY_ON");
            material.renderQueue = 3000;
        }
        else
        {
            material.SetFloat("_Mode", 0); // Opaque
            material.SetInt("_SrcBlend", (int)UnityEngine.Rendering.BlendMode.One);
            material.SetInt("_DstBlend", (int)UnityEngine.Rendering.BlendMode.Zero);
            material.SetInt("_ZWrite", 1);
            material.DisableKeyword("_ALPHATEST_ON");
            material.DisableKeyword("_ALPHABLEND_ON");
            material.DisableKeyword("_ALPHAPREMULTIPLY_ON");
            material.renderQueue = -1;
        }
 
        if (doubleSided)
        {
            material.SetInt("_Cull", (int)UnityEngine.Rendering.CullMode.Off);
        }
        else
        {
            material.SetInt("_Cull", (int)UnityEngine.Rendering.CullMode.Back);
        }
    }
}

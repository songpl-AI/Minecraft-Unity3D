using System.Collections;
using UnityEngine;
using UnityEngine.Networking;

// NOTE: This script assumes you have installed the "glTFast" package from Unity Package Manager or OpenUPM.
// Installation:
// 1. Open Window -> Package Manager
// 2. Click "+" -> Add package from git URL...
// 3. Enter: "https://github.com/atteneder/glTFast.git"
//
// If you use UnityGLTF or another library, the loading logic will differ slightly.

#if GLTFAST_PRESENT
using GLTFast;
#endif

namespace LoadGLTF
{
    /// <summary>
    /// Demonstrates how to load a glTF/GLB model from a remote URL using the glTFast library.
    /// This is the recommended "Best Practice" for runtime model loading in production.
    /// </summary>
    public class WebGltfLoader : MonoBehaviour
    {
        [Header("Settings")]
        [Tooltip("URL of the .glb or .gltf file")]
        public string modelUrl = "https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Models/master/2.0/Duck/glTF-Binary/Duck.glb";

        [Tooltip("Automatically load on Start")]
        public bool loadOnStart = true;

        [Header("Preview")]
        public bool autoRotate = true;
        public float rotationSpeed = 30f;

        private GameObject loadedModel;

        private void Start()
        {
            if (loadOnStart)
            {
                LoadModel(modelUrl);
            }
        }

        private void Update()
        {
            if (autoRotate && loadedModel != null)
            {
                loadedModel.transform.Rotate(Vector3.up * rotationSpeed * Time.deltaTime);
            }
        }

        public void LoadModel(string url)
        {
            if (string.IsNullOrEmpty(url))
            {
                Debug.LogError("[WebGltfLoader] URL is empty!");
                return;
            }

            // Cleanup previous model
            if (loadedModel != null)
            {
                Destroy(loadedModel);
            }

            StartCoroutine(DownloadAndLoad(url));
        }

        private IEnumerator DownloadAndLoad(string url)
        {
            Debug.Log($"[WebGltfLoader] Starting download: {url}");

#if GLTFAST_PRESENT
            // --- OPTION A: Using glTFast (Recommended) ---
            
            // glTFast handles downloading and loading efficiently internally.
            // We create a new GameObject to hold the model.
            loadedModel = new GameObject("GLTF_Model");
            loadedModel.transform.SetParent(this.transform, false);

            // GltfImport is the core class for loading
            var gltf = new GltfImport();
            
            // Load the URL
            // The success callback is handled via the return value of Load() and InstantiateMainScene()
            var task = gltf.Load(url);
            yield return new WaitUntil(() => task.IsCompleted);

            if (task.Result)
            {
                // Instantiate the scene into our GameObject
                var instantiator = new GameObjectInstantiator(gltf, loadedModel.transform);
                var success = gltf.InstantiateMainScene(instantiator);

                if (success)
                {
                    Debug.Log("[WebGltfLoader] Model loaded successfully!");
                    // Center the model or adjust scale if needed
                    loadedModel.transform.localPosition = Vector3.zero;
                }
                else
                {
                    Debug.LogError("[WebGltfLoader] Failed to instantiate glTF scene.");
                }
            }
            else
            {
                Debug.LogError("[WebGltfLoader] Failed to load glTF from URL.");
            }
#else
            // --- OPTION B: Placeholder / No Library Installed ---
            
            Debug.LogWarning("[WebGltfLoader] 'glTFast' package is NOT installed. Downloading raw file only.");
            Debug.LogWarning("Please install glTFast via Package Manager: https://github.com/atteneder/glTFast.git");
            Debug.LogWarning("Then define 'GLTFAST_PRESENT' in Player Settings -> Scripting Define Symbols to enable the code.");

            // Just a simple download demonstration to show the URL works
            using (UnityWebRequest uwr = UnityWebRequest.Get(url))
            {
                yield return uwr.SendWebRequest();

                if (uwr.result == UnityWebRequest.Result.Success)
                {
                    Debug.Log($"[WebGltfLoader] Downloaded {uwr.downloadHandler.data.Length} bytes. (Cannot render without glTFast)");
                }
                else
                {
                    Debug.LogError($"[WebGltfLoader] Download Error: {uwr.error}");
                }
            }
#endif
        }
    }
}

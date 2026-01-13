using UnityEngine;
using System.Collections.Generic;
using System.Globalization;
using System;

public static class RuntimeObjImporter
{
    public static Mesh Import(string objContent)
    {
        List<Vector3> vertices = new List<Vector3>();
        List<Vector3> normals = new List<Vector3>();
        List<Vector2> uv = new List<Vector2>();
        
        // OBJ indices are 1-based, so we need to adjust them
        // We will reconstruct the mesh data for Unity's format
        List<Vector3> newVertices = new List<Vector3>();
        List<Vector3> newNormals = new List<Vector3>();
        List<Vector2> newUVs = new List<Vector2>();
        List<int> triangles = new List<int>();

        string[] lines = objContent.Split(new char[] { '\n', '\r' }, StringSplitOptions.RemoveEmptyEntries);

        foreach (string line in lines)
        {
            string l = line.Trim();
            if (string.IsNullOrEmpty(l) || l.StartsWith("#"))
                continue;

            string[] parts = l.Split(new char[] { ' ' }, StringSplitOptions.RemoveEmptyEntries);
            if (parts.Length == 0) continue;

            string type = parts[0];

            if (type == "v")
            {
                // Vertex position
                float x = float.Parse(parts[1], CultureInfo.InvariantCulture);
                float y = float.Parse(parts[2], CultureInfo.InvariantCulture);
                float z = float.Parse(parts[3], CultureInfo.InvariantCulture);
                // Unity is Left-Handed, OBJ is usually Right-Handed. Flip X to convert.
                vertices.Add(new Vector3(-x, y, z));
            }
            else if (type == "vn")
            {
                // Vertex normal
                float x = float.Parse(parts[1], CultureInfo.InvariantCulture);
                float y = float.Parse(parts[2], CultureInfo.InvariantCulture);
                float z = float.Parse(parts[3], CultureInfo.InvariantCulture);
                // Flip X for normals too
                normals.Add(new Vector3(-x, y, z));
            }
            else if (type == "vt")
            {
                // Texture coordinate
                float u = float.Parse(parts[1], CultureInfo.InvariantCulture);
                float v = float.Parse(parts[2], CultureInfo.InvariantCulture);
                uv.Add(new Vector2(u, v));
            }
            else if (type == "f")
            {
                // Face definition
                // Supports f v1 v2 v3
                // Supports f v1/vt1 v2/vt2 v3/vt3
                // Supports f v1/vt1/vn1 v2/vt2/vn2 v3/vt3/vn3
                // Also supports quads (4 vertices) -> splits into 2 triangles
                
                int[] vIndices = new int[parts.Length - 1];
                int[] tIndices = new int[parts.Length - 1];
                int[] nIndices = new int[parts.Length - 1];

                for (int i = 0; i < parts.Length - 1; i++)
                {
                    string[] indices = parts[i + 1].Split('/');
                    
                    // Vertex Index
                    if (indices.Length >= 1 && !string.IsNullOrEmpty(indices[0]))
                        vIndices[i] = int.Parse(indices[0]);

                    // UV Index
                    if (indices.Length >= 2 && !string.IsNullOrEmpty(indices[1]))
                        tIndices[i] = int.Parse(indices[1]);

                    // Normal Index
                    if (indices.Length >= 3 && !string.IsNullOrEmpty(indices[2]))
                        nIndices[i] = int.Parse(indices[2]);
                }

                // Triangulate
                // If it's a triangle (3 vertices), we add 1 triangle
                // If it's a quad (4 vertices), we add 2 triangles (0,1,2) and (0,2,3)
                // Note: We need to reverse winding order because we flipped X axis?
                // Actually, if we flip X, we are mirroring. Standard OBJ is CCW. Unity is CW (usually) or CCW depending on cull mode.
                // Let's stick to standard winding (0, 1, 2). If mesh is inside-out, we swap to (0, 2, 1).
                // Since we negated X, the winding order effectively changes from CCW to CW relative to the new coords.
                // So (0, 1, 2) should be fine if original was CCW.
                
                for (int i = 0; i < vIndices.Length - 2; i++)
                {
                    AddVertexData(vIndices[0], tIndices[0], nIndices[0], vertices, uv, normals, newVertices, newUVs, newNormals, triangles);
                    AddVertexData(vIndices[i + 1], tIndices[i + 1], nIndices[i + 1], vertices, uv, normals, newVertices, newUVs, newNormals, triangles);
                    AddVertexData(vIndices[i + 2], tIndices[i + 2], nIndices[i + 2], vertices, uv, normals, newVertices, newUVs, newNormals, triangles);
                }
            }
        }

        Mesh mesh = new Mesh();
        // Support large meshes
        if (newVertices.Count > 65000)
            mesh.indexFormat = UnityEngine.Rendering.IndexFormat.UInt32;
            
        mesh.vertices = newVertices.ToArray();
        
        if (newUVs.Count > 0)
            mesh.uv = newUVs.ToArray();
            
        if (newNormals.Count > 0)
            mesh.normals = newNormals.ToArray();
            
        mesh.triangles = triangles.ToArray();
        
        if (newNormals.Count == 0)
            mesh.RecalculateNormals();
            
        mesh.RecalculateBounds();

        return mesh;
    }

    private static void AddVertexData(
        int vIdx, int tIdx, int nIdx,
        List<Vector3> sourceV, List<Vector2> sourceT, List<Vector3> sourceN,
        List<Vector3> destV, List<Vector2> destT, List<Vector3> destN,
        List<int> destTriangles)
    {
        // OBJ indices are 1-based. 
        // Negative indices refer to end of list (not handled here for simplicity, but standard OBJ can have them).
        // Let's assume standard positive indices.
        
        // Handle vertex position
        if (vIdx > 0 && vIdx <= sourceV.Count)
        {
            destV.Add(sourceV[vIdx - 1]);
        }
        else
        {
            destV.Add(Vector3.zero); // Error fallback
        }

        // Handle UV
        if (tIdx > 0 && tIdx <= sourceT.Count)
        {
            destT.Add(sourceT[tIdx - 1]);
        }
        else if (destT.Count > 0 || sourceT.Count > 0) // Keep sync if some have UVs
        {
            destT.Add(Vector2.zero);
        }

        // Handle Normal
        if (nIdx > 0 && nIdx <= sourceN.Count)
        {
            destN.Add(sourceN[nIdx - 1]);
        }
        else if (destN.Count > 0 || sourceN.Count > 0) // Keep sync
        {
            destN.Add(Vector3.up);
        }

        destTriangles.Add(destV.Count - 1);
    }
}

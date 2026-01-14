using UnityEngine;
using System.Collections.Generic;
using System.Globalization;
using System;

public class LoadedObjData
{
    public Mesh mesh;
    public string mtlFileName;
}

public static class RuntimeObjImporter
{
    public static LoadedObjData Import(string objContent, bool flipUV = true, bool flipFaces = false)
    {
        List<Vector3> vertices = new List<Vector3>();
        List<Vector3> normals = new List<Vector3>();
        List<Vector2> uv = new List<Vector2>();
        
        List<Vector3> newVertices = new List<Vector3>();
        List<Vector3> newNormals = new List<Vector3>();
        List<Vector2> newUVs = new List<Vector2>();
        List<int> triangles = new List<int>();

        string mtlFileName = "";

        string[] lines = objContent.Split(new char[] { '\n', '\r' }, StringSplitOptions.RemoveEmptyEntries);

        foreach (string line in lines)
        {
            string l = line.Trim();
            if (string.IsNullOrEmpty(l) || l.StartsWith("#"))
                continue;

            string[] parts = l.Split(new char[] { ' ' }, StringSplitOptions.RemoveEmptyEntries);
            if (parts.Length == 0) continue;

            string type = parts[0];

            if (type == "mtllib")
            {
                // Material library file
                if (parts.Length > 1)
                    mtlFileName = parts[1];
            }
            else if (type == "v")
            {
                float x = float.Parse(parts[1], CultureInfo.InvariantCulture);
                float y = float.Parse(parts[2], CultureInfo.InvariantCulture);
                float z = float.Parse(parts[3], CultureInfo.InvariantCulture);
                vertices.Add(new Vector3(-x, y, z));
            }
            else if (type == "vn")
            {
                float x = float.Parse(parts[1], CultureInfo.InvariantCulture);
                float y = float.Parse(parts[2], CultureInfo.InvariantCulture);
                float z = float.Parse(parts[3], CultureInfo.InvariantCulture);
                normals.Add(new Vector3(-x, y, z));
            }
            else if (type == "vt")
            {
                float u = float.Parse(parts[1], CultureInfo.InvariantCulture);
                float v = float.Parse(parts[2], CultureInfo.InvariantCulture);
                
                if (flipUV)
                    uv.Add(new Vector2(u, 1f - v));
                else
                    uv.Add(new Vector2(u, v));
            }
            else if (type == "f")
            {
                int[] vIndices = new int[parts.Length - 1];
                int[] tIndices = new int[parts.Length - 1];
                int[] nIndices = new int[parts.Length - 1];

                for (int i = 0; i < parts.Length - 1; i++)
                {
                    string[] indices = parts[i + 1].Split('/');
                    
                    if (indices.Length >= 1 && !string.IsNullOrEmpty(indices[0]))
                        vIndices[i] = int.Parse(indices[0]);

                    if (indices.Length >= 2 && !string.IsNullOrEmpty(indices[1]))
                        tIndices[i] = int.Parse(indices[1]);

                    if (indices.Length >= 3 && !string.IsNullOrEmpty(indices[2]))
                        nIndices[i] = int.Parse(indices[2]);
                }
                
                for (int i = 0; i < vIndices.Length - 2; i++)
                {
                    if (flipFaces)
                    {
                        // Reverse winding order: 0, 2, 1
                        AddVertexData(vIndices[0], tIndices[0], nIndices[0], vertices, uv, normals, newVertices, newUVs, newNormals, triangles);
                        AddVertexData(vIndices[i + 2], tIndices[i + 2], nIndices[i + 2], vertices, uv, normals, newVertices, newUVs, newNormals, triangles);
                        AddVertexData(vIndices[i + 1], tIndices[i + 1], nIndices[i + 1], vertices, uv, normals, newVertices, newUVs, newNormals, triangles);
                    }
                    else
                    {
                        // Standard winding order: 0, 1, 2
                        AddVertexData(vIndices[0], tIndices[0], nIndices[0], vertices, uv, normals, newVertices, newUVs, newNormals, triangles);
                        AddVertexData(vIndices[i + 1], tIndices[i + 1], nIndices[i + 1], vertices, uv, normals, newVertices, newUVs, newNormals, triangles);
                        AddVertexData(vIndices[i + 2], tIndices[i + 2], nIndices[i + 2], vertices, uv, normals, newVertices, newUVs, newNormals, triangles);
                    }
                }
            }
        }

        Mesh mesh = new Mesh();
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

        return new LoadedObjData { mesh = mesh, mtlFileName = mtlFileName };
    }

    private static int ResolveObjIndex(int idx, int count)
    {
        if (idx > 0) return idx;
        if (idx < 0) return count + idx + 1;
        return 0;
    }

    private static void AddVertexData(
        int vIdx, int tIdx, int nIdx,
        List<Vector3> sourceV, List<Vector2> sourceT, List<Vector3> sourceN,
        List<Vector3> destV, List<Vector2> destT, List<Vector3> destN,
        List<int> destTriangles)
    {
        vIdx = ResolveObjIndex(vIdx, sourceV.Count);
        tIdx = ResolveObjIndex(tIdx, sourceT.Count);
        nIdx = ResolveObjIndex(nIdx, sourceN.Count);

        if (vIdx > 0 && vIdx <= sourceV.Count)
            destV.Add(sourceV[vIdx - 1]);
        else
            destV.Add(Vector3.zero);

        if (tIdx > 0 && tIdx <= sourceT.Count)
            destT.Add(sourceT[tIdx - 1]);
        else if (destT.Count > 0 || sourceT.Count > 0)
            destT.Add(Vector2.zero);

        if (nIdx > 0 && nIdx <= sourceN.Count)
            destN.Add(sourceN[nIdx - 1]);
        else if (destN.Count > 0 || sourceN.Count > 0)
            destN.Add(Vector3.up);

        destTriangles.Add(destV.Count - 1);
    }
}

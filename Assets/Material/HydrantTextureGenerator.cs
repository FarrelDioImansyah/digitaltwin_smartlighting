using UnityEngine;

[ExecuteInEditMode]
public class HydrantTextureGenerator : MonoBehaviour
{
    [Header("Resolusi Tekstur")]
    public int width = 512;
    public int height = 680;

    [Header("Palet Warna")]
    public Color warnaMerahUtama = new Color(0.76f, 0.11f, 0.11f);
    public Color warnaMerahBingkai = new Color(0.55f, 0.07f, 0.07f);
    public Color warnaKacaGelap = new Color(0.10f, 0.11f, 0.13f);
    public Color warnaSelang = new Color(0.82f, 0.22f, 0.18f);
    public Color warnaKrom = new Color(0.85f, 0.87f, 0.90f);

    [Header("Pengaturan Permukaan")]
    [Range(0f, 1f)] public float metallic = 0.35f;
    [Range(0f, 1f)] public float smoothness = 0.55f;

    void Start()
    {
        GenerateAndApply();
    }

    // Bisa dipanggil langsung dari menu titik tiga komponen di Inspector tanpa Play Mode
    [ContextMenu("Generate Hydrant Texture")]
    public void GenerateAndApply()
    {
        Texture2D tex = new Texture2D(width, height, TextureFormat.RGBA32, false);
        tex.wrapMode = TextureWrapMode.Clamp;

        // Area kotak kaca di tengah (koordinat ternormalisasi 0.0 - 1.0)
        Rect glassRect = new Rect(0.26f, 0.25f, 0.48f, 0.50f);
        Vector2 hoseCenter = new Vector2(0.50f, 0.43f);

        for (int y = 0; y < height; y++)
        {
            float v = (float)y / height;

            for (int x = 0; x < width; x++)
            {
                float u = (float)x / width;

                // 1. Dasar bodi merah dengan sedikit grain logam prosedural
                float grain = (Mathf.PerlinNoise(u * 60f, v * 60f) - 0.5f) * 0.04f;
                Color pixel = warnaMerahUtama + new Color(grain, grain, grain, 0f);

                // 2. Bingkai luar & garis celah pintu
                if (u < 0.05f || u > 0.95f || v < 0.04f || v > 0.96f)
                {
                    pixel = warnaMerahBingkai;
                }
                else if (Mathf.Abs(u - 0.065f) < 0.004f || Mathf.Abs(u - 0.935f) < 0.004f ||
                         Mathf.Abs(v - 0.055f) < 0.004f || Mathf.Abs(v - 0.945f) < 0.004f)
                {
                    pixel = warnaMerahBingkai * 0.65f;
                }

                // 3. Label putih bagian atas (plakat HYDRANT)
                if (u > 0.36f && u < 0.64f && v > 0.82f && v < 0.88f)
                {
                    pixel = new Color(0.93f, 0.93f, 0.93f);
                    // Garis merah tipis di dalam plakat sebagai aksen teks
                    if (u > 0.40f && u < 0.60f && v > 0.842f && v < 0.858f)
                    {
                        pixel = warnaMerahUtama;
                    }
                }

                // 4. Bingkai karet hitam kaca & isi kaca
                Rect rubberFrame = new Rect(glassRect.x - 0.02f, glassRect.y - 0.015f,
                                            glassRect.width + 0.04f, glassRect.height + 0.03f);

                if (rubberFrame.Contains(new Vector2(u, v)))
                {
                    if (!glassRect.Contains(new Vector2(u, v)))
                    {
                        pixel = new Color(0.08f, 0.08f, 0.08f); // Karet lis kaca
                    }
                    else
                    {
                        // Interior gelap di balik kaca
                        pixel = warnaKacaGelap;

                        // 5. Gulungan selang pemadam (lingkaran konsentris)
                        Vector2 diff = new Vector2((u - hoseCenter.x) * ((float)width / height), v - hoseCenter.y);
                        float dist = diff.magnitude;

                        if (dist < 0.175f && dist > 0.045f)
                        {
                            float coilWave = Mathf.Sin(dist * 260f);
                            float shading = Mathf.Clamp01(0.75f + coilWave * 0.25f);
                            pixel = warnaSelang * shading;
                        }

                        // 6. Nozzle logam di tengah gulungan selang
                        if (dist <= 0.045f)
                        {
                            pixel = warnaKrom * 0.75f;
                        }

                        // 7. Efek pantulan diagonal kaca
                        float glare = Mathf.SmoothStep(0.0f, 1.0f, 1.0f - Mathf.Abs((u + v) - 1.15f) * 5f);
                        pixel = Color.Lerp(pixel, Color.white, glare * 0.14f);
                    }
                }

                // 8. Gagang kunci pintu krom di sisi kanan
                bool basePlate = (u > 0.83f && u < 0.89f && v > 0.44f && v < 0.56f);
                bool leverHandle = (u > 0.75f && u < 0.87f && v > 0.49f && v < 0.515f);
                if (basePlate || leverHandle)
                {
                    float metalShine = 0.85f + (v - 0.5f) * 1.5f;
                    pixel = warnaKrom * Mathf.Clamp(metalShine, 0.6f, 1.1f);
                }

                tex.SetPixel(x, y, pixel);
            }
        }

        tex.Apply();

        // Terapkan otomatis ke Material objek
        Renderer rend = GetComponent<Renderer>();
        if (rend != null)
        {
            Shader shader = Shader.Find("Universal Render Pipeline/Lit");
            if (shader == null) shader = Shader.Find("Standard");

            Material mat = new Material(shader);
            mat.mainTexture = tex;
            if (mat.HasProperty("_BaseMap")) mat.SetTexture("_BaseMap", tex);
            if (mat.HasProperty("_Metallic")) mat.SetFloat("_Metallic", metallic);
            if (mat.HasProperty("_Smoothness")) mat.SetFloat("_Smoothness", smoothness);
            if (mat.HasProperty("_Glossiness")) mat.SetFloat("_Glossiness", smoothness);

            rend.sharedMaterial = mat;
        }
    }
}
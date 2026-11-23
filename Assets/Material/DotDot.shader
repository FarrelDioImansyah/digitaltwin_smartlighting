Shader "Custom/PanelDotsUnlit"
{
    Properties
    {
        _BaseColor ("Warna Dasar Gelap", Color) = (0.04, 0.045, 0.05, 1)
        _FrameColor ("Warna Bingkai Kotak", Color) = (0.22, 0.24, 0.26, 1)
        _DotColor ("Warna Bulatan", Color) = (0.55, 0.58, 0.62, 1)
        
        _GridScale ("Jumlah Panel (Tiling)", Float) = 4.0
        _DotsPerPanel ("Bulatan per Sisi Panel", Float) = 4.0
        _FrameWidth ("Ketebalan Bingkai", Range(0.01, 0.2)) = 0.06
        _DotRadius ("Ukuran Bulatan", Range(0.1, 0.5)) = 0.34
        _NoiseStrength ("Kekuatan Tekstur Grain/Noise", Range(0.0, 0.3)) = 0.08
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            fixed4 _BaseColor;
            fixed4 _FrameColor;
            fixed4 _DotColor;
            float _GridScale;
            float _DotsPerPanel;
            float _FrameWidth;
            float _DotRadius;
            float _NoiseStrength;

            // Fungsi pseudo-random untuk efek bintik kasar (grain) seperti di gambar
            float hash21(float2 p)
            {
                p = frac(p * float2(123.34, 456.21));
                p += dot(p, p + 45.32);
                return frac(p.x * p.y);
            }

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // 1. Koordinat Panel Utama
                float2 panelUV = frac(i.uv * _GridScale);
                
                // 2. Deteksi Bingkai / Garis Tepi Panel
                float2 border = step(panelUV, _FrameWidth) + step(1.0 - _FrameWidth, panelUV);
                float isCorner = border.x * border.y; // Titik pertemuan sudut (hitam pekat)
                float isFrame = saturate(border.x + border.y); // Garis bingkai abu-abu

                // 3. Area Dalam Panel untuk Bulatan (4x4)
                float2 innerUV = saturate((panelUV - _FrameWidth) / (1.0 - 2.0 * _FrameWidth));
                float2 dotGridUV = frac(innerUV * _DotsPerPanel);
                
                // Hitung jarak dari titik tengah masing-masing sel bulatan
                float2 distVec = dotGridUV - 0.5;
                float dist = length(distVec);

                // Masking lingkaran dengan sedikit anti-aliasing
                float dotMask = smoothstep(_DotRadius, _DotRadius - 0.03, dist);
                
                // Efek 3D palsu (shading dome/setengah bola) karena ini shader Unlit
                float domeHeight = sqrt(saturate(1.0 - pow(dist / _DotRadius, 2.0)));
                // Simulasi arah cahaya dari kiri atas
                float fakeLight = saturate(dot(normalize(float3(distVec * 2.0, domeHeight)), normalize(float3(-0.4, 0.5, 0.8))));
                
                // 4. Gabungkan Warna
                fixed3 finalColor = _BaseColor.rgb;
                
                // Terapkan warna bulatan + shading 3D palsu
                fixed3 shadedDot = _DotColor.rgb * (0.4 + 0.75 * fakeLight);
                finalColor = lerp(finalColor, shadedDot, dotMask * (1.0 - isFrame));
                
                // Terapkan bingkai kotak (dengan sedikit gradasi tepi)
                float frameBevel = smoothstep(0.0, _FrameWidth, min(min(panelUV.x, 1.0 - panelUV.x), min(panelUV.y, 1.0 - panelUV.y)));
                fixed3 shadedFrame = _FrameColor.rgb * (0.7 + 0.4 * frameBevel);
                finalColor = lerp(finalColor, shadedFrame, isFrame);
                
                // Sudut pertemuan bingkai dibuat hitam gelap seperti di referensi
                finalColor = lerp(finalColor, float3(0.01, 0.01, 0.01), isCorner);

                // 5. Tambahkan efek grain/noise halus di seluruh permukaan
                float grain = (hash21(i.uv * 800.0) - 0.5) * _NoiseStrength;
                finalColor += grain;

                return fixed4(saturate(finalColor), 1.0);
            }
            ENDCG
        }
    }
}
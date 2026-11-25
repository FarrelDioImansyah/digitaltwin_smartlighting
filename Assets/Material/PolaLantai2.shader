Shader "Custom/CorridorTileFloorUnlit"
{
    Properties
    {
        _CreamColor ("Warna Keramik Krem Utama", Color) = (0.83, 0.81, 0.75, 1)
        _TaupeColor ("Warna Aksen Abu Kecokelatan", Color) = (0.55, 0.52, 0.47, 1)
        _BrownColor ("Warna Aksen Cokelat", Color) = (0.42, 0.31, 0.22, 1)
        _BlackColor ("Warna Aksen Hitam", Color) = (0.10, 0.10, 0.11, 1)
        _GroutColor ("Warna Nat Keramik", Color) = (0.28, 0.27, 0.25, 1)

        _TileSize ("Ukuran 1 Ubin (Meter)", Float) = 0.6
        _GroutWidth ("Ketebalan Garis Nat", Range(0.005, 0.05)) = 0.015
        _GlossStrength ("Kekuatan Kilap Lantai", Range(0, 0.5)) = 0.16
        _SwapAxis ("Tukar Arah Koridor (0 = Z, 1 = X)", Range(0, 1)) = 0
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
                float3 worldPos : TEXCOORD1;
                float4 vertex : SV_POSITION;
            };

            float4 _CreamColor;
            float4 _TaupeColor;
            float4 _BrownColor;
            float4 _BlackColor;
            float4 _GroutColor;

            float _TileSize;
            float _GroutWidth;
            float _GlossStrength;
            float _SwapAxis;

            float Hash(float2 p)
            {
                return frac(sin(dot(p, float2(127.1, 311.7))) * 43758.5453123);
            }

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // Koordinat grid ubin berdasarkan ukuran meter di dunia 3D
                float2 rawCoord = (_SwapAxis > 0.5) ? i.worldPos.zx : i.worldPos.xz;
                float2 gridUV = rawCoord / max(_TileSize, 0.05);

                // ID integer tiap kotak ubin (col = melintang koridor, row = memanjang koridor)
                float2 tileID = floor(gridUV);
                float2 tileLocal = frac(gridUV);

                // 1. Garis nat (grout) antar keramik
                float2 border = step(_GroutWidth, tileLocal) * step(tileLocal, 1.0 - _GroutWidth);
                float isTile = border.x * border.y;

                // 2. Pola warna blok koridor (berulang setiap 12 baris ubin ke depan)
                float rowMod = fmod(abs(tileID.y), 12.0);
                float colMod = fmod(abs(tileID.x), 4.0);

                float3 tileCol = _CreamColor.rgb;

                // Baris pembatas hitam melintang penuh (seperti di bagian bawah foto)
                if (rowMod < 1.0)
                {
                    tileCol = _BlackColor.rgb;
                }
                // Blok aksen cokelat di sisi kanan (seperti di baris ke-3 foto)
                else if (rowMod >= 3.0 && rowMod < 4.0 && colMod >= 2.0)
                {
                    tileCol = _BrownColor.rgb;
                }
                // Blok aksen abu kecokelatan di sisi kiri-tengah (seperti di baris ke-4 foto)
                else if (rowMod >= 4.0 && rowMod < 5.0 && colMod < 3.0)
                {
                    tileCol = _TaupeColor.rgb;
                }
                // Blok aksen abu kecokelatan jauh di depan
                else if (rowMod >= 8.0 && rowMod < 9.0 && colMod >= 1.0)
                {
                    tileCol = _TaupeColor.rgb;
                }

                // Variasi tone sangat halus antar ubin agar tidak terlihat seperti plastik
                float tileTone = (Hash(tileID) - 0.5) * 0.025;
                tileCol += tileTone;

                // Gabungkan warna keramik dan garis nat
                float3 finalCol = lerp(_GroutColor.rgb, tileCol, isTile);

                // 3. Efek kilap pantulan lampu koridor di bagian tengah lantai (Unlit Specular)
                float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);
                float3 fakeLightDir = normalize(float3(0.0, 0.65, 0.75));
                float3 halfVec = normalize(viewDir + fakeLightDir);
                float spec = pow(saturate(dot(float3(0, 1, 0), halfVec)), 48.0);
                finalCol += spec * _GlossStrength * isTile;

                return fixed4(finalCol, 1.0);
            }
            ENDCG
        }
    }
}
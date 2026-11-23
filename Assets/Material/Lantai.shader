Shader "Custom/MarbleCreamTiles_Unlit"
{
    Properties
    {
        _BaseCream ("Warna Krem Dasar", Color) = (0.76, 0.74, 0.71, 1)
        _WarmVein ("Warna Krem Hangat", Color) = (0.71, 0.68, 0.63, 1)
        _LightPatch ("Warna Putih Gading", Color) = (0.81, 0.80, 0.78, 1)
        
        _Scale ("Skala Pola Marmer", Float) = 1.8
        _FlowDistortion ("Kekuatan Aliran Pola", Range(0.5, 4.0)) = 2.2
        _Softness ("Kelembutan Gradasi", Range(0.5, 2.0)) = 1.1
        
        [Header(Pengaturan Ubin Lantai)]
        _TileCount ("Jumlah Kotak Ubin (Tiling)", Float) = 4.0
        _GroutColor ("Warna Garis Nat", Color) = (0.45, 0.43, 0.40, 1)
        _GroutWidth ("Ketebalan Garis Nat", Range(0.002, 0.05)) = 0.012
        _GroutSoftness ("Kehalusan Tepi Nat", Range(0.001, 0.02)) = 0.005
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

            fixed4 _BaseCream;
            fixed4 _WarmVein;
            fixed4 _LightPatch;
            float _Scale;
            float _FlowDistortion;
            float _Softness;

            float _TileCount;
            fixed4 _GroutColor;
            float _GroutWidth;
            float _GroutSoftness;

            float hash21(float2 p)
            {
                p = frac(p * float2(234.34, 435.345));
                p += dot(p, p + 34.23);
                return frac(p.x * p.y);
            }

            float noise(float2 p)
            {
                float2 i = floor(p);
                float2 f = frac(p);
                f = f * f * (3.0 - 2.0 * f);
                float a = hash21(i);
                float b = hash21(i + float2(1.0, 0.0));
                float c = hash21(i + float2(0.0, 1.0));
                float d = hash21(i + float2(1.0, 1.0));
                return lerp(lerp(a, b, f.x), lerp(c, d, f.x), f.y);
            }

            float fbm(float2 p)
            {
                float v = 0.0;
                float amp = 0.5;
                float2x2 rot = float2x2(0.87, -0.48, 0.48, 0.87);
                for (int i = 0; i < 6; i++)
                {
                    v += amp * noise(p);
                    p = mul(rot, p) * 2.03;
                    amp *= 0.5;
                }
                return v;
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
                // 1. Pembagian Grid Ubin Lantai
                float2 gridUV = i.uv * _TileCount;
                float2 tileID = floor(gridUV);      // ID unik tiap kotak ubin
                float2 tileUV = frac(gridUV);       // Koordinat 0..1 di dalam satu ubin

                // Offset acak per ubin agar pola marmer tiap kotak berbeda (tidak terlihat seperti stiker sambungan)
                float2 randomOffset = float2(hash21(tileID), hash21(tileID + 17.3)) * 15.0;
                float2 uv = (tileUV * _Scale) + randomOffset;

                // 2. Pola Marmer Krem (Domain Warping)
                float2 q = float2(
                    fbm(uv + float2(0.0, 0.0)),
                    fbm(uv + float2(5.2, 1.3))
                );

                float2 r = float2(
                    fbm(uv + _FlowDistortion * q + float2(1.7, 9.2)),
                    fbm(uv + _FlowDistortion * q + float2(8.3, 2.8))
                );

                float pattern = fbm(uv + _FlowDistortion * r);
                pattern = pow(saturate(pattern), _Softness);

                fixed3 col = lerp(_WarmVein.rgb, _BaseCream.rgb, smoothstep(0.2, 0.55, pattern));
                
                float lightMask = smoothstep(0.52, 0.62, pattern + (r.x - 0.5) * 0.25);
                col = lerp(col, _LightPatch.rgb, lightMask * 0.85);

                // Tekstur halus permukaan keramik matte
                float grain = (hash21(i.uv * 1100.0) - 0.5) * 0.015;
                col += grain;

                // 3. Garis Nat Kotak-Kotak (Grout)
                float2 distToEdge = min(tileUV, 1.0 - tileUV);
                float edgeDist = min(distToEdge.x, distToEdge.y);
                float groutMask = 1.0 - smoothstep(_GroutWidth, _GroutWidth + _GroutSoftness, edgeDist);

                // Sedikit bayangan pingul (bevel) halus di tepi ubin dekat nat
                float bevelMask = 1.0 - smoothstep(_GroutWidth, _GroutWidth * 3.0, edgeDist);
                col *= (1.0 - bevelMask * 0.08);

                // Gabungkan warna keramik dengan garis nat
                col = lerp(col, _GroutColor.rgb, groutMask);

                return fixed4(saturate(col), 1.0);
            }
            ENDCG
        }
    }
}
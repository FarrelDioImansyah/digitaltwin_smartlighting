Shader "Custom/ModularTaupeFloorDoff_Unlit"
{
    Properties
    {
        [Header(Palet Warna Ubin Doff)]
        _ColorBeige ("Warna Ubin Krem / Beige", Color) = (0.73, 0.69, 0.64, 1)
        _ColorLightTaupe ("Warna List Abu Taupe Muda", Color) = (0.61, 0.58, 0.55, 1)
        _ColorDarkTaupe ("Warna List Cokelat Taupe Gelap", Color) = (0.47, 0.43, 0.40, 1)
        
        [Header(Ukuran dan Garis Nat)]
        _GridScale ("Skala Tiling Modul", Float) = 2.0
        _GroutColor ("Warna Garis Nat", Color) = (0.33, 0.31, 0.29, 1)
        _GroutWidth ("Ketebalan Garis Nat", Range(0.001, 0.02)) = 0.005
        
        [Header(Tekstur Permukaan Doff)]
        _MarbleScale ("Skala Serat Halus Keramik", Float) = 4.5
        _MarbleStrength ("Intensitas Serat Keramik", Range(0.0, 0.2)) = 0.05
        _RoughnessGrain ("Tekstur Pori Kasar Doff (Matte)", Range(0.0, 0.12)) = 0.045
        _Chalkiness ("Efek Kapur / Redam Kontras Doff", Range(0.0, 0.3)) = 0.12
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

            fixed4 _ColorBeige;
            fixed4 _ColorLightTaupe;
            fixed4 _ColorDarkTaupe;
            float _GridScale;
            fixed4 _GroutColor;
            float _GroutWidth;
            float _MarbleScale;
            float _MarbleStrength;
            float _RoughnessGrain;
            float _Chalkiness;

            float hash21(float2 p)
            {
                p = frac(p * float2(127.1, 311.7));
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
                for (int i = 0; i < 4; i++)
                {
                    v += amp * noise(p);
                    p *= 2.03;
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
                float2 uv = i.uv * _GridScale;
                float2 moduleID = floor(uv);
                float2 m = frac(uv);

                float colIdx = step(0.5, m.x);
                
                fixed3 baseColor = _ColorBeige.rgb;
                float2 cellMin = float2(0.0, 0.0);
                float2 cellMax = float2(0.5, 1.0);
                float cellSeed = 1.0;

                if (colIdx < 0.5)
                {
                    cellMin.x = 0.0;
                    cellMax.x = 0.5;
                    if (m.y < 0.42)
                    {
                        cellMin.y = 0.0; cellMax.y = 0.42;
                        baseColor = _ColorBeige.rgb;
                        cellSeed = 1.1;
                    }
                    else if (m.y < 0.56)
                    {
                        cellMin.y = 0.42; cellMax.y = 0.56;
                        baseColor = _ColorLightTaupe.rgb;
                        cellSeed = 2.3;
                    }
                    else
                    {
                        cellMin.y = 0.56; cellMax.y = 1.0;
                        baseColor = _ColorBeige.rgb;
                        cellSeed = 3.7;
                    }
                }
                else
                {
                    cellMin.x = 0.5;
                    cellMax.x = 1.0;
                    if (m.y < 0.14)
                    {
                        cellMin.y = 0.0; cellMax.y = 0.14;
                        baseColor = _ColorLightTaupe.rgb;
                        cellSeed = 4.5;
                    }
                    else if (m.y < 0.46)
                    {
                        cellMin.y = 0.14; cellMax.y = 0.46;
                        baseColor = _ColorBeige.rgb;
                        cellSeed = 5.9;
                    }
                    else if (m.y < 0.58)
                    {
                        cellMin.y = 0.46; cellMax.y = 0.58;
                        baseColor = _ColorDarkTaupe.rgb;
                        cellSeed = 6.2;
                    }
                    else if (m.y < 0.86)
                    {
                        cellMin.y = 0.58; cellMax.y = 0.86;
                        baseColor = _ColorBeige.rgb;
                        cellSeed = 7.4;
                    }
                    else
                    {
                        cellMin.y = 0.86; cellMax.y = 1.0;
                        baseColor = _ColorDarkTaupe.rgb;
                        cellSeed = 8.8;
                    }
                }

                // Variasi tone halus per modul
                float modRand = hash21(moduleID + cellSeed);
                baseColor *= (0.97 + modRand * 0.06);

                // Serat keramik halus
                float2 randomOffset = float2(hash21(moduleID + cellSeed * 2.1), hash21(moduleID + cellSeed * 5.3)) * 10.0;
                float stonePattern = fbm(uv * _MarbleScale + randomOffset);
                baseColor += (stonePattern - 0.5) * _MarbleStrength;

                // Efek Doff / Matte:
                // 1. Pori-pori mikro dua tingkat (kasar + halus) yang menyerap cahaya
                float microPore = hash21(i.uv * 1600.0) - 0.5;
                float mediumPore = noise(i.uv * 280.0) - 0.5;
                baseColor += (microPore * 0.65 + mediumPore * 0.35) * _RoughnessGrain;

                // 2. Efek kapur lembut (chalky diffuse) untuk meredam kontras agar tampak kering & tidak licin
                fixed3 chalkTone = fixed3(0.62, 0.60, 0.58);
                baseColor = lerp(baseColor, chalkTone, _Chalkiness);

                // Garis nat
                float2 distMin = m - cellMin;
                float2 distMax = cellMax - m;
                float edgeDist = min(min(distMin.x, distMax.x), min(distMin.y, distMax.y));
                
                float groutMask = 1.0 - smoothstep(_GroutWidth, _GroutWidth + 0.0025, edgeDist);
                fixed3 finalCol = lerp(baseColor, _GroutColor.rgb, groutMask);

                return fixed4(saturate(finalCol), 1.0);
            }
            ENDCG
        }
    }
}
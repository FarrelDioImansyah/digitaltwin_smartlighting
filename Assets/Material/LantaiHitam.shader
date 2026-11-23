Shader "Custom/MarbleBlackGlossy_Unlit"
{
    Properties
    {
        _BaseBlack ("Hitam Dasar Pekat", Color) = (0.02, 0.02, 0.025, 1)
        _CharcoalVein ("Abu-abu Gelap / Charcoal", Color) = (0.08, 0.085, 0.095, 1)
        _SilverPatch ("Pantulan / Bercak Abu Terang", Color) = (0.22, 0.23, 0.25, 1)
        
        _Scale ("Skala Pola", Float) = 2.5
        _FlowDistortion ("Kekuatan Aliran Pola", Range(0.5, 4.0)) = 2.3
        _Softness ("Kontras Pola", Range(0.5, 2.5)) = 1.3
        
        [Header(Efek Glossy)]
        _Glossiness ("Kekuatan Kilap (Glossy)", Range(0.0, 2.0)) = 1.1
        _FresnelPower ("Ketajaman Pantulan Sudut", Range(1.0, 6.0)) = 3.0
        _BumpStrength ("Kedalaman Permukaan Halus", Range(0.0, 0.2)) = 0.04
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
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 worldPos : TEXCOORD1;
                float3 worldNormal : TEXCOORD2;
            };

            fixed4 _BaseBlack;
            fixed4 _CharcoalVein;
            fixed4 _SilverPatch;
            float _Scale;
            float _FlowDistortion;
            float _Softness;
            float _Glossiness;
            float _FresnelPower;
            float _BumpStrength;

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

            // Fungsi untuk menghasilkan nilai pola marmer
            float getMarblePattern(float2 uv)
            {
                float2 q = float2(
                    fbm(uv + float2(0.0, 0.0)),
                    fbm(uv + float2(5.2, 1.3))
                );

                float2 r = float2(
                    fbm(uv + _FlowDistortion * q + float2(1.7, 9.2)),
                    fbm(uv + _FlowDistortion * q + float2(8.3, 2.8))
                );

                return fbm(uv + _FlowDistortion * r);
            }

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.worldNormal = UnityObjectToWorldNormal(v.normal);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float2 uv = i.uv * _Scale;

                // 1. Pola Aliran Marmer Hitam (sama seperti struktur kode 2)
                float rawPattern = getMarblePattern(uv);
                float pattern = pow(saturate(rawPattern), _Softness);

                fixed3 col = lerp(_BaseBlack.rgb, _CharcoalVein.rgb, smoothstep(0.25, 0.65, pattern));
                
                float lightMask = smoothstep(0.55, 0.72, pattern);
                col = lerp(col, _SilverPatch.rgb, lightMask * 0.75);

                // 2. Kalkulasi Fake Normal (agar kilap mengikuti lekuk urat batu)
                float eps = 0.015;
                float hX = getMarblePattern(uv + float2(eps, 0.0)) - rawPattern;
                float hY = getMarblePattern(uv + float2(0.0, eps)) - rawPattern;
                float3 N = normalize(i.worldNormal + float3(hX, 0.0, hY) * _BumpStrength * 10.0);

                // 3. Simulasi Glossy Reflection (Skybox/Environment + Fresnel)
                float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);
                float3 reflDir = reflect(-viewDir, N);

                // Mengambil pantulan langit/environment Unity agar terasa glossy nyata
                half4 skyData = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, reflDir, 1.0);
                half3 skyColor = DecodeHDR(skyData, unity_SpecCube0_HDR);

                // Efek Fresnel (semakin miring sudut pandang kamera ke lantai, semakin mengilap)
                float fresnel = pow(1.0 - saturate(dot(N, viewDir)), _FresnelPower);
                
                // Gabungkan pantulan glossy ke warna hitam dasar
                fixed3 reflection = skyColor * _Glossiness * (0.12 + 0.88 * fresnel);
                col += reflection;

                return fixed4(saturate(col), 1.0);
            }
            ENDCG
        }
    }
}
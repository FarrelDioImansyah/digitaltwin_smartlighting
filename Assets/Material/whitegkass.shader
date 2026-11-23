Shader "Custom/WhiteGlass_Unlit"
{
    Properties
    {
        _TintColor ("Warna Kaca Putih", Color) = (0.95, 0.97, 0.99, 1)
        _EdgeColor ("Warna Tepian / Fresnel Putih", Color) = (0.85, 0.90, 0.95, 1)
        
        [Header(Transparansi dan Refleksi)]
        _BaseOpacity ("Transparansi Dasar (Tengah)", Range(0.05, 0.95)) = 0.25
        _EdgeOpacity ("Kepekatan Tepian (Fresnel)", Range(0.1, 1.0)) = 0.72
        _FresnelPower ("Ketajaman Sudut Fresnel", Range(1.0, 6.0)) = 2.6
        _ReflectionStrength ("Kekuatan Pantulan Cahaya", Range(0.0, 2.0)) = 0.9

        [Header(Kilap dan Efek Kaca Buram)]
        _StreakIntensity ("Intensitas Kilap Diagonal", Range(0.0, 1.0)) = 0.3
        _StreakAngle ("Sudut Garis Kilap", Range(-2.0, 2.0)) = 0.7
        _FrostAmount ("Efek Buram (Frosted Grain)", Range(0.0, 0.15)) = 0.0
    }
    SubShader
    {
        Tags { "Queue"="Transparent" "RenderType"="Transparent" "IgnoreProjector"="True" }
        LOD 100

        ZWrite Off
        Blend SrcAlpha OneMinusSrcAlpha

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

            fixed4 _TintColor;
            fixed4 _EdgeColor;
            float _BaseOpacity;
            float _EdgeOpacity;
            float _FresnelPower;
            float _ReflectionStrength;
            float _StreakIntensity;
            float _StreakAngle;
            float _FrostAmount;

            float hash21(float2 p)
            {
                p = frac(p * float2(127.1, 311.7));
                p += dot(p, p + 34.23);
                return frac(p.x * p.y);
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
                float3 N = normalize(i.worldNormal);
                float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);

                // 1. Efek Fresnel (tepian kaca terlihat lebih putih/reflektif saat dilihat menyamping)
                float ndotv = abs(dot(N, viewDir));
                float fresnel = pow(1.0 - ndotv, _FresnelPower);

                // 2. Pantulan Lingkungan / Skybox Unity
                float3 reflDir = reflect(-viewDir, N);
                half4 skyData = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, reflDir, 0.5);
                half3 skyReflection = DecodeHDR(skyData, unity_SpecCube0_HDR) * _ReflectionStrength;

                // 3. Kilap Garis Diagonal Halus
                float diag = i.uv.x + i.uv.y * _StreakAngle;
                float streak1 = smoothstep(0.38, 0.45, frac(diag * 0.8)) * (1.0 - smoothstep(0.45, 0.52, frac(diag * 0.8)));
                float streak2 = smoothstep(0.54, 0.57, frac(diag * 0.8)) * (1.0 - smoothstep(0.57, 0.60, frac(diag * 0.8)));
                float glare = (streak1 * 0.7 + streak2) * _StreakIntensity;

                // 4. Tekstur Bintik Frosted (opsional untuk kaca es/buram)
                float frostNoise = (hash21(i.uv * 1200.0) - 0.5) * _FrostAmount;

                // 5. Gabungkan warna kaca putih, pantulan, dan kilap
                fixed3 baseGlass = lerp(_TintColor.rgb, _EdgeColor.rgb, fresnel);
                fixed3 finalColor = baseGlass + (skyReflection * (0.25 + 0.75 * fresnel)) + glare + frostNoise;

                // Alpha (transparansi)
                float finalAlpha = saturate(lerp(_BaseOpacity, _EdgeOpacity, fresnel) + glare * 0.5 + length(skyReflection) * 0.12);

                return fixed4(saturate(finalColor), finalAlpha);
            }
            ENDCG
        }
    }
}
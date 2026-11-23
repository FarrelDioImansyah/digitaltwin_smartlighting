Shader "Custom/BlueGlass_Unlit"
{
    Properties
    {
        _TintColor ("Warna Kaca Biru", Color) = (0.12, 0.48, 0.78, 1)
        _EdgeColor ("Warna Tepian / Fresnel Biru Tua", Color) = (0.04, 0.22, 0.45, 1)
        
        [Header(Transparansi dan Refleksi)]
        _BaseOpacity ("Transparansi Dasar (Tengah)", Range(0.05, 0.9)) = 0.28
        _EdgeOpacity ("Kepekatan Tepian (Fresnel)", Range(0.1, 1.0)) = 0.75
        _FresnelPower ("Ketajaman Sudut Fresnel", Range(1.0, 6.0)) = 2.8
        _ReflectionStrength ("Kekuatan Pantulan Langit", Range(0.0, 2.0)) = 0.85

        [Header(Kilap Garis Kaca)]
        _StreakIntensity ("Intensitas Kilap Diagonal", Range(0.0, 1.0)) = 0.25
        _StreakAngle ("Sudut Garis Kilap", Range(-2.0, 2.0)) = 0.7
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

                // 1. Efek Fresnel (semakin miring sudut pandang, kaca makin reflektif & biru pekat)
                float ndotv = abs(dot(N, viewDir));
                float fresnel = pow(1.0 - ndotv, _FresnelPower);

                // 2. Pantulan Lingkungan / Skybox Unity
                float3 reflDir = reflect(-viewDir, N);
                half4 skyData = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, reflDir, 0.5);
                half3 skyReflection = DecodeHDR(skyData, unity_SpecCube0_HDR) * _ReflectionStrength;

                // 3. Kilap Garis Diagonal Halus (Fake Window Glare)
                float diag = i.uv.x + i.uv.y * _StreakAngle;
                float streak1 = smoothstep(0.38, 0.45, frac(diag * 0.8)) * (1.0 - smoothstep(0.45, 0.52, frac(diag * 0.8)));
                float streak2 = smoothstep(0.54, 0.57, frac(diag * 0.8)) * (1.0 - smoothstep(0.57, 0.60, frac(diag * 0.8)));
                float glare = (streak1 * 0.7 + streak2) * _StreakIntensity;

                // 4. Gabungkan warna kaca biru, pantulan, dan kilap
                fixed3 baseGlass = lerp(_TintColor.rgb, _EdgeColor.rgb, fresnel);
                fixed3 finalColor = baseGlass + (skyReflection * (0.25 + 0.75 * fresnel)) + glare;

                // Alpha (transparansi) meningkat di bagian tepi/pantulan agar terasa seperti kaca asli
                float finalAlpha = saturate(lerp(_BaseOpacity, _EdgeOpacity, fresnel) + glare * 0.6 + length(skyReflection) * 0.15);

                return fixed4(saturate(finalColor), finalAlpha);
            }
            ENDCG
        }
    }
}
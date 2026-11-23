Shader "Custom/MatteBlueWallUnlit"
{
    Properties
    {
        _BaseColor ("Warna Tembok Biru", Color) = (0.14, 0.34, 0.62, 1)
        _GrainStrength ("Kekuatan Tekstur Plamir/Doff", Range(0, 0.15)) = 0.035
        _GrainScale ("Kerapatan Tekstur", Float) = 450.0
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
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float3 worldNormal : TEXCOORD1;
                float3 worldPos : TEXCOORD2;
                float4 vertex : SV_POSITION;
            };

            float4 _BaseColor;
            float _GrainStrength;
            float _GrainScale;

            float Hash(float2 p)
            {
                return frac(sin(dot(p, float2(127.1, 311.7))) * 43758.5453123);
            }

            // Smooth noise untuk variasi cat tembok doff agar tidak terlihat seperti noise TV
            float ValueNoise(float2 p)
            {
                float2 i = floor(p);
                float2 f = frac(p);
                f = f * f * (3.0 - 2.0 * f);

                float a = Hash(i);
                float b = Hash(i + float2(1.0, 0.0));
                float c = Hash(i + float2(0.0, 1.0));
                float d = Hash(i + float2(1.0, 1.0));

                return lerp(lerp(a, b, f.x), lerp(c, d, f.x), f.y);
            }

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                o.worldNormal = UnityObjectToWorldNormal(v.normal);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // Menggunakan triplanar/worldPos agar ukuran pori tembok konsisten meski ukuran dinding berbeda-beda
                float2 wallCoord = (abs(i.worldNormal.x) > 0.5) ? i.worldPos.zy :
                                   (abs(i.worldNormal.z) > 0.5) ? i.worldPos.xy : i.worldPos.xz;

                // Kombinasi pori halus dan gelombang plamir cat doff
                float fineGrain = (ValueNoise(wallCoord * (_GrainScale * 0.25)) - 0.5) * _GrainStrength;
                float broadPatch = (ValueNoise(wallCoord * 3.0) - 0.5) * (_GrainStrength * 0.6);

                // Variasi gelap-terang lembut antar sisi tembok (efek doff tanpa kilap specular)
                float matteShade = dot(normalize(i.worldNormal), normalize(float3(0.35, 0.85, 0.45))) * 0.14 + 0.90;

                float3 finalColor = (_BaseColor.rgb * matteShade) + fineGrain + broadPatch;
                return fixed4(finalColor, 1.0);
            }
            ENDCG
        }
    }
}
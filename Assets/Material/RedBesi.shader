Shader "Custom/RedMetalUnlit"
{
    Properties
    {
        _BaseColor ("Warna Merah Besi", Color) = (0.72, 0.11, 0.11, 1)
        _GrainStrength ("Kekuatan Tekstur Besi", Range(0, 0.15)) = 0.03
        _GrainScale ("Skala Tekstur", Float) = 300.0
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
                float4 vertex : SV_POSITION;
            };

            float4 _BaseColor;
            float _GrainStrength;
            float _GrainScale;

            float Hash(float2 p)
            {
                return frac(sin(dot(p, float2(127.1, 311.7))) * 43758.5453123);
            }

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                o.worldNormal = UnityObjectToWorldNormal(v.normal);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // Tekstur grain halus permukaan cat besi
                float grain = (Hash(floor(i.uv * _GrainScale)) - 0.5) * _GrainStrength;

                // Sedikit variasi gelap-terang antar sisi agar sudut boks tetap terlihat jelas meski Unlit
                float fakeShade = dot(normalize(i.worldNormal), normalize(float3(0.4, 0.8, 0.5))) * 0.12 + 0.92;

                float3 finalColor = (_BaseColor.rgb * fakeShade) + grain;
                return fixed4(finalColor, 1.0);
            }
            ENDCG
        }
    }
}
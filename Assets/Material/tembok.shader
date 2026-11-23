Shader "Custom/WhiteWallPlaster_Unlit"
{
    Properties
    {
        _WallColor ("Warna Cat Putih Utama", Color) = (0.95, 0.95, 0.94, 1)
        _ShadowColor ("Warna Bayangan Pori", Color) = (0.87, 0.87, 0.86, 1)
        
        _Scale ("Skala Tekstur Plester", Float) = 35.0
        _BumpStrength ("Kedalaman Tekstur Cat", Range(0.0, 2.0)) = 0.85
        _FineGrain ("Bintik Halus Roller Cat", Range(0.0, 0.1)) = 0.03
        _LightDir ("Arah Cahaya Palsu (XYZ)", Vector) = (-0.4, 0.7, 0.6, 0)
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

            fixed4 _WallColor;
            fixed4 _ShadowColor;
            float _Scale;
            float _BumpStrength;
            float _FineGrain;
            float4 _LightDir;

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

            // Kombinasi multi-layer noise untuk tekstur acian / plester tembok
            float wallHeight(float2 uv)
            {
                float n1 = noise(uv);
                float n2 = noise(uv * 2.3 + float2(4.1, 7.2)) * 0.5;
                float n3 = noise(uv * 5.7 + float2(1.9, 3.4)) * 0.25;
                return (n1 + n2 + n3) / 1.75;
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
                float2 uv = i.uv * _Scale;

                // 1. Hitung ketinggian permukaan plester dan turunan (slope) untuk fake bump
                float eps = 0.05;
                float h  = wallHeight(uv);
                float hx = wallHeight(uv + float2(eps, 0.0));
                float hy = wallHeight(uv + float2(0.0, eps));

                // Rekonstruksi normal permukaan dari tinggi noise
                float3 fakeNormal = normalize(float3((h - hx) * _BumpStrength * 8.0, (h - hy) * _BumpStrength * 8.0, 1.0));
                float3 lightDir = normalize(_LightDir.xyz);

                // 2. Kalkulasi pencahayaan mikro pada benjolan cat
                float diffuse = saturate(dot(fakeNormal, lightDir));
                
                // Gabungkan warna bayangan pori dengan warna cat putih
                float shadeFactor = saturate(h * 0.4 + diffuse * 0.65);
                fixed3 col = lerp(_ShadowColor.rgb, _WallColor.rgb, shadeFactor);

                // 3. Tambahkan tekstur bintik roller cat ultra-halus
                float microGrain = (hash21(i.uv * 1500.0) - 0.5) * _FineGrain;
                col += microGrain;

                return fixed4(saturate(col), 1.0);
            }
            ENDCG
        }
    }
}

Shader "Custom/GreyWallTiles_Unlit"
{
    Properties
    {
        [Header(Warna Dinding Abu Abu)]
        _BaseGrey ("Warna Abu-Abu Utama", Color) = (0.71, 0.72, 0.74, 1)
        _CloudGrey ("Warna Awan Abu-Abu Halus", Color) = (0.76, 0.77, 0.79, 1)
        _GroutColor ("Warna Garis Nat Terang", Color) = (0.87, 0.88, 0.89, 1)
        _GroutShadow ("Warna Bayangan Tepi Nat", Color) = (0.58, 0.59, 0.61, 1)

        [Header(Ukuran Kotak Ubin Dinding)]
        _TilesX ("Jumlah Kolom (Horizontal)", Float) = 3.0
        _TilesY ("Jumlah Baris (Vertikal)", Float) = 4.0
        _GroutWidth ("Ketebalan Garis Nat", Range(0.002, 0.02)) = 0.007
        _GroutIrregularity ("Ketidakrataan Nat Alami", Range(0.0, 0.005)) = 0.0015

        [Header(Tekstur dan Kilap Keramik Dinding)]
        _CloudScale ("Skala Pola Halus", Float) = 3.0
        _Glossiness ("Kilap Halus Keramik (Satin)", Range(0.0, 1.0)) = 0.25
        _FineGrain ("Bintik Mikro Halus", Range(0.0, 0.03)) = 0.01
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

            fixed4 _BaseGrey;
            fixed4 _CloudGrey;
            fixed4 _GroutColor;
            fixed4 _GroutShadow;
            float _TilesX;
            float _TilesY;
            float _GroutWidth;
            float _GroutIrregularity;
            float _CloudScale;
            float _Glossiness;
            float _FineGrain;

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
                    p *= 2.02;
                    amp *= 0.5;
                }
                return v;
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
                // 1. Pembagian Grid Keramik Dinding
                float2 gridScale = float2(_TilesX, _TilesY);
                float2 gridUV = i.uv * gridScale;
                float2 tileID = floor(gridUV);
                float2 tileUV = frac(gridUV);

                // Sedikit variasi kecerahan tipis antar-kotak keramik
                float tileTone = 0.98 + hash21(tileID) * 0.04;

                // 2. Pola Permukaan Abu-Abu Halus (Clouding tipis seperti di gambar)
                float2 randomOffset = float2(hash21(tileID + 3.1), hash21(tileID + 7.4)) * 12.0;
                float cloud = fbm(tileUV * _CloudScale + randomOffset);
                fixed3 wallCol = lerp(_BaseGrey.rgb, _CloudGrey.rgb, cloud) * tileTone;

                // 3. Kilap Satin Halus (mengikuti pantulan lingkungan Unity)
                if (_Glossiness > 0.001)
                {
                    float3 N = normalize(i.worldNormal);
                    float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);
                    float3 reflDir = reflect(-viewDir, N);
                    half4 skyData = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, reflDir, 2.0);
                    half3 skyColor = DecodeHDR(skyData, unity_SpecCube0_HDR);
                    float fresnel = pow(1.0 - abs(dot(N, viewDir)), 2.5);
                    wallCol += skyColor * _Glossiness * (0.15 + 0.85 * fresnel);
                }

                // 4. Garis Nat Putih/Abu Terang dengan sedikit ketidakrataan alami
                float wobble = (noise(i.uv * 45.0) - 0.5) * _GroutIrregularity;
                float2 distEdge = min(tileUV, 1.0 - tileUV) + wobble;
                float minEdge = min(distEdge.x, distEdge.y);

                // Bayangan tipis di pinggiran keramik dekat garis nat
                float edgeShadow = 1.0 - smoothstep(_GroutWidth, _GroutWidth * 2.2, minEdge);
                wallCol = lerp(wallCol, _GroutShadow.rgb, edgeShadow * 0.45);

                // Garis nat utama berwarna lebih terang dari ubin (sesuai foto)
                float groutMask = 1.0 - smoothstep(_GroutWidth * 0.7, _GroutWidth * 1.15, minEdge);
                fixed3 finalCol = lerp(wallCol, _GroutColor.rgb, groutMask);

                // 5. Micro-grain tipis
                float grain = (hash21(i.uv * 1300.0) - 0.5) * _FineGrain;
                finalCol += grain;

                return fixed4(saturate(finalCol), 1.0);
            }
            ENDCG
        }
    }
}
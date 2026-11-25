Shader "Custom/LobbyMarbleGlossyUnlit"
{
    Properties
    {
        [Header(Warna Marmer Krem)]
        _CreamBase ("Warna Dasar Krem", Color) = (0.85, 0.84, 0.79, 1)
        _CreamCloud ("Corak Awan Krem", Color) = (0.76, 0.74, 0.68, 1)

        [Header(Warna Marmer Abu Gelap)]
        _GreyBase ("Warna Dasar Abu Gelap", Color) = (0.31, 0.31, 0.30, 1)
        _GreyShade ("Variasi Gelap Abu", Color) = (0.23, 0.23, 0.22, 1)
        _WhiteVein ("Warna Urat Putih Tajam", Color) = (0.72, 0.73, 0.71, 1)

        [Header(Ukuran dan Pola Ubin)]
        _TileWidth ("Lebar 1 Ubin (Meter)", Float) = 0.6
        _TileLength ("Panjang 1 Ubin (Meter)", Float) = 1.2
        _GroutColor ("Warna Garis Nat", Color) = (0.38, 0.37, 0.35, 1)
        _GroutWidth ("Ketebalan Nat", Range(0.001, 0.015)) = 0.004
        _SwapAxis ("Putar Arah Jalur 90 Derajat (0 atau 1)", Range(0, 1)) = 0

        [Header(Efek Glossy dan Pantulan)]
        _GlossReflect ("Kekuatan Pantulan Glossy", Range(0, 1)) = 0.42
        _FresnelPower ("Ketajaman Pantulan Sudut Pandang", Range(1, 8)) = 3.2
        _SpecularIntensity ("Kilap Lampu Atas", Range(0, 1)) = 0.35
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
                float3 worldPos : TEXCOORD1;
                float3 worldNormal : TEXCOORD2;
                float4 vertex : SV_POSITION;
            };

            float4 _CreamBase;
            float4 _CreamCloud;
            float4 _GreyBase;
            float4 _GreyShade;
            float4 _WhiteVein;

            float _TileWidth;
            float _TileLength;
            float4 _GroutColor;
            float _GroutWidth;
            float _SwapAxis;

            float _GlossReflect;
            float _FresnelPower;
            float _SpecularIntensity;

            float Hash(float2 p)
            {
                return frac(sin(dot(p, float2(127.1, 311.7))) * 43758.5453123);
            }

            float Noise(float2 p)
            {
                float2 i = floor(p);
                float2 f = frac(p);
                f = f * f * (3.0 - 2.0 * f);
                return lerp(lerp(Hash(i), Hash(i + float2(1.0, 0.0)), f.x),
                            lerp(Hash(i + float2(0.0, 1.0)), Hash(i + float2(1.0, 1.0)), f.x), f.y);
            }

            float Fbm(float2 p)
            {
                float v = 0.0;
                float a = 0.5;
                float2x2 rot = float2x2(0.80, 0.60, -0.60, 0.80);
                for (int i = 0; i < 4; i++)
                {
                    v += a * Noise(p);
                    p = mul(rot, p) * 2.05;
                    a *= 0.5;
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
                // Koordinat ubin persegi panjang sejajar (60x120 cm)
                float2 pos = (_SwapAxis > 0.5) ? i.worldPos.zx : i.worldPos.xz;
                float2 tileSize = float2(max(_TileLength, 0.1), max(_TileWidth, 0.1));
                float2 gridUV = pos / tileSize;

                float2 tileID = floor(gridUV);
                float2 localUV = frac(gridUV);

                // 1. Garis nat (Grout) tipis presisi
                float2 distEdge = min(localUV, 1.0 - localUV) * tileSize;
                float minDist = min(distEdge.x, distEdge.y);
                float isTile = smoothstep(_GroutWidth, _GroutWidth + 0.002, minDist);

                // 2. Pola Lantai: Jalur 2 baris abu-abu gelap memotong area marmer krem luas
                // Siklus berulang setiap 9 baris (baris 1 & 2 = abu-abu gelap, sisanya = krem)
                float rowCycle = fmod(abs(tileID.y), 9.0);
                float colCycle = fmod(abs(tileID.x), 8.0);
                bool isGreyMarble = (rowCycle >= 1.0 && rowCycle < 3.0);

                // Tambahan blok aksen abu-abu gelap di sisi seberang (seperti di kanan atas foto)
                if (rowCycle >= 6.0 && rowCycle < 8.0 && colCycle >= 5.0)
                {
                    isGreyMarble = true;
                }

                // 3. Corak Marmer Per Ubin
                float2 seedOffset = float2(Hash(tileID), Hash(tileID + 19.3)) * 12.0;
                float2 marbleCoord = pos * 2.2 + seedOffset;
                float n1 = Fbm(marbleCoord);
                float n2 = Fbm(marbleCoord * 2.5 + n1 * 1.8);

                float3 marbleCol;
                if (isGreyMarble)
                {
                    // Dasar abu-abu berawan lembut
                    marbleCol = lerp(_GreyShade.rgb, _GreyBase.rgb, smoothstep(0.3, 0.75, n1));

                    // Urat retakan putih tipis menyilang (khas marmer abu-abu pada foto)
                    float crack = 1.0 - abs(sin((marbleCoord.x * 0.7 + marbleCoord.y * 1.4) + n2 * 4.5));
                    crack = pow(saturate(crack), 28.0);
                    marbleCol = lerp(marbleCol, _WhiteVein.rgb, crack * 0.65);
                }
                else
                {
                    // Marmer krem dengan corak awan halus
                    float cloud = smoothstep(0.35, 0.75, n2);
                    marbleCol = lerp(_CreamBase.rgb, _CreamCloud.rgb, cloud * 0.55);
                }

                // Variasi tone tipis antar ubin agar tidak seragam mati
                marbleCol += (Hash(tileID) - 0.5) * 0.025;

                // Gabungkan marmer dan nat
                float3 baseSurface = lerp(_GroutColor.rgb, marbleCol, isTile);

                // 4. Efek Glossy Kuat (Pantulan Reflection Probe / Skybox + Fresnel)
                float3 N = normalize(i.worldNormal);
                float3 V = normalize(_WorldSpaceCameraPos - i.worldPos);
                float3 R = reflect(-V, N);

                // Ambil pantulan lingkungan (Reflection Probe / Skybox Unity)
                half4 skyData = UNITY_SAMPLE_TEXCUBE(unity_SpecCube0, R);
                half3 envReflection = DecodeHDR(skyData, unity_SpecCube0_HDR);

                // Fresnel: makin miring sudut kamera melihat lantai, makin kuat pantulan cerminnya
                float fresnel = pow(1.0 - saturate(dot(N, V)), _FresnelPower);
                float reflectFactor = saturate((0.18 + fresnel * 0.82) * _GlossReflect) * isTile;

                float3 finalCol = lerp(baseSurface, envReflection, reflectFactor);

                // Tambahan kilap lampu langit-langit koridor
                float3 lightDir = normalize(float3(0.15, 0.85, 0.5));
                float3 H = normalize(V + lightDir);
                float spec = pow(saturate(dot(N, H)), 96.0);
                finalCol += spec * _SpecularIntensity * isTile;

                return fixed4(finalCol, 1.0);
            }
            ENDCG
        }
    }
}
Shader "Custom/Floor9LobbyGlossyUnlit"
{
    Properties
    {
        [Header(Warna Keramik Lantai 9)]
        _CreamColor ("Warna Keramik Krem", Color) = (0.82, 0.81, 0.76, 1)
        _CreamCloud ("Corak Awan Krem", Color) = (0.72, 0.70, 0.65, 1)
        
        _BrownColor ("Warna Keramik Cokelat Lobi", Color) = (0.28, 0.23, 0.20, 1)
        _BrownCloud ("Corak Awan Cokelat", Color) = (0.21, 0.17, 0.15, 1)
        
        _BlackColor ("Warna Keramik Hitam Pilar", Color) = (0.08, 0.08, 0.09, 1)
        _WhiteVein ("Warna Garis Urat Marmer", Color) = (0.75, 0.76, 0.78, 1)
        _GroutColor ("Warna Nat Keramik", Color) = (0.32, 0.30, 0.28, 1)

        [Header(Pengaturan Pola Urat Marmer)]
        _MarbleScale ("Skala Corak Marmer", Float) = 2.2
        _VeinSharpness ("Ketajaman Garis Urat", Range(10, 60)) = 32.0
        _VeinOpacity ("Ketebalan Urat Putih", Range(0, 1)) = 0.55

        [Header(Ukuran Grid dan Pola)]
        _TileSize ("Ukuran 1 Ubin Kotak (Meter)", Float) = 0.6
        _GroutWidth ("Ketebalan Garis Nat", Range(0.002, 0.02)) = 0.006
        _SwapAxis ("Putar Pola 90 Derajat (0 atau 1)", Range(0, 1)) = 0

        [Header(Efek Glossy dan Pantulan)]
        _GlossReflect ("Kekuatan Pantulan Glossy", Range(0, 1)) = 0.45
        _FresnelPower ("Ketajaman Sudut Pantulan", Range(1, 8)) = 3.0
        _SpecularIntensity ("Kilap Lampu Langit-langit", Range(0, 1)) = 0.30
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

            float4 _CreamColor;
            float4 _CreamCloud;
            float4 _BrownColor;
            float4 _BrownCloud;
            float4 _BlackColor;
            float4 _WhiteVein;
            float4 _GroutColor;

            float _MarbleScale;
            float _VeinSharpness;
            float _VeinOpacity;

            float _TileSize;
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

            // Fractal Brownian Motion untuk menghasilkan gumpalan awan dan kelokan urat marmer
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
                // Koordinat ubin bujur sangkar (60x60 cm)
                float2 pos = (_SwapAxis > 0.5) ? i.worldPos.zx : i.worldPos.xz;
                float size = max(_TileSize, 0.05);
                float2 gridUV = pos / size;

                float2 tileID = floor(gridUV);
                float2 localUV = frac(gridUV);

                // 1. Garis nat (Grout) tipis antar ubin kotak
                float2 distEdge = min(localUV, 1.0 - localUV);
                float minDist = min(distEdge.x, distEdge.y);
                float isTile = smoothstep(_GroutWidth, _GroutWidth + 0.003, minDist);

                // 2. Pola Zonasi Lantai 9 (Siklus 12x16 ubin)
                float col = fmod(abs(tileID.x), 12.0);
                float row = fmod(abs(tileID.y), 16.0);

                // Tipe zona: 0 = Cokelat/Abu Gelap Lobi, 1 = Krem Koridor, 2 = Hitam Pilar
                int zoneType = 0;

                // Jalur koridor utama krem (4 ubin di kiri-tengah, sepanjang 10 baris)
                if (col >= 1.0 && col < 5.0 && row < 10.0)
                {
                    zoneType = 1;
                }

                // Pulau/panel krem persegi di area dalam depan lift (2x3 ubin)
                if (col >= 2.0 && col < 4.0 && row >= 12.0 && row < 15.0)
                {
                    zoneType = 1;
                }

                // Aksen bingkai hitam pekat di sekitar kaki pilar (kiri bawah)
                if ((col < 1.0 && row < 4.0) || (col >= 1.0 && col < 2.0 && row < 1.0))
                {
                    zoneType = 2;
                }

                // 3. Corak Awan Marmer + Garis Urat Tipis Berkelok (seperti gambar referensi)
                float2 seedOffset = float2(Hash(tileID), Hash(tileID + 19.3)) * 15.0;
                float2 marbleCoord = pos * _MarbleScale + seedOffset;
                
                float n1 = Fbm(marbleCoord);
                float n2 = Fbm(marbleCoord * 2.4 + n1 * 1.9);

                // Garis urat tipis berkelok acak (ridge noise)
                float veinWave = sin((marbleCoord.x * 0.7 + marbleCoord.y * 1.3) + n2 * 4.8);
                float thinVein = pow(saturate(1.0 - abs(veinWave)), _VeinSharpness);

                float3 tileCol;
                if (zoneType == 1)
                {
                    // Ubin Krem: dominan corak awan lembut (cloudy)
                    float cloud = smoothstep(0.32, 0.78, n2);
                    tileCol = lerp(_CreamColor.rgb, _CreamCloud.rgb, cloud * 0.65);
                }
                else if (zoneType == 2)
                {
                    // Ubin Hitam Pilar: gelap pekat dengan urat tipis redup
                    float cloud = smoothstep(0.30, 0.75, n1);
                    tileCol = lerp(_BlackColor.rgb, _BlackColor.rgb * 1.35, cloud * 0.4);
                    tileCol = lerp(tileCol, _WhiteVein.rgb, thinVein * (_VeinOpacity * 0.45));
                }
                else
                {
                    // Ubin Cokelat/Abu Gelap: awan lembut + garis urat putih berkelok tajam
                    float cloud = smoothstep(0.30, 0.75, n1);
                    tileCol = lerp(_BrownCloud.rgb, _BrownColor.rgb, cloud);
                    tileCol = lerp(tileCol, _WhiteVein.rgb, thinVein * _VeinOpacity);
                }

                // Variasi kecerahan tipis antar ubin
                tileCol += (Hash(tileID) - 0.5) * 0.02;

                // Gabungkan keramik marmer dan nat
                float3 baseSurface = lerp(_GroutColor.rgb, tileCol, isTile);

                // 4. Efek Glossy (Pantulan Reflection Probe / Skybox + Fresnel)
                float3 N = normalize(i.worldNormal);
                float3 V = normalize(_WorldSpaceCameraPos - i.worldPos);
                float3 R = reflect(-V, N);

                half4 skyData = UNITY_SAMPLE_TEXCUBE(unity_SpecCube0, R);
                half3 envReflection = DecodeHDR(skyData, unity_SpecCube0_HDR);

                float fresnel = pow(1.0 - saturate(dot(N, V)), _FresnelPower);
                float reflectFactor = saturate((0.20 + fresnel * 0.80) * _GlossReflect) * isTile;

                float3 finalCol = lerp(baseSurface, envReflection, reflectFactor);

                // Kilap lampu koridor di permukaan ubin
                float3 lightDir = normalize(float3(0.1, 0.85, 0.5));
                float3 H = normalize(V + lightDir);
                float spec = pow(saturate(dot(N, H)), 80.0);
                finalCol += spec * _SpecularIntensity * isTile;

                return fixed4(finalCol, 1.0);
            }
            ENDCG
        }
    }
}
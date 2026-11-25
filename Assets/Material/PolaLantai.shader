Shader "Custom/MarbleStripeFloorUnlit"
{
    Properties
    {
        _CreamBase ("Marmer Krem - Dasar", Color) = (0.88, 0.86, 0.81, 1)
        _CreamVein ("Marmer Krem - Urat", Color) = (0.76, 0.71, 0.63, 1)
        
        _DarkBase ("Marmer Gelap - Dasar", Color) = (0.23, 0.21, 0.20, 1)
        _DarkVein ("Marmer Gelap - Urat", Color) = (0.42, 0.39, 0.35, 1)
        
        _GroutColor ("Warna Nat Tipis", Color) = (0.35, 0.33, 0.31, 1)

        _StripeWidth ("Lebar 1 Baris Ubin (Meter)", Float) = 0.6
        _TileLength ("Panjang 1 Ubin (Meter)", Float) = 1.2
        _GroutWidth ("Ketebalan Nat", Range(0.001, 0.02)) = 0.006
        
        _GlossStrength ("Kekuatan Pantulan Kilap", Range(0, 1)) = 0.45
        _SpecPower ("Fokus Kilap (Shininess)", Range(10, 128)) = 64.0
        
        _VeinScale ("Kerapatan Urat Marmer", Float) = 15.0
        _SwapAxis ("Tukar Arah Baris (0=Z, 1=X)", Range(0, 1)) = 0
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
                float3 worldNormal : NORMAL;
                float4 vertex : SV_POSITION;
            };

            float4 _CreamBase;
            float4 _CreamVein;
            float4 _DarkBase;
            float4 _DarkVein;
            float4 _GroutColor;

            float _StripeWidth;
            float _TileLength;
            float _GroutWidth;
            float _GlossStrength;
            float _SpecPower;
            float _VeinScale;
            float _SwapAxis;

            // Generator noise untuk urat marmer alami
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

            // Fractal Brownian Motion (fBm) untuk kompleksitas urat marmer
            float fBm(float2 p)
            {
                float v = 0.0;
                float am = 0.5;
                for (int i = 0; i < 4; i++)
                {
                    v += am * Noise(p);
                    p *= 2.14;
                    am *= 0.47;
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
                // Menentukan koordinat horizontal (melintang) & vertikal (memanjang)
                float2 rawPos = (_SwapAxis > 0.5) ? i.worldPos.zx : i.worldPos.xz;
                
                // Koordinat grid ubin persegi panjang
                float2 gridUV = float2(rawPos.x / max(_TileLength, 0.1), rawPos.y / max(_StripeWidth, 0.1));
                
                // ID untuk menentukan baris (untuk warna pola stripe) dan kolom (untuk pergeseran/offset ubin)
                float2 tileID = floor(gridUV);
                float2 tileLocal = frac(gridUV);

                // Pola selang-seling (Stripe): Baris genap krem, baris ganjil abu-abu gelap
                // misal: 2 baris krem, 1 baris gelap, dst. agar mirip aslinya.
                // Disini kita gunakan fmod(baris, 3) -> 0 dan 1 krem, 2 gelap
                float stripePattern = fmod(abs(tileID.y), 3.0);
                bool isDarkTile = (stripePattern >= 2.0);

                // 1. Hitung garis nat (Grout)
                // Deteksi jarak dari tepi ubin lokal (dalam meter)
                float2 distToEdge = tileLocal * float2(_TileLength, _StripeWidth);
                float2 distToEdgeTarget = (1.0 - tileLocal) * float2(_TileLength, _StripeWidth);
                float minEdge = min(min(distToEdge.x, distToEdge.y), min(distToEdgeTarget.x, distToEdgeTarget.y));
                
                float isGrout = smoothstep(_GroutWidth, _GroutWidth + 0.003, minEdge);

                // 2. Efek Corak Marmer Prosedural (Marble Veins)
                // Menggunakan World Position agar coraknya menyambung alami tapi distorsi acak per ubin
                float2 marbleSeed = rawPos + Hash(tileID) * 5.0; // bedakan urat tiap ubin
                float n = fBm(marbleSeed * _VeinScale);
                
                // Efek urat berombak/sinusoidal alami marmer
                float vein = sin(marbleSeed.x * 0.5 + marbleSeed.y * 0.3 + n * 6.5);
                vein = saturate(1.0 - abs(vein));
                vein = pow(vein, 4.0); // buat uratnya menipis dan tajam

                // Tentukan warna berdasarkan jenis ubin
                float3 tileCol;
                if (isDarkTile)
                {
                    // Ubin Gelap
                    tileCol = lerp(_DarkBase.rgb, _DarkVein.rgb, vein * 0.6);
                    // Beri variasi kehitaman/kegelapan acak antar ubin
                    tileCol *= 0.85 + Hash(tileID) * 0.3;
                }
                else
                {
                    // Ubin Krem
                    tileCol = lerp(_CreamBase.rgb, _CreamVein.rgb, vein * 0.5);
                    // Beri variasi kecerahan alami antar ubin
                    tileCol += (Hash(tileID) - 0.5) * 0.04;
                }

                // Campurkan warna marmer dengan nat tipis
                float3 finalCol = lerp(_GroutColor.rgb, tileCol, isGrout);

                // 3. Pantulan Cahaya (Specular) - Sangat krusial untuk marmer kilap (glossy)
                float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);
                // Menghadapkan arah simulasi lampu ke arah lantai dari atas depan
                float3 fakeLightDir = normalize(float3(0.1, 0.9, 0.4));
                float3 halfVec = normalize(viewDir + fakeLightDir);
                
                float spec = pow(saturate(dot(normalize(i.worldNormal), halfVec)), _SpecPower);
                
                // Tambahkan kilap hanya pada ubin (nat/grout lebih doff)
                finalCol += spec * _GlossStrength * isGrout;

                // 4. Tambahkan sedikit fake Reflection dari atas
                float fakeRefl = saturate(0.2 + 0.8 * (1.0 - dot(viewDir, normalize(i.worldNormal))));
                finalCol += _GlossStrength * 0.35 * fakeRefl * isGrout * lerp(_CreamBase.rgb, _DarkVein.rgb, isDarkTile);

                return fixed4(finalCol, 1.0);
            }
            ENDCG
        }
    }
}
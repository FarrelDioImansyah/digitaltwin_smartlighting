Shader "Custom/WoodDoor_Unlit"
{
    Properties
    {
        _WoodLight ("Warna Kayu Terang", Color) = (0.58, 0.36, 0.20, 1)
        _WoodDark ("Warna Serat Kayu Gelap", Color) = (0.32, 0.17, 0.08, 1)
        _PoreColor ("Warna Pori-Pori Kayu", Color) = (0.20, 0.10, 0.04, 1)
        
        [Header(Pola Serat Kayu)]
        _RingScale ("Kepadatan Serat (Rings)", Float) = 12.0
        _StretchY ("Kelurusan Serat Vertikal", Float) = 0.18
        _Distortion ("Gelombang / Mata Kayu", Range(0.5, 5.0)) = 2.2
        _PoreIntensity ("Ketajaman Pori Halus", Range(0.0, 1.0)) = 0.45

        [Header(Sambungan Papan Pintu)]
        _PlankCount ("Jumlah Papan Vertikal", Float) = 3.0
        _GrooveWidth ("Lebar Celah Papan", Range(0.0, 0.05)) = 0.012
        _GrooveDarkness ("Kegelapan Celah Papan", Range(0.0, 1.0)) = 0.65
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

            fixed4 _WoodLight;
            fixed4 _WoodDark;
            fixed4 _PoreColor;
            float _RingScale;
            float _StretchY;
            float _Distortion;
            float _PoreIntensity;
            float _PlankCount;
            float _GrooveWidth;
            float _GrooveDarkness;

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
                    p *= 2.04;
                    amp *= 0.5;
                }
                return v;
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
                // 1. Pembagian Papan Vertikal Pintu (Planks)
                float plankCoord = i.uv.x * _PlankCount;
                float plankID = floor(plankCoord);
                float plankUVx = frac(plankCoord);

                // Offset acak tiap papan agar serat tidak menyambung simetris
                float plankOffset = hash21(float2(plankID, 4.2)) * 25.0;
                // Variasi tipis kecerahan warna tiap bilah papan kayu
                float plankTone = 0.92 + hash21(float2(plankID, 9.1)) * 0.16;

                // 2. Koordinat Serat Kayu (dipanjangkan ke sumbu Y agar serat berdiri vertikal)
                float2 woodUV = float2(plankUVx, i.uv.y * _StretchY) + float2(plankOffset, plankOffset * 0.3);

                // Gelombang organik untuk membentuk lengkungan serat dan mata kayu
                float warp = fbm(woodUV * 2.5) * _Distortion;
                float ringVal = sin((woodUV.x * _RingScale + warp) * 3.14159);
                
                // Pertajam pola cincin kayu (garis gelap lebih tipis daripada bagian terang)
                float grain = pow(abs(ringVal), 0.55);
                fixed3 col = lerp(_WoodDark.rgb, _WoodLight.rgb, grain);

                // 3. Pori-Pori Kayu Halus Memanjang (Micro-pores)
                float2 poreUV = float2(plankUVx * 90.0 + plankOffset, i.uv.y * 8.0);
                float pores = smoothstep(0.72, 0.95, noise(poreUV));
                col = lerp(col, _PoreColor.rgb, pores * _PoreIntensity);

                // Terapkan variasi tone antar papan
                col *= plankTone;

                // 4. Garis Celah Sambungan Papan Pintu (Groove)
                if (_GrooveWidth > 0.0001 && _PlankCount > 1.0)
                {
                    float distEdge = min(plankUVx, 1.0 - plankUVx);
                    float groove = 1.0 - smoothstep(_GrooveWidth * 0.5, _GrooveWidth * 1.5, distEdge);
                    col *= (1.0 - groove * _GrooveDarkness);
                }

                return fixed4(saturate(col), 1.0);
            }
            ENDCG
        }
    }
}
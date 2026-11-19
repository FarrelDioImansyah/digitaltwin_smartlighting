using System;
using System.Collections.Generic;
using System.Text;
using UnityEngine;
using UnityEngine.UI;
using NativeWebSocket;

[Serializable]
public class GedungStatus
{
    public bool relay;
    public string mode;
}

[Serializable]
public class SmartLightingData
{
    public int lux;
    public bool isGelap;
    public int pir;
    public bool latch;
    public GedungStatus gedung1;
    public GedungStatus gedung2;
}

public class DigitalTwinManager : MonoBehaviour
{
    [Header("Konfigurasi MQTT Broker")]
    public string brokerUrl = "wss://broker.hivemq.com:8884/mqtt";
    public string topicStatus = "saw/lantai9/smartlighting/status";
    public string topicCmd = "saw/lantai9/smartlighting/cmd";

    [Header("Pengaturan Auto-Off (Detik)")]
    public float durasiTimeoutGerakan = 10f; // Mati setelah 10 detik tanpa gerakan
    private float timerTanpaGerakan = 0f;
    private bool statusGedung1Aktif = false;
    private SmartLightingData lastData;

    [Header("Objek Lampu Gedung 1 (Koridor SAW Lt. 9)")]
    public Light[] lampuGedung1;
    public Renderer[] meshLampuGedung1;

    [Header("Objek Lampu Gedung 2")]
    public Light[] lampuGedung2;
    public Renderer[] meshLampuGedung2;

    [Header("Visualisasi Manusia & Pencahayaan Ruangan")]
    public GameObject avatarManusiaSelasar;
    public Light cahayaLingkungan;

    [Header("Material Emission")]
    public Color warnaEmissionNyala = new Color(1f, 0.92f, 0.5f) * 2.5f;
    public Color warnaEmissionMati = Color.black;

    [Header("UI Monitoring (Opsional)")]
    public Text textStatusUI;

    private WebSocket websocket;
    private float pingTimer = 0f;

    async void Start()
    {
        websocket = new WebSocket(brokerUrl, new List<string> { "mqtt" });

        websocket.OnOpen += () => {
            Debug.Log("[Unity MQTT] Terhubung ke HiveMQ Broker!");
            SendMqttConnect();
            SendMqttSubscribe(topicStatus);
        };

        websocket.OnError += (e) => Debug.LogError("[Unity MQTT] Error: " + e);
        websocket.OnClose += (e) => Debug.Log("[Unity MQTT] Koneksi ditutup.");
        websocket.OnMessage += (bytes) => ParseMqttPacket(bytes);

        await websocket.Connect();
    }

    void Update()
    {
#if !UNITY_WEBGL || UNITY_EDITOR
        if (websocket != null)
        {
            websocket.DispatchMessageQueue();
        }
#endif
        // Keep-alive PING setiap 20 detik
        if (websocket != null && websocket.State == WebSocketState.Open)
        {
            pingTimer += Time.deltaTime;
            if (pingTimer >= 20f)
            {
                pingTimer = 0f;
                websocket.Send(new byte[] { 0xC0, 0x00 });
            }
        }

        // ===== LOGIKA TIMER 10 DETIK DI UNITY =====
        UpdateLogikaTimeoutUnity();
    }

    private void UpdateLogikaTimeoutUnity()
    {
        if (lastData == null) return;

        // Jalankan logika otomatis hanya jika mode Gedung 1 adalah AUTO
        if (lastData.gedung1.mode == "AUTO")
        {
            if (!lastData.isGelap)
            {
                // Jika ruangan terang, langsung matikan & reset timer
                timerTanpaGerakan = 0f;
                statusGedung1Aktif = false;
            }
            else
            {
                // Ruangan sedang GELAP
                if (lastData.pir == 1)
                {
                    // Ada gerakan -> nyalakan lampu & reset hitung mundur
                    timerTanpaGerakan = 0f;
                    statusGedung1Aktif = true;
                }
                else if (statusGedung1Aktif)
                {
                    // Tidak ada gerakan (pir == 0), tapi lampu masih menyala -> hitung mundur
                    timerTanpaGerakan += Time.deltaTime;

                    if (timerTanpaGerakan >= durasiTimeoutGerakan)
                    {
                        statusGedung1Aktif = false;
                        timerTanpaGerakan = 0f;
                        Debug.Log("[Unity Timer] 10 detik tanpa gerakan -> Mematikan Lampu Gedung 1");
                    }
                }
            }
        }
        else
        {
            // Jika mode MAN-ON atau MAN-OFF, ikuti status manual dari alat
            timerTanpaGerakan = 0f;
            statusGedung1Aktif = lastData.gedung1.relay;
        }

        // Terapkan visual ke Gedung 1 & Avatar Manusia
        SetLampuGedung(lampuGedung1, meshLampuGedung1, statusGedung1Aktif);

        if (avatarManusiaSelasar != null)
        {
            // Avatar muncul selama ada gerakan atau selama hitung mundur belum habis
            avatarManusiaSelasar.SetActive(statusGedung1Aktif && lastData.gedung1.mode == "AUTO");
        }

        UpdateTeksUI();
    }

    private void OnMqttData(string jsonPayload)
    {
        try
        {
            SmartLightingData data = JsonUtility.FromJson<SmartLightingData>(jsonPayload);
            if (data == null) return;

            lastData = data;

            // Gedung 2 langsung mengikuti data dari ESP32
            SetLampuGedung(lampuGedung2, meshLampuGedung2, data.gedung2.relay);

            // Cahaya lingkungan mengikuti Lux
            if (cahayaLingkungan != null)
            {
                float targetIntensity = Mathf.Clamp(data.lux / 500f, 0.15f, 1.2f);
                cahayaLingkungan.intensity = targetIntensity;
            }
        }
        catch (Exception ex)
        {
            Debug.LogWarning("[Unity MQTT] Gagal parsing JSON: " + ex.Message);
        }
    }

    private void UpdateTeksUI()
    {
        if (textStatusUI == null || lastData == null) return;

        string infoTimer = (statusGedung1Aktif && lastData.pir == 0 && lastData.gedung1.mode == "AUTO")
            ? $" (Mati dalam {(durasiTimeoutGerakan - timerTanpaGerakan):F1}s)"
            : "";

        textStatusUI.text = $"Lux: {lastData.lux} lx ({(lastData.isGelap ? "GELAP" : "TERANG")})\n" +
                            $"PIR: {(lastData.pir == 1 ? "ADA GERAKAN" : "DIAM / KOSONG")}\n" +
                            $"Gedung 1: {(statusGedung1Aktif ? "ON" : "OFF")} [{lastData.gedung1.mode}]{infoTimer}\n" +
                            $"Gedung 2: {(lastData.gedung2.relay ? "ON" : "OFF")} [{lastData.gedung2.mode}]";
    }

    private void SetLampuGedung(Light[] lights, Renderer[] renderers, bool isOn)
    {
        foreach (Light l in lights)
        {
            if (l != null) l.enabled = isOn;
        }
        foreach (Renderer r in renderers)
        {
            if (r != null)
            {
                r.material.EnableKeyword("_EMISSION");
                r.material.SetColor("_EmissionColor", isOn ? warnaEmissionNyala : warnaEmissionMati);
            }
        }
    }

    public void KirimPerintahKeESP32(string cmd)
    {
        if (websocket != null && websocket.State == WebSocketState.Open)
        {
            SendMqttPublish(topicCmd, cmd);
            Debug.Log("[Unity -> Wokwi] Mengirim perintah: " + cmd);
        }
    }

    // ===== HELPER PAKET MQTT 3.1.1 RINGAN =====
    private async void SendMqttConnect()
    {
        string clientId = "UnitySAW9_" + UnityEngine.Random.Range(1000, 9999);
        byte[] idBytes = Encoding.UTF8.GetBytes(clientId);
        List<byte> packet = new List<byte> {
            0x10, (byte)(12 + idBytes.Length),
            0x00, 0x04, (byte)'M', (byte)'Q', (byte)'T', (byte)'T',
            0x04, 0x02, 0x00, 0x3C,
            (byte)(idBytes.Length >> 8), (byte)(idBytes.Length & 0xFF)
        };
        packet.AddRange(idBytes);
        await websocket.Send(packet.ToArray());
    }

    private async void SendMqttSubscribe(string topic)
    {
        byte[] topicBytes = Encoding.UTF8.GetBytes(topic);
        List<byte> packet = new List<byte> {
            0x82, (byte)(5 + topicBytes.Length),
            0x00, 0x01,
            (byte)(topicBytes.Length >> 8), (byte)(topicBytes.Length & 0xFF)
        };
        packet.AddRange(topicBytes);
        packet.Add(0x00);
        await websocket.Send(packet.ToArray());
    }

    private async void SendMqttPublish(string topic, string message)
    {
        byte[] topicBytes = Encoding.UTF8.GetBytes(topic);
        byte[] msgBytes = Encoding.UTF8.GetBytes(message);
        int remainingLength = 2 + topicBytes.Length + msgBytes.Length;

        List<byte> packet = new List<byte> { 0x30 };
        do
        {
            byte encodedByte = (byte)(remainingLength % 128);
            remainingLength /= 128;
            if (remainingLength > 0) encodedByte |= 128;
            packet.Add(encodedByte);
        } while (remainingLength > 0);

        packet.Add((byte)(topicBytes.Length >> 8));
        packet.Add((byte)(topicBytes.Length & 0xFF));
        packet.AddRange(topicBytes);
        packet.AddRange(msgBytes);
        await websocket.Send(packet.ToArray());
    }

    private void ParseMqttPacket(byte[] data)
    {
        if (data.Length < 4) return;
        if ((data[0] & 0xF0) == 0x30)
        {
            int multiplier = 1;
            int value = 0;
            int index = 1;
            byte encodedByte;
            do
            {
                if (index >= data.Length) return;
                encodedByte = data[index++];
                value += (encodedByte & 127) * multiplier;
                multiplier *= 128;
            } while ((encodedByte & 128) != 0);

            if (index + 2 > data.Length) return;
            int topicLen = (data[index] << 8) | data[index + 1];
            index += 2 + topicLen;

            if (((data[0] >> 1) & 0x03) > 0) index += 2;

            if (index < data.Length)
            {
                string payload = Encoding.UTF8.GetString(data, index, data.Length - index);
                OnMqttData(payload);
            }
        }
    }

    private async void OnApplicationQuit()
    {
        if (websocket != null)
        {
            await websocket.Close();
        }
    }
}
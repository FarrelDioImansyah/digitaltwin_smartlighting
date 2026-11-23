using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using TMPro; // Wajib untuk TextMeshPro Dropdown

public class CameraCurveSwitcher : MonoBehaviour
{
    [System.Serializable]
    public class CameraAnglePath
    {
        public string namaAngle = "Angle Baru";
        [Tooltip("Titik tujuan akhir kamera (Empty GameObject)")]
        public Transform targetPoint;

        [Tooltip("Titik kontrol 1 untuk menarik lengkungan keluar dari posisi awal")]
        public Transform controlPoint1;

        [Tooltip("Titik kontrol 2 untuk menarik lengkungan masuk ke posisi tujuan")]
        public Transform controlPoint2;

        [Tooltip("Durasi perjalanan kamera di jalur ini (detik)")]
        public float durasiGerak = 2.5f;
    }

    [Header("Daftar Angle & Jalur Curve")]
    public List<CameraAnglePath> daftarAngle = new List<CameraAnglePath>();

    [Header("UI Navigasi")]
    [Tooltip("Masukkan TMP_Dropdown dari Canvas di sini")]
    public TMP_Dropdown locationDropdown;

    [Header("Pengaturan Mode Otomatis")]
    [Tooltip("Centang jika ingin kamera otomatis berkeliling sendiri")]
    public bool autoSwitch = false;
    [Tooltip("Jeda waktu sebelum pindah otomatis ke angle berikutnya (detik)")]
    public float intervalPindah = 5f;
    public bool loop = true;

    private int currentIndex = 0;
    private Coroutine activeMoveCoroutine;
    private Coroutine autoSwitchCoroutine;

    void Start()
    {
        SetupDropdown();

        if (daftarAngle.Count > 0 && daftarAngle[0].targetPoint != null)
        {
            // Set posisi & rotasi awal kamera sesuai angle pertama
            transform.position = daftarAngle[0].targetPoint.position;
            transform.rotation = daftarAngle[0].targetPoint.rotation;

            if (autoSwitch)
            {
                autoSwitchCoroutine = StartCoroutine(AutoSwitchRoutine());
            }
        }
    }

    // Mengisi opsi Dropdown otomatis dari daftarAngle
    void SetupDropdown()
    {
        if (locationDropdown == null) return;

        locationDropdown.ClearOptions();
        List<string> options = new List<string>();

        foreach (var angle in daftarAngle)
        {
            options.Add(angle.namaAngle);
        }

        locationDropdown.AddOptions(options);
        locationDropdown.value = 0;
        locationDropdown.RefreshShownValue();

        // Daftarkan event saat user memilih item di dropdown
        locationDropdown.onValueChanged.AddListener(PindahKeIndex);
    }

    // Fungsi utama untuk dipanggil oleh Dropdown atau Button (berdasarkan Index)
    public void PindahKeIndex(int targetIndex)
    {
        if (targetIndex < 0 || targetIndex >= daftarAngle.Count) return;
        if (targetIndex == currentIndex && activeMoveCoroutine == null) return;

        // Hentikan mode auto-switch jika user mengambil alih kontrol lewat UI
        if (autoSwitchCoroutine != null)
        {
            StopCoroutine(autoSwitchCoroutine);
            autoSwitchCoroutine = null;
        }

        // Hentikan pergerakan curve yang sedang berjalan agar tidak tabrakan
        if (activeMoveCoroutine != null)
        {
            StopCoroutine(activeMoveCoroutine);
        }

        currentIndex = targetIndex;

        // Sinkronkan tampilan teks Dropdown jika dipicu lewat tombol Next/Prev
        if (locationDropdown != null && locationDropdown.value != targetIndex)
        {
            locationDropdown.SetValueWithoutNotify(targetIndex);
        }

        activeMoveCoroutine = StartCoroutine(MoveAlongCurve(daftarAngle[targetIndex]));
    }

    // Fungsi opsional jika ingin memakai tombol UI "Next" & "Previous"
    public void PindahBerikutnya()
    {
        int nextIndex = currentIndex + 1;
        if (nextIndex >= daftarAngle.Count)
        {
            if (loop) nextIndex = 0;
            else return;
        }
        PindahKeIndex(nextIndex);
    }

    public void PindahSebelumnya()
    {
        int prevIndex = currentIndex - 1;
        if (prevIndex < 0)
        {
            if (loop) prevIndex = daftarAngle.Count - 1;
            else return;
        }
        PindahKeIndex(prevIndex);
    }

    IEnumerator AutoSwitchRoutine()
    {
        while (true)
        {
            yield return new WaitForSeconds(intervalPindah);

            int nextIndex = currentIndex + 1;
            if (nextIndex >= daftarAngle.Count)
            {
                if (loop) nextIndex = 0;
                else yield break;
            }

            currentIndex = nextIndex;
            if (locationDropdown != null)
            {
                locationDropdown.SetValueWithoutNotify(nextIndex);
            }

            activeMoveCoroutine = StartCoroutine(MoveAlongCurve(daftarAngle[nextIndex]));
            yield return activeMoveCoroutine;
        }
    }

    IEnumerator MoveAlongCurve(CameraAnglePath path)
    {
        if (path.targetPoint == null) yield break;

        Vector3 p0 = transform.position;
        Quaternion startRot = transform.rotation;

        Vector3 p3 = path.targetPoint.position;
        Quaternion endRot = path.targetPoint.rotation;

        Vector3 p1 = path.controlPoint1 != null ? path.controlPoint1.position : Vector3.Lerp(p0, p3, 0.33f);
        Vector3 p2 = path.controlPoint2 != null ? path.controlPoint2.position : Vector3.Lerp(p0, p3, 0.66f);

        float elapsed = 0f;
        while (elapsed < path.durasiGerak)
        {
            elapsed += Time.deltaTime;
            float t = Mathf.Clamp01(elapsed / path.durasiGerak);
            float smoothT = Mathf.SmoothStep(0f, 1f, t);

            transform.position = CalculateCubicBezier(smoothT, p0, p1, p2, p3);
            transform.rotation = Quaternion.Slerp(startRot, endRot, smoothT);

            yield return null;
        }

        transform.position = p3;
        transform.rotation = endRot;
        activeMoveCoroutine = null;
    }

    Vector3 CalculateCubicBezier(float t, Vector3 p0, Vector3 p1, Vector3 p2, Vector3 p3)
    {
        float u = 1f - t;
        float tt = t * t;
        float uu = u * u;
        float uuu = uu * u;
        float ttt = tt * t;

        Vector3 point = uuu * p0;
        point += 3f * uu * t * p1;
        point += 3f * u * tt * p2;
        point += ttt * p3;
        return point;
    }

    void OnDrawGizmos()
    {
        if (daftarAngle == null || daftarAngle.Count < 2) return;

        for (int i = 0; i < daftarAngle.Count; i++)
        {
            int prevIndex = (i == 0) ? daftarAngle.Count - 1 : i - 1;
            if (!loop && i == 0) continue;

            var startNode = daftarAngle[prevIndex].targetPoint;
            var endNode = daftarAngle[i].targetPoint;

            if (startNode == null || endNode == null) continue;

            Vector3 p0 = startNode.position;
            Vector3 p3 = endNode.position;
            Vector3 p1 = daftarAngle[i].controlPoint1 != null ? daftarAngle[i].controlPoint1.position : Vector3.Lerp(p0, p3, 0.33f);
            Vector3 p2 = daftarAngle[i].controlPoint2 != null ? daftarAngle[i].controlPoint2.position : Vector3.Lerp(p0, p3, 0.66f);

            Gizmos.color = Color.cyan;
            Vector3 prevPoint = p0;
            for (int step = 1; step <= 25; step++)
            {
                float t = step / 25f;
                Vector3 currentPoint = CalculateCubicBezier(t, p0, p1, p2, p3);
                Gizmos.DrawLine(prevPoint, currentPoint);
                prevPoint = currentPoint;
            }

            Gizmos.color = Color.yellow;
            Gizmos.DrawLine(p0, p1);
            Gizmos.DrawLine(p3, p2);
        }
    }
}
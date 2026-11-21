using System.Collections;
using System.Collections.Generic;
using UnityEngine;

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

    [Header("Pengaturan Waktu")]
    [Tooltip("Jeda waktu sebelum pindah ke angle berikutnya (detik)")]
    public float intervalPindah = 5f;
    public bool loop = true;

    private int currentIndex = 0;

    void Start()
    {
        if (daftarAngle.Count > 0 && daftarAngle[0].targetPoint != null)
        {
            // Set posisi & rotasi awal kamera sesuai angle pertama
            transform.position = daftarAngle[0].targetPoint.position;
            transform.rotation = daftarAngle[0].targetPoint.rotation;

            StartCoroutine(AutoSwitchRoutine());
        }
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

            yield return StartCoroutine(MoveAlongCurve(daftarAngle[nextIndex]));
            currentIndex = nextIndex;
        }
    }

    IEnumerator MoveAlongCurve(CameraAnglePath path)
    {
        if (path.targetPoint == null) yield break;

        Vector3 p0 = transform.position;
        Quaternion startRot = transform.rotation;

        Vector3 p3 = path.targetPoint.position;
        Quaternion endRot = path.targetPoint.rotation;

        // Jika Control Point tidak diisi, otomatis buat titik tengah lurus
        Vector3 p1 = path.controlPoint1 != null ? path.controlPoint1.position : Vector3.Lerp(p0, p3, 0.33f);
        Vector3 p2 = path.controlPoint2 != null ? path.controlPoint2.position : Vector3.Lerp(p0, p3, 0.66f);

        float elapsed = 0f;
        while (elapsed < path.durasiGerak)
        {
            elapsed += Time.deltaTime;
            float t = Mathf.Clamp01(elapsed / path.durasiGerak);

            // SmoothStep agar akselerasi awal & pengereman akhir halus (ease-in-out)
            float smoothT = Mathf.SmoothStep(0f, 1f, t);

            // Hitung posisi & rotasi di jalur Bezier Curve
            transform.position = CalculateCubicBezier(smoothT, p0, p1, p2, p3);
            transform.rotation = Quaternion.Slerp(startRot, endRot, smoothT);

            yield return null;
        }

        transform.position = p3;
        transform.rotation = endRot;
    }

    // Rumus Cubic Bezier Curve
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

    // Visualisasi garis curve di Scene View agar mudah diatur
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

            // Garis bantu kuning ke Control Points
            Gizmos.color = Color.yellow;
            Gizmos.DrawLine(p0, p1);
            Gizmos.DrawLine(p3, p2);
        }
    }
}
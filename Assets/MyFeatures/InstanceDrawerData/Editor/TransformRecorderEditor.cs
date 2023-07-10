using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using System.IO;

[CustomEditor(typeof(TransformRecorder))]
public class TransformRecorderEditor : Editor {
    public override void OnInspectorGUI() {
        TransformRecorder transformRecorder = (TransformRecorder)target;

        if (GUILayout.Button("SetTransformInfo")) {
            transformRecorder.transformInfo.Clear();
            string original = transformRecorder.text.text;

            string[] arr = original.Split('\n');
            for (int i = 0; i < arr.Length - 1; i++) {
                string[] temp = arr[i].Split(' ');

                //pos
                temp[1] = temp[1].Remove(0, 1);
                temp[1] = temp[1].Remove(temp[1].Length - 1, 1);
                temp[2] = temp[2].Remove(temp[2].Length - 1, 1);
                temp[3] = temp[3].Remove(temp[3].Length - 1, 1);
                Vector3 pos = new Vector4(-float.Parse(temp[1]), float.Parse(temp[2]), float.Parse(temp[3]), 0f);

                //orient
                temp[4] = temp[4].Remove(0, 1);
                temp[4] = temp[4].Remove(temp[4].Length - 1, 1);
                temp[5] = temp[5].Remove(temp[5].Length - 1, 1);
                temp[6] = temp[6].Remove(temp[6].Length - 1, 1);
                temp[7] = temp[7].Remove(temp[7].Length - 1, 1);
                Quaternion rotate = new Quaternion(-float.Parse(temp[4]), float.Parse(temp[5]), float.Parse(temp[6]), -float.Parse(temp[7]));

                //scale
                Vector3 scale = float.Parse(temp[8]) * Vector3.one;

                transformRecorder.transformInfo.Add(Matrix4x4.TRS(pos, rotate, scale));
            }
        }
        base.OnInspectorGUI();
        EditorGUILayout.LabelField(transformRecorder.transformInfo.Count.ToString());
    }
}

using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[DisallowMultipleComponent]
[ExecuteInEditMode]
public class PostManager : MonoBehaviour {
    [SerializeField] int m_SetIndex = 0;
    [SerializeField] VolumeProfile[] m_Profiles;
    int m_CurrentProfileIndex = 0;
    Volume volume;
    void OnEnable() {
        volume = FindObjectOfType<Volume>();
    }

    public void SetProfile(int setIndex) {
        if (volume != null && m_SetIndex != m_CurrentProfileIndex) {
            if (setIndex >= 0 && setIndex < m_Profiles.Length) {
                volume.sharedProfile = m_Profiles[setIndex];
                m_CurrentProfileIndex = setIndex;
            }
        }
    }

    void Update() {
        SetProfile(m_SetIndex);
    }

}

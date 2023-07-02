using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
#if UNITY_EDITOR
using UnityEditor;
using UnityEditor.ProjectWindowCallback;
#endif


public class MilesRendererData : ScriptableRendererData {
    [System.Serializable, ReloadGroup]
    public sealed class ShaderResources {
        [Reload("Shaders/Utils/Blit.shader")]
        public Shader blitPixelShader;
    }

    public ShaderResources shaderResources = null;

    [SerializeField]
    LayerMask m_OpaqueLayerMask = -1;
    public LayerMask opaqueLayerMask {
        get => m_OpaqueLayerMask;
        set {
            SetDirty();
            m_OpaqueLayerMask = value;
        }
    }

    [SerializeField]
    StencilStateData m_DefaultStencilState = new StencilStateData();
    public StencilStateData defaulStencilState {
        get => m_DefaultStencilState;
        set {
            SetDirty();
            m_DefaultStencilState = value;
        }
    }

#if UNITY_EDITOR
    internal class CreateMilesRendererAsset : EndNameEditAction {
        public override void Action(int instanceId, string pathName, string resourceFile) {
            var instance = CreateInstance<MilesRendererData>();
            AssetDatabase.CreateAsset(instance, pathName);
            ResourceReloader.ReloadAllNullIn(instance, UniversalRenderPipelineAsset.packagePath);
            Selection.activeObject = instance;
        }
    }
#endif
    protected override ScriptableRenderer Create() {
#if UNITY_EDITOR
        if (!Application.isPlaying) {
            ResourceReloader.TryReloadAllNullIn(this, UniversalRenderPipelineAsset.packagePath);
        }
#endif
        return new MilesRenderer(this);
    }
#if UNITY_EDITOR
    [MenuItem("Assets/Create/Rendering/Universal Render Pipeline/Miles Renderer", priority = CoreUtils.assetCreateMenuPriority2)]
    static void CreateMilesRendererData() {
        ProjectWindowUtil.StartNameEditingIfProjectWindowExists(0, CreateInstance<CreateMilesRendererAsset>(), "CustomMilesRendererData.asset", null, null);
    }
#endif

    protected override void OnEnable() {
        base.OnEnable();
        if (shaderResources == null) {
            return;
        }
    }
}

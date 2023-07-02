using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering.Universal.Internal;

public class MilesBlitPass : ScriptableRenderPass {
    const string m_ProfilerTag = "Miles Blit Pass";
    RenderTargetHandle m_Source;
    Material m_MilesBlitMaterial;
    TextureDimension m_TargetDimension;
    public MilesBlitPass(RenderPassEvent passEvent, Material blitMaterial) {
        m_MilesBlitMaterial = blitMaterial;
        renderPassEvent = passEvent;
    }

    public void Setup(RenderTextureDescriptor descriptor, RenderTargetHandle colorSourceHandle) {
        m_Source = colorSourceHandle;
        m_TargetDimension = descriptor.dimension;
    }

    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData) {
        if (m_MilesBlitMaterial == null) {
            Debug.LogAssertionFormat("Missing {0}. {1} render pass will not execute. Check for missing reference in the renderer resources.", m_MilesBlitMaterial, GetType().Name);
            return;
        }

        ref CameraData cameraData = ref renderingData.cameraData;
        RenderTargetIdentifier finalTarget = (cameraData.targetTexture != null) ? new RenderTargetIdentifier(cameraData.targetTexture) : BuiltinRenderTextureType.CameraTarget;
        bool requiresSRGBConvertion = Display.main.requiresSrgbBlitToBackbuffer;
        bool isSceneViewCamera = cameraData.isSceneViewCamera;

        CommandBuffer cmd = CommandBufferPool.Get(m_ProfilerTag);

        // any keyword needed?
        if (requiresSRGBConvertion) {
            cmd.EnableShaderKeyword(ShaderKeywordStrings.LinearToSRGBConversion);
        } else {
            cmd.DisableShaderKeyword(ShaderKeywordStrings.LinearToSRGBConversion);
        }

        // any property needed?
        cmd.SetGlobalTexture("_BlitSource", m_Source.Identifier());

        if (isSceneViewCamera || cameraData.isDefaultViewport) {
            // set target first
            cmd.SetRenderTarget(BuiltinRenderTextureType.CameraTarget, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.DontCare);
            // draw
            cmd.Blit(m_Source.Identifier(), finalTarget);
        } else {
        }

        context.ExecuteCommandBuffer(cmd);
        CommandBufferPool.Release(cmd);
    }
}

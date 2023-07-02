using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering.Universal.Internal;

public class MilesRenderer : ScriptableRenderer {
    const string k_CreateCameraTextures = "Create Camera Texture By Miles";
    StencilState m_DefaultStencilState;
    RenderTargetHandle m_ActiveCameraColorAttachment;
    RenderTargetHandle m_CameraColorAttachmentByMiles;
    DrawObjectsPass m_RenderOpaqueForwardPass;
    FinalBlitPass m_FinalBlitPass;
    MilesBlitPass m_MilesBlitPass;
    DrawSkyboxPass m_DrawSkyboxPass;
    Material m_BlitMaterial;
    Material m_MilesBlitMaterial;

    public MilesRenderer(MilesRendererData data) : base(data) {
        m_BlitMaterial = CoreUtils.CreateEngineMaterial(data.shaderResources.blitPixelShader);
        m_MilesBlitMaterial = CoreUtils.CreateEngineMaterial(Shader.Find("Hidden/Universal Render Pipeline/Miles/MilesBlit"));
        StencilStateData stencilStateData = data.defaulStencilState;
        m_RenderOpaqueForwardPass = new DrawObjectsPass("Render Opaque Objects By Miles", true, RenderPassEvent.BeforeRenderingOpaques, RenderQueueRange.opaque, data.opaqueLayerMask, m_DefaultStencilState, stencilStateData.stencilReference);
        m_FinalBlitPass = new FinalBlitPass(RenderPassEvent.AfterRendering + 1, m_BlitMaterial);
        m_MilesBlitPass = new MilesBlitPass(RenderPassEvent.AfterRendering + 1, m_MilesBlitMaterial);
        m_DrawSkyboxPass = new DrawSkyboxPass(RenderPassEvent.BeforeRenderingSkybox);
        m_CameraColorAttachmentByMiles.Init("_CameraColorAttachmentByMiles");
    }

    public override void Setup(ScriptableRenderContext context, ref RenderingData renderingData) {

        ref CameraData cameraData = ref renderingData.cameraData;
        bool isPreviewCamera = cameraData.isPreviewCamera;
        bool createColorTexture = RequiresIntermediateColorTexture(ref cameraData);
        /*
        * if the LEFT is true, expression is always true, no matter the RIGHT is true or false
        * if the LEFT is false, expression is true only when the RIGHT is true
        */
        createColorTexture |= (rendererFeatures.Count != 0);

        /*
        * if the LEFT is true, expression is true only when the RIGHT is true
        * if the LEFT is false, expression is always false
        */
        createColorTexture &= !isPreviewCamera;

#if UNITY_ANDROID || UNITY_WEBGL
        if(SystemInfo.graphicsDeviceType != GraphicsDeviceType.Vulkan) {
        }
#endif
        if (cameraData.renderType == CameraRenderType.Base) {
            m_ActiveCameraColorAttachment = (createColorTexture) ? m_CameraColorAttachmentByMiles : RenderTargetHandle.CameraTarget;
            bool intermediateRenderTexture = createColorTexture;
            if (createColorTexture) {
                CreateCameraRenderTarget(context, ref renderingData.cameraData);
            }

        } else {
            m_ActiveCameraColorAttachment = m_CameraColorAttachmentByMiles;
        }

        // no new depth?
        ConfigureCameraTarget(m_ActiveCameraColorAttachment.Identifier(), BuiltinRenderTextureType.CameraTarget);

        EnqueuePass(m_RenderOpaqueForwardPass);

        Skybox cameraSkybox;
        cameraData.camera.TryGetComponent<Skybox>(out cameraSkybox);
        bool isOverlayCamera = cameraData.renderType == CameraRenderType.Overlay;
        if (cameraData.camera.clearFlags == CameraClearFlags.Skybox && (RenderSettings.skybox != null || cameraSkybox?.material != null) && !isOverlayCamera) {
            EnqueuePass(m_DrawSkyboxPass);
        }

        bool lastCameraInTheStack = cameraData.resolveFinalTarget;
        if (lastCameraInTheStack) {
            var sourceForFinalPass = m_ActiveCameraColorAttachment;
            bool cameraTargetResolved =
                m_ActiveCameraColorAttachment == RenderTargetHandle.CameraTarget;
            if (!cameraTargetResolved) {
                //m_FinalBlitPass.Setup(renderingData.cameraData.cameraTargetDescriptor, sourceForFinalPass);
                //EnqueuePass(m_FinalBlitPass);
                m_MilesBlitPass.Setup(renderingData.cameraData.cameraTargetDescriptor, sourceForFinalPass);
                EnqueuePass(m_MilesBlitPass);
            }
        }
    }

    protected override void Dispose(bool disposing) {
        CoreUtils.Destroy(m_BlitMaterial);
        CoreUtils.Destroy(m_MilesBlitMaterial);
    }

    public override void FinishRendering(CommandBuffer cmd) {
        if (m_ActiveCameraColorAttachment != RenderTargetHandle.CameraTarget) {
            cmd.ReleaseTemporaryRT(m_ActiveCameraColorAttachment.id);
            m_ActiveCameraColorAttachment = RenderTargetHandle.CameraTarget;
        }
    }

    void CreateCameraRenderTarget(ScriptableRenderContext context, ref CameraData cameraData) {
        // this name shows in renderdoc
        CommandBuffer cmd = CommandBufferPool.Get(k_CreateCameraTextures);
        var descriptor = cameraData.cameraTargetDescriptor;
        int msaaSamples = descriptor.msaaSamples;

        if (m_ActiveCameraColorAttachment != RenderTargetHandle.CameraTarget) {
            var colorDescriptor = descriptor;
            colorDescriptor.useMipMap = false;
            colorDescriptor.autoGenerateMips = false;
            colorDescriptor.depthBufferBits = 24;
            cmd.GetTemporaryRT(m_CameraColorAttachmentByMiles.id, colorDescriptor, FilterMode.Point);
        }
        context.ExecuteCommandBuffer(cmd);
        CommandBufferPool.Release(cmd);
    }

    bool RequiresIntermediateColorTexture(ref CameraData cameraData) {
        return cameraData.isHdrEnabled;
    }

}

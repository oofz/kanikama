﻿Shader "Kanikama/LightmapComposite"
{
    Properties
    {
        _Tex2DArray("_Tex2DArray", 2DArray) = "" {}
        _TexCount("_TexCount", int) = 0
    }
    SubShader
    {
        Tags { "RenderType" = "Opaque" }
        LOD 100

        Pass
        {

            CGPROGRAM
            #pragma vertex CustomRenderTextureVertexShader
            #pragma fragment frag
            #include "UnityCustomRenderTexture.cginc"
            #include "LightmapComposite.hlsl"
            ENDCG
        }
    }
}

// This is a modification of UnityGlobalIllumination.cginc from
// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)
#ifndef KANIKAMA_GLOBAL_ILLUMINATION_INCLUDED
    #define KANIKAMA_GLOBAL_ILLUMINATION_INCLUDED
    #include "UnityGlobalIllumination.cginc"
    #include "../CGIncludes/KanikamaComposite.hlsl"

    inline UnityGI KanikamaGI_Base(UnityGIInput data, half occlusion, half3 normalWorld)
    {
        UnityGI o_gi;
        ResetUnityGI(o_gi);

        // Base pass with Lightmap support is responsible for handling ShadowMask / blending here for performance reason
        #if defined(HANDLE_SHADOWS_BLENDING_IN_GI)
            half bakedAtten = UnitySampleBakedOcclusion(data.lightmapUV.xy, data.worldPos);
            float zDist = dot(_WorldSpaceCameraPos - data.worldPos, UNITY_MATRIX_V[2].xyz);
            float fadeDist = UnityComputeShadowFadeDistance(data.worldPos, zDist);
            data.atten = UnityMixRealtimeAndBakedShadows(data.atten, bakedAtten, UnityComputeShadowFade(fadeDist));
        #endif

        o_gi.light = data.light;
        o_gi.light.color *= data.atten;

        #if UNITY_SHOULD_SAMPLE_SH
            o_gi.indirect.diffuse = ShadeSHPerPixel(normalWorld, data.ambient, data.worldPos);
        #endif

        #if defined(LIGHTMAP_ON)
            // Baked lightmaps
            half4 bakedColorTex = UNITY_SAMPLE_TEX2D(unity_Lightmap, data.lightmapUV.xy);
            half3 bakedColor = DecodeLightmap(bakedColorTex);

            #ifdef DIRLIGHTMAP_COMBINED
                fixed4 bakedDirTex = UNITY_SAMPLE_TEX2D_SAMPLER (unity_LightmapInd, unity_Lightmap, data.lightmapUV.xy);
                o_gi.indirect.diffuse += DecodeDirectionalLightmap (bakedColor, bakedDirTex, normalWorld);

                #if defined(LIGHTMAP_SHADOW_MIXING) && !defined(SHADOWS_SHADOWMASK) && defined(SHADOWS_SCREEN)
                    ResetUnityLight(o_gi.light);
                    o_gi.indirect.diffuse = SubtractMainLightWithRealtimeAttenuationFromLightmap (o_gi.indirect.diffuse, data.atten, bakedColorTex, normalWorld);
                #endif

            #else // not directional lightmap
                o_gi.indirect.diffuse += bakedColor;

                #if defined(LIGHTMAP_SHADOW_MIXING) && !defined(SHADOWS_SHADOWMASK) && defined(SHADOWS_SCREEN)
                    ResetUnityLight(o_gi.light);
                    o_gi.indirect.diffuse = SubtractMainLightWithRealtimeAttenuationFromLightmap(o_gi.indirect.diffuse, data.atten, bakedColorTex, normalWorld);
                #endif

            #endif
        #endif

        #ifdef DYNAMICLIGHTMAP_ON
            // Dynamic lightmaps
            fixed4 realtimeColorTex = UNITY_SAMPLE_TEX2D(unity_DynamicLightmap, data.lightmapUV.zw);
            half3 realtimeColor = DecodeRealtimeLightmap (realtimeColorTex);

            #ifdef DIRLIGHTMAP_COMBINED
                half4 realtimeDirTex = UNITY_SAMPLE_TEX2D_SAMPLER(unity_DynamicDirectionality, unity_DynamicLightmap, data.lightmapUV.zw);
                o_gi.indirect.diffuse += DecodeDirectionalLightmap (realtimeColor, realtimeDirTex, normalWorld);
            #else
                o_gi.indirect.diffuse += realtimeColor;
            #endif
        #endif
    
        // custom lightmap array
        #if defined(_KANIKAMA_MODE_SINGLE)
            o_gi.indirect.diffuse += KanikamaSampleLightmap(data.lightmapUV.xy);
        #elif defined(_KANIKAMA_MODE_ARRAY)
            o_gi.indirect.diffuse += KanikamaSampleLightmapArray(data.lightmapUV.xy);
        #elif defined(_KANIKAMA_MODE_DIRECTIONAL) && !defined(_KANIKAMA_SPECULAR)
            o_gi.indirect.diffuse += KanikamaSampleDirectionalLightmapArray(data.lightmapUV.xy, normalWorld);
        #endif

        o_gi.indirect.diffuse *= occlusion;
        return o_gi;
    }


#if defined(_KANIKAMA_MODE_DIRECTIONAL) && defined(_KANIKAMA_SPECULAR)
    // Directional lightmap specular based on BakeryDirectionalLightmapSpecular in Bakery.cginc by Mr F
    // https://geom.io/bakery/wiki/
    inline void KanikamaDirectionalLightmapSpecular(float2 lightmapUV, half3 normalWorld, half3 viewDir, half roughness, half occulsion, out half3 diffuse, out half3 specular)
    {
        for (int i = 0; i < knkm_Count; i++)
        {
            half3 bakedColor = DecodeLightmap(UNITY_SAMPLE_TEX2DARRAY(knkm_LightmapArray, float3(lightmapUV.x, lightmapUV.y, i))) * knkm_Colors[i];
            half4 dirTex = UNITY_SAMPLE_TEX2DARRAY_SAMPLER(knkm_LightmapIndArray, knkm_LightmapArray, float3(lightmapUV.x, lightmapUV.y, i));
            half3 dominantDir = dirTex.xyz - 0.5;
            half3 halfDir = Unity_SafeNormalize(normalize(dominantDir) + viewDir);
            half nh = saturate(dot(normalWorld, halfDir));
            half spec = GGXTerm(nh, roughness);
            half halfLambert = dot(normalWorld, dominantDir) + 0.5;
            half3 diff = bakedColor * halfLambert / max(1e-4h, dirTex.w);
            diffuse += diff * occulsion;
            specular += spec * bakedColor * occulsion;
        }
    }
#endif
    inline UnityGI KanikamaGlobalIllumination(UnityGIInput data, half occlusion, half3 normalWorld, Unity_GlossyEnvironmentData glossIn)
    {
        UnityGI o_gi = KanikamaGI_Base(data, occlusion, normalWorld);
        o_gi.indirect.specular = UnityGI_IndirectSpecular(data, occlusion, glossIn);

#if defined(_KANIKAMA_MODE_DIRECTIONAL) && defined(_KANIKAMA_SPECULAR)
        half roughness = PerceptualRoughnessToRoughness(glossIn.roughness);
        half3 diffuse;
        half3 specular;
        KanikamaDirectionalLightmapSpecular(data.lightmapUV.xy, normalWorld, data.worldViewDir, roughness, occlusion, /* out */ diffuse, /* out */specular);
        o_gi.indirect.diffuse += diffuse;
        o_gi.indirect.specular += specular;
#endif
        return o_gi;
    }

#endif

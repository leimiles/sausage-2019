#ifndef CHICKEN_CUSTOM_FUNCTION
#define CHICKEN_CUSTOM_FUNCTION

#include "Chicken-PS.hlsl"

half3 SubtractDirectMainLightFromLightmapCustom(Light mainLight, half3 normalWS, half3 bakedGI, half3 shadowColor)
{
    // Let's try to make realtime shadows work on a surface, which already contains
    // baked lighting and shadowing from the main sun light.
    // Summary:
    // 1) Calculate possible value in the shadow by subtracting estimated light contribution from the places occluded by realtime shadow:
    //      a) preserves other baked lights and light bounces
    //      b) eliminates shadows on the geometry facing away from the light
    // 2) Clamp against user defined ShadowColor.
    // 3) Pick original lightmap value, if it is the darkest one.


    // 1) Gives good estimate of illumination as if light would've been shadowed during the bake.
    // We only subtract the main direction light. This is accounted in the contribution term below.
    half shadowStrength = GetMainLightShadowStrength();
    half contributionTerm = saturate(dot(mainLight.direction, normalWS));
    half3 lambert = mainLight.color * contributionTerm;
    half3 estimatedLightContributionMaskedByInverseOfShadow = lambert * (1.0 - mainLight.shadowAttenuation);
    half3 subtractedLightmap = bakedGI - estimatedLightContributionMaskedByInverseOfShadow;
    subtractedLightmap = clamp(subtractedLightmap, shadowColor, bakedGI);
    //subtractedLightmap = clamp(subtractedLightmap, _ShadowColor, half3(0.5,0.5,0.5));
    //return bakedGI;
    //return subtractedLightmap;
    //return estimatedLightContributionMaskedByInverseOfShadow;

    // 2) Allows user to define overall ambient of the scene and control situation when realtime shadow becomes too dark.
    half3 realtimeShadow = max(subtractedLightmap, _SubtractiveShadowColor.xyz);
    realtimeShadow = lerp(bakedGI, realtimeShadow, shadowStrength);

    // 3) Pick darkest color
    return min(bakedGI, realtimeShadow);
}

half3 SampleLightmap_LBP(float2 lightmapUV, half3 normalWS, TEXTURE2D_PARAM(_Lightmap, sampler_Lightmap)) {
    #ifdef UNITY_LIGHTMAP_FULL_HDR
        bool encodeLightmap = false;
    #else
        bool encodeLightmap = true;
    #endif
    half4 decodeInstructions = half4(LIGHTMAP_HDR_MULTIPLIER, LIGHTMAP_HDR_EXPONENT, 0.0h, 0.0h);
    half4 transformCoords = half4(1, 1, 0, 0);
    return SampleSingleLightmap(TEXTURE2D_ARGS(_Lightmap, sampler_Lightmap), lightmapUV, transformCoords, encodeLightmap, decodeInstructions);
}

half3 GetMatCap(InputData inputData, float2 uv, TEXTURE2D_PARAM(_MatCap, sampler_MatCap)) {
    float3x3 matcapTransform0 = float3x3(
        0.500f,0.000f,0.500f,
        0.000f,0.500f,0.500f,
        0.000f,0.000f,1.000f
        );
    half3 normalWS = inputData.normalWS;
    half3 matcap;

    #ifdef _USE_CURVATURA
        half3 correctiveNormalWS = normalize(reflect(-inputData.viewDirectionWS, inputData.normalWS));
        float curvature = saturate(length(fwidth(inputData.normalWS)) / length(fwidth(inputData.positionWS)) * 0.1);
        normalWS = lerp(correctiveNormalWS, normalWS, curvature);
    #endif

    half3 normalVS = TransformWorldToViewDir(normalWS);
    normalVS.z = 1;
    
    #ifdef _USE_MATCAP_SPLIT
        half3 matcapT = 
              half3(0.000f,0.500f,0.500f)/*01Suit*/     * step(uv.x , 0.5)                        * step(0.5 , uv.y)
            + half3(0.500f,0.500f,0.500f)/*02Coat*/     * step(0.5 , uv.x)                        * step(0.5 , uv.y)
            + half3(0.500f,0.250f,0.250f)/*03Shirt*/    * step(0.5 , uv.x) * step(uv.x , 0.75)    * step(0.25 , uv.y) * step(uv.y , 0.5)
            + half3(0.750f,0.250f,0.250f)/*04Glove*/    * step(0.75 , uv.x)                       * step(0.25 , uv.y) * step(uv.y , 0.5)
            + half3(0.750f,0.000f,0.250f)/*05Shoe*/     * step(0.75 , uv.x)                       * step(uv.y , 0.25)
            + half3(0.500f,0.000f,0.250f)/*06Butt*/     * step(0.5 , uv.x) * step(uv.x , 0.75)    * step(uv.y , 0.25)            
            + half3(0.250f,0.250f,0.250f)/*07Face*/     * step(0.25 , uv.x) * step(uv.x , 0.5)    * step(0.25 , uv.y) * step(uv.y , 0.5)
            + half3(0.250f,0.000f,0.250f)/*08Hair*/     * step(0.25 , uv.x) * step(uv.x , 0.5)    * step(uv.y , 0.25)
            + half3(0.000f,0.375f,0.125f)/*09Arm*/      * step(uv.x , 0.125)                      * step(0.375 , uv.y) * step(uv.y , 0.5)
            + half3(0.125f,0.375f,0.125f)/*10Hand*/     * step(0.125 , uv.x) * step(uv.x , 0.25)  * step(0.375 , uv.y) * step(uv.y , 0.5)
            + half3(0.000f,0.250f,0.125f)/*11Leg*/      * step(uv.x , 0.125)                      * step(0.25 , uv.y) * step(uv.y , 0.375)
            + half3(0.125f,0.250f,0.125f)/*12Foot*/     * step(0.125 , uv.x) * step(uv.x , 0.25)  * step(0.25 , uv.y) * step(uv.y , 0.375)
            + half3(0.000f,0.125f,0.125f)/*13Body*/     * step(uv.x , 0.125)                      * step(0.125 , uv.y) * step(uv.y , 0.25)
            + half3(0.125f,0.125f,0.125f)/*14Other*/    * step(0.125 , uv.x) * step(uv.x , 0.25)  * step(0.125 , uv.y) * step(uv.y , 0.25)
            + half3(0.125f,0.000f,0.125f)/*15Empty*/    * step(0.125 , uv.x) * step(uv.x , 0.25)  * step(uv.y , 0.125)
            + half3(0.000f,0.000f,0.125f)/*16head*/     * step(uv.x , 0.125)                      * step(uv.y , 0.125)
        ;
        float3x3 matcapTransform1 = float3x3(
            matcapT.z,  0,          matcapT.x,
            0,          matcapT.z,  matcapT.y,
            0,          0,          1
        );

        float3x3 matcapTransformFinal = mul(matcapTransform1, matcapTransform0);
        matcap = SAMPLE_TEXTURE2D(_MatCap, sampler_MatCap, mul(matcapTransformFinal, normalVS).xy).rgb;
    #else
        matcap = SAMPLE_TEXTURE2D(_MatCap, sampler_MatCap, mul(matcapTransform0, normalVS).xy).rgb;
    #endif
    return matcap;
}

half3 GetMatCapWithID(InputData inputData, TEXTURE2D_PARAM(_MatCap, sampler_MatCap), half matcapID) {
    float3x3 matcapTransform0 = float3x3(
        0.500f,0.000f,0.500f,
        0.000f,0.500f,0.500f,
        0.000f,0.000f,1.000f
        );
    half3 normalWS = inputData.normalWS;
    half3 matcap;

    #ifdef _USE_CURVATURA
        half3 correctiveNormalWS = normalize(reflect(-inputData.viewDirectionWS, inputData.normalWS));
        float curvature = saturate(length(fwidth(inputData.normalWS)) / length(fwidth(inputData.positionWS)) * 0.1);
        normalWS = lerp(correctiveNormalWS, normalWS, curvature);
    #endif

    half3 normalVS = TransformWorldToViewDir(normalWS);
    normalVS.z = 1;
    half3 matcapT = 
          half3(0.000f,0.750f,0.250f)/*01*/     * step(matcapID , 0.09375)
        + half3(0.250f,0.750f,0.250f)/*02*/     * step(0.09375 , matcapID) * step(matcapID , 0.15625)
        + half3(0.500f,0.750f,0.250f)/*03*/     * step(0.15625 , matcapID) * step(matcapID , 0.21875)
        + half3(0.750f,0.750f,0.250f)/*04*/     * step(0.21875 , matcapID) * step(matcapID , 0.28125)
        + half3(0.000f,0.500f,0.250f)/*05*/     * step(0.28125 , matcapID) * step(matcapID , 0.34375)
        + half3(0.250f,0.500f,0.250f)/*06*/     * step(0.34375 , matcapID) * step(matcapID , 0.40625)
        + half3(0.500f,0.500f,0.250f)/*07*/     * step(0.40625 , matcapID) * step(matcapID , 0.46875)
        + half3(0.750f,0.500f,0.250f)/*08*/     * step(0.46875 , matcapID) * step(matcapID , 0.53125)
        + half3(0.000f,0.250f,0.250f)/*09*/     * step(0.53125 , matcapID) * step(matcapID , 0.59375)
        + half3(0.250f,0.250f,0.250f)/*10*/     * step(0.59375 , matcapID) * step(matcapID , 0.65625)
        + half3(0.500f,0.250f,0.250f)/*11*/     * step(0.65625 , matcapID) * step(matcapID , 0.71875)
        + half3(0.750f,0.250f,0.250f)/*12*/     * step(0.71875 , matcapID) * step(matcapID , 0.78125)
        + half3(0.000f,0.000f,0.250f)/*13*/     * step(0.78125 , matcapID) * step(matcapID , 0.84375)
        + half3(0.250f,0.000f,0.250f)/*14*/     * step(0.84375 , matcapID) * step(matcapID , 0.90625)
        + half3(0.500f,0.000f,0.250f)/*15*/     * step(0.90625 , matcapID) * step(matcapID , 0.96875)
        + half3(0.750f,0.000f,0.250f)/*16*/     * step(0.96875 , matcapID)
    ;
    float3x3 matcapTransform1 = float3x3(
        matcapT.z,  0,          matcapT.x,
        0,          matcapT.z,  matcapT.y,
        0,          0,          1
    );

    float3x3 matcapTransformFinal = mul(matcapTransform1, matcapTransform0);
    matcap = SAMPLE_TEXTURE2D(_MatCap, sampler_MatCap, mul(matcapTransformFinal, normalVS).xy).rgb;    
    return matcap;
}

// get control value which indicates how r g b a color mixes
void GetControlValue(half weight, half edge, half4 controlColor01, half4 controlColor02, half4 controlColor03, half4 controlColor04
	, out half4 splat01, out half4 splat02, out half4 splat03, out half4 splat04) {
    half4 controlValue01 = controlColor01;
    half4 controlValue02 = controlColor02;
	half4 controlValue03 = controlColor03;
	half4 controlValue04 = controlColor04;
    half s01 = controlValue01.r;
    half s02 = controlValue01.g = smoothstep(0, edge, controlValue01.g) * edge * 3.0;
    half s03 = controlValue01.b = smoothstep(0, edge, controlValue01.b) * edge * 3.0;
    half s04 = controlValue01.a = smoothstep(0, edge, controlValue01.a) * edge * 3.0; 
    half s05 = controlValue02.r = smoothstep(0, edge, controlValue02.r) * edge * 3.0;
    half s06 = controlValue02.g = smoothstep(0, edge, controlValue02.g) * edge * 3.0;
    half s07 = controlValue02.b = smoothstep(0, edge, controlValue02.b) * edge * 3.0;
    half s08 = controlValue02.a = smoothstep(0, edge, controlValue02.a) * edge * 3.0;
	half s09 = controlValue03.r = smoothstep(0, edge, controlValue03.r) * edge * 3.0;
	half s10 = controlValue03.g = smoothstep(0, edge, controlValue03.g) * edge * 3.0;
	half s11 = controlValue03.b = smoothstep(0, edge, controlValue03.b) * edge * 3.0;
	half s12 = controlValue03.a = smoothstep(0, edge, controlValue03.a) * edge * 3.0; 
	half s13 = controlValue04.r = smoothstep(0, edge, controlValue04.r) * edge * 3.0;
	half s14 = controlValue04.g = smoothstep(0, edge, controlValue04.g) * edge * 3.0;
	half s15 = controlValue04.b = smoothstep(0, edge, controlValue04.b) * edge * 3.0;
	half s16 = controlValue04.a = smoothstep(0, edge, controlValue04.a) * edge * 3.0;
    
    half maxChannel = max(s01
	    , max(s02
	    	, max(s03
	    		, max(s04
	    			, max(s05
	    				, max(s06
	    					, max(s07
	    						, max(s08
	    							, max(s09
	    								, max(s10
	    									, max(s11
	    										, max(s12
	    											, max(s13
	    												, max(s14
	    													, max(s15,s16)))))))))))))));
    half4 maxControl01 = controlValue01 - maxChannel;
    half4 maxControl02 = controlValue02 - maxChannel;
	half4 maxControl03 = controlValue03 - maxChannel;
	half4 maxControl04 = controlValue04 - maxChannel;
    half4 withWeight01 = max(maxControl01 + weight, half4(0, 0, 0, 0)) * controlColor01;
    half4 withWeight02 = max(maxControl02 + weight, half4(0, 0, 0, 0)) * controlColor02;
	half4 withWeight03 = max(maxControl03 + weight, half4(0, 0, 0, 0)) * controlColor03;
	half4 withWeight04 = max(maxControl04 + weight, half4(0, 0, 0, 0)) * controlColor04;
	half weightTotal = withWeight01.r + withWeight01.g + withWeight01.b + withWeight01.a
						+ withWeight02.r + withWeight02.g + withWeight02.b + withWeight02.a
						+ withWeight03.r + withWeight03.g + withWeight03.b + withWeight03.a
						+ withWeight04.r + withWeight04.g + withWeight04.b + withWeight04.a;
    half4 finalValue01 = withWeight01 / weightTotal;
    half4 finalValue02 = withWeight02 / weightTotal;
	half4 finalValue03 = withWeight03 / weightTotal;
	half4 finalValue04 = withWeight04 / weightTotal;
    splat01 = saturate(finalValue01);
    splat02 = saturate(finalValue02);
	splat03 = saturate(finalValue03);
	splat04 = saturate(finalValue04);   
}

float2 RotateUV(float2 tarUV, float angle, float2 center) {
	angle = radians(angle);
	float3x3 matrixMove = float3x3(
		1, 0, -center.x,
        0, 1, -center.y,
        0, 0, 1
    );
	float3x3 matrixRotate = float3x3(
		cos(angle) ,   sin(angle), 0,
        -sin(angle),   cos(angle), 0,
        0,             0, 		  1
	);
	float3x3 matrixBack = float3x3(
		1, 0, center.x,
        0, 1, center.y,
        0, 0, 1
    );
	return mul(matrixBack, mul(matrixRotate, mul(matrixMove, float3(tarUV, 1)))).xy;
}

float NewSin(float theta, float upScale, float downScale) {
	float originSin = sin(theta);
	return (step(originSin, 0) * downScale + step(0, originSin) * upScale) * originSin;
}

bool IsPointUnderLine(float2 pot01, float2 pot02, float2 pot) {
	float3 vectLevel = float3(pot02 - pot01, 0);
	float3 vectCur = float3(pot - pot01, 0);
	return cross(vectLevel, vectCur).z < 0;
}

float GetMax(float3 color)
{
	return max(color.r, max (color.g, color.b));
}

half MaxIn3(half3 origin) {
    return max(max(origin.x, origin.y), origin.z);
}

half MinIn3(half3 origin) {
    return min(min(origin.x, origin.y), origin.z);
}

half GetScale(half vMin, half vMax, half value) {
    half vMid = (vMax + vMin) / 2;
    return 1 - smoothstep(0, vMid, abs(value - vMid));
}

float UnityGet2DClipping (in float2 position, in float4 clipRect)
{
	float2 inside = step(clipRect.xy, position.xy) * step(position.xy, clipRect.zw);
	return inside.x * inside.y;
}

half3 MixFogAdvanced(real3 fragColor, real fogFactor, half3 fogColor01, half3 fogColor02, half3 viewDir, half4 params) {
    half p = dot(normalize(params.xy), float2(viewDir.x, viewDir.z));
    p = (p + 1) / 2;
    p = smoothstep(params.z, params.w, p);
    half3 fogColor = lerp(fogColor02, fogColor01, p);
    fragColor = lerp(fogColor, fragColor, fogFactor);
    //fragColor = smoothstep(params.z, params.w, fragColor);
    return fragColor;
}

half4 EncodeHDR(half3 color) {
#if _USE_RGBM
    half4 outColor = EncodeRGBM(color);
#else
    half4 outColor = half4(color, 1.0);
#endif

#if UNITY_COLORSPACE_GAMMA
    return half4(sqrt(outColor.xyz), outColor.w); // linear to γ
#else
    return outColor;
#endif
}

half3 DecodeHDR(half4 color) {
#if UNITY_COLORSPACE_GAMMA
    color.xyz *= color.xyz; // γ to linear
#endif

#if _USE_RGBM
    return DecodeRGBM(color);
#else
    return color.xyz;
#endif
}

float3 Chicken_HeightToNormal(float height, float3 normal, float3 pos)
{
    float3 worldDirivativeX = ddx(pos);
    float3 worldDirivativeY = ddy(pos);
    float3 crossX = cross(normal, worldDirivativeX);
    float3 crossY = cross(normal, worldDirivativeY);
    float3 d = abs(dot(crossY, worldDirivativeX));
    float3 inToNormal = ((((height + ddx(height)) - height) * crossY) + (((height + ddy(height)) - height) * crossX)) * sign(d);
    inToNormal.y *= -1.0;
    return normalize((d * normal) - inToNormal);
}

float3 Chicken_RGB2HSV(float3 c){
	float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	float4 p = lerp( float4( c.bg, K.wz ), float4( c.gb, K.xy ), step( c.b, c.g ) );
	float4 q = lerp( float4( p.xyw, c.r ), float4( c.r, p.yzx ), step( p.x, c.r ) );
	float d = q.x - min( q.w, q.y );
	float e = 1.0e-10;
	return float3( abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

float3 Chicken_HSV2RGB(float3 c){
	float4 K = float4( 1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0 );
	float3 p = abs( frac( c.xxx + K.xyz ) * 6.0 - K.www );
	return c.z * lerp( K.xxx, saturate( p - K.xxx ), c.y );
}

float3 Chicken_SwitchColor(float3 sourceColor, float Hue_Intensity, float Saturation_Intensity, float Value_Intensity, float mask, float Switch_Speed = 1){
    float3 sourceHSV = Chicken_RGB2HSV(sourceColor.rgb);
    float Hue = clamp(frac(sourceHSV.x + Hue_Intensity + Switch_Speed * _Time.x), 0, 1);
    float Saturate = clamp(sourceHSV.y + Saturation_Intensity, 0, 1);
    float Value = clamp(sourceHSV.z + Value_Intensity, 0, 1);

    float3 finalHSV = float3(Hue, Saturate, Value) * mask + sourceHSV * (1 - mask);
    float3 finalColor = Chicken_HSV2RGB(finalHSV);      
    return finalColor;
}

float ComputeScan(float3 positionWS, float _TimeScale, float _LineScale){
    float3 a = positionWS + (_TimeScale / 5 * _Time.y);
    float b = _LineScale / 6;

    float3 c = (fmod(a * (-1), b) - b / 4) * (-1);
    float3 d = fmod(a, b) - b / 4;
    float e = saturate(a.x * 100);

    float scan = saturate(lerp(c, d, e).g * 75);

    return scan;
}

void StarAlphaClip(float4 positionSS, float alpha, float _Cutoff){
    float4x4 thresholdMatrix = {
        1.0 / 17.0,     9.0 / 17.0,     3.0 / 17.0,     11.0 / 17.0,
        13.0 / 17.0,    5.0 / 17.0,     15.0 / 17.0,    7.0 / 17.0,
        4.0 / 17.0,     12.0 / 17.0,    2.0 / 17.0,     10.0 / 17.0,
        16.0 / 17.0,    8.0 / 17.0,     14.0 / 17.0,    6.0 / 17.0
    };
    float4x4 _RowAccess = {
        1,0,0,0,
        0,1,0,0,
        0,0,1,0,
        0,0,0,1
    };
    float2 pos = positionSS.xy / positionSS.w;
    pos *= _ScreenParams.xy;
    clip((1.0f - _Cutoff) * alpha - thresholdMatrix[fmod(pos.x, 4)] * _RowAccess[fmod(pos.y, 4)]);
}

float3 CustomSH(half3 normalWS,float4 unity_Custom_SHAr,float4 unity_Custom_SHAg,float4 unity_Custom_SHAb,
	float4 unity_Custom_SHBr,float4 unity_Custom_SHBg,float4 unity_Custom_SHBb,float4 unity_Custom_SHC){
	real4 SHCoefficients[7];
	SHCoefficients[0] = unity_Custom_SHAr;
	SHCoefficients[1] = unity_Custom_SHAg;
	SHCoefficients[2] = unity_Custom_SHAb;
	SHCoefficients[3] = unity_Custom_SHBr;
	SHCoefficients[4] = unity_Custom_SHBg;
	SHCoefficients[5] = unity_Custom_SHBb;
	SHCoefficients[6] = unity_Custom_SHC;
	return max(float3(0, 0, 0), SampleSH9(SHCoefficients, normalWS));
}
#endif
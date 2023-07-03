#ifndef PLAYERDITHERFADING_HLSL_INCLUDED
#define PLAYERDITHERFADING_HLSL_INCLUDED

float4 DitherMatrix(half4 input, half4 positionSS)
{
    half2 uv = positionSS.xy / positionSS.w * _ScreenParams.xy;
    float DITHER_THRESHOLDS[16] = {
        1.0 / 17.0, 9.0 / 17.0, 3.0 / 17.0, 11.0 / 17.0,
        13.0 / 17.0, 5.0 / 17.0, 15.0 / 17.0, 7.0 / 17.0,
        4.0 / 17.0, 12.0 / 17.0, 2.0 / 17.0, 10.0 / 17.0,
        16.0 / 17.0, 8.0 / 17.0, 14.0 / 17.0, 6.0 / 17.0
    };
    uint index = (uint(uv.x) % 4) * 4 + uint(uv.y) % 4;
    float4 output = input - DITHER_THRESHOLDS[index];
    return output;
}

float4 Remap(float4 In, float2 InMinMax, float2 OutMinMax)
{
    float4 output = OutMinMax.x + (In - InMinMax.x) * (OutMinMax.y - OutMinMax.x) / (InMinMax.y - InMinMax.x);
    return output;
}

#endif
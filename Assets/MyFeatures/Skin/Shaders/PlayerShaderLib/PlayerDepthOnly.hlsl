#ifndef PLAYERDEPTHONLY_HLSL_INCLUDED
#define PLAYERDEPTHONLY_HLSL_INCLUDED



struct Attributes
{
    float3 positionOS : POSITION;
};

struct Varyings
{
    float4 positionCS : SV_POSITION;
};



Varyings vert(Attributes v)
{
    Varyings o = (Varyings)0;
    VertexPositionInputs vpi = GetVertexPositionInputs(v.positionOS.xyz);
    o.positionCS = vpi.positionCS;
    return o;
}

half4 frag(Varyings input) : SV_Target
{
    return 0;
}

#endif
#ifndef INPUT_INSTANCEDGRASS_RANDOM_INCLUDED
#define INPUT_INSTANCEDGRASS_RANDOM_INCLUDED

uint rng_state;

float4 rotateAroundYInDegrees(float4 vertex, float degrees)
{
    float alpha = degrees * UNITY_PI / 180.0;
    float sina, cosa;
    sincos(alpha, sina, cosa);
    float2x2 m = float2x2(cosa, -sina, sina, cosa);
    return float4(mul(m, vertex.xz), vertex.yw).xzyw;
}

float4 rotateAroundXInDegrees(float4 vertex, float degrees)
{
    float alpha = degrees * UNITY_PI / 180.0;
    float sina, cosa;
    sincos(alpha, sina, cosa);
    float2x2 m = float2x2(cosa, -sina, sina, cosa);
    return float4(mul(m, vertex.yz), vertex.xw).zxyw;
}

void wang_hash(uint seed)
{
    rng_state = (seed ^ 61) ^(seed >> 16);
    rng_state *= 9;
    rng_state = rng_state ^(rng_state >> 4);
    rng_state *= 0x27d4eb2d;
    rng_state = rng_state ^(rng_state >> 15);
}

uint rand_xorshift()
{
    rng_state ^= (rng_state << 13);
    rng_state ^= (rng_state >> 17);
    rng_state ^= (rng_state << 5);

    return rng_state;
}

float randValue()
{
    return rand_xorshift() * (1.0 / 4294967296.0);
}

void initRand(uint seed)
{
    wang_hash(seed);
}

float randValue(uint seed)
{
    initRand(seed);
    return randValue();
}

#endif
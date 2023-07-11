#ifndef CHICKEN_PS_INCLUDED
#define CHICKEN_PS_INCLUDED
// 变暗
half3 Darken(half3 A, half3 B)
{
    return min(A,B);
}
// 正片叠底
half3 Multiply(half3 A, half3 B)
{
    return A*B;
}
// 滤色
half3 Screen(half3 A, half3 B)
{
    return 1-((1-A)*(1-B));
}
// 颜色加深
half3 ColorBurn(half3 A, half3 B)
{
    return A-((1-A)*(1-B))/B;
}
// 线性减淡
half3 LinearDodge(half3 A, half3 B)
{
    return A+B;
}
// 叠加
half3 Overlay(half3 A, half3 B)
{
    half3 ifFlag= step(A,half3(0.5,0.5,0.5));
    return ifFlag*A*B*2+(1-ifFlag)*(1-(1-A)*(1-B)*2);    
}
// 强光
half3 HardLight(half3 A, half3 B)
{
    half3 ifFlag= step(B,half3(0.5,0.5,0.5));
    return ifFlag*A*B*2+(1-ifFlag)*(1-(1-A)*(1-B)*2);
}
// 柔光
half3 SoftLight(half3 A, half3 B)
{
    half3 ifFlag= step(B,half3(0.5,0.5,0.5));
    return ifFlag*(A*B*2+A*A*(1-B*2))+(1-ifFlag)*(A*(1-B)*2+sqrt(A)*(2*B-1));
}
// 亮光
half3 VividLight(half3 A, half3 B)
{
    half3 ifFlag= step(B,half3(0.5,0.5,0.5));
    return ifFlag*(A-(1-A)*(1-2*B)/(2*B))+(1-ifFlag)*(A+A*(2*B-1)/(2*(1-B)));
}
// 点光
half3 PinLight(half3 A, half3 B)
{
    half3 ifFlag= step(B,half3(0.5,0.5,0.5));
    return ifFlag*(min(A,2*B))+(1-ifFlag)*(max(A,(B*2-1)));
}
// 线性光
half3 LinearLight(half3 A, half3 B)
{
    return A+2*B-1;
}
// 实色混合
half3 HardMix(half3 A, half3 B)
{
    half3 ifFlag= step(A+B,half3(1,1,1));
    return ifFlag*(half3(0,0,0))+(1-ifFlag)*(half3(1,1,1));
}
// 排除
half3 Exclusion(half3 A, half3 B)
{
    return A+B-A*B*2;
}
// 差值
half3 Difference(half3 A, half3 B)
{
    return abs(A-B);
}
// 深色
half3 DarkerColor(half3 A, half3 B)
{
    half ifFlag= step(B.r+B.g+B.b,A.r+A.g+A.b);
    return ifFlag*(B)+(1-ifFlag)*(A);
}
// 浅色
half3 LighterColor(half3 A, half3 B)
{
    half ifFlag= step(B.r+B.g+B.b,A.r+A.g+A.b);
    return ifFlag*(A)+(1-ifFlag)*(B);
}
// 减去
half3 Subtract(half3 A, half3 B)
{
    return A-B;
}
// 划分
half3 Divide(half3 A, half3 B)
{
    return A/B;
}

//ShaderGraph
half BlendBurn(half base, half blend, half opacity = 1)
{
    half target = 1.0 - (1.0 - blend) / (base + 0.00001);
    target = lerp(base, target, opacity);
    return target;
}

half BlendDarken(half base, half blend, half opacity = 1)
{
    half target = min(blend, base);
    target = lerp(base, target, opacity);
    return target;
}

half BlendDifference(half base, half blend, half opacity = 1)
{
    half target = abs(blend - base);
    target = lerp(base, target, opacity);
    return target;
}

half BlendDodge(half base, half blend, half opacity = 1)
{
    half target = base / (1.0 - clamp(blend, 0.00001, 0.99999));
    target = lerp(base, target, opacity);
    return target;
}

half BlendDivide(half base, half blend, half opacity = 1)
{
    half target = base / (blend + 0.00001);
    target = lerp(base, target, opacity);
    return target;
}

half BlendExclusion(half base, half blend, half opacity = 1)
{
    half target = blend + base - (2.0 * blend * base);
    target = lerp(base, target, opacity);
    return target;
}

half BlendHardLight(half base, half blend, half opacity = 1)
{
    half result1 = 1.0 - 2.0 * (1.0 - base) * (1.0 - blend);
    half result2 = 2.0 * base * blend;
    half zeroOrOne = step(blend, 0.5);
    half target = result2 * zeroOrOne + (1 - zeroOrOne) * result1;
    target = lerp(base, target, opacity);
    return target;
}

half BlendHardMix(half base, half blend, half opacity = 1)
{
    half target = step(1 - base, blend);
    target = lerp(base, target, opacity);
    return target;
}

half BlendLighten(half base, half blend, half opacity = 1)
{
    half target = max(blend, base);
    target = lerp(base, target, opacity);
    return target;
}

half BlendLinearBurn(half base, half blend, half opacity = 1)
{
    half target = base + blend - 1.0;
    target = lerp(base, target, opacity);
    return target;
}

half BlendLinearDodge(half base, half blend, half opacity = 1)
{
    half target = base + blend;
    target = lerp(base, target, opacity);
    return target;
}

//线性光
half BlendLinearLight(half base, half blend, half opacity = 1)
{
    half result1 = max(base + (2 * blend) - 1, 0);
    half result2 = min(base + 2 * (blend - 0.5), 1);
    half zeroOrOne = step(0.5, blend);
    half target = result2 * zeroOrOne + (1 - zeroOrOne) * result1;
    target = lerp(base, target, opacity);
    return target;
}

//线性增减
half BlendLinearLightAddSub(half base, half blend, half opacity = 1)
{
    half target = blend + 2.0 * base - 1.0;
    target = lerp(base, target, opacity);
    return target;
}

//乘
half BlendMultiply(half base, half blend, half opacity = 1)
{
    half target = base * blend;
    target = lerp(base, target, opacity);
    return target;
}

//反向
half BlendNegation(half base, half blend, half opacity = 1)
{
    half target = 1.0 - abs(1.0 - blend - base);
    target = lerp(base, target, opacity);
    return target;
}

//滤色
half BlendScreen(half base, half blend, half opacity = 1)
{
    half target = 1.0 - (1.0 - blend) * (1.0 - base);
    target = lerp(base, target, opacity);
    return target;
}

//叠加
half BlendOverlay(half base, half blend, half opacity = 1)
{
    half result1 = 1.0 - 2.0 * (1.0 - base) * (1.0 - blend);
    half result2 = 2.0 * base * blend;
    half zeroOrOne = step(base, 0.5);
    half target = result2 * zeroOrOne + (1 - zeroOrOne) * result1;
    target = lerp(base, target, opacity);
    return target;
}

//点光
half BlendPinLight(half base, half blend, half opacity = 1)
{
    half check = step(0.5, blend);
    half result1 = check * max(2.0 * (base - 0.5), blend);
    half target = result1 + (1.0 - check) * min(2.0 * base, blend);
    target = lerp(base, target, opacity);
    return target;
}

//柔光
half BlendSoftLight(half base, half blend, half opacity = 1)
{
    half result1 = 2.0 * base * blend + (1.0 - 2.0 * blend);
    half result2 = sqrt(base) * (2.0 * blend - 1.0) + 2.0 * base * (1.0 - blend);
    half zeroOrOne = step(0.5, blend);
    half target = result2 * zeroOrOne + (1 - zeroOrOne) * result1;
    target = lerp(base, target, opacity);
    return target;
}

//动态光
half BlendVividLight(half base, half blend, half opacity = 1)
{
    base = clamp(base, 0.00001, 0.99999);
    half result1 = 1.0 - (1.0 - blend) / (2.0 * base);
    half result2 = blend / (2.0 * (1.0 - base));
    half zeroOrOne = step(0.5, base);
    half target = result2 * zeroOrOne + (1 - zeroOrOne) * result1;
    target = lerp(base, target, opacity);
    return target;
}

//减去
half BlendSubtract(half base, half blend, half opacity = 1)
{
    half target = base - blend;
    target = lerp(base, target, opacity);
    return target;
}

//覆盖
half BlendOverwrite(half base, half blend, half opacity = 1)
{
    half target = 0;
    target = lerp(base, target, opacity);
    return target;
}

//自定义
half BlendCustom(half base, half blend, half opacity = 1)
{
    half target = blend + 0.1f * base;
    target = lerp(base, target, opacity);
    return target;
}

#endif

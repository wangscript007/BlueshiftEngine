#ifndef PHONG_BRDF_INCLUDED
#define PHONG_BRDF_INCLUDED

$include "BRDFLibrary.glsl"

#if defined(DIRECT_LIGHTING)

// Phong/Blinn-Phong lighting
vec3 DirectLit_Phong() {
    float NdotL = dot(shading.n, shading.l);

#if defined(_WRAPPED_DIFFUSE)
    float oneMinusW = 1.0 + wrappedDiffuse;
    vec3 Cd = shading.diffuse.rgb * (NdotL + wrappedDiffuse) / (oneMinusW * oneMinusW);
    NdotL = max(NdotL, 0.0);
#else // Lambertian
    NdotL = max(NdotL, 0.0);
    vec3 Cd = shading.diffuse.rgb * NdotL;
#endif

#ifdef USE_BLINN_PHONG
    vec3 H = normalize(shading.l + shading.v);

    float NdotH = max(dot(shading.n, H), 0.0);

    float normFactor = shading.specularPower * 0.125 + 0.25;

    vec3 Cs = shading.specular.rgb * normFactor * pow(NdotH, shading.specularPower) * NdotL;
#else
    vec3 R = reflect(-shading.l, shading.n);

    float RdotV = max(dot(R, shading.v), 0.0);

    float normFactor = shading.specularPower * 0.5 + 1.0;

    vec3 Cs = shading.specular.rgb * normFactor * pow(RdotV, shading.specularPower);
#endif

    return Cd * (vec3(1.0) - shading.specular.rgb) + Cs;
}

// Phong/Blinn-Phong lighting with Fresnel
vec3 DirectLit_PhongFresnel() {
    float NdotL = dot(shading.n, shading.l);

#if defined(_WRAPPED_DIFFUSE)
    float oneMinusW = 1.0 + wrappedDiffuse;
    vec3 Cd = shading.diffuse.rgb * (NdotL + wrappedDiffuse) / (oneMinusW * oneMinusW);
    NdotL = max(NdotL, 0.0);
#else // Lambertian
    NdotL = max(NdotL, 0.0);
    vec3 Cd = shading.diffuse.rgb * NdotL;
#endif

#ifdef USE_BLINN_PHONG // Microfacet Blinn-Phong
    vec3 H = normalize(shading.l + shading.v);

    float NdotH = max(dot(shading.n, H), 0.0);
    float VdotH = max(dot(shading.v, H), 0.0);
    
    // Fresnel reflection term
    vec3 F = F_SchlickSG(shading.specular.rgb, VdotH);

    float normFactor = shading.specularPower * 0.125 + 0.25;

    // Final specular lighting
    vec3 Cs = F * normFactor * pow(NdotH, shading.specularPower) * NdotL;
#else
    vec3 R = reflect(-shading.l, shading.n);

    float RdotV = max(dot(R, shading.v), 0.0);

    // Fresnel reflection term
    vec3 F = F_SchlickSG(shading.specular.rgb, shading.ndotv);

    float normFactor = shading.specularPower * 0.5 + 1.0;

    // Final specular lighting
    vec3 Cs = F * normFactor * pow(RdotV, shading.specularPower);
#endif

    // Final diffuse lighting
    // From reflection term F, we can directly calculate the ratio of refraction
    return Cd * (vec3(1.0) - F) + Cs;
}

#endif

#if defined(INDIRECT_LIGHTING)

vec3 IndirectLit_PhongFresnel() {
    vec3 d = texCUBE(probe0DiffuseCubeMap, shading.n.yzx).rgb;
#ifdef PROBE_BLENDING
    d *= probeLerp;
    d += texCUBE(probe1DiffuseCubeMap, shading.n.yzx).rgb * (1.0 - probeLerp);
#endif

    vec3 Cd = shading.diffuse.rgb * d;

    // (log2(shading.specularPower) - log2(maxSpecularPower)) / log2(pow(maxSpecularPower, -1/numMipmaps))
    // (log2(shading.specularPower) - 11) / (-11/8)
    float specularMipLevel = -(8.0 / 11.0) * log2(shading.specularPower) + 8.0;
    
    // This is single cubemap texture lookup with Phong not Blinn-Phong
    vec3 s = texCUBElod(probe0SpecularCubeMap, vec4(shading.s0.yzx, specularMipLevel)).rgb;
#ifdef PROBE_BLENDING
    s *= probeLerp;
    s += texCUBElod(probe1SpecularCubeMap, vec4(shading.s1.yzx, specularMipLevel)).rgb * (1.0 - probeLerp);
#endif

    vec3 F = F_SchlickRoughness(shading.specular.rgb, shading.roughness, shading.ndotv);

    vec3 Cs = F * s;

    return Cd * (vec3(1.0) - F) + Cs;
}

#endif

#endif

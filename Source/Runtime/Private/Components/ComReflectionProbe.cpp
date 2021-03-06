// Copyright(c) 2017 POLYGONTEK
// 
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// 
// http ://www.apache.org/licenses/LICENSE-2.0
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#include "Precompiled.h"
#include "Render/Render.h"
#include "Components/ComTransform.h"
#include "Components/ComEnvironmentProbe.h"
#include "Game/GameWorld.h"
#include "Game/TagLayerSettings.h"
#include "Asset/Asset.h"
#include "Asset/GuidMapper.h"
#include "Platform/PlatformTime.h"

BE_NAMESPACE_BEGIN

OBJECT_DECLARATION("Reflection Probe", ComEnvironmentProbe, Component)
BEGIN_EVENTS(ComEnvironmentProbe)
END_EVENTS

void ComEnvironmentProbe::RegisterProperties() {
    REGISTER_ACCESSOR_PROPERTY("type", "Type", EnvProbe::Type, GetType, SetType, EnvProbe::Baked,
        "", PropertyInfo::EditorFlag).SetEnumString("Baked;Realtime");
    REGISTER_ACCESSOR_PROPERTY("refreshMode", "Refresh Mode", EnvProbe::RefreshMode, GetRefreshMode, SetRefreshMode, EnvProbe::OnAwake,
        "", PropertyInfo::EditorFlag).SetEnumString("OnAwake;EveryFrame");
    REGISTER_ACCESSOR_PROPERTY("timeSlicing", "Time Slicing", bool, IsTimeSlicing, SetTimeSlicing, true,
        "", PropertyInfo::EditorFlag);
    REGISTER_ACCESSOR_PROPERTY("importance", "Importance", int, GetImportance, SetImportance, 1,
        "", PropertyInfo::EditorFlag);
    REGISTER_ACCESSOR_PROPERTY("resolution", "Resolution", EnvProbe::Resolution, GetResolution, SetResolution, EnvProbe::Resolution128,
        "", PropertyInfo::EditorFlag).SetEnumString("16;32;64;128;256;1024;2048");
    REGISTER_ACCESSOR_PROPERTY("hdr", "HDR", bool, IsHDR, SetHDR, true,
        "", PropertyInfo::EditorFlag);
    REGISTER_ACCESSOR_PROPERTY("cullingMask", "Culling Mask", int, GetLayerMask, SetLayerMask, -1,
        "", PropertyInfo::EditorFlag);
    REGISTER_ACCESSOR_PROPERTY("clear", "Clear", EnvProbe::ClearMethod, GetClearMethod, SetClearMethod, 1,
        "", PropertyInfo::EditorFlag).SetEnumString("Color;Skybox");
    REGISTER_MIXED_ACCESSOR_PROPERTY("clearColor", "Clear Color", Color3, GetClearColor, SetClearColor, Color3(0, 0, 0),
        "", PropertyInfo::EditorFlag);
    REGISTER_ACCESSOR_PROPERTY("clearAlpha", "Clear Alpha", float, GetClearAlpha, SetClearAlpha, 0.0f,
        "", PropertyInfo::EditorFlag);
    REGISTER_ACCESSOR_PROPERTY("near", "Near", float, GetClippingNear, SetClippingNear, 0.1,
        "Near clipping plane distance", PropertyInfo::EditorFlag).SetRange(0.01, 10000, 0.02);
    REGISTER_ACCESSOR_PROPERTY("far", "Far", float, GetClippingFar, SetClippingFar, 500,
        "Far clipping plane distance", PropertyInfo::EditorFlag).SetRange(0.01, 10000, 0.02);
    REGISTER_ACCESSOR_PROPERTY("boxProjection", "Box Projection", bool, IsBoxProjection, SetBoxProjection, false,
        "", PropertyInfo::EditorFlag);
    REGISTER_MIXED_ACCESSOR_PROPERTY("boxSize", "Box Size", Vec3, GetBoxSize, SetBoxSize, Vec3(10, 10, 10),
        "The size of the box in which the reflections will be applied to objects", PropertyInfo::EditorFlag).SetRange(0, 1e8, 0.05);
    REGISTER_MIXED_ACCESSOR_PROPERTY("boxOffset", "Box Offset", Vec3, GetBoxOffset, SetBoxOffset, Vec3(0, 0, 0),
        "The center of the box in which the reflections will be applied to objects", PropertyInfo::EditorFlag);
    REGISTER_MIXED_ACCESSOR_PROPERTY("bakedDiffuseProbeTexture", "Baked Diffuse Probe Texture", Guid, GetBakedDiffuseProbeTextureGuid, SetBakedDiffuseProbeTextureGuid, GuidMapper::defaultCubeTextureGuid,
        "", PropertyInfo::EditorFlag).SetMetaObject(&TextureAsset::metaObject);
    REGISTER_MIXED_ACCESSOR_PROPERTY("bakedSpecularProbeTexture", "Baked Specular Probe Texture", Guid, GetBakedSpecularProbeTextureGuid, SetBakedSpecularProbeTextureGuid, GuidMapper::defaultCubeTextureGuid,
        "", PropertyInfo::EditorFlag).SetMetaObject(&TextureAsset::metaObject);
}

ComEnvironmentProbe::ComEnvironmentProbe() {
    probeHandle = -1;
    sphereHandle = -1;
    sphereMesh = nullptr;
}

ComEnvironmentProbe::~ComEnvironmentProbe() {
    Purge(false);
}

void ComEnvironmentProbe::Purge(bool chainPurge) {
    if (sphereDef.mesh) {
        meshManager.ReleaseMesh(sphereDef.mesh);
        sphereDef.mesh = nullptr;
    }

    if (sphereMesh) {
        meshManager.ReleaseMesh(sphereMesh);
        sphereMesh = nullptr;
    }

    for (int i = 0; i < sphereDef.materials.Count(); i++) {
        materialManager.ReleaseMaterial(sphereDef.materials[i]);
    }
    sphereDef.materials.Clear();

    if (sphereHandle != -1) {
        renderWorld->RemoveRenderObject(sphereHandle);
        sphereHandle = -1;
    }

    if (chainPurge) {
        Component::Purge();
    }
}

void ComEnvironmentProbe::Init() {
    Component::Init();

    renderWorld = GetGameWorld()->GetRenderWorld();

    ComTransform *transform = GetEntity()->GetTransform();

    probeDef.origin = transform->GetOrigin();

    transform->Connect(&ComTransform::SIG_TransformUpdated, this, (SignalCallback)&ComEnvironmentProbe::TransformUpdated, SignalObject::Unique);

    sphereDef.layer = TagLayerSettings::EditorLayer;
    sphereDef.maxVisDist = MeterToUnit(50.0f);

    sphereMesh = meshManager.GetMesh("_defaultSphereMesh");

    sphereDef.mesh = sphereMesh->InstantiateMesh(Mesh::StaticMesh);
    sphereDef.localAABB = sphereMesh->GetAABB();
    sphereDef.origin = transform->GetOrigin();
    sphereDef.scale = Vec3(1, 1, 1);
    sphereDef.axis = Mat3::identity;
    sphereDef.materialParms[RenderObject::RedParm] = 1.0f;
    sphereDef.materialParms[RenderObject::GreenParm] = 1.0f;
    sphereDef.materialParms[RenderObject::BlueParm] = 1.0f;
    sphereDef.materialParms[RenderObject::AlphaParm] = 1.0f;
    sphereDef.materialParms[RenderObject::TimeOffsetParm] = 0.0f;
    sphereDef.materialParms[RenderObject::TimeScaleParm] = 1.0f;

    // Mark as initialized
    SetInitialized(true);

    UpdateVisuals();
}

void ComEnvironmentProbe::OnActive() {
    UpdateVisuals();
}

void ComEnvironmentProbe::OnInactive() {
    renderWorld->RemoveRenderObject(sphereHandle);
    sphereHandle = -1;
}

bool ComEnvironmentProbe::HasRenderEntity(int renderEntityHandle) const {
    if (this->sphereHandle == renderEntityHandle) {
        return true;
    }

    return false;
}

bool ComEnvironmentProbe::RayIntersection(const Vec3 &start, const Vec3 &dir, bool backFaceCull, float &lastScale) const {
    return false;
}

void ComEnvironmentProbe::Awake() {
    if (probeDef.type == EnvProbe::Type::Realtime) {
        if (probeDef.refreshMode == EnvProbe::RefreshMode::OnAwake) {
            renderSystem.ScheduleToRefreshEnvProbe(renderWorld, probeHandle);
        }
    }
}

void ComEnvironmentProbe::Update() {
    if (!IsActiveInHierarchy()) {
        return;
    }

    if (probeDef.type == EnvProbe::Type::Realtime) {
        if (probeDef.refreshMode == EnvProbe::RefreshMode::EveryFrame) {
            renderSystem.ScheduleToRefreshEnvProbe(renderWorld, probeHandle);
        }
    }
}

void ComEnvironmentProbe::DrawGizmos(const RenderCamera::State &viewState, bool selected) {
    RenderWorld *renderWorld = GetGameWorld()->GetRenderWorld();

    if (selected) {
        AABB aabb = AABB(-probeDef.boxSize, probeDef.boxSize);
        aabb += probeDef.origin + probeDef.boxOffset;
        
        renderWorld->SetDebugColor(Color4(0.0f, 0.5f, 1.0f, 1.0f), Color4::zero);
        renderWorld->DebugAABB(aabb, 1.0f, false, true, true);

        gizmoCurrentTime = PlatformTime::Milliseconds();

        if (gizmoCurrentTime > gizmoRefreshTime + 3000) {
            gizmoRefreshTime = gizmoCurrentTime;

            if (probeDef.type == EnvProbe::Type::Realtime) {
                renderSystem.ScheduleToRefreshEnvProbe(renderWorld, probeHandle);
            }
        }
    }
}

const AABB ComEnvironmentProbe::GetAABB() {
    return Sphere(Vec3::origin, MeterToUnit(0.5f)).ToAABB();
}

void ComEnvironmentProbe::UpdateVisuals() {
    if (!IsInitialized() || !IsActiveInHierarchy()) {
        return;
    }

    if (probeHandle == -1) {
        probeHandle = renderWorld->AddEnvProbe(&probeDef);
    } else {
        renderWorld->UpdateEnvProbe(probeHandle, &probeDef);
    }

    if (sphereDef.materials.Count() == 0) {
        EnvProbe *reflectionProbe = renderWorld->GetEnvProbe(probeHandle);
        Texture *specularSumTexture = reflectionProbe->GetSpecularSumCubeTexture();

        sphereDef.materials.SetCount(1);
        sphereDef.materials[0] = materialManager.GetSingleTextureMaterial(specularSumTexture, Material::EnvCubeMapHint);
    }

    if (sphereHandle == -1) {
        sphereHandle = renderWorld->AddRenderObject(&sphereDef);
    } else {
        renderWorld->UpdateRenderObject(sphereHandle, &sphereDef);
    }
}

void ComEnvironmentProbe::TransformUpdated(const ComTransform *transform) {
    probeDef.origin = transform->GetOrigin();

    sphereDef.origin = transform->GetOrigin();

    UpdateVisuals();
}

EnvProbe::Type ComEnvironmentProbe::GetType() const {
    return probeDef.type;
}

void ComEnvironmentProbe::SetType(EnvProbe::Type type) {
    probeDef.type = type;

    UpdateVisuals();
}

EnvProbe::RefreshMode ComEnvironmentProbe::GetRefreshMode() const {
    return probeDef.refreshMode;
}

void ComEnvironmentProbe::SetRefreshMode(EnvProbe::RefreshMode refreshMode) {
    probeDef.refreshMode = refreshMode;

    UpdateVisuals();
}

bool ComEnvironmentProbe::IsTimeSlicing() const {
    return probeDef.timeSlicing;
}

void ComEnvironmentProbe::SetTimeSlicing(bool timeSlicing) {
    probeDef.timeSlicing = timeSlicing;

    UpdateVisuals();
}

int ComEnvironmentProbe::GetImportance() const {
    return probeDef.importance;
}

void ComEnvironmentProbe::SetImportance(int importance) {
    probeDef.importance = importance;

    UpdateVisuals();
}

EnvProbe::Resolution ComEnvironmentProbe::GetResolution() const {
    return probeDef.resolution;
}

void ComEnvironmentProbe::SetResolution(EnvProbe::Resolution resolution) {
    probeDef.resolution = resolution;

    UpdateVisuals();
}

bool ComEnvironmentProbe::IsHDR() const {
    return probeDef.useHDR;
}

void ComEnvironmentProbe::SetHDR(bool useHDR) {
    probeDef.useHDR = useHDR;

    UpdateVisuals();
}

int ComEnvironmentProbe::GetLayerMask() const {
    return probeDef.layerMask;
}

void ComEnvironmentProbe::SetLayerMask(int layerMask) {
    probeDef.layerMask = layerMask;

    UpdateVisuals();
}

EnvProbe::ClearMethod ComEnvironmentProbe::GetClearMethod() const {
    return probeDef.clearMethod;
}

void ComEnvironmentProbe::SetClearMethod(EnvProbe::ClearMethod clearMethod) {
    probeDef.clearMethod = clearMethod;

    UpdateVisuals();
}

Color3 ComEnvironmentProbe::GetClearColor() const {
    return probeDef.clearColor.ToColor3();
}

void ComEnvironmentProbe::SetClearColor(const Color3 &clearColor) {
    probeDef.clearColor.ToColor3() = clearColor;

    UpdateVisuals();
}

float ComEnvironmentProbe::GetClearAlpha() const {
    return probeDef.clearColor.a;
}

void ComEnvironmentProbe::SetClearAlpha(float clearAlpha) {
    probeDef.clearColor.a = clearAlpha;

    UpdateVisuals();
}

float ComEnvironmentProbe::GetClippingNear() const {
    return probeDef.clippingNear;
}

void ComEnvironmentProbe::SetClippingNear(float clippingNear) {
    probeDef.clippingNear = clippingNear;

    if (probeDef.clippingNear > probeDef.clippingFar) {
        SetProperty("far", probeDef.clippingNear);
    }

    UpdateVisuals();
}

float ComEnvironmentProbe::GetClippingFar() const {
    return probeDef.clippingFar;
}

void ComEnvironmentProbe::SetClippingFar(float clippingFar) {
    if (clippingFar >= probeDef.clippingNear) {
        probeDef.clippingFar = clippingFar;
    }

    UpdateVisuals();
}

bool ComEnvironmentProbe::IsBoxProjection() const {
    return probeDef.useBoxProjection;
}

void ComEnvironmentProbe::SetBoxProjection(bool useBoxProjection) {
    probeDef.useBoxProjection = useBoxProjection;

    UpdateVisuals();
}

Vec3 ComEnvironmentProbe::GetBoxSize() const {
    return probeDef.boxSize;
}

void ComEnvironmentProbe::SetBoxSize(const Vec3 &boxSize) {
    probeDef.boxSize = boxSize;

    // The origin must be included in the box range.
    // So if it doesn't we need to adjust box offset.
    Vec3 adjustedBoxOffset = probeDef.boxOffset;

    for (int i = 0; i < 3; i++) {
        float delta = probeDef.boxOffset[i] - probeDef.boxSize[i];
        if (delta > 0) {
            adjustedBoxOffset[i] = probeDef.boxOffset[i] - delta;
        }
    }

    if (adjustedBoxOffset != probeDef.boxSize) {
        SetProperty("boxOffset", adjustedBoxOffset);
    }

    UpdateVisuals();
}

Vec3 ComEnvironmentProbe::GetBoxOffset() const {
    return probeDef.boxOffset;
}

void ComEnvironmentProbe::SetBoxOffset(const Vec3 &boxOffset) {
    probeDef.boxOffset = boxOffset;

    // The origin must be included in the box range.
    // So if it doesn't we need to adjust box size.
    Vec3 adjustedBoxSize = probeDef.boxSize;

    for (int i = 0; i < 3; i++) {
        float delta = probeDef.boxOffset[i] - probeDef.boxSize[i];
        if (delta > 0) {
            adjustedBoxSize[i] = probeDef.boxSize[i] + delta;
        }
    }

    if (adjustedBoxSize != probeDef.boxSize) {
        SetProperty("boxSize", adjustedBoxSize);
    }

    UpdateVisuals();
}

Guid ComEnvironmentProbe::GetBakedDiffuseProbeTextureGuid() const {
    if (probeDef.bakedDiffuseSumTexture) {
        const Str texturePath = probeDef.bakedDiffuseSumTexture->GetHashName();
        return resourceGuidMapper.Get(texturePath);
    }
    return Guid();
}

void ComEnvironmentProbe::SetBakedDiffuseProbeTextureGuid(const Guid &textureGuid) {
    if (probeDef.bakedDiffuseSumTexture) {
        textureManager.ReleaseTexture(probeDef.bakedDiffuseSumTexture);
    }
    const Str texturePath = resourceGuidMapper.Get(textureGuid);
    probeDef.bakedDiffuseSumTexture = textureManager.GetTexture(texturePath);
}

Guid ComEnvironmentProbe::GetBakedSpecularProbeTextureGuid() const {
    if (probeDef.bakedSpecularSumTexture) {
        const Str texturePath = probeDef.bakedSpecularSumTexture->GetHashName();
        return resourceGuidMapper.Get(texturePath);
    }
    return Guid();
}

void ComEnvironmentProbe::SetBakedSpecularProbeTextureGuid(const Guid &textureGuid) {
    if (probeDef.bakedSpecularSumTexture) {
        textureManager.ReleaseTexture(probeDef.bakedSpecularSumTexture);
    }
    const Str texturePath = resourceGuidMapper.Get(textureGuid);
    probeDef.bakedSpecularSumTexture = textureManager.GetTexture(texturePath);
}

void ComEnvironmentProbe::BakeDiffuseProbeTexture() {
    EnvProbe *reflectionProbe = renderWorld->GetEnvProbe(probeHandle);

    Texture *diffuseSumTexture = reflectionProbe->GetDiffuseSumCubeTexture();

    Image diffuseSumImage;
    Texture::GetCubeImageFromCubeTexture(diffuseSumTexture, 1, diffuseSumImage);

    // Convert format to RGB_11F_11F_10F if texture format is HDR
    if (diffuseSumImage.IsFloatFormat()) {
        diffuseSumImage.ConvertFormatSelf(Image::RGB_11F_11F_10F, false, Image::HighQuality);
    }

    Str path = GetGameWorld()->MapName();
    path.StripFileExtension();
    path.AppendPath(va("DiffuseProbe-%i.dds", probeHandle));
    
    diffuseSumImage.WriteDDS(path);
}

void ComEnvironmentProbe::BakeSpecularProbeTexture() {
    EnvProbe *reflectionProbe = renderWorld->GetEnvProbe(probeHandle);

    Texture *specularSumTexture = reflectionProbe->GetSpecularSumCubeTexture();

    Image specularSumImage;
    int numMipLevels = Math::Log(2, specularSumTexture->GetWidth()) + 1;
    Texture::GetCubeImageFromCubeTexture(specularSumTexture, numMipLevels, specularSumImage);

    // Convert format to RGB_11F_11F_10F if texture format is HDR
    if (specularSumImage.IsFloatFormat()) {
        specularSumImage.ConvertFormatSelf(Image::RGB_11F_11F_10F, false, Image::HighQuality);
    }

    Str path = GetGameWorld()->MapName();
    path.StripFileExtension();
    path.AppendPath(va("SpecularProbe-%i.dds", probeHandle));

    specularSumImage.WriteDDS(path);
}

void ComEnvironmentProbe::Bake() {
    BakeDiffuseProbeTexture();

    BakeSpecularProbeTexture();
}

BE_NAMESPACE_END

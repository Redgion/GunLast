class M9Corpse extends SkeletalMeshActor;

var SkeletalMeshComponent OriginalMesh;
var bool bRagdollActive;
var bool bSettling;
var float SettleTime;
var float FloorZ;
var Vector SettleStart;
var Vector SettleEnd;
var Rotator SettleStartRotation;
var Rotator SettleEndRotation;
var name RootBodyBone;

static function bool PhysicsFits(PhysicsAsset Asset, SkeletalMeshComponent Source)
{
    local int i;
    if (Asset == None || Source == None || Asset.BodySetup.Length < 3)
        return false;
    for (i = 0; i < Asset.BodySetup.Length; ++i)
    {
        if (Asset.BodySetup[i] == None || Source.MatchRefBone(Asset.BodySetup[i].BoneName) < 0)
            return false;
    }
    return true;
}

function bool InitializeCorpse(OLPawn Source, PhysicsAsset Asset)
{
    local int i;
    local name Bone;
    local Vector HitLocation, HitNormal;
    local Actor FloorActor;

    if (Source == None || Source.Mesh == None || Source.Mesh.SkeletalMesh == None)
        return false;
    OriginalMesh = Source.Mesh;
    SetLocation(OriginalMesh.GetPosition());
    SetRotation(OriginalMesh.GetRotation());
    SetDrawScale(Source.DrawScale);
    SetDrawScale3D(Source.DrawScale3D);
    SkeletalMeshComponent.SetSkeletalMesh(OriginalMesh.SkeletalMesh);
    SkeletalMeshComponent.SetScale(OriginalMesh.Scale);
    SkeletalMeshComponent.SetScale3D(OriginalMesh.Scale3D);
    for (i = 0; i < Max(OriginalMesh.Materials.Length, OriginalMesh.SkeletalMesh.Materials.Length); ++i)
        SkeletalMeshComponent.SetMaterial(i, OriginalMesh.GetMaterial(i));
    FloorActor = Trace(HitLocation, HitNormal, Source.Location - vect(0,0,500), Source.Location + vect(0,0,30), false);
    FloorZ = FloorActor != None ? HitLocation.Z : Source.Location.Z - 100.0;
    if (!PhysicsFits(Asset, OriginalMesh))
    {
        BeginSafeCollapse();
        return true;
    }

    SkeletalMeshComponent.SetPhysicsAsset(Asset, true);
    SkeletalMeshComponent.MinDistFactorForKinematicUpdate = 0.0;
    SkeletalMeshComponent.bUpdateKinematicBonesFromAnimation = false;
    SkeletalMeshComponent.bUpdateSkelWhenNotRendered = true;
    SkeletalMeshComponent.PhysicsWeight = 1.0;
    SkeletalMeshComponent.SetRBChannel(RBCC_Pawn);
    SkeletalMeshComponent.SetRBCollidesWithChannel(RBCC_Default, true);
    SkeletalMeshComponent.SetRBCollidesWithChannel(RBCC_GameplayPhysics, true);
    SkeletalMeshComponent.SetRBCollidesWithChannel(RBCC_Pawn, false);
    SkeletalMeshComponent.SetBlockRigidBody(true);
    SkeletalMeshComponent.SetHasPhysicsAssetInstance(true, true);
    SetPhysics(PHYS_RigidBody);
    if (SkeletalMeshComponent.PhysicsAssetInstance == None)
    {
        BeginSafeCollapse();
        return true;
    }
    SkeletalMeshComponent.PhysicsAssetInstance.SetAllBodiesFixed(false);
    SkeletalMeshComponent.PhysicsAssetInstance.SetAllMotorsAngularPositionDrive(false, false, SkeletalMeshComponent);
    SkeletalMeshComponent.PhysicsAssetInstance.SetAllMotorsAngularVelocityDrive(false, false, SkeletalMeshComponent);
    SkeletalMeshComponent.PhysicsAssetInstance.SetAllMotorsAngularDriveParams(0.0, 0.0, 0.0, SkeletalMeshComponent);
    // Start each body in the NPC's current pose instead of snapping to the bind pose.
    for (i = 0; i < Asset.BodySetup.Length; ++i)
    {
        Bone = Asset.BodySetup[i].BoneName;
        SkeletalMeshComponent.SetRBPosition(OriginalMesh.GetBoneLocation(Bone), Bone);
        SkeletalMeshComponent.SetRBRotation(QuatToRotator(OriginalMesh.GetBoneQuaternion(Bone)), Bone);
    }
    RootBodyBone = Asset.BodySetup[0].BoneName;
    SkeletalMeshComponent.SetRBLinearVelocity(vect(0,0,0));
    SkeletalMeshComponent.SetRBAngularVelocity(vect(0,0,0));
    SkeletalMeshComponent.WakeRigidBody();
    bRagdollActive = true;
    LogInternal("[M9Repair] corpse physics started: " $ string(Source) $ " asset=" $ string(Asset));
    return true;
}

function BeginSafeCollapse()
{
    bRagdollActive = false;
    SetPhysics(PHYS_None);
    SkeletalMeshComponent.SetHasPhysicsAssetInstance(false);
    SkeletalMeshComponent.PhysicsWeight = 0.0;
    SkeletalMeshComponent.SetBlockRigidBody(false);
    SkeletalMeshComponent.SetParentAnimComponent(OriginalMesh);
    SettleStart = Location;
    SettleEnd = Location;
    SettleEnd.Z = FloorZ + 15.0;
    SettleStartRotation = Rotation;
    SettleEndRotation = Rotation;
    SettleEndRotation.Roll += 16384;
    SettleTime = 0.0;
    bSettling = true;
    LogInternal("[M9Repair] corpse uses safe collapse: " $ string(OriginalMesh));
}

simulated event Tick(float DeltaTime)
{
    local float Alpha;
    Super.Tick(DeltaTime);
    if (bRagdollActive && SkeletalMeshComponent.GetBoneLocation(RootBodyBone).Z < FloorZ - 120.0)
        BeginSafeCollapse();
    if (bSettling)
    {
        SettleTime += DeltaTime;
        Alpha = FClamp(SettleTime / 0.7, 0.0, 1.0);
        Alpha = Alpha * Alpha * (3.0 - 2.0 * Alpha);
        SetLocation(VLerp(SettleStart, SettleEnd, Alpha));
        SetRotation(RLerp(SettleStartRotation, SettleEndRotation, Alpha, true));
        if (SettleTime >= 0.7)
            bSettling = false;
    }
}

defaultproperties
{
    Begin Object Name=SkeletalMeshComponent0
        MinDistFactorForKinematicUpdate=0.0
        bUpdateSkelWhenNotRendered=true
        bUpdateKinematicBonesFromAnimation=false
        bHasPhysicsAssetInstance=false
        CollideActors=true
        BlockActors=false
        BlockRigidBody=true
        RBChannel=RBCC_Pawn
        RBCollideWithChannels=(Default=true,GameplayPhysics=true,Pawn=false)
    End Object
    CollisionComponent=SkeletalMeshComponent0
    bNoDelete=false
    bStatic=false
    bCollideActors=true
    bBlockActors=false
    bCollideWorld=true
    bDamageAppliesImpulse=false
    RemoteRole=ROLE_None
}

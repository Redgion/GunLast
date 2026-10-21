class M9WorldProp extends Actor;
var StaticMeshComponent BodyMesh;
var StaticMeshComponent SlideMesh;
var StaticMeshComponent MagazineMesh;
var PrimitiveComponent SourceComponent;
var SkeletalMeshComponent SourceSkeletal;
var Actor SourceActor;
var OLBatteriesPickupFactory SourcePickup;
var bool bMagazineOnly;
var bool bAssetsReady;
var bool bSourceVisible;

simulated event PostBeginPlay()
{
    local StaticMesh BodyAsset, SlideAsset, MagazineAsset;
    Super.PostBeginPlay();
    BodyAsset=StaticMesh(DynamicLoadObject("M9Assets.M9_Body",class'StaticMesh',true));
    SlideAsset=StaticMesh(DynamicLoadObject("M9Assets.M9_Slide",class'StaticMesh',true));
    MagazineAsset=StaticMesh(DynamicLoadObject("M9Assets.M9_Magazine",class'StaticMesh',true));
    bAssetsReady=BodyAsset!=None && SlideAsset!=None && MagazineAsset!=None;
    if (!bAssetsReady) return;
    BodyMesh.SetStaticMesh(BodyAsset);
    SlideMesh.SetStaticMesh(SlideAsset);
    MagazineMesh.SetStaticMesh(MagazineAsset);
    BodyMesh.SetMaterial(0,class'M9MaterialLibrary'.static.GetGrip());
    SlideMesh.SetMaterial(0,class'M9MaterialLibrary'.static.GetMetal());
    MagazineMesh.SetMaterial(0,class'M9MaterialLibrary'.static.GetMetal());
}

function bool InitializeVisual(Actor OriginalActor, PrimitiveComponent OriginalComponent, bool bOnlyMagazine)
{
    local Vector XAxis,YAxis,ZAxis,Center;
    if (!bAssetsReady || OriginalComponent==None || OriginalActor==None) return false;
    SourceActor=OriginalActor;
    SourceComponent=OriginalComponent;
    SourceSkeletal=SkeletalMeshComponent(OriginalComponent);
    SourcePickup=OLBatteriesPickupFactory(OriginalActor);
    bMagazineOnly=bOnlyMagazine;
    bSourceVisible=!SourceComponent.HiddenGame;
    SetDrawScale(SourceActor.DrawScale * SourceComponent.Scale);
    SetDrawScale3D(SourceActor.DrawScale3D * SourceComponent.Scale3D);
    if (SourceSkeletal!=None)
        SourceSkeletal.bUpdateSkelWhenNotRendered=true;
    if (bMagazineOnly)
    {
        BodyMesh.SetHidden(true);
        SlideMesh.SetHidden(true);
        MagazineMesh.SetRotation(rot(0,0,16384));
        GetAxes(rot(0,0,16384),XAxis,YAxis,ZAxis);
        Center=XAxis*(-6.48)+YAxis*(-0.05)+ZAxis*(-1.88);
        MagazineMesh.SetTranslation(-Center+vect(0,0,1.65));
    }
    else
    {
        BodyMesh.SetRotation(rot(0,32768,16384));
        SlideMesh.SetRotation(rot(0,32768,16384));
        MagazineMesh.SetRotation(rot(0,32768,16384));
    }
    UpdateVisual();
    return true;
}

function vector GetPickupCenter()
{
    local vector XAxis,YAxis,ZAxis;
    // The magazine geometry was recentered to local (0,0,1.65) in InitializeVisual.
    GetAxes(Rotation,XAxis,YAxis,ZAxis);
    return Location+ZAxis*(1.65*DrawScale*DrawScale3D.Z);
}

function UpdateVisual()
{
    local Vector Position;
    local Rotator Orientation;
    local bool bInvisible;
    if (SourceActor==None || SourceActor.bDeleteMe || SourceComponent==None)
    {
        Destroy();
        return;
    }
    if (!SourceComponent.HiddenGame) bSourceVisible=true;
    bInvisible=SourceActor.bHidden || !bSourceVisible;
    if (SourcePickup!=None)
        bInvisible=SourceActor.bHidden || SourcePickup.bUsed || SourcePickup.bDisabled;
    SetHidden(bInvisible);
    Position=SourceComponent.GetPosition();
    Orientation=SourceComponent.GetRotation();
    if (!bMagazineOnly && SourceSkeletal!=None && SourceSkeletal.MatchRefBone('bone_cam')>=0)
    {
        Position=SourceSkeletal.GetBoneLocation('bone_cam');
        Orientation=QuatToRotator(SourceSkeletal.GetBoneQuaternion('bone_cam'));
    }
    SetLocation(Position);
    SetRotation(Orientation);
    SourceComponent.SetHidden(true);
}

simulated event Tick(float DeltaTime)
{
    Super.Tick(DeltaTime);
    if (SourceComponent!=None) UpdateVisual();
}

defaultproperties
{
    Begin Object Class=DynamicLightEnvironmentComponent Name=PropLightEnvironment
        bEnabled=true
    End Object
    Components.Add(PropLightEnvironment)
    Begin Object Class=StaticMeshComponent Name=BodyComponent
        LightEnvironment=PropLightEnvironment
        CollideActors=false
        BlockActors=false
        BlockRigidBody=false
    End Object
    BodyMesh=BodyComponent
    Components.Add(BodyComponent)
    Begin Object Class=StaticMeshComponent Name=SlideComponent
        LightEnvironment=PropLightEnvironment
        CollideActors=false
        BlockActors=false
        BlockRigidBody=false
    End Object
    SlideMesh=SlideComponent
    Components.Add(SlideComponent)
    Begin Object Class=StaticMeshComponent Name=MagazineComponent
        LightEnvironment=PropLightEnvironment
        CollideActors=false
        BlockActors=false
        BlockRigidBody=false
    End Object
    MagazineMesh=MagazineComponent
    Components.Add(MagazineComponent)
    TickGroup=TG_PostUpdateWork
    bHidden=true
    bCollideActors=false
    bBlockActors=false
    RemoteRole=ROLE_None
}

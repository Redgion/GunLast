class M9WorldReplacements extends Actor;
var array<PrimitiveComponent> ReplacedComponents;
var array<M9WorldProp> ReplacementVisuals;
var array<OLBatteriesPickupFactory> Magazines;
var array<bool> MagazineUsed;
var float ScanTime;
var float FocusScanTime;
var OLBatteriesPickupFactory FocusedMagazine;
var vector FocusedMagazineLocation;
var string LastPickupFailure;

simulated event PostBeginPlay()
{
    Super.PostBeginPlay();
    RefreshWorldItems();
}

function bool IsHandycam(string AssetName)
{
    AssetName=Caps(AssetName);
    return InStr(AssetName,"HANDYCAM")>=0 || InStr(AssetName,"CAMCORDER")>=0;
}

function ReplaceVisual(Actor SourceActor, PrimitiveComponent SourceComponent, bool bOnlyMagazine)
{
    local M9WorldProp Visual;
    local int ExistingIndex;
    if (SourceActor==None || SourceActor.bDeleteMe || SourceComponent==None) return;
    ExistingIndex=ReplacedComponents.Find(SourceComponent);
    if (ExistingIndex!=INDEX_NONE && ExistingIndex<ReplacementVisuals.Length && ReplacementVisuals[ExistingIndex]!=None && !ReplacementVisuals[ExistingIndex].bDeleteMe) return;
    Visual=Spawn(class'M9WorldProp',self,,SourceActor.Location,SourceActor.Rotation,,true);
    if (Visual==None) return;
    if (!Visual.InitializeVisual(SourceActor,SourceComponent,bOnlyMagazine))
    {
        Visual.Destroy();
        return;
    }
    if (ExistingIndex==INDEX_NONE)
    {
        ReplacedComponents.AddItem(SourceComponent);
        ReplacementVisuals.AddItem(Visual);
    }
    else ReplacementVisuals[ExistingIndex]=Visual;
    LogInternal("[M9Repair] world model replaced: " $ string(SourceActor) $ " magazine=" $ bOnlyMagazine);
}

function AwardMagazine(PistolPlayerController Player, OLBatteriesPickupFactory Pickup)
{
    local int Amount;
    Amount=Max(Pickup.NumBatteries,1)*8;
    Player.PistolReserve+=Amount;
    Player.LastMagazineAmount=Amount;
    Player.MagazineNoticeUntil=WorldInfo.TimeSeconds+2.0;
    LogInternal("[M9Repair] ammunition pickup=" $ string(Pickup) $ " amount=" $ Amount $ " reserve=" $ Player.PistolReserve);
}

function AddMagazineAmmo(OLBatteriesPickupFactory Pickup)
{
    local PistolPlayerController Player;
    foreach WorldInfo.AllControllers(class'PistolPlayerController',Player)
    {
        AwardMagazine(Player,Pickup);
        return;
    }
}

function vector GetMagazineLocation(OLBatteriesPickupFactory Battery)
{
    local int Index;
    Index=ReplacedComponents.Find(Battery.PickupMesh);
    if (Index!=INDEX_NONE && Index<ReplacementVisuals.Length && ReplacementVisuals[Index]!=None)
    {
        ReplacementVisuals[Index].UpdateVisual();
        return ReplacementVisuals[Index].GetPickupCenter();
    }
    return Battery.PickupMesh.GetPosition();
}

function bool MagazineReachable(PistolPlayerController Player, vector ViewLocation, vector Target, out string Reason)
{
    local vector Sample, HitLocation, HitNormal, Direction;
    local Actor Obstacle;
    local int I;
    Direction=Normal(Target-ViewLocation);
    // World collision only: non-blocking trigger actors must not hide pickups.
    // Stop before the item so collision of its supporting shelf is not the endpoint.
    for (I=0; I<3; ++I)
    {
        Sample=Target-Direction*8.0;
        Sample.Z+=float(I)*6.0;
        Obstacle=Player.HeroPawn.Trace(HitLocation,HitNormal,Sample,ViewLocation,false);
        if (Obstacle==None) { Reason=""; return true; }
        // Retail pickups can sit slightly inside the coarse collision of their support.
        if (VSize(HitLocation-Target)<=18.0) { Reason=""; return true; }
        Reason="world obstruction " $ string(Obstacle) $ " gap=" $ VSize(HitLocation-Target);
    }
    return false;
}

function OLBatteriesPickupFactory FindMagazineTarget(PistolPlayerController Player, optional bool bLogFailure)
{
    local OLBatteriesPickupFactory Battery, Best, NativeTarget;
    local vector ViewLocation, Forward, Target, Delta;
    local rotator ViewRotation;
    local float Distance, Along, Across, Score, BestScore, NearestDistance;
    local string Reason, NearestReason;
    if (Player==None || Player.HeroPawn==None) return None;
    Player.GetPlayerViewPoint(ViewLocation,ViewRotation);
    Forward=vector(ViewRotation);
    NativeTarget=OLBatteriesPickupFactory(Player.HeroPawn.ActivePickup);
    BestScore=1000000.0;
    NearestDistance=1000000.0;
    foreach AllActors(class'OLBatteriesPickupFactory',Battery)
    {
        if (Battery.bDeleteMe || Battery.bUsed || Battery.PickupMesh==None) continue;
        Target=GetMagazineLocation(Battery);
        Delta=Target-ViewLocation;
        Distance=VSize(Delta);
        if (Distance>300.0) continue;
        Reason="";
        if (Battery.bDisabled || Battery.bHidden) Reason="disabled/hidden by game";
        Along=Delta dot Forward;
        Across=VSize(Delta-Forward*Along);
        if (Reason=="" && (Along<=0.0 || Across>65.0 || Along/FMax(Distance,1.0)<0.75)) Reason="outside aim";
        if (Reason=="" && VSize(Target-Player.HeroPawn.Location)>260.0) Reason="outside reach";
        // Native active pickup is already selected by the game's interaction code.
        if (Reason=="" && Battery!=NativeTarget && !MagazineReachable(Player,ViewLocation,Target,Reason))
        {
            if (Reason=="") Reason="blocked";
        }
        if (Distance<NearestDistance)
        {
            NearestDistance=Distance;
            NearestReason=string(Battery) $ " reason=" $ Reason $ " distance=" $ Distance $ " across=" $ Across $ " center=" $ Target;
        }
        if (Reason!="") continue;
        Score=Across*3.0+Distance;
        if (Battery==NativeTarget) Score-=1000.0;
        if (Score<BestScore) { Best=Battery; BestScore=Score; }
    }
    if (Best==None && bLogFailure)
    {
        if (NearestReason=="") NearestReason="no unused magazine within 300 units";
        LastPickupFailure=NearestReason;
        LogInternal("[M9Pickup] no target: " $ NearestReason $ " camera=" $ ViewLocation);
    }
    return Best;
}

function bool TryPickupMagazine(PistolPlayerController Player)
{
    local OLBatteriesPickupFactory Best;
    local int Index;
    RefreshWorldItems();
    Best=FindMagazineTarget(Player,true);
    if (Best==None || Best.bUsed) return false;
    Index=Magazines.Find(Best);
    if (Index==INDEX_NONE)
    {
        Magazines.AddItem(Best);
        MagazineUsed.AddItem(true);
    }
    else MagazineUsed[Index]=true;
    Best.bUsed=true;
    Best.bDisabled=true;
    Best.SetHidden(true);
    Best.PickupMesh.SetHidden(true);
    Best.SetCollision(false,false);
    FocusedMagazine=None;
    AwardMagazine(Player,Best);
    LogInternal("[M9Pickup] consumed " $ string(Best));
    return true;
}

function RefreshWorldItems()
{
    local OLBatteriesPickupFactory Battery;
    local SkeletalMeshActor CinematicProp;
    local StaticMeshActor StaticProp;
    local int Index;
    foreach AllActors(class'OLBatteriesPickupFactory',Battery)
    {
        if (Battery.PickupMesh==None) continue;
        Index=Magazines.Find(Battery);
        if (Index==INDEX_NONE)
        {
            Magazines.AddItem(Battery);
            MagazineUsed.AddItem(Battery.bUsed);
            Index=Magazines.Length-1;
        }
        ReplaceVisual(Battery,Battery.PickupMesh,true);
        if (Battery.bUsed && !MagazineUsed[Index]) AddMagazineAmmo(Battery);
        MagazineUsed[Index]=Battery.bUsed;
    }
    foreach AllActors(class'SkeletalMeshActor',CinematicProp)
    {
        if (CinematicProp.SkeletalMeshComponent==None || CinematicProp.SkeletalMeshComponent.SkeletalMesh==None) continue;
        if (IsHandycam(string(CinematicProp.SkeletalMeshComponent.SkeletalMesh.Name)))
            ReplaceVisual(CinematicProp,CinematicProp.SkeletalMeshComponent,false);
    }
    foreach AllActors(class'StaticMeshActor',StaticProp)
    {
        if (StaticProp.StaticMeshComponent==None || StaticProp.StaticMeshComponent.StaticMesh==None) continue;
        if (IsHandycam(string(StaticProp.StaticMeshComponent.StaticMesh.Name)))
            ReplaceVisual(StaticProp,StaticProp.StaticMeshComponent,false);
    }
}

simulated event Tick(float DeltaTime)
{
    local PistolPlayerController Player;
    Super.Tick(DeltaTime);
    FocusScanTime-=DeltaTime;
    if (FocusScanTime<=0.0)
    {
        FocusScanTime=0.10;
        FocusedMagazine=None;
        foreach WorldInfo.AllControllers(class'PistolPlayerController',Player)
        {
            FocusedMagazine=FindMagazineTarget(Player);
            if (FocusedMagazine!=None) FocusedMagazineLocation=GetMagazineLocation(FocusedMagazine);
            break;
        }
    }
    ScanTime-=DeltaTime;
    if (ScanTime<=0.0)
    {
        ScanTime=0.25;
        RefreshWorldItems();
    }
}

defaultproperties
{
    bHidden=true
    bCollideActors=false
    bBlockActors=false
    RemoteRole=ROLE_None
}

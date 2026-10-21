class PistolViewModel extends Actor
	notplaceable
	hidecategories(Navigation);

var export editinline StaticMeshComponent M9Body;
var export editinline StaticMeshComponent M9Slide;
var export editinline StaticMeshComponent M9Magazine;
var export editinline SpotLightComponent PistolFlashlight;
var export editinline PointLightComponent MuzzleLight;
var SoundCue FireCue;
var SoundCue EmptyCue;
var SoundCue DrawCue;
var SoundCue MagOutCue;
var SoundCue MagInCue;
var SoundCue SlideCue;
var bool bAssetsReady;
var bool bSlideLocked;
var bool bReloadAnimation;
var bool bPlayedMagOut;
var bool bPlayedMagIn;
var bool bPlayedSlide;
var float ShotTime;
var float ReloadElapsed;
var float ReloadLength;
var float IdleTime;
var float RecoilAmount;
var float ReloadAmount;

simulated event PostBeginPlay()
{
	local StaticMesh BodyAsset, SlideAsset, MagazineAsset;

	super.PostBeginPlay();
	BodyAsset = StaticMesh(DynamicLoadObject("M9Assets.M9_Body", Class'Engine.StaticMesh', true));
	SlideAsset = StaticMesh(DynamicLoadObject("M9Assets.M9_Slide", Class'Engine.StaticMesh', true));
	MagazineAsset = StaticMesh(DynamicLoadObject("M9Assets.M9_Magazine", Class'Engine.StaticMesh', true));
	bAssetsReady = ((BodyAsset != none) && SlideAsset != none) && MagazineAsset != none;
	if(!bAssetsReady)
	{
		LogInternal("[M9] Missing M9Assets meshes. Import and save assets before installing.");
		return;
	}
	M9Body.SetStaticMesh(BodyAsset);
	M9Slide.SetStaticMesh(SlideAsset);
	M9Magazine.SetStaticMesh(MagazineAsset);
 M9Body.SetMaterial(0, class'M9MaterialLibrary'.static.GetGrip());
 M9Slide.SetMaterial(0, class'M9MaterialLibrary'.static.GetMetal());
 M9Magazine.SetMaterial(0, class'M9MaterialLibrary'.static.GetMetal());
	FireCue = SoundCue(DynamicLoadObject("M9Assets.M9_Fire_Cue", Class'Engine.SoundCue', true));
	EmptyCue = SoundCue(DynamicLoadObject("M9Assets.M9_Empty_Cue", Class'Engine.SoundCue', true));
	DrawCue = SoundCue(DynamicLoadObject("M9Assets.M9_Draw_Cue", Class'Engine.SoundCue', true));
	MagOutCue = SoundCue(DynamicLoadObject("M9Assets.M9_MagOut_Cue", Class'Engine.SoundCue', true));
	MagInCue = SoundCue(DynamicLoadObject("M9Assets.M9_MagIn_Cue", Class'Engine.SoundCue', true));
	SlideCue = SoundCue(DynamicLoadObject("M9Assets.M9_Slide_Cue", Class'Engine.SoundCue', true));
	if((((((FireCue == none) || EmptyCue == none) || DrawCue == none) || MagOutCue == none) || MagInCue == none) || SlideCue == none)
	{
		LogInternal("[M9] One or more SoundCues are missing; check asset names.");
	}
}

function LocalSound(SoundCue Cue)
{
	local PlayerController PC;

	PC = PlayerController(Owner);
	if((Cue != none) && PC != none)
	{
		PC.ClientPlaySound(Cue);
	}
}

function UpdateFlashlightPose(Vector CameraPosition, Rotator CameraOrientation)
{
    local Vector LightOrigin, Delta, Direction, Forward, Right, Up, LocalOrigin, LocalDirection;
    GetAxes(Rotation,Forward,Right,Up);
    LightOrigin=CameraPosition+Vector(CameraOrientation)*6.0;
    Delta=LightOrigin-Location;
    Direction=Vector(CameraOrientation);
    LocalOrigin.X=Delta dot Forward;LocalOrigin.Y=Delta dot Right;LocalOrigin.Z=Delta dot Up;
    LocalDirection.X=Direction dot Forward;LocalDirection.Y=Direction dot Right;LocalDirection.Z=Direction dot Up;
    PistolFlashlight.SetTranslation(LocalOrigin);
    PistolFlashlight.SetRotation(Rotator(LocalDirection));
}

function SetFlashlightEnabled(bool bEnabled)
{
	PistolFlashlight.SetEnabled(bEnabled && !bHidden);
}

function OnDraw()
{
	IdleTime = 0.0000000;
	LocalSound(DrawCue);
}

function OnFire(bool bLastRound)
{
	ShotTime = 0.0000000;
	bSlideLocked = bLastRound;
	RecoilAmount = 1.0000000;
	MuzzleLight.SetEnabled(true);
	LocalSound(FireCue);
}

function OnReload(float Duration)
{
	ReloadLength = FMax(0.2000000, Duration);
	ReloadElapsed = 0.0000000;
	bReloadAnimation = true;
	bPlayedMagOut = false;
	bPlayedMagIn = false;
	bPlayedSlide = false;
}

function CancelReload()
{
	bReloadAnimation = false;
	ReloadAmount = 0.0000000;
	M9Magazine.SetTranslation(vect(0.0000000, 0.0000000, 0.0000000));
	M9Magazine.SetHidden(false);
}

function OnHolster()
{
	CancelReload();
	MuzzleLight.SetEnabled(false);
	PistolFlashlight.SetEnabled(false);
	RecoilAmount = 0.0000000;
	ShotTime = 10.0000000;
}

function GetAnimationPose(out Vector Offset, out Rotator Turn)
{
	Offset = vect(0.0000000, 0.0000000, 0.0000000);
	Turn = rot(0, 0, 0);
	Offset.X = -2.4000000 * RecoilAmount;
	Offset.Z = (0.8000000 * RecoilAmount) - (6.0000000 * ReloadAmount);
	Offset.Y = Sin(IdleTime * 1.6000000) * 0.1000000;
	Offset.Z += (Sin(IdleTime * 2.1000000) * 0.0800000);
	Turn.Pitch = int((1500.0000000 * RecoilAmount) - (1600.0000000 * ReloadAmount));
	Turn.Roll = int(-7000.0000000 * ReloadAmount);
}

simulated event Tick(float DeltaTime)
{
	local float T, SlideBack, MagDrop;
	local Vector Offset;

	super.Tick(DeltaTime);
	if(!bAssetsReady || bHidden)
	{
		return;
	}
	IdleTime += DeltaTime;
	ShotTime += DeltaTime;
	if(ShotTime < 0.0350000)
	{
		SlideBack = ShotTime / 0.0350000;		
	}
	else
	{
		SlideBack = FMax(0.0000000, 1.0000000 - ((ShotTime - 0.0350000) / 0.0850000));
	}
	if(bSlideLocked && ShotTime >= 0.0350000)
	{
		SlideBack = 1.0000000;
	}
	RecoilAmount = FMax(0.0000000, 1.0000000 - (ShotTime / 0.1800000));
	MuzzleLight.SetEnabled(ShotTime < 0.0450000);
	if(bReloadAnimation)
	{
		ReloadElapsed += DeltaTime;
		T = FClamp(ReloadElapsed / ReloadLength, 0.0000000, 1.0000000);
		ReloadAmount = FMin(1.0000000, T / 0.1500000) * FMin(1.0000000, (1.0000000 - T) / 0.1500000);
		if((T >= 0.1800000) && !bPlayedMagOut)
		{
			bPlayedMagOut = true;
			LocalSound(MagOutCue);
		}
		if((T >= 0.6700000) && !bPlayedMagIn)
		{
			bPlayedMagIn = true;
			LocalSound(MagInCue);
		}
		if((T >= 0.8600000) && !bPlayedSlide)
		{
			bPlayedSlide = true;
			LocalSound(SlideCue);
			bSlideLocked = false;
		}
		if(T < 0.1800000)
		{
			MagDrop = 0.0000000;			
		}
		else
		{
			if(T < 0.4000000)
			{
				MagDrop = (T - 0.1800000) / 0.2200000;				
			}
			else
			{
				if(T < 0.5200000)
				{
					MagDrop = 1.0000000;					
				}
				else
				{
					if(T < 0.7200000)
					{
						MagDrop = 1.0000000 - ((T - 0.5200000) / 0.2000000);						
					}
					else
					{
						MagDrop = 0.0000000;
					}
				}
			}
		}
		Offset = vect(0.0000000, 0.0000000, 0.0000000);
		Offset.Z = -18.0000000 * MagDrop;
		M9Magazine.SetTranslation(Offset);
		M9Magazine.SetHidden((T >= 0.4000000) && T < 0.5200000);
		if((T >= 0.8200000) && T < 0.9400000)
		{
			SlideBack = FMax(SlideBack, Sin(((T - 0.8200000) / 0.1200000) * 3.1415930));
		}
		if(T >= 1.0000000)
		{
			CancelReload();
		}
	}
	Offset = vect(0.0000000, 0.0000000, 0.0000000);
	Offset.X = -2.7000000 * SlideBack;
	M9Slide.SetTranslation(Offset);
}

defaultproperties
{
 Begin Object Class=StaticMeshComponent Name=M9BodyComponent
  DepthPriorityGroup=SDPG_Foreground
  bCastDynamicShadow=false
  CollideActors=false
  BlockActors=false
  BlockRigidBody=false
 End Object
 M9Body=M9BodyComponent
 Components.Add(M9BodyComponent)
 Begin Object Class=StaticMeshComponent Name=M9SlideComponent
  DepthPriorityGroup=SDPG_Foreground
  bCastDynamicShadow=false
  CollideActors=false
  BlockActors=false
  BlockRigidBody=false
 End Object
 M9Slide=M9SlideComponent
 Components.Add(M9SlideComponent)
 Begin Object Class=StaticMeshComponent Name=M9MagazineComponent
  DepthPriorityGroup=SDPG_Foreground
  bCastDynamicShadow=false
  CollideActors=false
  BlockActors=false
  BlockRigidBody=false
 End Object
 M9Magazine=M9MagazineComponent
 Components.Add(M9MagazineComponent)
 Begin Object Class=SpotLightComponent Name=PistolFlashlightComponent
  InnerConeAngle=12.0
  OuterConeAngle=30.0
  Radius=850.0
  FalloffExponent=2.0
  Translation=(X=13.0,Y=0.0,Z=0.0)
  Brightness=0.075
  LightColor=(R=245,G=242,B=230,A=255)
  bEnabled=false
  bForceDynamicLight=true
  bPrecomputedLightingIsValid=false
  CastShadows=false
  CastStaticShadows=false
  CastDynamicShadows=false
 End Object
 PistolFlashlight=PistolFlashlightComponent
 Components.Add(PistolFlashlightComponent)
 Begin Object Class=PointLightComponent Name=MuzzleLightComponent
  Radius=120.0
  Translation=(X=13.0,Y=0.0,Z=5.0)
  Brightness=0.12
  LightColor=(R=255,G=190,B=95,A=255)
  bEnabled=false
  bForceDynamicLight=true
  bPrecomputedLightingIsValid=false
  CastShadows=false
 End Object
 MuzzleLight=MuzzleLightComponent
 Components.Add(MuzzleLightComponent)
 ShotTime=10.0
 bHidden=true
 bCollideActors=false
 bBlockActors=false
 RemoteRole=ROLE_None
}

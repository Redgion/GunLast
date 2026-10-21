class PistolPlayerController extends OLPlayerController
	config(Game)
	hidecategories(Navigation);

var int PistolAmmo;
var int PistolReserve;
var bool bPistolReloading;
var bool bPistolDrawn;
var bool bPistolFlashlightOn;
var transient bool bPistolDrawingIn;
var transient bool bPistolHolstering;
var PistolViewModel PistolView;
var transient float PistolReloadTimeRemaining;
var float PistolDamage;
var float PistolRange;
var float PistolReloadDuration;
var transient float PistolDrawAlpha;
var transient float PistolNextShotTime;
var transient float PistolNextEmptyTime;
var transient bool bPistolReloadBound;
var transient float MagazineNoticeUntil;
var transient int LastMagazineAmount;

exec function FirePistol()
{
	local Vector Start, Direction, End, HitLocation, HitNormal;

	local Rotator ViewRotation;
	local Actor HitActor;
	local OLPawn HitEnemy;
	local PistolGame CurrentPistolGame;
	local int EnemyHealth;
	local TraceHitInfo HitInfo;
	local float ShotRange;
	local int ShotDamage;
	// Interact before firing; native battery capacity does not limit ammunition.
	CurrentPistolGame = PistolGame(WorldInfo.Game);
	if (CurrentPistolGame != None && CurrentPistolGame.WorldReplacements != None)
	{
		if (CurrentPistolGame.WorldReplacements.TryPickupMagazine(self)) return;
	}
	if(((!bPistolDrawn || bPistolHolstering || bPistolReloading) || HeroPawn == none) || PistolView == none)
	{
		return;
	}
	if((PistolDrawAlpha < 1.0000000) || WorldInfo.TimeSeconds < PistolNextShotTime)
	{
		return;
	}
	if(PistolAmmo <= 0)
	{
		if(WorldInfo.TimeSeconds >= PistolNextEmptyTime)
		{
			PistolView.LocalSound(PistolView.EmptyCue);
			PistolNextEmptyTime = WorldInfo.TimeSeconds + 0.2500000;
		}
		return;
	}
	--PistolAmmo;
	PistolNextShotTime = WorldInfo.TimeSeconds + 0.1600000;
	PistolView.OnFire(PistolAmmo == 0);
	ClientMessage((("Pistol ammo: " $ string(PistolAmmo)) $ " / ") $ string(PistolReserve));
	ShotRange = PistolRange;
	if(ShotRange < 1000.0000000)
	{
		ShotRange = 12000.0000000;
	}
	ShotDamage = int(PistolDamage);
	if(ShotDamage < 1)
	{
		ShotDamage = 34;
	}
	GetPlayerViewPoint(Start, ViewRotation);
	Direction = Vector(ViewRotation);
	End = Start + (Direction * ShotRange);
	HitActor = Trace(HitLocation, HitNormal, End, Start, true, vect(0.0000000, 0.0000000, 0.0000000), HitInfo);
	HitEnemy = OLPawn(HitActor);
	if((HitEnemy != none) && OLHero(HitEnemy) != none)
	{
		HitEnemy = none;
	}
	CurrentPistolGame = PistolGame(WorldInfo.Game);
	if(CurrentPistolGame == none)
	{
		LogInternal("[OutlastPistolMod] FirePistol: active game is not PistolGame");
		return;
	}
	if(HitEnemy == none)
	{
		HitEnemy = CurrentPistolGame.FindPistolTarget(Start, Direction, ShotRange);
	}
	if(HitEnemy == none)
	{
		HitEnemy = CurrentPistolGame.FindPistolTarget(Start, Vector(Rotation), ShotRange);
	}
	LogInternal((((((("[OutlastPistolMod] FirePistol: range=" $ string(ShotRange)) $ " damage=") $ string(ShotDamage)) $ " hitactor=") $ string(HitActor)) $ " target=") $ string(HitEnemy));
	if(HitEnemy != none)
	{
		EnemyHealth = CurrentPistolGame.ApplyPistolDamage(HitEnemy, ShotDamage);
		if(EnemyHealth > 0)
		{
			ClientMessage((("Enemy health: " $ string(EnemyHealth)) $ " / ") $ string(CurrentPistolGame.PistolEnemyHealth));			
		}
		else
		{
			ClientMessage("Enemy down");
		}
	}
}

function bool EnsurePistolView()
{
	if(PistolView == none)
	{
		PistolView = Spawn(Class'OutlastPistolMod.PistolViewModel', self);
	}
	if(PistolView == none)
	{
		return false;
	}
	if(!PistolView.bAssetsReady)
	{
		ClientMessage("M9Assets is missing. See README_RU.txt.");
		return false;
	}
	return true;
}

exec function TogglePistolFlashlight()
{
	if(!bPistolDrawn || bPistolHolstering)
	{
		TogglePistol();
	}
	if(!bPistolDrawn || PistolView == none)
	{
		return;
	}
	bPistolFlashlightOn = !bPistolFlashlightOn;
	PistolView.SetFlashlightEnabled(bPistolFlashlightOn);
}

exec function TogglePistol()
{
    local Vector ViewLocation;
    local Rotator ViewRotation;
    if (bPistolHolstering)
    {
        bPistolHolstering=false;
        bPistolDrawingIn=true;
        PistolView.OnDraw();
        PistolView.SetFlashlightEnabled(bPistolFlashlightOn);
        return;
    }
    if (bPistolDrawn)
    {
        bPistolDrawingIn=false;
        bPistolHolstering=true;
        bPistolReloading=false;
        PistolReloadTimeRemaining=0.0;
        PistolView.OnHolster();
        return;
    }
    if (!EnsurePistolView()) return;
    bPistolDrawn=true;
    bPistolDrawingIn=true;
    bPistolHolstering=false;
    PistolDrawAlpha=0.0;
    PistolView.SetHidden(false);
    PistolView.OnDraw();
    PistolView.SetFlashlightEnabled(bPistolFlashlightOn);
    GetPlayerViewPoint(ViewLocation,ViewRotation);
    PositionPistol(ViewLocation,ViewRotation);
}

function PositionPistol(Vector ViewLocation, Rotator ViewRotation)
{
	local Vector Forward, Right, Up, AnimOffset;
	local Rotator AnimRotation;
	local float LowerAmount;
	if((PistolView == none) || !bPistolDrawn)
	{
		return;
	}
	GetAxes(ViewRotation, Forward, Right, Up);
	LowerAmount = 1.0000000 - PistolDrawAlpha;
	LowerAmount = (LowerAmount * LowerAmount) * (3.0000000 - (2.0000000 * LowerAmount));
	PistolView.GetAnimationPose(AnimOffset, AnimRotation);
	PistolView.SetLocation(((ViewLocation + (Forward * ((29.0000000 - (8.0000000 * LowerAmount)) + AnimOffset.X))) + (Right * ((9.0000000 + (5.0000000 * LowerAmount)) + AnimOffset.Y))) + (Up * ((-10.0000000 - (23.0000000 * LowerAmount)) + AnimOffset.Z)));
	AnimRotation.Pitch-=int(4500.0*LowerAmount);
    AnimRotation.Roll+=int(2500.0*LowerAmount);
	PistolView.SetRotation(ViewRotation + AnimRotation);
 PistolView.UpdateFlashlightPose(ViewLocation,ViewRotation);
}

function BindPistolReload()
{
    local int Index;
    local bool bFoundR;
    if (PlayerInput == None) return;
    for (Index=0; Index<PlayerInput.Bindings.Length; ++Index)
    {
        if (PlayerInput.Bindings[Index].Name == 'R' || PlayerInput.Bindings[Index].Name == 'OLA_Reload')
            PlayerInput.Bindings[Index].Command = "ReloadPistol";
        if (PlayerInput.Bindings[Index].Name == 'R') bFoundR=true;
    }
    if (!bFoundR)
    {
        Index=PlayerInput.Bindings.Length;
        PlayerInput.Bindings.Add(1);
        PlayerInput.Bindings[Index].Name='R';
        PlayerInput.Bindings[Index].Command="ReloadPistol";
    }
    bPistolReloadBound=true;
    LogInternal("[M9Repair] R reload binding active");
}

event PlayerTick(float DeltaTime)
{
	local Vector ViewLocation;
	local Rotator ViewRotation;

	super(PlayerController).PlayerTick(DeltaTime);
    if (!bPistolReloadBound) BindPistolReload();
	if(bPistolDrawn && HeroPawn != none)
	{
		if(HeroPawn.CameraMesh != none)
		{
			HeroPawn.CameraMesh.SetHidden(true);
		}
		if(HeroPawn.CameraMeshShadowProxy != none)
		{
			HeroPawn.CameraMeshShadowProxy.SetHidden(true);
		}
	}
	if(bPistolDrawn && PistolView != none)
	{
		if(bPistolDrawingIn)
		{
			PistolDrawAlpha = FMin(1.0000000, PistolDrawAlpha + (DeltaTime / 0.3800000));
			if(PistolDrawAlpha >= 1.0000000)
			{
				bPistolDrawingIn = false;
			}
		}
        if (bPistolHolstering)
            PistolDrawAlpha=FMax(0.0,PistolDrawAlpha-DeltaTime/0.30);
        GetPlayerViewPoint(ViewLocation,ViewRotation);
        PositionPistol(ViewLocation,ViewRotation);
        if (bPistolHolstering && PistolDrawAlpha<=0.0)
        {
            bPistolHolstering=false;
            bPistolDrawn=false;
            PistolView.SetHidden(true);
        }
    }
    if(bPistolReloading)
	{
		PistolReloadTimeRemaining -= DeltaTime;
		if(PistolReloadTimeRemaining <= 0.0000000)
		{
			FinishPistolReload();
		}
	}
}

exec function ReloadPistol()
{
	if((((!bPistolDrawn || bPistolHolstering || PistolView == none) || bPistolReloading) || PistolAmmo >= 8) || PistolReserve <= 0)
	{
		return;
	}
	bPistolReloading = true;
	PistolReloadTimeRemaining = FMax(0.2000000, PistolReloadDuration);
	PistolView.OnReload(PistolReloadTimeRemaining);
	ClientMessage("Reloading pistol...");
}

function FinishPistolReload()
{
	local int Needed;
	if(!bPistolReloading)
	{
		return;
	}
	Needed = 8 - PistolAmmo;
	if(Needed > PistolReserve)
	{
		Needed = PistolReserve;
	}
	PistolAmmo += Needed;
	PistolReserve -= Needed;
	bPistolReloading = false;
	PistolReloadTimeRemaining = 0.0000000;
	ClientMessage((("Pistol reloaded: " $ string(PistolAmmo)) $ " / ") $ string(PistolReserve));
}

event Destroyed()
{
	if(PistolView != none)
	{
		PistolView.Destroy();
	}
	super(PlayerController).Destroyed();
}

defaultproperties
{
 PistolAmmo=8
 PistolReserve=32
 PistolDamage=34.0
 PistolRange=12000.0
 PistolReloadDuration=2.0
}

class PistolGame extends OLGame
	config(Game)
	hidecategories(Navigation,Movement,Collision,Navigation,Movement,Collision);

var config int PistolEnemyHealth;
var transient array<OLPawn> PistolTrackedEnemies;
var transient array<int> PistolEnemyHealthValues;
var transient float PistolEnemyScanTimer;
var transient array<bool> PistolEnemyDead;
var transient M9WorldReplacements WorldReplacements;

function RefreshPistolEnemies()
{
	local OLPawn Enemy;
	foreach AllActors(Class'OLGame.OLPawn', Enemy)
	{
		if(((Enemy != none) && OLHero(Enemy) == none) && PistolTrackedEnemies.Find(Enemy) == -1)
		{
			RegisterPistolEnemy(Enemy);
		}		
	}	
}

function OLPawn FindPistolTarget(Vector ShotStart, Vector ShotDirection, float MaxRange)
{
	local OLPawn Enemy, BestEnemy, NearestEnemy;
	local Vector Offset, AimPoint;
	local float AlongDistance, BestDistance, NearestDistance, CollisionRadius, CollisionHeight, AimDot,
		BestDot, EnemyDistance;

	local int I;

	ShotDirection = Normal(ShotDirection);
	BestDistance = MaxRange + 1.0000000;
	NearestDistance = MaxRange + 1.0000000;
	BestDot = 0.5000000;
	I = 0;
	J0x63:
	if(I < PistolTrackedEnemies.Length)
	{
		Enemy = PistolTrackedEnemies[I];
		if((Enemy == none) || OLHero(Enemy) != none)
		{			
		}
		else
		{
			if(I >= PistolEnemyHealthValues.Length)
			{
				PistolEnemyHealthValues.AddItem(Max(PistolEnemyHealth, 100));
			}
			if(PistolEnemyHealthValues[I] <= 0)
			{				
			}
			else
			{
				Enemy.GetBoundingCylinder(CollisionRadius, CollisionHeight);
				if(CollisionHeight < 80.0000000)
				{
					CollisionHeight = 100.0000000;
				}
				AimPoint = Enemy.Location + (vect(0.0000000, 0.0000000, 1.0000000) * (CollisionHeight * 0.6500000));
				Offset = AimPoint - ShotStart;
				AlongDistance = Offset Dot ShotDirection;
				AimDot = Normal(Offset) Dot ShotDirection;
				EnemyDistance = VSize(Offset);
				LogInternal((((((((("[OutlastPistolMod] target candidate=" $ string(Enemy.Name)) $ " dist=") $ string(EnemyDistance)) $ " along=") $ string(AlongDistance)) $ " dot=") $ string(AimDot)) $ " hp=") $ string(PistolEnemyHealthValues[I]));
				if(EnemyDistance > MaxRange)
				{					
				}
				else
				{
					if(EnemyDistance < NearestDistance)
					{
						NearestEnemy = Enemy;
						NearestDistance = EnemyDistance;
					}
					if((AimDot >= 0.0000000) && (AimDot > BestDot) || (AimDot == BestDot) && EnemyDistance < BestDistance)
					{
						BestEnemy = Enemy;
						BestDistance = EnemyDistance;
						BestDot = AimDot;
						LogInternal((((("[OutlastPistolMod] aim candidate=" $ string(Enemy.Name)) $ " dot=") $ string(AimDot)) $ " range=") $ string(EnemyDistance));
					}
				}
			}
		}
		++I;
		goto J0x63;
	}
	if(BestEnemy == none)
	{
		BestEnemy = NearestEnemy;
	}
	LogInternal("[OutlastPistolMod] selected target=" $ string(BestEnemy));
	return BestEnemy;
}

function RegisterPistolEnemy(OLPawn Enemy)
{
	local int HealthCap;
	if((Enemy == none) || PistolTrackedEnemies.Find(Enemy) != -1)
	{
		return;
	}
	HealthCap = Max(PistolEnemyHealth, 100);
	PistolTrackedEnemies.AddItem(Enemy);
	PistolEnemyHealthValues.AddItem(HealthCap);
 PistolEnemyDead.AddItem(false);
	Enemy.HealthMax = HealthCap;
	Enemy.Health = HealthCap;
}

function PhysicsAsset GetCorpsePhysics(OLPawn Enemy)
{
    local PhysicsAsset Asset;
    local SkeletalMeshComponent TemplateMesh;
    local string MeshName;
    if (Enemy.Mesh == None) return None;
    Asset = Enemy.Mesh.PhysicsAsset;
    if (class'M9Corpse'.static.PhysicsFits(Asset, Enemy.Mesh)) return Asset;
    TemplateMesh = SkeletalMeshComponent(Enemy.Mesh.ObjectArchetype);
    if (TemplateMesh != None && TemplateMesh.SkeletalMesh == Enemy.Mesh.SkeletalMesh && class'M9Corpse'.static.PhysicsFits(TemplateMesh.PhysicsAsset, Enemy.Mesh))
        return TemplateMesh.PhysicsAsset;
    MeshName = Caps(string(Enemy.Mesh.SkeletalMesh.Name));
    if (OLEnemySoldier(Enemy) != None || InStr(MeshName, "SOLDIER") >= 0)
    {
        Asset = PhysicsAsset(FindObject("Soldier-v2_Physics", class'PhysicsAsset'));
        if (Asset == None) Asset = PhysicsAsset(DynamicLoadObject("03_Soldier.Meshes.Soldier-v2_Physics", class'PhysicsAsset', true));
    }
    else
    {
        Asset = PhysicsAsset(FindObject(string(Enemy.Mesh.SkeletalMesh.Name) $ "_Physics", class'PhysicsAsset'));
        if (Asset == None && OLEnemyNanoCloud(Enemy) == None)
            Asset = PhysicsAsset(DynamicLoadObject("02_Generic_Patient.Meshes.Patient_2_Physics", class'PhysicsAsset', true));
    }
    if (class'M9Corpse'.static.PhysicsFits(Asset, Enemy.Mesh)) return Asset;
    return None;
}

function DisableDeadPawn(OLPawn Enemy)
{
    local Controller DeadAI;
    if (Enemy == None || Enemy.bDeleteMe) return;
    DeadAI = Enemy.Controller;
    if (DeadAI != None && !DeadAI.bIsPlayer)
    {
        DeadAI.UnPossess();
        DeadAI.SetTickIsDisabled(true);
    }
    Enemy.Health = 0;
    Enemy.bCanBeDamaged = false;
    Enemy.SetCollision(false, false);
    Enemy.SetPhysics(PHYS_None);
    Enemy.SetHidden(true);
    if (Enemy.Mesh != None)
    {
        Enemy.Mesh.SetHidden(true);
        Enemy.Mesh.SetHasPhysicsAssetInstance(false);
    }
    Enemy.SetTickIsDisabled(true);
}

function CommitPistolDeath(OLPawn Enemy, int EnemyIndex)
{
    local M9Corpse Corpse;
    local OLEnemyPawn EnemyAI;
    if (PistolEnemyDead[EnemyIndex]) return;
    // Commit the dead state even when physics is unavailable. HP and AI cannot disagree.
    PistolEnemyDead[EnemyIndex] = true;
    PistolEnemyHealthValues[EnemyIndex] = 0;
    Corpse = Spawn(class'M9Corpse', self,, Enemy.Location, Enemy.Rotation,, true);
    if (Corpse != None && !Corpse.InitializeCorpse(Enemy, GetCorpsePhysics(Enemy)))
        Corpse.Destroy();
    EnemyAI = OLEnemyPawn(Enemy);
    if (EnemyAI != None)
    {
        EnemyAI.CancelSpecialMove();
        EnemyAI.DisableRootMotion();
        EnemyAI.Modifiers.bShouldAttack = false;
        EnemyAI.Modifiers.bAttackOnProximity = false;
    }
    DisableDeadPawn(Enemy);
    LogInternal("[M9Repair] NPC death committed: " $ string(Enemy) $ " corpse=" $ string(Corpse));
}

function int ApplyPistolDamage(OLPawn Enemy, int DamageAmount)
{
    local int EnemyIndex;
    if (Enemy == None || Enemy.bDeleteMe || OLHero(Enemy) != None || DamageAmount <= 0)
        return -1;
    RegisterPistolEnemy(Enemy);
    EnemyIndex = PistolTrackedEnemies.Find(Enemy);
    if (EnemyIndex == INDEX_NONE) return -1;
    if (PistolEnemyDead[EnemyIndex]) return 0;
    PistolEnemyHealthValues[EnemyIndex] = Max(0, PistolEnemyHealthValues[EnemyIndex] - DamageAmount);
    Enemy.HealthMax = Max(PistolEnemyHealth, 100);
    Enemy.Health = PistolEnemyHealthValues[EnemyIndex];
    LogInternal("[M9Repair] damage=" $ DamageAmount $ " NPC=" $ string(Enemy) $ " HP=" $ Enemy.Health);
    if (Enemy.Health <= 0)
        CommitPistolDeath(Enemy, EnemyIndex);
    return PistolEnemyHealthValues[EnemyIndex];
}

event PostBeginPlay()
{
    Super.PostBeginPlay();
    WorldReplacements = Spawn(class'M9WorldReplacements', self);
    LogInternal("[M9Repair] build 2026-10-20-r4 active; HP=" $ PistolEnemyHealth);
}

event Tick(float DeltaTime)
{
 local int DeadIndex;
	PistolEnemyScanTimer -= DeltaTime;
	if(PistolEnemyScanTimer <= 0.0000000)
	{
		PistolEnemyScanTimer = 1.0000000;
		RefreshPistolEnemies();
  for (DeadIndex=0; DeadIndex<PistolTrackedEnemies.Length; ++DeadIndex)
   if (DeadIndex<PistolEnemyDead.Length && PistolEnemyDead[DeadIndex]) DisableDeadPawn(PistolTrackedEnemies[DeadIndex]);
	}
	super(Actor).Tick(DeltaTime);
}

static event Class<GameInfo> SetGameType(string MapName, string Options, string Portal)
{
	return default.Class;
}

defaultproperties
{
 PistolEnemyHealth=100
 DefaultPawnClass=class'OLGame.OLHero'
	HUDType=Class'OutlastPistolMod.PistolHUD'
	PlayerControllerClass=Class'OutlastPistolMod.PistolPlayerController'
}
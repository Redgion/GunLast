class PistolHUD extends OLHUD
	transient
	config(Game)
	hidecategories(Navigation,Navigation);

var transient float NextEnemyScanTime;
var transient float LastBarRenderTime;
var transient bool bRenderedBarsThisFrame;
var transient float NextHudLogTime;
var transient float LastPickupPromptTime;
var transient bool bPickupPromptDrawn;

function Draw()
{
	super.Draw();
	DrawEnemyHealthBars();
    DrawMagazinePrompt();
}

event PostRender()
{
	super(MobileHUD).PostRender();
	DrawEnemyHealthBars();
    DrawMagazinePrompt();
}

function DrawEnemyHealthBars()
{
	local PistolGame ModGame;
	local OLPawn Enemy;
	local Vector CameraLocation, ViewDirection, WorldPoint, ScreenPoint;
	local Rotator CameraRotation;
	local float HealthRatio, BarWidth, BarHeight, BarX, Bary, CollisionRadius,
		CollisionHeight;

	local int I;
	if((Canvas == none) || PlayerOwner == none)
	{
		return;
	}
	ModGame = PistolGame(WorldInfo.Game);
	if(ModGame == none)
	{
		return;
	}
	if(bRenderedBarsThisFrame && LastBarRenderTime == WorldInfo.TimeSeconds)
	{
		return;
	}
	bRenderedBarsThisFrame = true;
	LastBarRenderTime = WorldInfo.TimeSeconds;
	if(WorldInfo.TimeSeconds >= NextEnemyScanTime)
	{
		ModGame.RefreshPistolEnemies();
		NextEnemyScanTime = WorldInfo.TimeSeconds + 0.5000000;
	}
	if(WorldInfo.TimeSeconds >= NextHudLogTime)
	{
		LogInternal("[OutlastPistolMod] overhead HUD active; tracked NPCs=" $ string(ModGame.PistolTrackedEnemies.Length));
		NextHudLogTime = WorldInfo.TimeSeconds + 5.0000000;
	}
	PlayerOwner.GetPlayerViewPoint(CameraLocation, CameraRotation);
	ViewDirection = Vector(CameraRotation);
	BarWidth = 112.0000000;
	BarHeight = 10.0000000;
	I = 0;
	J0x276:
	if(I < ModGame.PistolTrackedEnemies.Length)
	{
		Enemy = ModGame.PistolTrackedEnemies[I];
		if(((Enemy == none) || Enemy.bDeleteMe) || ModGame.PistolEnemyHealthValues[I] <= 0)
		{			
		}
		else
		{
			Enemy.GetBoundingCylinder(CollisionRadius, CollisionHeight);
			if(CollisionHeight < 80.0000000)
			{
				CollisionHeight = 100.0000000;
			}
			WorldPoint = Enemy.Location + (vect(0.0000000, 0.0000000, 1.0000000) * ((CollisionHeight * 1.7500000) + 20.0000000));
			if(((WorldPoint - CameraLocation) Dot ViewDirection) <= 0.0000000)
			{				
			}
			else
			{
				ScreenPoint = Canvas.Project(WorldPoint);
				if((((ScreenPoint.X < 8.0000000) || ScreenPoint.X > (Canvas.ClipX - 8.0000000)) || ScreenPoint.Y < 8.0000000) || ScreenPoint.Y > (Canvas.ClipY - 8.0000000))
				{					
				}
				else
				{
					BarX = ScreenPoint.X - (BarWidth * 0.5000000);
					Bary = (ScreenPoint.Y - BarHeight) - 4.0000000;
					HealthRatio = FClamp(float(ModGame.PistolEnemyHealthValues[I]) / float(Max(ModGame.PistolEnemyHealth, 100)), 0.0000000, 1.0000000);
					Canvas.SetPos(BarX, Bary);
					Canvas.SetDrawColor(0, 0, 0, 230);
					Canvas.DrawRect(BarWidth, BarHeight);
					Canvas.SetPos(BarX + 2.0000000, Bary + 2.0000000);
					if(HealthRatio > 0.5000000)
					{
						Canvas.SetDrawColor(60, 230, 80, 255);						
					}
					else
					{
						if(HealthRatio > 0.2500000)
						{
							Canvas.SetDrawColor(240, 190, 35, 255);							
						}
						else
						{
							Canvas.SetDrawColor(235, 45, 35, 255);
						}
					}
					Canvas.DrawRect((BarWidth - 4.0000000) * HealthRatio, BarHeight - 4.0000000);
				}
			}
		}
		++I;
		goto J0x276;
	}
}

function DrawMagazinePrompt()
{
    local PistolPlayerController Player;
    local PistolGame ModGame;
    local M9WorldReplacements Items;
    local vector Screen;
    local Font PreviousFont;
    local string Label;
    local float Width,Height;
    if (Canvas==None || PlayerOwner==None) return;
    if (bPickupPromptDrawn && LastPickupPromptTime==WorldInfo.TimeSeconds) return;
    bPickupPromptDrawn=true;
    LastPickupPromptTime=WorldInfo.TimeSeconds;
    Player=PistolPlayerController(PlayerOwner);
    ModGame=PistolGame(WorldInfo.Game);
    if (Player==None || ModGame==None) return;
    Items=ModGame.WorldReplacements;
    if (Items==None) return;
    PreviousFont=Canvas.Font;
    Canvas.Font=class'Engine'.static.GetSmallFont();
    if (Items.FocusedMagazine!=None && !Items.FocusedMagazine.bUsed)
    {
        Screen=Canvas.Project(Items.FocusedMagazineLocation);
        Label="[LMB] Pick up magazine";
        Canvas.TextSize(Label,Width,Height);
        Canvas.SetPos(FClamp(Screen.X-Width*0.5,8.0,FMax(8.0,Canvas.ClipX-Width-8.0)),FClamp(Screen.Y+16.0,8.0,FMax(8.0,Canvas.ClipY-Height-8.0)));
        Canvas.SetDrawColor(255,235,150,255);
        Canvas.DrawText(Label);
    }
    if (Player.MagazineNoticeUntil>WorldInfo.TimeSeconds)
    {
        Label="+" $ Player.LastMagazineAmount $ " ammo | Reserve: " $ Player.PistolReserve;
        Canvas.TextSize(Label,Width,Height);
        Canvas.SetPos((Canvas.ClipX-Width)*0.5,Canvas.ClipY*0.72);
        Canvas.SetDrawColor(160,255,160,255);
        Canvas.DrawText(Label);
    }
    Canvas.Font=PreviousFont;
}

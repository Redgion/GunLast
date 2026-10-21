class M9MaterialLibrary extends Object;

static function MaterialInterface BuildFinish(bool bGrip)
{
    local MaterialInterface ParentMaterial;
    local MaterialInstanceConstant Finish;
    local LinearColor Tint, Reflection;
    local string ParentPath;
    ParentPath=bGrip ? "Basic_Mat_Plastic.PlasticBlack-02_INST" : "Basic_Mat_Metal.Metal_brushed_MAT";
    ParentMaterial=MaterialInterface(FindObject(ParentPath,class'MaterialInterface'));
    if (ParentMaterial==None)
        ParentMaterial=MaterialInterface(DynamicLoadObject(ParentPath,class'MaterialInterface',true));
    if (ParentMaterial==None)
    {
        LogInternal("[M9Repair] material unavailable: " $ ParentPath);
        return MaterialInterface(DynamicLoadObject("01_Animated_Props.handycam_mat_INST",class'MaterialInterface',true));
    }
    Finish=new class'MaterialInstanceConstant';
    Finish.SetParent(ParentMaterial);
    Tint.R=bGrip ? 0.18 : 0.28;
    Tint.G=bGrip ? 0.18 : 0.30;
    Tint.B=bGrip ? 0.19 : 0.33;
    Tint.A=1.0;
    Reflection.R=0.15;Reflection.G=0.16;Reflection.B=0.18;Reflection.A=0.08;
    if (bGrip) Finish.SetVectorParameterValue('ColorDiffuse',Tint);
    else Finish.SetVectorParameterValue('DiffuseColor',Tint);
    Finish.SetVectorParameterValue('ColorCubemap',Reflection);
    Finish.SetScalarParameterValue('SpecIntensity',bGrip ? 0.05 : 0.22);
    Finish.SetScalarParameterValue('SpecPower',bGrip ? 24.0 : 64.0);
    LogInternal("[M9Repair] textured finish created: " $ ParentPath);
    return Finish;
}

static function MaterialInterface GetMetal()
{
    return BuildFinish(false);
}
static function MaterialInterface GetGrip()
{
    return BuildFinish(true);
}

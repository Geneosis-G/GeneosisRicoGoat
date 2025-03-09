class ProximityMine extends GGExplosiveActorContent;

/** If true, then we have ragdolled a limb */
var bool mRagdolledLimb;

/** The velocity we give the mine when launched */
var float mLaunchSpeed;

var SoundCue mHitPawnSoundCue;
var SoundCue mHitNonPawnSoundCue;

var PhysicalMaterial mExplosivePhysMat;

var rotator mRotOffset;

simulated event PreBeginPlay()
{
	super.PreBeginPlay();

	Instigator = Pawn( Owner );

	SetCollision( false, false );
	CollisionComponent.SetActorCollision( false, false );
	StaticMeshComponent.SetBlockRigidBody( false );
}

function PlaceMine()
{
	// Update collission
	SetCollision( true, true );
	CollisionComponent.SetActorCollision( true, false );
	StaticMeshComponent.SetBlockRigidBody( true );

	SetPhysics( PHYS_RigidBody );

	//Fix explosivity
	GetKActorPhysMaterial().PhysicalMaterialProperty=mExplosivePhysMat.PhysicalMaterialProperty;

	// Fire the mine straight forward
	StaticMeshComponent.SetRBLinearVelocity(Owner.Velocity + (vector( StaticMeshComponent.GetRotation() ) * mLaunchSpeed));
}

function TriggerMine()
{
 	ManageExplosion(none, none, none);
}

function bool HandleCollission( Actor Other, PrimitiveComponent OtherComp, vector HitLocation, vector HitNormal )
{
	local GGPawn pawn;
	local TraceHitInfo hitInfo;
	local vector dir;

	pawn = GGPawn( Other );

	// Direction the mine is flying
	dir = normal( StaticMeshComponent.GetRBLinearVelocity() );
	if( pawn != None )
	{
		// Several collission might come the first frame
		if( mRagdolledLimb )
		{
			return true;
		}

		PlaySound( mHitPawnSoundCue );

		// Find where we hit the mesh if we continue the same path
		if( TraceComponent( HitLocation, HitNormal, pawn.Mesh, Location - dir * 100, Location + dir * 100,, hitInfo ) && hitInfo.BoneName != '' )
		{
			mRagdolledLimb = true;
			SetPhysics( PHYS_None );

			SetCollision( false, false );
			StaticMeshComponent.SetNotifyRigidBodyCollision( false );
			StaticMeshComponent.SetActorCollision( false, false );
			StaticMeshComponent.SetBlockRigidBody( false );

			StaticMeshComponent.SetLightEnvironment(pawn.mLightEnvironment);

			if(HitLocation != vect(0, 0, 0))
				SetLocation(HitLocation);

			SetRotation(rot(0, 0, 0));
			SetBase( pawn,, pawn.mesh, hitInfo.BoneName );

			if(HitNormal != vect(0, 0, 0))
				StaticMeshComponent.SetRotation( rotator(HitNormal) + rot(-16384, 0, 0));
			else
				StaticMeshComponent.SetRotation( rotator(-dir) + rot(-16384, 0, 0));
		}

		return true;
	}
	else if(!ShouldIgnoreActor(Other))
	{
		if( mRagdolledLimb )
		{
			return true;
		}

		mRagdolledLimb = true;

		PlaySound( mHitNonPawnSoundCue );

		SetPhysics( PHYS_None );

		SetCollision( false, false );
		StaticMeshComponent.SetNotifyRigidBodyCollision( false );
		StaticMeshComponent.SetActorCollision( false, false );
		StaticMeshComponent.SetBlockRigidBody( false );

		SetRotation(rot(0, 0, 0));
		if(GGKactor(Other) != none)
			mRotOffset = Rotation - GGKactor(Other).StaticMeshComponent.GetRotation();
		SetBase(Other);

		if(HitNormal != vect(0, 0, 0))
			StaticMeshComponent.SetRotation(rotator(HitNormal) + rot(-16384, 0, 0));
		else
			StaticMeshComponent.SetRotation(rotator(-dir) + rot(-16384, 0, 0));

		return true;
	}

	return false;
}

function bool ShouldIgnoreActor(Actor act)
{
	return (
	Volume(act) != none
	|| GGApexDestructibleActor(act) != none
	|| act == self
	|| act == Owner);
}

event Touch( Actor Other, PrimitiveComponent OtherComp, vector HitLocation, vector HitNormal )
{
	if( Other == Instigator )
	{
		return;
	}

	if( !HandleCollission( Other, OtherComp, HitLocation, HitNormal ) )
	{
		super.Touch( Other, OtherComp, HitLocation, HitNormal );
	}
}

event Bump( Actor Other, PrimitiveComponent OtherComp, Vector HitNormal )
{
	if( Other == Instigator )
	{
		return;
	}

	if( !HandleCollission( Other, OtherComp, Location, HitNormal ) )
	{
		super.Bump( Other, OtherComp, HitNormal );
	}
}

event RigidBodyCollision( PrimitiveComponent HitComponent, PrimitiveComponent OtherComponent,
	const out CollisionImpactData RigidCollisionData, int ContactIndex )
{
	if( OtherComponent != none && OtherComponent.Owner == Instigator )
	{
		return;
	}

	// Don't call super if we attach to other, that will ragdoll the other pawn
	if( !HandleCollission( OtherComponent != none ? OtherComponent.Owner : None, OtherComponent, RigidCollisionData.ContactInfos[ContactIndex].ContactPosition, RigidCollisionData.ContactInfos[ContactIndex].ContactNormal ) )
	{
		super.RigidBodyCollision( HitComponent, OtherComponent, RigidCollisionData, ContactIndex );
	}
}

function bool ShouldExplode( int damageDealt, class< DamageType > damageType, vector momentum, Actor damageCauser );

event Tick(float deltaTime)
{
	super.Tick(DeltaTime);
	// Fix glitchy rotation on kactors
	if(GGKactor(Base) != none)
	{
		SetRotation(rTurn(GGKactor(Base).StaticMeshComponent.GetRotation(), mRotOffset));
	}
}

function rotator rTurn(rotator rHeading,rotator rTurnAngle)
{
    // Generate a turn in object coordinates
    //     this should handle any gymbal lock issues

    local vector vForward,vRight,vUpward;
    local vector vForward2,vRight2,vUpward2;
    local rotator T;
    local vector  V;

    GetAxes(rHeading,vForward,vRight,vUpward);
    //  rotate in plane that contains vForward&vRight
    T.Yaw=rTurnAngle.Yaw; V=vector(T);
    vForward2=V.X*vForward + V.Y*vRight;
    vRight2=V.X*vRight - V.Y*vForward;
    vUpward2=vUpward;

    // rotate in plane that contains vForward&vUpward
    T.Yaw=rTurnAngle.Pitch; V=vector(T);
    vForward=V.X*vForward2 + V.Y*vUpward2;
    vRight=vRight2;
    vUpward=V.X*vUpward2 - V.Y*vForward2;

    // rotate in plane that contains vUpward&vRight
    T.Yaw=rTurnAngle.Roll; V=vector(T);
    vForward2=vForward;
    vRight2=V.X*vRight + V.Y*vUpward;
    vUpward2=V.X*vUpward - V.Y*vRight;

    T=OrthoRotation(vForward2,vRight2,vUpward2);

   return(T);
}

DefaultProperties
{
	Tag="TetherIgnore"

	Physics=PHYS_Interpolating

	mLaunchSpeed=1750
	//CustomGravityScaling=0.3

	Begin Object name=StaticMeshComponent0
		StaticMesh=StaticMesh'Space_Portal.Meshes.Buttonbase'
		//StaticMesh=StaticMesh'Heist_Props_Temp.mesh.Buttonbase'
		Scale3D=(X=0.05f,Y=0.05f,Z=0.2f)
		bNotifyRigidBodyCollision=true
		ScriptRigidBodyCollisionThreshold=10.0f //If too big, we won't get any notifications from collisions between kactors
		BlockRigidBody=true
	End Object

	mExplosivePhysMat=PhysicalMaterial'Physical_Materials.Garage.PhysMat_Explosive_Tube'

	bCollideActors=true
	bBlockActors=true

	bCallRigidBodyWakeEvents=true

	mHitPawnSoundCue=SoundCue'Space_CommandoBridge_Sounds.General.CB_Station_Button_Pressed_Cue'
	mHitNonPawnSoundCue=SoundCue'Space_CommandoBridge_Sounds.General.CB_Station_Button_Pressed_Cue'

	bStatic=false
	bNoDelete=false
}
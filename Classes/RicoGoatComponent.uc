class RicoGoatComponent extends GGHangGliderComponent;

var GGGoat gMe;
var GGMutator myMut;
var RicoGoatHookComponent mOtherComp;

var MaterialInstanceConstant mChuteMaterial;

var bool mUseWingsuit;
var float mEjectWingsuitStartTime;
var float mEjectWingsuitDuration;
var StaticMeshComponent mWingsuitMesh;
var float mSpeedFactor;
var float mWingsuitBoost;
var float mMaxSpeed;
var float mExpectedSpeed;
var float mRotInterpSpeed;
var rotator mCurrentRot;
var float mCamRotInterpSpeed;
var bool isForwardPressed;
var bool isBackPressed;
var bool isLeftPressed;
var bool isRightPressed;
var ParticleSystemComponent mTrailParticleLeft;
var ParticleSystemComponent mTrailParticleRight;

var bool mUseMines;
var array<ProximityMine> mMines;
var int mMaxMines;


/**
 * See super.
 */
function AttachToPlayer( GGGoat goat, optional GGMutator owningMutator )
{
	local color darkColor;
	local LinearColor newColor;

	super.AttachToPlayer(goat, owningMutator);

	if(mGoat != none)
	{
		gMe=goat;
		myMut=owningMutator;

		darkColor = MakeColor( 20, 20, 20, 255 );
		newColor = ColorToLinearColor(darkColor);
		mChuteMaterial.SetVectorParameterValue('color', newColor);
		mChuteMesh.SetMaterial(0, mChuteMaterial);
		mOriginalChuteMat = mChuteMaterial;
		mChuteMesh.SetLightEnvironment(gMe.mesh.LightEnvironment);

		gMe.mesh.AttachComponentToSocket( mWingsuitMesh, mChuteSocket );
		mWingsuitMesh.SetHidden(true);
		mWingsuitMesh.SetLightEnvironment(gMe.mesh.LightEnvironment);

		gMe.mesh.AttachComponentToSocket( mTrailParticleLeft, mChuteSocket );
		mTrailParticleLeft.SetTranslation(vect(-15.f, -65.f, 15.f));
		mTrailParticleLeft.DeactivateSystem();
		mTrailParticleLeft.KillParticlesForced();

		gMe.mesh.AttachComponentToSocket( mTrailParticleRight, mChuteSocket );
		mTrailParticleRight.SetTranslation(vect(-15.f, 65.f, 15.f));
		mTrailParticleRight.DeactivateSystem();
		mTrailParticleRight.KillParticlesForced();
	}
}

function KeyState( name newKey, EKeyState keyState, PlayerController PCOwner )
{
	local GGPlayerInputGame localInput;

	if(PCOwner != gMe.Controller)
		return;

	localInput = GGPlayerInputGame( PCOwner.PlayerInput );

	if( keyState == KS_Down )
	{
		if( localInput.IsKeyIsPressed( "GBA_Jump", string( newKey ) ) )
		{
			if(mGoat.Physics == PHYS_Falling)
				ToggleChute();
		}

		if( localInput.IsKeyIsPressed( "GBA_AbilityBite", string( newKey ) ) )
		{
			if(mGoat.Physics == PHYS_Falling)
				ToggleWingsuit();
		}

		if( localInput.IsKeyIsPressed( "GBA_Forward", string( newKey ) ))
		{
			isForwardPressed = true;
		}

		if( localInput.IsKeyIsPressed( "GBA_Back", string( newKey ) ))
		{
			isBackPressed = true;
		}

		if( localInput.IsKeyIsPressed( "GBA_Left", string( newKey ) ))
		{
			isLeftPressed = true;
		}

		if( localInput.IsKeyIsPressed( "GBA_Right", string( newKey ) ))
		{
			isRightPressed = true;
		}

		if( newKey == 'LEFTCONTROL' || newKey == 'XboxTypeS_DPad_Down')
		{
			if(gMe.Velocity == vect(0, 0, 0))
				ToggleUseMines();
		}

		if( localInput.IsKeyIsPressed( "GBA_Special", string( newKey ) ))
		{
			if(mUseMines)
				PlaceMine();
		}

		if( localInput.IsKeyIsPressed( "GBA_Baa", string( newKey ) ))
		{
			gMe.SetTimer(1.f, false, NameOf(ExplodeMines), self);
		}
	}
	else if( keyState == KS_Up )
	{
		if( localInput.IsKeyIsPressed( "GBA_Forward", string( newKey ) ))
		{
			isForwardPressed = false;
		}

		if( localInput.IsKeyIsPressed( "GBA_Back", string( newKey ) ))
		{
			isBackPressed = false;
		}

		if( localInput.IsKeyIsPressed( "GBA_Left", string( newKey ) ))
		{
			isLeftPressed = false;
		}

		if( localInput.IsKeyIsPressed( "GBA_Right", string( newKey ) ))
		{
			isRightPressed = false;
		}

		if( localInput.IsKeyIsPressed( "GBA_Baa", string( newKey ) ))
		{
			gMe.ClearTimer(NameOf(ExplodeMines), self);
		}
	}
}

function EnableChute( bool enable )
{
	//myMut.WorldInfo.Game.Broadcast(myMut, "MultiJumpRemaining=" $ gMe.MultiJumpRemaining);
	if(enable && gMe.MultiJumpRemaining > 0)
		return;

	if(enable && Abs( Normalize(mGoat.Rotation).Pitch ) < mRotationThreshold)
	{
		//Close wingsuit if needed
		EnableWingsuit(false);
	}

	super.EnableChute(enable);
}

function EnableWingsuit( bool enable )
{
	if(enable == mUseWingsuit)
		return;

	if(enable)
	{
		//Close parachute if needed
		EnableChute(false);

		//Disable grapling hook/tether if needed
		//myMut.WorldInfo.Game.Broadcast(myMut, "mOtherComp=" $ mOtherComp);
		mOtherComp.BreakTether();
		mOtherComp.DetachHook();

		mWingsuitMesh.SetScale( 0.f );
		mEjectWingsuitStartTime = gMe.WorldInfo.TimeSeconds;

		mWingsuitMesh.SetHidden( false );

		if( mChuteOpenAC == none || ( mChuteOpenAC != none && mChuteOpenAC.IsPendingKill() ) )
		{
			mChuteOpenAC = mGoat.CreateAudioComponent( mChuteOpenSound, false );
		}

		if( mChuteOpenAC.IsPlaying() )
		{
			mChuteOpenAC.Stop();
			mChuteOpenAC.Play();
		}
		else
		{
			mChuteOpenAC.Play();
		}

		mWindSound.FadeIn(6, 1);

		//Add speed boost if needed
		mExpectedSpeed = VSize(gMe.Velocity);
		if(mExpectedSpeed < mWingsuitBoost)
			mExpectedSpeed = mWingsuitBoost;

		mCurrentRot = Normalize(gMe.Rotation);
	}
	else
	{
		mWindSound.FadeOut(2, 0);

		mWingsuitMesh.SetHidden( true );

		gMe.mesh.SetRotation(gMe.mesh.default.Rotation);

		if(mTrailParticleLeft.bIsActive)
		{
			mTrailParticleLeft.DeactivateSystem();
		}
		if(mTrailParticleRight.bIsActive)
		{
			mTrailParticleRight.DeactivateSystem();
		}
	}
	mUseWingsuit = enable;
}

function ToggleWingsuit()
{
	EnableWingsuit(!mUseWingsuit);
}

function SpawnRBodyParachute( vector loc, rotator chuteRot )
{
	if( mChuteDetachAC == none || ( mChuteDetachAC != none && mChuteDetachAC.IsPendingKill() ) )
	{
		mChuteDetachAC = mGoat.CreateAudioComponent( mChuteDetachSound, false );
	}

	if( mChuteDetachAC.IsPlaying() )
	{
		mChuteDetachAC.Stop();
		mChuteDetachAC.Play();
	}
	else
	{
		mChuteDetachAC.Play();
	}
}

function ToggleUseMines()
{
	mUseMines = !mUseMines;
	if(mUseMines)
		myMut.WorldInfo.Game.Broadcast(myMut, "Mine placement enabled");
	else
		myMut.WorldInfo.Game.Broadcast(myMut, "Mine placement disabled");
}

function PlaceMine()
{
	local ProximityMine newMine;
	local vector minePos;
	local rotator mineRot;

	// Make mine aim at 45 deg down
	mineRot = gMe.Rotation;
	mineRot.Pitch += -8192;
	minePos = gMe.Location + (normal(vector(gMe.Rotation)) * gMe.GetCollisionRadius()) + (vect(0, 0, 1) * gMe.GetCollisionHeight());
	newMine = gMe.Spawn(class'ProximityMine', gMe,, minePos, mineRot,, true);

	// Stick mine to something
	newMine.PlaceMine();

	mMines.AddItem(newMine);
	if(myMut.WorldInfo.Game.GameSpeed >= 1.0f && !myMut.WorldInfo.bPlayersOnly)
	{
		while(mMines.Length > mMaxMines)
		{
			mMines[0].ShutDown();
			mMines[0].Destroy();
			mMines.Remove(0, 1);
		}
	}
}

function ExplodeMines()
{
	local ProximityMine mine;

	if(!mUseMines)
		return;

	foreach mMines(mine)
	{
		mine.TriggerMine();
	}

	mMines.Length = 0;
}
//Custom tick function  to get correct valued for aBaseY and aStrafe
function Tick( float deltaTime )
{
	local float currentBaseY, currentStrafe;

	//Direction pressed for controllers
	if(gMe.Controller != none && GGLocalPlayer(PlayerController( gMe.Controller ).Player).mIsUsingGamePad)
	{
		currentBaseY=PlayerController( gMe.Controller ).PlayerInput.aBaseY;
		currentStrafe=PlayerController( gMe.Controller ).PlayerInput.aStrafe;

		isForwardPressed = currentBaseY > 0.8f;
		isBackPressed = currentBaseY < -0.8f;
		isRightPressed = currentStrafe > 0.8f;
		isLeftPressed = currentStrafe < -0.8f;
	}
}

simulated event TickMutatorComponent( float delta )
{
	super.TickMutatorComponent(delta);

	if(gMe.Physics != PHYS_FALLING && mUseWIngsuit)
	{
		EnableWingsuit(false);
		return;
	}

	HandleWingsuitEjectScale();
	HandleGoatAngle(delta);
	HandleWingsuitVelocity(delta);
	HandleVisualEffects();
}

/**
  * Adds the velocity to the goat
  */
function HandleVelocityAdd( float delta )
{
	local vector velToAdd;
	local InterpActor grabbedInterpActor;
	local vector interpActVelToAdd;
	local float linearVel;
	local bool grappleStatic;

	super.HandleVelocityAdd(delta);

	if( mIsChuteOut )
	{
		// Check if the goat has grappled something that should move it
		grabbedInterpActor = InterpActor( mOtherComp.mGrapplingHook.mGrappledActor );
		grappleStatic = mOtherComp.mGrapplingHook.IsGrappling() && !mOtherComp.mDestinationReached;
		//myMut.WorldInfo.Game.Broadcast(myMut, "grappleStatic=" $ grappleStatic);
		if(grabbedInterpActor != none || grappleStatic)
		{
			interpActVelToAdd = Normal( grabbedInterpActor.Location - gMe.Location ) * VSize( grabbedInterpActor.Velocity * vect( 1, 1, 0 ) ) ;

			if(grabbedInterpActor != none)
			{
				gMe.Velocity.X = interpActVelToAdd.X;
				gMe.Velocity.Y = interpActVelToAdd.Y;
			}

			linearVel = VSize2D(gMe.Velocity);

			if(VSizeSq( grabbedInterpActor.Velocity ) > 100.f || grappleStatic)
			{
				velToAdd.Z += linearVel * 2.f;
				//myMut.WorldInfo.Game.Broadcast(myMut, "+500");
			}

			if(gMe.Location.Z - grabbedInterpActor.Location.Z > 1000.f
			|| (grappleStatic && gMe.Location.Z - mOtherComp.mGrapplingHook.mGrappledLocation.Z > 1000.f))
			{
				velToAdd.Z = 0.f;
				//myMut.WorldInfo.Game.Broadcast(myMut, "+0");
			}

			gMe.Velocity.Z += velToAdd.Z * delta;
			if(grappleStatic && gMe.Location.Z > mOtherComp.mGrapplingHook.mGrappledLocation.Z)
				gMe.Velocity = Normal(gMe.Velocity) * Max(linearVel, gMe.Velocity.Z);
		}

		// if destination reached with open parachute and no interpactor dragging us, detach hook
		if(grabbedInterpActor == none && mOtherComp.mDestinationReached)
		{
			mOtherComp.DetachHook();
		}
	}
}

function HandleWingsuitEjectScale()
{
	if( ( gMe.WorldInfo.TimeSeconds - mEjectWingsuitStartTime  ) < mEjectWingsuitDuration )
	{
		mWingsuitMesh.SetScale( ( gMe.WorldInfo.TimeSeconds - mEjectWingsuitStartTime ) / mEjectWingsuitDuration );
	}
	else if(mWingsuitMesh.Scale != 1.f)
	{
		mWingsuitMesh.SetScale(1.f);
	}
}

function HandleGoatAngle(float delta)
{
	local rotator expectedRot, newRot, desiredRotation;

	if(!mUseWingsuit)
 		return;

	expectedRot = mCurrentRot;
	expectedRot.Roll = 0;
	if(isForwardPressed)
	{
		expectedRot.Pitch = -16384;
	}
	if(isBackPressed)
	{
		expectedRot.Pitch = 16384;
	}
	if(isLeftPressed)
	{
		expectedRot.Roll = -16384;
	}
	if(isRightPressed)
	{
		expectedRot.Roll = 16384;
	}
	newRot = RInterpTo( mCurrentRot, expectedRot, delta, mRotInterpSpeed );
	mCurrentRot = Normalize(newRot);

	//Roll should be applied to the mesh
	desiredRotation=gMe.mesh.default.Rotation;
	desiredRotation.Roll = expectedRot.Roll;
	gMe.mesh.SetRotation( RInterpTo( gMe.mesh.Rotation, desiredRotation, delta, mRotInterpSpeed ) );

	//Convert Roll into Yaw turn
	mCurrentRot.Yaw = mCurrentRot.Yaw + (gMe.mesh.Rotation.Roll * delta / 1.f);

	gMe.SetRotation(mCurrentRot);
}

function HandleWingsuitVelocity(float delta)
{
 	local float speed, newSpeed, speedFactor;
 	local rotator normRot, expectedCamRot, newCamRot;
 	local GGPlayerControllerGame pc;

 	if(!mUseWingsuit)
 		return;

	//Comute new velocity depending on goat angle
	speed = mExpectedSpeed;

	normRot = Normalize(gMe.Rotation);
	speedFactor = -normRot.Pitch * mSpeedFactor;

	newSpeed = speed + (speedFactor * delta);

	if(newSpeed > mMaxSpeed)
		newSpeed = mMaxSpeed;

	mExpectedSpeed = newSpeed;
	if(mExpectedSpeed < 100.f)
	{
		EnableWingsuit(false);
		return;
	}

	gMe.Velocity = mExpectedSpeed * normal(vector(gMe.Rotation));

	//Force camera to follow player
	pc = GGPlayerControllerGame( gMe.Controller );
	if(pc != none)
	{
		expectedCamRot = gMe.Rotation;
		expectedCamRot.Roll = 0;
		newCamRot = RInterpTo( pc.PlayerCamera.Rotation, expectedCamRot, delta, mCamRotInterpSpeed );
		GGCamera( pc.PlayerCamera ).SetDesiredRotation( newCamRot );
		pc.SetRotation( newCamRot );

		//Cancel right click rotation
		pc.mRotationRate = rot(0, 0, 0);
		gMe.mTotalRotation = rot( 0, 0, 0 );
	}
}

function HandleVisualEffects()
{
	if(!mUseWingsuit)
 		return;

 	if(mExpectedSpeed > mMaxSpeed / 2.f)//Enough speed to show speed trails
 	{
		if(!mTrailParticleLeft.bIsActive)
		{
			mTrailParticleLeft.ActivateSystem();
		}
		if(!mTrailParticleRight.bIsActive)
		{
			mTrailParticleRight.ActivateSystem();
		}
	}
	else
	{
		if(mTrailParticleLeft.bIsActive)
		{
			mTrailParticleLeft.DeactivateSystem();
		}
		if(mTrailParticleRight.bIsActive)
		{
			mTrailParticleRight.DeactivateSystem();
		}
	}
}

function OnCollision( Actor actor0, Actor actor1 )
{
	if(actor0 == gMe || actor1 == gMe)
	{
		if(mUseWingsuit)
		{
			gMe.SetRagdoll(true);
		}
	}
}

function OnTakeDamage( Actor damagedActor, Actor damageCauser, int damage, class< DamageType > dmgType, vector momentum )
{
	if(damagedActor == gMe && mUseWingsuit)
	{
		gMe.SetRagdoll(true);
	}
}

function OnRagdoll( Actor ragdolledActor, bool isRagdoll )
{
	if(ragdolledActor == gMe && isRagdoll)
	{
		EnableWingsuit(false);
	}
}

defaultproperties
{
	mUseMines=true

	mGoggleMesh=none
	mChuteMaterial=MaterialInstanceConstant'Parachute.Materials.Parachute_Mat_INST_01'

	mEjectWingsuitDuration=0.25f
	mSpeedFactor=0.1f
	mWingsuitBoost=1000.f
	mMaxSpeed=5000.f
	mRotInterpSpeed = 1.f
	mCamRotInterpSpeed=5.f

	mMaxMines=6

	Begin Object class=StaticMeshComponent Name=wingsuitMesh
		StaticMesh=StaticMesh'Hanglider.mesh.Hanglider_01'
		Materials[0]=Material'GasStation.Materials.WallParasol_Black_Mat_01'
		Scale3D=(x=-0.2f, y=0.2f, z=0.2f)
	End Object
	mWingsuitMesh=wingsuitMesh

	Begin Object class=ParticleSystemComponent Name=TrailParticleSystemComponent1
		Template=ParticleSystem'Space_Particles.Particles.Hovercraft_Trail_Light_PS'
		bAutoActivate=false
	End Object
	mTrailParticleLeft=TrailParticleSystemComponent1

	Begin Object class=ParticleSystemComponent Name=TrailParticleSystemComponent2
		Template=ParticleSystem'Space_Particles.Particles.Hovercraft_Trail_Light_PS'
		bAutoActivate=false
	End Object
	mTrailParticleRight=TrailParticleSystemComponent2
}
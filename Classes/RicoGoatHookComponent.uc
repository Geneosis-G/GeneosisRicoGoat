class RicoGoatHookComponent extends GGTetherGoatComponents;

var GGGoat gMe;
var GGMutator myMut;
var RicoGoatComponent mOtherComp;

var bool mTetherEnabled;
var vector mAimCenter;

var instanced GGGrapplingHook mGrapplingHook;
var HookRope mRope;
var bool mDestinationReached;
var bool mDefaultCRBVOI;
var float mStopDistFactor;
var vector mStartLocation;

var array<TetherRope> mTetherRopes;
var int mMaxTetherRopes;

var bool mShrinkRopes;
var bool mExtendRopes;
var float mResizeRatio;

/**
 * See super.
 */
function AttachToPlayer( GGGoat goat, optional GGMutator owningMutator )
{
	super.AttachToPlayer(goat, owningMutator);

	if(mGoat != none)
	{
		gMe=goat;
		myMut=owningMutator;

		mGrapplingHook.mOwningPawn = gMe;
		gMe.AttachComponent(mGrapplingHook);

		SpawnRope();

		mDefaultCRBVOI=gMe.mCanRagdollByVelocityOrImpact;
	}
}

function SpawnRope()
{
	mRope = gMe.Spawn(class'HookRope', gMe,, gMe.Location,,, true);
	mRope.SetHidden(true);
}

function TickMutatorComponent( float deltaTime )
{
	super(GGMutatorComponentSpace).TickMutatorComponent( deltaTime );

	mNearbyTetherPoint = GetBestNearbyTetherablePoint();
	UpdateTetherLocationParticle( true, mNearbyTetherPoint.location );

	if(mRope == none || mRope.bPendingDelete)
		SpawnRope();

	UpdateHook();
	UpdateTetherRopes(deltaTime);
}

function UpdateTetherLocationParticle( bool showParticle, optional vector particleLocation )
{
	if( showParticle )
	{
		if(mTetherLocationParticleActor == none || mTetherLocationParticleActor.bPendingDelete)
		{
			SpawnTetherLocationActor();
		}
	}

	super.UpdateTetherLocationParticle(showParticle, particleLocation);
}

function UpdateHook()
{
	local float orientation;

	if(!mGrapplingHook.IsGrappling() || mDestinationReached)
		return;

	// if hook retracting, stay in the air until destination is reached
	if(gMe.Physics == PHYS_Falling || gMe.Physics == PHYS_Flying)
	{
		if(VSize2D(mGrapplingHook.mGrappledLocation - gMe.Location) > (gMe.GetCollisionRadius() * mStopDistFactor))
		{
			if(gMe.Velocity.Z < 0.f && gMe.mDistanceToGround < 100.f)
			{
				gMe.Velocity.Z = 300.f;
			}
		}
		else
		{
			mDestinationReached = true;
		}

		orientation = ((mGrapplingHook.mGrappledLocation - gMe.Location) * vect(1, 1, 0)) dot ((mGrapplingHook.mGrappledLocation - mStartLocation) * vect(1, 1, 0));
		if(mGrapplingHook.mGrappledActor.bStatic && orientation < 0.f)
		{
			mDestinationReached = true;
		}
	}
}

function UpdateTetherRopes(float deltaTime)
{
	// If hook retracting, break tether
	if(mCurrentTether != none && mGrapplingHook.IsGrappling())
	{
		if(gMe.Physics == PHYS_Falling || gMe.Physics == PHYS_Flying)
			BreakTether(false);
	}
	// Extend or shrink ropes depending on key pressed
	if(mShrinkRopes && mExtendRopes)
	{
		BreakTetherRopes();
	}
	else if(mShrinkRopes)
	{
		ResizeTetherRopes(-mResizeRatio * deltaTime);
	}
	else if(mExtendRopes)
	{
		ResizeTetherRopes(mResizeRatio * deltaTime);
	}
}

function BreakTetherRopes()
{
	while(mTetherRopes.Length > 0)
	{
		if(mTetherRopes[0] == none || mTetherRopes[0].bPendingDelete)
			mTetherRopes.Remove(0, 1);
		else
			mTetherRopes[0].DestroyTetherRope();
	}
}

function ResizeTetherRopes(float dist)
{
	local TetherRope tr;

	foreach mTetherRopes(tr)
	{
		tr.SetTetherLength(tr.mTetherLength + dist);
		tr.CreateTetherConstraint();
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
		if( localInput.IsKeyIsPressed( "GBA_FreeLook", string( newKey ) ) )
		{
			if(!mGrapplingHook.IsGrappling())
			{
				TetherKeyPressed();
				AttachHook();
				mTetherEnabled = false;
				gMe.SetTimer(0.5f, false, NameOf(EnableTether), self);
			}
			else
			{
				DetachHook();
			}
		}

		if( newKey == 'G' || newKey == 'XboxTypeS_DPad_Up')
		{
			mShrinkRopes = true;
		}

		if( newKey == 'H' || newKey == 'XboxTypeS_DPad_Down')
		{
			mExtendRopes = true;
		}
	}
	else if( keyState == KS_Up )
	{
		if( localInput.IsKeyIsPressed( "GBA_FreeLook", string( newKey ) ) )
		{
			gMe.ClearTimer(NameOf(EnableTether), self);
			if(!mTetherEnabled)
			{
				BreakTether(false);
				RetractHook();
			}
			else
			{
				DetachHook();
				if(mCurrentTether != none)
					TetherKeyPressed();//Attack second part of tether
			}
		}

		if( newKey == 'G' || newKey == 'XboxTypeS_DPad_Up')
		{
			mShrinkRopes = false;
		}

		if( newKey == 'H' || newKey == 'XboxTypeS_DPad_Down')
		{
			mExtendRopes = false;
		}
	}
}

function AttachHook()
{
	local vector startLoc;
	//myMut.WorldInfo.Game.Broadcast(myMut, "mOtherComp=" $ mOtherComp);
	if(mGrapplingHook.IsGrappling() || gMe.DrivenVehicle != None  || gMe.mIsRagdoll || mOtherComp.mUseWingsuit)
		return;

	mTetherDeviceMesh.GetSocketWorldLocationAndRotation(mTetherStartSocketName, startLoc);
	mGrapplingHook.ShootGrapplingHook( startLoc, mNearbyTetherPoint.Location - startLoc );
	if(mGrapplingHook.IsGrappling())
	{
		mRope.AttachRope(mTetherDeviceMesh, mGrapplingHook.mGrappledComponent, startLoc, mGrapplingHook.mGrappledLocation, mTetherStartSocketName, mGrapplingHook.mGrappledBoneName);
		mRope.SetHidden(false);
	}
	mDestinationReached = false;
	gMe.mCanRagdollByVelocityOrImpact=false;
	mStartLocation = gMe.Location;
}

function RetractHook()
{
	if(mGrapplingHook.IsGrappling())
		gMe.DoJump(true);
}

function DetachHook()
{
	if(mGrapplingHook.IsGrappling())
	{
		mGrapplingHook.ReleaseActor();
		mRope.DetachRope();
		mRope.SetHidden(true);
	}
	gMe.mCanRagdollByVelocityOrImpact=mDefaultCRBVOI;
}

function EnableTether()
{
	mTetherEnabled = true;
}

function BreakTether(bool breakSound = true)
{
	if(mCurrentTether != none)
	{
		TetherRope(mCurrentTether).DestroyTetherRope(breakSound);
		mCurrentTether = none;
	}
}

function bool CanTetherToActor( actor actorToTest )
{
	return ( mCurrentTether == none || !mCurrentTether.IsTetheredToActor( actorToTest ) ) && !(string( actorToTest.Tag ) ~= mIgnoreTag) && !ShouldIgnoreActor(actorToTest);
}

function bool ShouldIgnoreActor(Actor act)
{
	return (
	Volume(act) != none
	|| GGApexDestructibleActor(act) != none
	|| (mCurrentTether != none &&
		(act == mCurrentTether
		|| act == mCurrentTether.Owner)));
}

function NearbyTetherPoint GetBestNearbyTetherablePoint()
{
	local Actor foundActor, targetActor;
	local Vector outClosestPoint, startLocation, dummyExtent, dummyOutPoint, camLocation, StartTrace, EndTrace, AdjustedAim, hitNormal;
	local rotator camRotation;
	local name closestBone;
	local NearbyTetherPoint newNearbyTetherPoint;

	//Find item pointed by camera
	GGPlayerControllerGame( gMe.Controller ).PlayerCamera.GetCameraViewPoint( camLocation, camRotation );
	StartTrace = camLocation;

	AdjustedAim = vector(camRotation);

	EndTrace = StartTrace + (AdjustedAim * mGrapplingHook.mRange);

	targetActor = gMe.Trace( mAimCenter, hitNormal, EndTrace, StartTrace);
	if(targetActor == none) mAimCenter=EndTrace;

	//If near tetherable actor move target to that actor
	foundActor = GetClosestTetherableActor();

	if( foundActor != none )
	{
		startLocation = mGoat.Location;
		outClosestPoint = mAimCenter;

		if( DynamicSMActor(foundActor) != None )
		{
			DynamicSMActor(foundActor).StaticMeshComponent.ClosestPointOnComponentToPoint( startLocation, dummyExtent, dummyOutPoint, outClosestPoint );
		}

		if( Pawn( foundActor ) != None )
		{
			closestBone = GGGrabbableActorInterface( foundActor ).GetGrabInfo( mGoat.Location );

			if( closestBone == 'none' || closestBone == '' )
			{
				closestBone = Pawn( foundActor ).mesh.FindClosestBone( mGoat.Location );
			}

			// Last case scenario just use the first bone in the mesh
			if( closestBone == 'none' || closestBone == '' )
			{
				closestBone = Pawn( foundActor ).mesh.GetBoneName( 0 );
			}

			newNearbyTetherPoint.Location = Pawn( foundActor ).mesh.GetBoneLocation( closestBone );
			newNearbyTetherPoint.TetherActor = foundActor;
		}
		else
		{
			newNearbyTetherPoint.Location = outClosestPoint;
			newNearbyTetherPoint.TetherActor = foundActor;
		}
	}
	else
	{
		newNearbyTetherPoint.Location = mAimCenter;
		newNearbyTetherPoint.TetherActor = targetActor;
	}

	return newNearbyTetherPoint;
}

function Actor GetClosestTetherableActor()
{
	local float closestDist, tempDist;
	local Actor actorItr, closestActor;

	closestDist = 9999999999999999.0f;

	foreach mGoat.OverlappingActors(class'Actor', actorItr, mLookForTetherPointRadius, mAimCenter)
	{
		if ( IsActorEligibleForRangedTether( actorItr ) )
		{
			// If this actor's tag is the priority tag, just return it no matter what
			if( string( actorItr.Tag ) ~= mPriorityTag )
			{
				return actorItr;
			}

			tempDist = VSizeSq( mAimCenter - actorItr.Location );

			if( tempDist < closestDist )
			{
				closestDist = tempDist;
				closestActor = actorItr;
			}
		}
	}

	return closestActor;
}

function bool IsActorEligibleForRangedTether( Actor actorToTest )
{
	if( actorToTest == None || actorToTest == mGoat || ( mLastActorTethered != None && actorToTest == mLastActorTethered ) || !CanTetherToActor( actorToTest ) )
	{
		return false;
	}

	return true;
}

function TetherKeyPressed()
{
	local ETetherStatus tetherSuccessful;
	local actor actorToTetherTo;
	local vector locationToAttachTetherTo;

	// Don't grab things while driving?
	if(mGoat.DrivenVehicle != None || gMe.mIsRagdoll || mOtherComp.mUseWingsuit)
		return;

	// Tether the best nearby actor
	if( mNearbyTetherPoint.TetherActor != none )
	{
		actorToTetherTo = mNearbyTetherPoint.TetherActor;
		locationToAttachTetherTo = mNearbyTetherPoint.Location;
	}

	if( actorToTetherTo != none )
	{
		if( mCurrentTether == none )
		{
			mCurrentTether = mGoat.Spawn( class'TetherRope',,, locationToAttachTetherTo,,, true);
		}

		tetherSuccessful = TetherToActor( actorToTetherTo, locationToAttachTetherTo );

		if( tetherSuccessful == THRS_FIRST_SUCCESS )
		{
			mLastActorTethered = actorToTetherTo;
			mNearbyTetherPoint.TetherActor = none;
			// Fix glitch when linking close actor to distant actor
			mCurrentTether.mTetherPoint.mActorBasedOn = mTetherLocationParticleActor;
			mCurrentTether.mTetherPoint.SetBase(mTetherLocationParticleActor);
		}
		else
		{
			mLastActorTethered = none;
		}
	}
	else if(mCurrentTether != none)
	{
		BreakTether(false);
	}
}

function ShowTetherHint( Actor currentActor, optional string hintName, optional int hintPriority );
function RemoveTetherHint( optional string hintName );

function OnRagdoll( Actor ragdolledActor, bool isRagdoll )
{
	if(ragdolledActor == gMe && isRagdoll)
	{
		BreakTether(false);
		DetachHook();
	}
}

function OnLanded( Actor actorLanded, Actor actorLandedOn )
{
	if(actorLanded == gMe)
	{
		DetachHook();
	}
}

function OnTetherAttached(TetherRope tether)
{
	mTetherRopes.AddItem(tether);
	if(myMut.WorldInfo.Game.GameSpeed >= 1.0f && !myMut.WorldInfo.bPlayersOnly)
	{
		while(mTetherRopes.Length > mMaxTetherRopes)
		{
			mTetherRopes[0].DestroyTetherRope();
		}
	}
}

function OnTetherDestroyed(TetherRope tether)
{
	mTetherRopes.RemoveItem(tether);
}

defaultproperties
{
	mStopDistFactor = 3.f;
	mMaxTetherRopes = 6.f;
	mResizeRatio = 100.f;

	Begin Object name=tetherMesh
		Scale3D=(X=1.f, Y=-1.f, Z=0.5f)
		Materials[0]=Material'Props_01.Materials.Bicycle_Black_Mat_01'
		Materials[1]=Material'Props_01.Materials.Bicycle_Black_Mat_01'
	End Object

	mTetherShootSound = SoundCue'Heist_Audio.Cue.SFX_Syringe_Shot_Mono_01_Cue'

	Begin Object class=GGGrapplingHook name=GrapplingHook
	End Object
	mGrapplingHook=GrapplingHook
}
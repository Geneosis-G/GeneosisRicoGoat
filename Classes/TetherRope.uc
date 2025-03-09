class TetherRope extends GGTether;

var HookRope mRope;

var vector mTetherLocation;
var vector mTetherPointLocation;

var float mTetherLength;
var float mMaxTetherLength;

var bool mTetherComplete;

function PrepareGoatMutator( GGGoat goat )
{
	local GGGameInfo gameInfo;

	super.PrepareGoatMutator(goat);

	gameInfo = GGGameInfo( class'WorldInfo'.static.GetWorldInfo().Game );
	mTetherMutator = RicoGoatHookComponent( gameInfo.FindMutatorComponent( class'RicoGoatHookComponent', mGoat.mCachedSlotNr ) );
}

function ETetherStatus TetherToActor( Actor actorToTetherTo, GGGoat goat, vector tetherLocation )
{
	local ETetherStatus res;
	local ParticleSystemComponent psc;

	res = super.TetherToActor(actorToTetherTo, goat, tetherLocation);
	if(res == THRS_FIRST_SUCCESS)
	{
		mTetherLocation = tetherLocation;
		if(mTetherPoint != none)
		{
			foreach mTetherPoint.AllOwnedComponents(class'ParticleSystemComponent', psc)
			{
				psc.DeactivateSystem();
				psc.KillParticlesForced();
				mTetherPoint.DetachComponent(psc);
			}
		}
	}

	return res;
}

function TetherCompleted( vector tetherLocation )
{
	mTetherPointLocation = tetherLocation;

	mTetherComplete = true;
	// Compute values needed for the following functions
	SetTetherLength(GetDistanceBetweenTetheredActors());

	//WorldInfo.Game.Broadcast(self, "=============================");
	//WorldInfo.Game.Broadcast(self, "mActorBasedOn=" $ mActorBasedOn);
	//WorldInfo.Game.Broadcast(self, "mInterpActorAttachComponent=" $ mInterpActorAttachComponent);
	//WorldInfo.Game.Broadcast(self, "mBoneAttachedTo=" $ mBoneAttachedTo);
	//WorldInfo.Game.Broadcast(self, "mTetherLocation=" $ mTetherLocation);
	//WorldInfo.Game.Broadcast(self, "mInterpActorAttachComponent.GetPosition()=" $ mInterpActorAttachComponent.GetPosition());
	//WorldInfo.Game.Broadcast(self, "GetMainComponent=" $ GetMainComponent(mActorBasedOn, mInterpActorAttachComponent));
	//WorldInfo.Game.Broadcast(self, "location1=" $ GetBestLocation(GetMainComponent(mActorBasedOn, mInterpActorAttachComponent), mBoneAttachedTo, mTetherLocation));
	//WorldInfo.Game.Broadcast(self, "mTetherPoint.mActorBasedOn=" $ mTetherPoint.mActorBasedOn);
	//WorldInfo.Game.Broadcast(self, "mTetherPoint.mInterpActorAttachComponent=" $ mTetherPoint.mInterpActorAttachComponent);
	//WorldInfo.Game.Broadcast(self, "mTetherPoint.mBoneAttachedTo=" $ mTetherPoint.mBoneAttachedTo);
	//WorldInfo.Game.Broadcast(self, "mTetherPointLocation=" $ mTetherPointLocation);
	//WorldInfo.Game.Broadcast(self, "mTetherPoint.mInterpActorAttachComponent.GetPosition()=" $ mTetherPoint.mInterpActorAttachComponent.GetPosition());
	//WorldInfo.Game.Broadcast(self, "GetMainComponent=" $ GetMainComponent(mTetherPoint.mActorBasedOn, mTetherPoint.mInterpActorAttachComponent));
	//WorldInfo.Game.Broadcast(self, "location2=" $ GetBestLocation(GetMainComponent(mTetherPoint.mActorBasedOn, mTetherPoint.mInterpActorAttachComponent), mTetherPoint.mBoneAttachedTo, mTetherPointLocation));
	//WorldInfo.Game.Broadcast(self, "TetherCompleted(" $ (mTetherLength * 1.5f) $ ")");

	//WorldInfo.Game.Broadcast(self, "TetherCompleted(" $ mActorBasedOn $ "," $ mTetherPoint.mActorBasedOn $ "," $ mTetherLocation $ "," $ mTetherPointLocation $ "," $ mBoneAttachedTo $ "," $ mTetherPoint.mBoneAttachedTo $ ")");
	//WorldInfo.Game.Broadcast(self, "static?(" $ mActorBasedOn.bStatic $ "," $ mTetherPoint.mActorBasedOn.bStatic $ ")");
	//WorldInfo.Game.Broadcast(self, "worldGeo?(" $ mActorBasedOn.bWorldGeometry $ "," $ mTetherPoint.mActorBasedOn.bWorldGeometry $ ")");

	// We can now move on to creating the constraint that will hold the two actors together
	CreateTetherConstraint();

	// Create the rope
	InitBeamParticle();

	// We set stuff attached to vehicles mass to zero to make them follow better
	SetZeroMassToAnythingNotAVehicle();

	// Inform mutator component that we are attached
	if(RicoGoatHookComponent(mTetherMutator) != none)
		RicoGoatHookComponent(mTetherMutator).OnTetherAttached(self);
}

function DestroyTetherRope(bool breakSound = true)
{
	SetRBBodyInstanceMassToNormal( mTetherPoint.mActorBasedOn );

	if(breakSound)
		PlaySound( mTetherBreakSound );

	Destroy();
}

event Destroyed()
{
	local array< GGTether > tethers;
	local GGNpc npc;

	if(mRope != none)
	{
		mRope.ShutDown();
		mRope.Destroy();
		mRope = none;
	}

	if(RicoGoatHookComponent(mTetherMutator) != none)
		RicoGoatHookComponent(mTetherMutator).OnTetherDestroyed(self);

	//if removing last tether, enable stand up on NPC
	npc = GGNpc(mActorBasedOn);
	if(npc != none)
	{
		tethers = GetTethersAttachedToActor(mActorBasedOn);
		if(tethers.Length == 0 || (tethers.Length == 1 && tethers.Find(self) != INDEX_NONE))
			npc.EnableStandUp( class'GGNpc'.const.SOURCE_TETHER );
	}
	npc = GGNpc(mTetherPoint.mActorBasedOn);
	if(npc != none)
	{
		tethers = GetTethersAttachedToActor(mTetherPoint.mActorBasedOn);
		if(tethers.Length == 0 || (tethers.Length == 1 && tethers.Find(self) != INDEX_NONE))
			npc.EnableStandUp( class'GGNpc'.const.SOURCE_TETHER );
	}

	super.Destroyed();
}

/** This is what actually holds the two tethered objects together, with some leniency */
function CreateTetherConstraint()
{
	local primitivecomponent prim1, prim2;

	mDistanceJointSetup.LinearYSetup.LimitSize = mTetherLength;
	mDistanceJointSetup.LinearZSetup.LimitSize = mTetherLength;
	mDistanceJointSetup.LinearXSetup.LimitSize = mTetherLength;

	prim1=GetMainComponent(mActorBasedOn, mInterpActorAttachComponent);
	prim2=GetMainComponent(mTetherPoint.mActorBasedOn, mTetherPoint.mInterpActorAttachComponent);

	mDistanceJointInstance.InitConstraint( prim1, prim2, mDistanceJointSetup, 0.f, self, none, false);
}

function InitBeamParticle()
{
	// No beam, but a rope
	mRope = mGoat.Spawn(class'HookRope', mGoat,, mGoat.Location,,, true);
	mRope.AttachRope(GetMainComponent(mActorBasedOn, mInterpActorAttachComponent), GetMainComponent(mTetherPoint.mActorBasedOn, mTetherPoint.mInterpActorAttachComponent), mTetherLocation, mTetherPointLocation, mBoneAttachedTo, mTetherPoint.mBoneAttachedTo);
}

function UpdateTetherBeamParticle()
{
	// if tether fully attached
	if(mTetherComplete)
	{
		// Make sure rope did not dissapear
		if(mRope == none || mRope.bPendingDelete)
			InitBeamParticle();
	}
}

function PlayTetherSoundLoop();

function CheckIfTetherShouldDestroy()
{
	// if tether fully attached
	if(mTetherComplete)
	{
		// Destroy tether if extended too much
		if(GetDistanceBetweenTetheredActors() > mTetherLength * 1.5f)
		{
			//WorldInfo.Game.Broadcast(self, "#################################");
			//WorldInfo.Game.Broadcast(self, "mActorBasedOn=" $ mActorBasedOn);
			//WorldInfo.Game.Broadcast(self, "mInterpActorAttachComponent=" $ mInterpActorAttachComponent);
			//WorldInfo.Game.Broadcast(self, "mBoneAttachedTo=" $ mBoneAttachedTo);
			//WorldInfo.Game.Broadcast(self, "mTetherLocation=" $ mTetherLocation);
			//WorldInfo.Game.Broadcast(self, "mInterpActorAttachComponent.GetPosition()=" $ mInterpActorAttachComponent.GetPosition());
			//WorldInfo.Game.Broadcast(self, "GetMainComponent=" $ GetMainComponent(mActorBasedOn, mInterpActorAttachComponent));
			//WorldInfo.Game.Broadcast(self, "location1=" $ GetBestLocation(GetMainComponent(mActorBasedOn, mInterpActorAttachComponent), mBoneAttachedTo, mTetherLocation));
			//WorldInfo.Game.Broadcast(self, "mTetherPoint.mActorBasedOn=" $ mTetherPoint.mActorBasedOn);
			//WorldInfo.Game.Broadcast(self, "mTetherPoint.mInterpActorAttachComponent=" $ mTetherPoint.mInterpActorAttachComponent);
			//WorldInfo.Game.Broadcast(self, "mTetherPoint.mBoneAttachedTo=" $ mTetherPoint.mBoneAttachedTo);
			//WorldInfo.Game.Broadcast(self, "mTetherPointLocation=" $ mTetherPointLocation);
			//WorldInfo.Game.Broadcast(self, "mTetherPoint.mInterpActorAttachComponent.GetPosition()=" $ mTetherPoint.mInterpActorAttachComponent.GetPosition());
			//WorldInfo.Game.Broadcast(self, "GetMainComponent=" $ GetMainComponent(mTetherPoint.mActorBasedOn, mTetherPoint.mInterpActorAttachComponent));
			//WorldInfo.Game.Broadcast(self, "location2=" $ GetBestLocation(GetMainComponent(mTetherPoint.mActorBasedOn, mTetherPoint.mInterpActorAttachComponent), mTetherPoint.mBoneAttachedTo, mTetherPointLocation));
			//WorldInfo.Game.Broadcast(self, "DestroyTetherRope(" $ GetDistanceBetweenTetheredActors() $ ">" $ (mTetherLength * 1.5f) $ ")");
			DestroyTetherRope();
			return;
		}
	}

	super.CheckIfTetherShouldDestroy();
}

function PrimitiveComponent GetMainComponent(Actor act, PrimitiveComponent primitive)
{
	if(interpactor( act ) != none || act.bStatic)
	{
		return primitive;
	}

	return act.CollisionComponent;
}

function vector GetBestLocation(PrimitiveComponent comp, name bone, vector targetLoc)
{
	local SkeletalMeshComponent skelMesh;
	local vector bestLoc;

	skelMesh = SkeletalMeshComponent( comp );
	// Find position to attach to on first component
	if(skelMesh != none)
	{
		if(skelMesh.GetSocketByName(bone) != none)
		{
			skelMesh.GetSocketWorldLocationAndRotation(bone, bestLoc);
		}
		if(bestLoc == vect(0, 0, 0))
		{
			bestLoc = skelMesh.GetBoneLocation(bone);
		}
	}
	if(bestLoc == vect(0, 0, 0))
	{
		bestLoc = comp.GetPosition();
	}
	if(bestLoc == vect(0, 0, 0))
	{
		bestLoc = targetLoc;
	}

	return bestLoc;
}

function float GetDistanceBetweenTetheredActors()
{
	local vector location1, location2;

	location1 = GetBestLocation(GetMainComponent(mActorBasedOn, mInterpActorAttachComponent), mBoneAttachedTo, mTetherLocation);
	location2 = GetBestLocation(GetMainComponent(mTetherPoint.mActorBasedOn, mTetherPoint.mInterpActorAttachComponent), mTetherPoint.mBoneAttachedTo, mTetherPointLocation);

	return VSize(location1 - location2);
}

function SetTetherLength(float newLength)
{
	mTetherLength = newLength;
	if(mTetherLength < 1.f)
		mTetherLength = 1.f;
	if(mTetherLength > mMaxTetherLength)
		mTetherLength = mMaxTetherLength;
}

DefaultProperties
{
	mMaxTetherLength = 10000.f

	mTetherLoopSound = none
	mTetherBreakSound = SoundCue'Zombie_Sounds.Waterland.Whiplash_Lever_Down_Cue'

	Components.Remove(ParticleSystemComponent0)
	mTetherBeamComponent=none
	Components.Remove(ParticleSystemComponent1)
}
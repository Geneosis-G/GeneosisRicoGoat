class HookRope extends DynamicSMActor;

var PrimitiveComponent mComp1;
var PrimitiveComponent mComp2;

var name mBone1;
var name mBone2;

var vector mLocation1;
var vector mLocation2;

var bool mIsAttached;
var float mDefaultLength;
var float mRopeScaleFactor;

event PostBeginPlay()
{
	local float r;

	Super.PostBeginPlay();

	SetRotation(rot(0, 0, 0));
	GetBoundingCylinder(r, mDefaultLength);
}

/**
 * Connects two primitive components with the rope, this won't work very well if distance between location1 and location2 is too long
 *
 * @param comp1 - first primitive component
 * @param comp2 - second primitive component
 * @param offset - offset in comp1 space to where to attach the rope to comp1
 * @param bone1 -
 * @param bone2 -
 */
function AttachRope(PrimitiveComponent comp1, PrimitiveComponent comp2, vector location1, vector location2, optional name bone1 = '', optional name bone2 = '')
{
	mComp1 = comp1;
	mComp2 = comp2;
	mLocation1 = location1;
	mLocation2 = location2;
	mBone1 = bone1;
	mBone2 = bone2;

	//WorldInfo.Game.Broadcast(self, "AttachRope(" $ mComp1 $ "," $ mComp2 $ "," $ mLocation1 $ "," $ mLocation2 $ "," $ mBone1 $ "," $ mBone2 $ ")");

	mIsAttached = true;
}

function DetachRope()
{
	mIsAttached = false;
}

event Tick(float deltaTime)
{
	super.Tick(DeltaTime);

	UpdateRopeLocation();
}

function UpdateRopeLocation()
{
	local SkeletalMeshComponent skelMesh1, skelMesh2;
	local vector location1, location2, betweenLocations;
	local float scaleFactor;

	if(!mIsAttached)
		return;

	skelMesh1 = SkeletalMeshComponent( mComp1 );
	skelMesh2 = SkeletalMeshComponent( mComp2 );
	// Find position to attach to on first component
	if(skelMesh1 != none)
	{
		if(skelMesh1.GetSocketByName(mBone1) != none)
		{
			skelMesh1.GetSocketWorldLocationAndRotation(mBone1, location1);
		}
		if(location1 == vect(0, 0, 0))
		{
			location1 = skelMesh1.GetBoneLocation(mBone1);
		}
	}
	if(location1 == vect(0, 0, 0))
	{
		location1 = mComp1.GetPosition();
	}
	if(location1 == vect(0, 0, 0) || mComp1.Owner.bStatic)
	{
		location1 = mLocation1;
	}
	// Find position to attach to on second component
	if(skelMesh2 != none)
	{
		if(skelMesh2.GetSocketByName(mBone2) != none)
		{
			skelMesh2.GetSocketWorldLocationAndRotation(mBone2, location2);
		}
		if(location2 == vect(0, 0, 0))
		{
			location2 = skelMesh2.GetBoneLocation(mBone2);
		}
	}
	if(location2 == vect(0, 0, 0))
	{
		location2 = mComp2.GetPosition();
	}
	if(location2 == vect(0, 0, 0) || mComp2.Owner.bStatic)
	{
		location2 = mLocation2;
	}
	// Convert lenght into rope scale
	betweenLocations = location2 - location1;
	scaleFactor = mRopeScaleFactor * VSize(betweenLocations) / mDefaultLength;
	StaticMeshComponent.SetScale3D(vect(1.f, 1.f, 0.f) + (vect(0.f, 0.f, 1.f) * scaleFactor));
	// Place rope between locations
	SetLocation(location2);
	SetRotation(rotator(normal(betweenLocations)) + rot(16384, 0, 0));
	//WorldInfo.Game.Broadcast(self, "================");
	//WorldInfo.Game.Broadcast(self, "location1=" $ location1);
	//WorldInfo.Game.Broadcast(self, "location2=" $ location2);
	//WorldInfo.Game.Broadcast(self, "ropeLocation=" $ ropeLocation);
	//WorldInfo.Game.Broadcast(self, "VSize(betweenLocations)=" $ VSize(betweenLocations));
	//WorldInfo.Game.Broadcast(self, "mDefaultLength=" $ mDefaultLength);
	//WorldInfo.Game.Broadcast(self, "scaleFactor=" $ scaleFactor);
}

DefaultProperties
{
	mRopeScaleFactor = 0.5f;

	Begin Object name=StaticMeshComponent0
		StaticMesh=StaticMesh'Space_ObstacleCourse.Meshes.Rope'
		Scale3D=(X=1.f,Y=1.f,Z=1.f)
	End Object

	bNoDelete=false
	bStatic=false
}
class RicoGoat extends GGMutator;

var class< GGMutatorComponent > mMutatorComponentClass2;
var array< RicoGoatComponent > mComponents;

function ModifyPlayer(Pawn Other)
{
	local GGGoat goat;
	local GGMutatorComponent mutComp;
	local RicoGoatComponent ricoComp;
	local RicoGoatHookComponent ricoComp2;

	goat = GGGoat( other );
	if( goat != none )
	{
		if( IsValidForPlayer( goat ) && mMutatorComponentClass2 != none )
		{
			mutComp = new default.mMutatorComponentClass2;
			mutComp.AttachToPlayer( goat, self );
			ricoComp2 = RicoGoatHookComponent(mutComp);
		}
	}

	super.ModifyPlayer( other );

	if( goat != none )
	{
		ricoComp=RicoGoatComponent(GGGameInfo( class'WorldInfo'.static.GetWorldInfo().Game ).FindMutatorComponent(class'RicoGoatComponent', goat.mCachedSlotNr));
		if(ricoComp != none && mComponents.Find(ricoComp) == INDEX_NONE)
		{
			mComponents.AddItem(ricoComp);
		}
		//Link components
		ricoComp.mOtherComp = ricoComp2;
		ricoComp2.mOtherComp = ricoComp;
		//WorldInfo.Game.Broadcast(self, "ricoComp=" $ ricoComp);
		//WorldInfo.Game.Broadcast(self, "ricoComp2=" $ ricoComp2);
		//WorldInfo.Game.Broadcast(self, "ricoComp.mOtherComp=" $ ricoComp.mOtherComp);
		//WorldInfo.Game.Broadcast(self, "ricoComp2.mOtherComp=" $ ricoComp2.mOtherComp);
	}
}

function OnPlayerRespawn( PlayerController respawnController, bool died )
{
	local GGGoat goat;
	local RicoGoatComponent ricoComp;
	local RicoGoatHookComponent ricoComp2;

	goat = GGGoat( respawnController.Pawn );

	if(goat != none)
	{
		ricoComp=RicoGoatComponent(GGGameInfo( class'WorldInfo'.static.GetWorldInfo().Game ).FindMutatorComponent(class'RicoGoatComponent', goat.mCachedSlotNr));
		ricoComp2=RicoGoatHookComponent(GGGameInfo( class'WorldInfo'.static.GetWorldInfo().Game ).FindMutatorComponent(class'RicoGoatHookComponent', goat.mCachedSlotNr));
		//Link components
		ricoComp.mOtherComp = ricoComp2;
		ricoComp2.mOtherComp = ricoComp;
		//Add component to list if needed
		if(ricoComp != none && mComponents.Find(ricoComp) == INDEX_NONE)
		{
			mComponents.AddItem(ricoComp);
		}
	}

	super.OnPlayerRespawn(respawnController, died);
}

simulated event Tick( float delta )
{
	local int i;

	for( i = 0; i < mComponents.Length; i++ )
	{
		mComponents[ i ].Tick( delta );
	}
	super.Tick( delta );
}

DefaultProperties
{
	mMutatorComponentClass=class'RicoGoatComponent'
	mMutatorComponentClass2=class'RicoGoatHookComponent'
}
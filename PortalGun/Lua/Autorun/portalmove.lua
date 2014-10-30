
if( SERVER ) then
    AddCSLuaFile( "portalmove.lua" );
end

if( CLIENT ) then
       
	/*------------------------------------
			CreateMove()
	------------------------------------*/
	local function CreateMove( cmd )
   
		local pl = LocalPlayer();
		if( IsValid( pl ) ) then
   
			if( pl.InPortal and pl.InPortal:IsValid() and pl:GetMoveType() == MOVETYPE_NOCLIP) then
				
				local right = 0;
				local forward = 0;
				local maxspeed = pl:GetMaxSpeed();
				if pl:Crouching() then
					maxspeed = pl:GetCrouchedWalkSpeed()
				end
			   
				// forward/back
				if( cmd:KeyDown( IN_FORWARD ) ) then
					forward = forward + maxspeed;
				end
				if( cmd:KeyDown( IN_BACK ) ) then
					forward = forward - maxspeed;
				end
			   
				// left/right
				if( cmd:KeyDown( IN_MOVERIGHT ) ) then
					right = right + maxspeed;
				end
				if( cmd:KeyDown( IN_MOVELEFT ) ) then
					right = right - maxspeed;
				end
				
				cmd:SetForwardMove( forward );
				cmd:SetSideMove( right );
			end
	   
		end
   
	end
	hook.Add( "CreateMove", "Noclip.CreateMove", CreateMove );

end

function SubAxis( v, x )
    return v - ( v:Dot( x ) * x )
end

function ipMove( ply, mv )
		local portal = ply.InPortal
        if IsValid( portal ) and ply:GetMoveType() == MOVETYPE_NOCLIP then
                -- if ply:GetMoveType() != MOVETYPE_NOCLIP then
					-- return
                -- end
				//Glitchy fix.
				-- if portal:GetPos():Distance(ply:GetPos()) > 80 and portal:IsLinked() and portal:GetOther():GetPos():Distance(ply:GetPos()) > 80 then
					-- print("booting player.")
					-- ply.InPortal = nil
					-- ply:SetMoveType(MOVETYPE_WALK)
					-- ply:EmitSound("player/portal_exit".. portal.PortalType ..".wav",80,100 + (30 * (mv:GetVelocity():Length() - 100)/1000))
					-- return false
				-- end
				
                local deltaTime = FrameTime()
				
                local noclipSpeed = 1.75
                local noclipAccelerate = 5
               
                local pos = mv:GetOrigin()
                local pOrg = portal:GetPos()
				if portal:OnFloor() then
					pOrg = pOrg - Vector(0,0,20)
				end
                local pAng = portal:GetAngles()
				
				// calculate acceleration for this frame.
                local ang = mv:GetMoveAngles()
                local acceleration = ( ang:Forward() * mv:GetForwardSpeed() ) + ( ang:Right() * mv:GetSideSpeed() ) 
				acceleration.z = 0
				
                // clamp to our max speed, and take into account noclip speed
                local accelSpeed = math.min( acceleration:Length(), ply:GetMaxSpeed() );
                local accelDir = acceleration:GetNormal()
                acceleration = accelDir * accelSpeed * noclipSpeed
				
				//Gonna calculate these at some point.
				-- local plyHeight = 72 --Player height
				-- local bot, top = pOrg - pAng:Up()*55, pOrg + pAng:Up()*55 --bottom and top points of the portal
				-- local portHeight = math.abs(top.z-bot.z) --isometric portal height
				-- local gap = math.abs(portHeight-plyHeight) --max height difference
				-- local minZ, maxZ = -(portHeight/2), -(portHeight/2) + gap
				-- print(portHeight)
				-- print(minZ,maxZ)
				
				local gravity = Vector(0,0,0)
				local g = GetConVarNumber("sv_gravity")
				if portal:IsHorizontal() then
					if pos.z > pOrg.z-54 then
						gravity.z = -g
					end
				else
					gravity.z = -g
				end
               
                // calculate final velocity with friction
                local getvel = mv:GetVelocity()
                local newVelocity = getvel + acceleration * deltaTime * noclipAccelerate;
				newVelocity = newVelocity + (gravity * deltaTime)
				newVelocity.z = math.max(newVelocity.z, -3000) --Clamp that fall speed. 
				newVelocity.z = newVelocity.z * .9999 --Correct incrementing zvelocity
                newVelocity.x = newVelocity.x * ( 0.98 - deltaTime * 5 )
                newVelocity.y = newVelocity.y * ( 0.98 - deltaTime * 5 )
				
				local frontDist
				if portal:IsHorizontal() then --Fix diagonal portal with OBB detection.
					local OBBPos = util.ClosestPointInOBB(pOrg,ply:OBBMins(),ply:OBBMaxs(),ply:GetPos(),false)
					frontDist = OBBPos:PlaneDistance(pOrg,pAng:Forward())
				else
					frontDist = math.min(pos:PlaneDistance(pOrg,pAng:Forward()), ply:GetHeadPos():PlaneDistance(pOrg,pAng:Forward()))
				end
				
				local localOrigin = portal:WorldToLocal( pos + newVelocity * deltaTime ) --Apply movement, localize before clamping.
				
				local minY,maxY,minZ,maxZ
				if portal:IsHorizontal() then
					minY = -20
					maxY = 20
					minZ = -55
					maxZ = -14
				else
					minY = -20
					maxY = 20
					minZ = -44
					maxZ = 44
				end
				
				-- print(frontDist)
				
				if frontDist < 25.29 then
					localOrigin.z = math.Clamp(localOrigin.z,minZ,maxZ)
					localOrigin.y = math.Clamp(localOrigin.y,minY,maxY)
				elseif frontDist < 16 then
					localOrigin.y = math.Clamp(localOrigin.y,minY,maxY)
				else
					ply.InPortal = nil
					ply:SetMoveType(MOVETYPE_WALK)
					-- ply:EmitSound("player/portal_exit".. portal.PortalType ..".wav",80,100 + (30 * (newVelocity:Length() - 100)/1000))
				end
				
				local newOrigin = portal:LocalToWorld(localOrigin)

                // set velocity
                mv:SetVelocity( newVelocity )
               
			   //Move the player
                mv:SetOrigin( newOrigin )
               
                return true;
        end
end
hook.Add("Move","hpdMoveHook",ipMove)

local vec = FindMetaTable("Vector")
function vec:PlaneDistance(plane,normal)
	return normal:Dot(self-plane)
end

timer.Simple(.1, function()
	if GAMEMODE then
		function GAMEMODE:HandlePlayerNoClipping(ply,vel)--, "Portal: Pretend To Walk", function(ply,vel)
			-- print("Changed anim")
			if IsValid( ply.InPortal ) then
				ply:SetAnimation(PLAYER_WALK)
			end
			return false
		end --)
	elseif GM then
		function GM:HandlePlayerNoClipping(ply,vel)--, "Portal: Pretend To Walk", function(ply,vel)
			-- print("Changed anim")
			if IsValid( ply.InPortal ) then
				ply:SetAnimation(PLAYER_WALK)
			end
			return false
		end --)
	else
		MsgN("Portal Gun: Couldn't change noclip animations.")
	end
end)

function math.YawBetweenPoints(a,b)
	local xDiff = a.x - b.x; 
	local yDiff = a.y - b.y; 
	return math.atan2(yDiff, xDiff) * (180 / math.pi) 
end

// Returns the distance between a point and an OBB, defined by mins and maxs.
// If a center is given, it will return a distance within the OBB if the point is within the OBB.
//	Works in 2 dimensions. Ignores Z of target and center.
// Also only works with player OBB's so far. Derp.
function util.ClosestPointInOBB(point,mins,maxs,center,Debug)
	-- local yaw = ply:GetRight():Angle().y+90
	local Debug = Debug or false
	local yaw = math.rad(math.YawBetweenPoints(point,center))
	local radius
	local abs_cos_angle= math.abs(math.cos(yaw));
	local abs_sin_angle= math.abs(math.sin(yaw));
	if (16*abs_sin_angle <= 16*abs_cos_angle) then
		radius= 16/abs_cos_angle;
	else
		radius= 16/abs_sin_angle;
	end
	
	radius = math.min(radius,math.Distance(center.x,center.y,point.x,point.y))
	local x,y = math.cos(yaw)*radius, math.sin(yaw)*radius
	
	if Debug then
		if not CLIENT then
			umsg.Start("drawOBB")
				umsg.Vector(point)
				umsg.Vector(mins)
				umsg.Vector(maxs)
				umsg.Vector(center)
			umsg.End()
		else
			debugoverlay.Box(center,mins,maxs,FrameTime()+.01,Color(200,30,30,0))
			debugoverlay.Line(center+Vector(0,0,0),center+Vector(x,y,0),FrameTime()+.01,Color(200,30,30,255))
			debugoverlay.Cross(center+Vector(x,y,0),2,1,Color(300,200,30,255))
			debugoverlay.Cross(point,5,1,Color(30,200,30,255))
		end
	end
	
	
	return Vector(x,y,0) + center
	
end

if CLIENT then
	usermessage.Hook("drawOBB", function(umsg)
		local point, mins, maxs, center = umsg:ReadVector(),umsg:ReadVector(),umsg:ReadVector(),umsg:ReadVector()
		util.ClosestPointInOBB(point,mins,maxs,center,true)
	end)
end

-- hook.Add("Think", "OBBTest", function(ply)
	-- for k,ply in pairs(player.GetAll())do
		-- if CLIENT then
			-- util.ClosestPointInOBB(Vector(0,0,0),ply:OBBMins(),ply:OBBMaxs(),ply:GetPos(),true)
		-- end
	-- end
-- end)


local CanMoveThrough = {
	CONTENTS_EMPTY,
	CONTENTS_DEBRIS,
	CONTENTS_WATER
}

--everytick:
local function CollisionBoxOutsideMap( ent, minBound, maxBound )
	local pPos = ent:LocalToWorld(ent:OBBCenter())
	if not util.IsInWorld( Vector( pPos.x+minBound.x, pPos.y+minBound.y, pPos.z+minBound.z ) ) then
		
		return true 
	end
	if not util.IsInWorld( Vector( pPos.x-minBound.x, pPos.y+minBound.y, pPos.z+minBound.z ) ) then
		return true 
	end
	if not util.IsInWorld( Vector( pPos.x-minBound.x, pPos.y-minBound.y, pPos.z+minBound.z ) ) then
		return true 
	end
	if not util.IsInWorld( Vector( pPos.x+minBound.x, pPos.y-minBound.y, pPos.z+minBound.z ) ) then
		return true 
	end
	
	if not util.IsInWorld( Vector( pPos.x+maxBound.x, pPos.y+maxBound.y, pPos.z+maxBound.z ) ) then
		return true 
	end
	if not util.IsInWorld( Vector( pPos.x-maxBound.x, pPos.y+maxBound.y, pPos.z+maxBound.z ) ) then
		return true 
	end
	if not util.IsInWorld( Vector( pPos.x-maxBound.x, pPos.y-maxBound.y, pPos.z+maxBound.z ) ) then
		return true 
	end
	if not util.IsInWorld( Vector( pPos.x+maxBound.x, pPos.y-maxBound.y, pPos.z+maxBound.z ) ) then
		return true 
	end
	
	for i=0.2, 0.8, 0.2 do
		if not util.IsInWorld( Vector( pPos.x, pPos.y, pPos.z+(maxBound.z+minBound.z)*i ) ) then
			return true 
		end
	end
	
	
	
	return false
end
local function CollisionBoxContainsProps( ent, minBound, maxBound )
	local pPos = ent:LocalToWorld(ent:OBBCenter())
	lowerBoxPos = Vector()
	lowerBoxPos:Set(pPos)
	lowerBoxPos:Add(minBound)
	upperBoxPos = Vector()
	upperBoxPos:Set(pPos)
	upperBoxPos:Add(maxBound)
	
	t = ents.FindInBox(lowerBoxPos, upperBoxPos)
	for key,value in pairs(t) do
		if value == ent then continue end
		if value:GetSolid() != SOLID_NONE then return true end
	end
	return false
end

function IsStuck(ply)
	local a,b = CollisionBoxOutsideMap(ply,ply:OBBMins(), ply:OBBMaxs()), CollisionBoxContainsProps(ply,ply:OBBMins(), ply:OBBMaxs())
	print( a, b)
	return a or b
end

class CBoatVibrationManager extends CObject {
    private var lastTilt, lastPitch, lastHeave : float;
    private var lastTiltDir, lastPitchDir, lastHeaveDir : float;
    private var vibeCooldown : float;
    private var hasTriggeredThisFlip : bool; // The Latch

    private var maxPitchSeen, minPitchSeen : float;
    private var messageTimer : float;

    public function ProcessBuoyancy(dt : float, lV : Vector, rV : Vector, fV : Vector, bV : Vector) {
        var curTilt, curPitch, curHeave : float;
        var dirTilt, dirPitch, dirHeave : float;
        var sTilt, sPitch, sHeave : float;
        var winnerStrength : float;
        var winnerType : int; 

        if (messageTimer > 0) messageTimer -= dt;

        curTilt  = lV.Z - rV.Z;
        curPitch = fV.Z - bV.Z;
        curHeave = (lV.Z + rV.Z + fV.Z + bV.Z) / 4.0;

        dirTilt  = GetSign(curTilt - lastTilt);
        dirPitch = GetSign(curPitch - lastPitch);
        dirHeave = GetSign(curHeave - lastHeave);

        // --- RESET THE LATCH ---
        // If the boat returns close to level, allow a new trigger for the next wave
        if (AbsF(curPitch) < 0.1) {
            hasTriggeredThisFlip = false;
        }

        sTilt = 0;
        if (dirTilt != lastTiltDir && lastTiltDir != 0) { sTilt = AbsF(curTilt) * 5.0; }

        sHeave = 0;
        if (dirHeave != lastHeaveDir && lastHeaveDir != 0) { sHeave = 0.5; }

        sPitch = 0;
        // --- TRIGGER WITH LATCH ---
        // 1. Must be a direction flip
        // 2. Must be outside the noise floor (0.2)
        // 3. Must NOT have fired already for this specific crest/trough
        if (dirPitch != lastPitchDir && lastPitchDir != 0) {
            if (AbsF(curPitch) > 0.2 && !hasTriggeredThisFlip) { 
                sPitch = AbsF(curPitch) * 5.0;
                hasTriggeredThisFlip = true; // Lock it!
            }
        }

        winnerStrength = 0;
        winnerType = 0;
        if (sPitch > winnerStrength) { 
            winnerStrength = sPitch; 
            winnerType = 2; 
        }

        if (winnerStrength > 0.01 && vibeCooldown <= 0) {
            winnerStrength = MaxF(winnerStrength, 0.4);

            if (messageTimer <= 0) {
                thePlayer.DisplayHudMessage("SINGLE VIBE: " + curPitch);
                messageTimer = 1.0; // Block HUD spam for 1 full second
            }

            if (winnerType == 2) {
                theGame.VibrateController(0.4, 0.1, 0.2);
            }
            
            vibeCooldown = 0.8; 
        }

        if (vibeCooldown > 0) vibeCooldown -= dt;
        UpdateState(lV, rV, fV, bV);
    }

    private function UpdateState(lV : Vector, rV : Vector, fV : Vector, bV : Vector) {
        var curT, curP, curH : float;
        curT = lV.Z - rV.Z;
        curP = fV.Z - bV.Z;
        curH = (lV.Z + rV.Z + fV.Z + bV.Z) / 4.0;

        if (AbsF(curT - lastTilt) > 0.0001) lastTiltDir = GetSign(curT - lastTilt);
        if (AbsF(curP - lastPitch) > 0.0001) lastPitchDir = GetSign(curP - lastPitch);
        if (AbsF(curH - lastHeave) > 0.0001) lastHeaveDir = GetSign(curH - lastHeave);

        lastTilt = curT; lastPitch = curP; lastHeave = curH;
    }

    private function GetSign(val : float) : float {
        if (val > 0.0001) return 1.0;
        if (val < -0.0001) return -1.0;
        return 0;
    }
}

@addField(CBoatComponent) 
public var boatVibeManager : CBoatVibrationManager;

// Create manager when player takes the helm
@wrapMethod(CBoatComponent) function OnMountStarted( entity : CEntity, vehicleSlot : EVehicleSlot ) {
    if (!boatVibeManager) {
        boatVibeManager = new CBoatVibrationManager in this;
    }
    return wrappedMethod(entity, vehicleSlot);
}

// Destroy manager when player lets go of the helm
@wrapMethod(CBoatComponent) function OnDismountFinished( entity : CEntity, vehicleSlot : EVehicleSlot  ) {
    if (boatVibeManager) {
        delete boatVibeManager;
        boatVibeManager = NULL;
    }
    return wrappedMethod(entity, vehicleSlot);
}

@wrapMethod(CBoatComponent) function OnTick(dt : float) {
    var retVal: bool;
    retVal = wrappedMethod(dt);

    if (boatVibeManager) {
        boatVibeManager.ProcessBuoyancy( dt, 
            GetBuoyancyPointStatus_Left(),
            GetBuoyancyPointStatus_Right(),
            GetBuoyancyPointStatus_Front(),
            GetBuoyancyPointStatus_Back()
        );
    }

    return retVal;
}

/* @wrapMethod(CBoatComponent) function SetRudderDir( rider : CActor, value : float ) {
    // Check for change
    if (steerSound && boatVibeManager) {
        boatVibeManager.TriggerRudder();
    }
    wrappedMethod(rider, value);
} */
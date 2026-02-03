class CBoatVibrationManager extends CObject {
    private var lastPitch : float;
    private var lastPitchDir : float;
    private var vibeCooldown : float;
    private var hasTriggeredThisFlip : bool; 
    private var messageTimer : float;

    public function ProcessBuoyancy(dt : float, lV : Vector, rV : Vector, fV : Vector, bV : Vector) {
        var curPitch : float;
        var dirPitch : float;
        var sPitch : float;
        var vibeDuration : float;
        var absPitch : float;

        if (messageTimer > 0) messageTimer -= dt;
        if (vibeCooldown > 0) vibeCooldown -= dt;

        curPitch = fV.Z - bV.Z;
        absPitch = AbsF(curPitch); // We use this for all checks
        dirPitch = GetSign(curPitch - lastPitch);

        // 1. Reset the Latch when the boat is relatively level
        if (absPitch < 0.1) {
            hasTriggeredThisFlip = false;
        }

        // 2. Trigger Logic
        sPitch = 0;
        if (dirPitch != lastPitchDir && lastPitchDir != 0) {
            // Check against the absolute pitch so -0.4 is treated like 0.4
            if (absPitch > 0.2 && !hasTriggeredThisFlip) { 
                sPitch = absPitch; 
                hasTriggeredThisFlip = true;
            }
        }

        // 3. Execution
        if (sPitch > 0 && vibeCooldown <= 0) {
            // Mapping 0.2 -> 0.5 pitch to 0.1 -> 0.4 duration
            vibeDuration = (sPitch - 0.2) + 0.1;
            vibeDuration = ClampF(vibeDuration, 0.1, 0.4);

            if (messageTimer <= 0) {
                thePlayer.DisplayHudMessage("WAVE THUMP: Str " + sPitch + " Dur " + vibeDuration);
                messageTimer = 1.0;
            }

            theGame.VibrateController(0.2, 0.05, vibeDuration);
            vibeCooldown = 0.6; // Slightly shorter cooldown to allow crest AND trough hits
        }

        UpdateState(curPitch, dirPitch);
    }

    private function UpdateState(curP : float, dirP : float) {
        lastPitch = curP;
        if (AbsF(curP - lastPitch) > 0.0001) {
            lastPitchDir = dirP;
        }
    }

    private function GetSign(val : float) : float {
        if (val > 0.0001) return 1.0;
        if (val < -0.0001) return -1.0;
        return 0;
    }

    private function ClampF(val : float, min : float, max : float) : float {
        if (val < min) return min;
        if (val > max) return max;
        return val;
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
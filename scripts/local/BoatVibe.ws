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

        if (messageTimer > 0) messageTimer -= dt;
        if (vibeCooldown > 0) vibeCooldown -= dt;

        // 1. Physics Capture (Pitch Only)
        curPitch = fV.Z - bV.Z;
        dirPitch = GetSign(curPitch - lastPitch);

        // 2. The Latch Reset
        // Allow a new trigger once the boat settles toward the center
        if (AbsF(curPitch) < 0.1) {
            hasTriggeredThisFlip = false;
        }

        // 3. The Trigger Logic
        sPitch = 0;
        if (dirPitch != lastPitchDir && lastPitchDir != 0) {
            // Noise floor 0.2, only fire once per wave crest/trough
            if (AbsF(curPitch) > 0.2 && !hasTriggeredThisFlip) { 
                sPitch = AbsF(curPitch); 
                hasTriggeredThisFlip = true;
            }
        }

        // 4. Execution
        if (sPitch > 0 && vibeCooldown <= 0) {
            // --- DYNAMIC DURATION CALCULATION ---
            // We map pitch (0.2 to 0.5) to duration (0.1 to 0.4)
            // A simple linear scale: (Pitch - 0.2) + 0.1
            vibeDuration = (sPitch - 0.2) + 0.1;
            vibeDuration = ClampF(vibeDuration, 0.1, 0.4);

            if (messageTimer <= 0) {
                thePlayer.DisplayHudMessage("WAVE THUMP: Str " + sPitch + " Dur " + vibeDuration);
                messageTimer = 1.0;
            }

            // Vibe Strength halved as requested (0.2 Large motor, 0.05 Small motor)
            theGame.VibrateController(0.2, 0.05, vibeDuration);
            
            vibeCooldown = 0.8; 
        }

        UpdateState(curPitch, dirPitch);
    }

    private function UpdateState(curP : float, dirP : float) {
        lastPitch = curP;
        // Direction is updated only if movement is significant to avoid jitter
        if (AbsF(curP - lastPitch) > 0.0001) {
            lastPitchDir = dirP;
        }
    }

    private function GetSign(val : float) : float {
        if (val > 0.0001) return 1.0;
        if (val < -0.0001) return -1.0;
        return 0;
    }

    // Helper to keep duration in bounds
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
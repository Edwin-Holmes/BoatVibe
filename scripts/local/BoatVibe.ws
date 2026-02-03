class CBoatVibrationManager extends CObject {
    private var lastPitch : float;
    private var lastPitchDir : float;
    private var vibeCooldown : float;
    private var hasTriggeredThisFlip : bool; 
    private var messageTimer : float;

    // Echo Variables
    private var echoTimer : float;
    private var echoDuration : float;

    public function ProcessBuoyancy(dt : float, lV : Vector, rV : Vector, fV : Vector, bV : Vector) {
        var curPitch, absPitch, diff, dirPitch : float;
        var vibeDuration : float;

        if (messageTimer > 0) messageTimer -= dt;
        if (vibeCooldown > 0) vibeCooldown -= dt;

        curPitch = fV.Z - bV.Z;
        absPitch = AbsF(curPitch);
        diff = curPitch - lastPitch;
        dirPitch = GetSign(diff);

        // 1. Reset Latch
        if (absPitch < 0.1) {
            hasTriggeredThisFlip = false;
        }

        // 2. Main Trigger Logic
        if (dirPitch != lastPitchDir && dirPitch != 0 && lastPitchDir != 0) {
            if (absPitch > 0.2 && !hasTriggeredThisFlip && vibeCooldown <= 0) {
                
                vibeDuration = (absPitch - 0.2) + 0.1;
                vibeDuration = ClampF(vibeDuration, 0.1, 0.4);

                // Execute Primary Vibe
                theGame.VibrateController(0.2, 0.05, vibeDuration);
                
                // 3. Queue the Echo if it was a big wave
                if (vibeDuration >= 0.25) {
                    // Start echo after: Primary Duration + 0.1s gap
                    echoTimer = vibeDuration + 0.1; 
                    echoDuration = vibeDuration * 2.0;
                }

                hasTriggeredThisFlip = true;
                vibeCooldown = 0.5; 

                if (messageTimer <= 0) {
                    thePlayer.DisplayHudMessage("THUMP! Dur: " + vibeDuration + (echoTimer > 0 ? " (Echo Queued)" : ""));
                    messageTimer = 0.5;
                }
            }
        }

        // 4. Handle Echo Queue
        if (echoTimer > 0) {
            echoTimer -= dt;
            if (echoTimer <= 0) {
                // Secondary echo vibe: subtle but long
                theGame.VibrateController(0.0, 0.02, echoDuration);
                if (messageTimer <= 0) {
                    thePlayer.DisplayHudMessage("...echo settlement...");
                }
            }
        }

        // 5. Update State
        if (AbsF(diff) > 0.0001) {
            lastPitchDir = dirPitch;
        }
        lastPitch = curPitch;
    }

    private function GetSign(val : float) : float {
        if (val > 0.001) return 1.0;
        if (val < -0.001) return -1.0;
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
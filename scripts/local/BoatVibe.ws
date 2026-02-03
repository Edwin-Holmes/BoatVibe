class CBoatVibrationManager extends CObject {
    private var lastPitch, lastTilt : float;
    private var lastPitchDir, lastTiltDir : float;
    private var vibeCooldown : float;
    private var hasTriggeredThisFlip : bool; 
    private var echoTimer : float;
    private var echoDuration : float;

    // The "Anti-Double-Thud" Timer
    private var pitchDominanceTimer : float;

    public function ProcessBuoyancy(dt : float, lV : Vector, rV : Vector, fV : Vector, bV : Vector) {
        var curPitch, absPitch, diffP, dirPitch : float;
        var curTilt, absTilt, diffT, dirTilt : float;
        var vibeDuration : float;

        if (vibeCooldown > 0) vibeCooldown -= dt;
        if (pitchDominanceTimer > 0) pitchDominanceTimer -= dt;

        // 1. Capture Physics
        curPitch = fV.Z - bV.Z;
        absPitch = AbsF(curPitch);
        diffP = curPitch - lastPitch;
        dirPitch = GetSign(diffP);

        curTilt = lV.Z - rV.Z;
        absTilt = AbsF(curTilt);
        diffT = curTilt - lastTilt;
        dirTilt = GetSign(diffT);

        // 2. Reset Latch
        if (absPitch < 0.1 && absTilt < 0.1) {
            hasTriggeredThisFlip = false;
        }

        // 3. PITCH TRIGGER (The Boss)
        if (dirPitch != lastPitchDir && dirPitch != 0 && lastPitchDir != 0) {
            if (absPitch > 0.2 && !hasTriggeredThisFlip && vibeCooldown <= 0) {
                
                vibeDuration = (absPitch - 0.2) + 0.1;
                vibeDuration = ClampF(vibeDuration, 0.1, 0.6);

                theGame.VibrateController(0.2, 0.0, vibeDuration);
                
                if (vibeDuration >= 0.25) {
                    echoTimer = vibeDuration + 1.0; 
                    echoDuration = vibeDuration * 0.75;
                }

                hasTriggeredThisFlip = true;
                vibeCooldown = 0.5; 
                
                // Block Roll for the next half second
                pitchDominanceTimer = 0.5; 
            }
        }

        // 4. ROLL TRIGGER (The Assistant)
        // Only fires if we aren't currently "Pitch Dominant"
        if (pitchDominanceTimer <= 0 && dirTilt != lastTiltDir && dirTilt != 0 && lastTiltDir != 0) {
            if (absTilt > 0.2 && !hasTriggeredThisFlip && vibeCooldown <= 0) {
                
                vibeDuration = (absTilt - 0.2) + 0.1;
                vibeDuration = ClampF(vibeDuration, 0.1, 0.6);

                theGame.VibrateController(0.2, 0.0, vibeDuration);
                
                hasTriggeredThisFlip = true;
                vibeCooldown = 0.5; 
            }
        }

        // 5. Handle Echo Queue
        if (echoTimer > 0) {
            echoTimer -= dt;
            if (echoTimer <= 0) {
                theGame.VibrateController(0.0, 0.02, echoDuration);
            }
        }

        // 6. Update States
        if (AbsF(diffP) > 0.0001) lastPitchDir = dirPitch;
        lastPitch = curPitch;

        if (AbsF(diffT) > 0.0001) lastTiltDir = dirTilt;
        lastTilt = curTilt;
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
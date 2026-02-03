class CBoatVibrationManager extends CObject {
    private var lastPitch, lastTilt : float;
    private var lastPitchDir, lastTiltDir : float;
    private var vibeCooldown : float;
    private var hasTriggeredPitchFlip : bool; 
    private var hasTriggeredRollFlip : bool; 
    private var echoTimer, echoDuration, pitchDominanceTimer : float;

    // Diagnostic Variables
    private var diagTimer : float;
    private var minTiltObserved, maxTiltObserved, maxDeltaObserved : float;

    public function ProcessBuoyancy(dt : float, lV : Vector, rV : Vector, fV : Vector, bV : Vector) {
        var curPitch, absPitch, diffP, dirPitch : float;
        var curTilt, absTilt, diffT, dirTilt : float;
        var vibeDuration : float;
        var triggeredPitchThisFrame : bool;

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

        // --- Diagnostic Tracking ---
        diagTimer += dt;
        if (curTilt < minTiltObserved) minTiltObserved = curTilt;
        if (curTilt > maxTiltObserved) maxTiltObserved = curTilt;
        if (AbsF(diffT) > maxDeltaObserved) maxDeltaObserved = AbsF(diffT);

        if (diagTimer >= 20.0) {
            thePlayer.DisplayHudMessage("ROLL LOG | Range: [" + minTiltObserved + " to " + maxTiltObserved + "] | Max Delta: " + maxDeltaObserved);
            diagTimer = 0; minTiltObserved = 0; maxTiltObserved = 0; maxDeltaObserved = 0;
        }

        // 2. Pitch Latch Reset (Keep this stable)
        if (absPitch < 0.1) hasTriggeredPitchFlip = false;

        // 3. PITCH TRIGGER (Priority)
        triggeredPitchThisFrame = false;
        if (dirPitch != lastPitchDir && dirPitch != 0 && lastPitchDir != 0) {
            if (absPitch > 0.2 && !hasTriggeredPitchFlip && vibeCooldown <= 0) {
                vibeDuration = ClampF((absPitch - 0.2) + 0.1, 0.1, 0.6);
                theGame.VibrateController(0.2, 0.0, vibeDuration);
                
                if (vibeDuration >= 0.25) {
                    echoTimer = vibeDuration + 1.0; 
                    echoDuration = vibeDuration * 0.75;
                }
                hasTriggeredPitchFlip = true;
                vibeCooldown = 0.4; 
                pitchDominanceTimer = 0.4; 
                triggeredPitchThisFrame = true;
            }
        }

        // 4. ROLL TRIGGER (Direction-Based Latch)
        if (!triggeredPitchThisFrame && pitchDominanceTimer <= 0) {
            // If direction changed, we reset the roll latch immediately
            if (dirTilt != lastTiltDir) {
                hasTriggeredRollFlip = false; 
            }

            if (dirTilt != 0 && lastTiltDir != 0) {
                // Using 0.05 threshold to catch those 0.4 peaks easily
                if (absTilt > 0.05 && !hasTriggeredRollFlip && vibeCooldown <= 0) {
                    
                    // Scale: 0.1 tilt -> 0.2 vibe duration. 0.4 tilt -> 0.5 vibe duration.
                    vibeDuration = (absTilt - 0.05) + 0.15; 
                    vibeDuration = ClampF(vibeDuration, 0.1, 0.6);
                    thePlayer.DisplayHudMessage("roll vibe");
                    theGame.VibrateController(0.2, 0.0, vibeDuration);
                    
                    hasTriggeredRollFlip = true; // Lock until next direction change
                    vibeCooldown = 0.25; // Snappy cooldown for rhythmic rocking
                }
            }
        }

        // 5. Echo & State Updates
        if (echoTimer > 0) {
            echoTimer -= dt;
            if (echoTimer <= 0) theGame.VibrateController(0.0, 0.02, echoDuration);
        }

        if (AbsF(diffP) > 0.0001) lastPitchDir = dirPitch;
        lastPitch = curPitch;
        
        if (AbsF(diffT) > 0.0001) lastTiltDir = dirTilt;
        lastTilt = curTilt;
    }

    private function GetSign(val : float) : float {
        // Tuned to your 0.005 - 0.01 delta data
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
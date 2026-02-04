class CBoatVibrationManager extends CObject {
    // State Tracking
    private var lastPitch, lastTilt : float;
    private var lastPitchDir, lastTiltDir : float;
    
    // Timers & Latches
    private var vibeCooldown : float;
    private var pitchDominanceTimer : float;
    private var hasTriggeredPitchFlip : bool; 
    private var hasTriggeredRollFlip : bool; 
    
    // Secondary Effects
    private var echoTimer : float;
    private var echoDuration : float;

    public function ProcessBuoyancy(dt : float, lV : Vector, rV : Vector, fV : Vector, bV : Vector) {
        var curPitch, absPitch, diffP, dirPitch : float;
        var curTilt, absTilt, diffT, dirTilt : float;
        var vibeDuration : float;
        var pitchJustTriggered : bool;

        // Update Timers
        if (vibeCooldown > 0) vibeCooldown -= dt;
        if (pitchDominanceTimer > 0) pitchDominanceTimer -= dt;
        if (echoTimer > 0) echoTimer -= dt;

        // 1. CAPTURE PHYSICS
        curPitch = fV.Z - bV.Z;
        absPitch = AbsF(curPitch);
        diffP = curPitch - lastPitch;
        dirPitch = GetSign(diffP);

        curTilt = lV.Z - rV.Z;
        absTilt = AbsF(curTilt);
        diffT = curTilt - lastTilt;
        dirTilt = GetSign(diffT);

        // 2. LATCH RESETS
        // Pitch resets when the boat levels out front-to-back
        if (absPitch < 0.1) {
            hasTriggeredPitchFlip = false;
        }

        // 3. PITCH TRIGGER (The Main Event)
        pitchJustTriggered = false;
        
        if (dirPitch != lastPitchDir && dirPitch != 0 && lastPitchDir != 0) {
            // Threshold lowered to 0.05 to catch subtle movements on flat water
            if (absPitch > 0.05 && !hasTriggeredPitchFlip && vibeCooldown <= 0) {
                
                vibeDuration = ClampF((absPitch - 0.05) + 0.1, 0.1, 0.6);
                theGame.VibrateController(0.2, 0.0, vibeDuration);
                
                // Set up the motor 'echo' for heavy hits
                if (vibeDuration >= 0.25) {
                    echoTimer = vibeDuration + 1.0; 
                    echoDuration = vibeDuration * 0.75;
                }

                hasTriggeredPitchFlip = true;
                vibeCooldown = 2.0; 
                pitchDominanceTimer = 4.0; 
                pitchJustTriggered = true;
            }
        }

        // 4. ROLL TRIGGER (The Apex Detail)
        // Only executes if Pitch hasn't fired recently
        if (!pitchJustTriggered && pitchDominanceTimer <= 0) {
            
            // RESET: Allow a new vibe if we start moving back INWARD (toward center)
            // Even if we don't hit 0, moving inward resets the "Apex" requirement.
            if ((curTilt > 0 && dirTilt < 0) || (curTilt < 0 && dirTilt > 0)) {
                hasTriggeredRollFlip = false;
            }

            // TRIGGER: Direction changed at the peak of a roll
            if (dirTilt != lastTiltDir && lastTiltDir != 0) {
                
                // Threshold lowered to 0.08 to catch smaller rolls
                if (absTilt > 0.08 && !hasTriggeredRollFlip && vibeCooldown <= 0) {
                    
                    vibeDuration = (absTilt - 0.08) + 0.1;
                    vibeDuration = ClampF(vibeDuration, 0.1, 0.4);

                    // Slightly softer intensity for Roll
                   theGame.VibrateControllerHard();
                   //theGame.VibrateController(0.15, 0.0, vibeDuration);
                    
                    hasTriggeredRollFlip = true; 
                    vibeCooldown = 2.0; 
                }
            }
        }

        // 5. HANDLE ECHO
        if (echoTimer <= 0 && echoDuration > 0) {
            theGame.VibrateController(0.0, 0.02, echoDuration);
            echoDuration = 0; // Reset after firing
        }

        // 6. UPDATE HISTORY
        if (AbsF(diffP) > 0.001) lastPitchDir = dirPitch;
        lastPitch = curPitch;
        
        if (AbsF(diffT) > 0.001) lastTiltDir = dirTilt;
        lastTilt = curTilt;
    }

    private function GetSign(val : float) : float {
        if (val > 0.0005) return 1.0;
        if (val < -0.0005) return -1.0;
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
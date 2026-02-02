class CBoatVibrationManager extends CObject {
    private var lastTilt, lastPitch, lastHeave : float;
    private var lastTiltDir, lastPitchDir, lastHeaveDir : float;
    
    // The "Padding" Timer
    private var vibeCooldown : float;

    public function ProcessBuoyancy(dt : float, lV : Vector, rV : Vector, fV : Vector, bV : Vector) {
        var currentTilt, currentPitch, currentHeave : float;
        var diffTilt, diffPitch, diffHeave : float;
        var curTiltDir, curPitchDir, curHeaveDir : float;
        
        // 1. Tick the cooldown
        if (vibeCooldown > 0) {
            vibeCooldown -= dt;
        }

        // 2. Physical States
        currentTilt  = lV.Z - rV.Z;
        currentPitch = fV.Z - bV.Z;
        currentHeave = (lV.Z + rV.Z + fV.Z + bV.Z) / 4.0;

        diffTilt  = currentTilt - lastTilt;
        diffPitch = currentPitch - lastPitch;
        diffHeave = currentHeave - lastHeave;

        curTiltDir  = GetSign(diffTilt);
        curPitchDir = GetSign(diffPitch);
        curHeaveDir = GetSign(diffHeave);

        // 3. APEX DETECTION (Only if cooldown is finished)
        if (vibeCooldown <= 0) {
            
            // --- HEAVE (Vertical Impact) ---
            if (curHeaveDir == 1.0 && lastHeaveDir == -1.0 && AbsF(diffHeave) > 0.002) {
                theGame.VibrateController(0.15, 0.0, 0.05); // Short sharp thump
                vibeCooldown = 0.3; // 0.3s of silence padding
            }
            // --- PITCH (Nose tilt) ---
            else if (curPitchDir != lastPitchDir && AbsF(currentPitch) > 0.15) {
                theGame.VibrateController(0.1, 0.0, 0.05);
                vibeCooldown = 0.25;
            }
            // --- ROLL (Side sway) ---
            else if (curTiltDir != lastTiltDir && AbsF(currentTilt) > 0.12) {
                theGame.VibrateController(0.0, 0.08, 0.05);
                vibeCooldown = 0.2;
            }
        }

        // 4. Update states
        lastTilt  = currentTilt;
        lastPitch = currentPitch;
        lastHeave = currentHeave;

        if (AbsF(diffTilt)  > 0.001) lastTiltDir  = curTiltDir;
        if (AbsF(diffPitch) > 0.001) lastPitchDir = curPitchDir;
        if (AbsF(diffHeave) > 0.001) lastHeaveDir = curHeaveDir;
    }

    private function GetSign(val : float) : float {
        if (val > 0) return 1.0;
        if (val < 0) return -1.0;
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

@wrapMethod(CBoatComponent) function SetRudderDir( rider : CActor, value : float ) {
    // Check for change
    if (steerSound && boatVibeManager) {
        boatVibeManager.TriggerRudder();
    }
    wrappedMethod(rider, value);
}
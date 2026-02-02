class CBoatVibrationManager extends CObject {
    // Current physical states
    private var lastTilt   : float; // Left/Right Roll
    private var lastPitch  : float; // Front/Back Pitch
    private var lastHeave  : float; // Vertical Altitude

    // Direction trackers (1.0 = increasing, -1.0 = decreasing)
    private var lastTiltDir  : float;
    private var lastPitchDir : float;
    private var lastHeaveDir : float;

    public function ProcessBuoyancy(dt : float, lV : Vector, rV : Vector, fV : Vector, bV : Vector) {
        var currentTilt, currentPitch, currentHeave : float;
        var diffTilt, diffPitch, diffHeave : float;
        var curTiltDir, curPitchDir, curHeaveDir : float;
        
        var rumbleL, rumbleH : float;
        var duration : float;

        // 1. Calculate current boat orientation from the buoyancy cross
        currentTilt  = lV.Z - rV.Z;                   // Positive = Leaning Right
        currentPitch = fV.Z - bV.Z;                   // Positive = Nose Up
        currentHeave = (lV.Z + rV.Z + fV.Z + bV.Z) / 4.0; // Average height

        // 2. Calculate deltas to find direction
        diffTilt  = currentTilt - lastTilt;
        diffPitch = currentPitch - lastPitch;
        diffHeave = currentHeave - lastHeave;

        curTiltDir  = GetSign(diffTilt);
        curPitchDir = GetSign(diffPitch);
        curHeaveDir = GetSign(diffHeave);

        // 3. APEX DETECTION LOGIC
        // We only trigger a vibe when the direction flips (Reached a peak or trough)

        // --- ROLL (Side to Side) ---
        // Uses HFM to simulate weight shift/tension
        if (curTiltDir != lastTiltDir && AbsF(currentTilt) > 0.08) {
            rumbleH = MinF(0.12, AbsF(currentTilt) * 0.2);
            theGame.VibrateController(0.0, rumbleH, 0.06);
        }

        // --- PITCH (Front to Back) ---
        // Uses LFM for the "thud" of the nose hitting or lifting
        if (curPitchDir != lastPitchDir && AbsF(currentPitch) > 0.1) {
            rumbleL = MinF(0.15, AbsF(currentPitch) * 0.3);
            theGame.VibrateController(rumbleL, 0.0, 0.08);
        }

        // --- HEAVE (Vertical Slam) ---
        // Specifically trigger when the boat stops falling and starts rising (Bottom of wave)
        if (curHeaveDir == 1.0 && lastHeaveDir == -1.0 && AbsF(diffHeave) > 0.002) {
            // A combined jolt for hitting the "floor" of the water
            theGame.VibrateController(0.12, 0.04, 0.1);
        }

        // 4. State Storage
        lastTilt  = currentTilt;
        lastPitch = currentPitch;
        lastHeave = currentHeave;

        // Only update direction if there was meaningful movement (filters micro-noise)
        if (AbsF(diffTilt)  > 0.0001) lastTiltDir  = curTiltDir;
        if (AbsF(diffPitch) > 0.0001) lastPitchDir = curPitchDir;
        if (AbsF(diffHeave) > 0.0001) lastHeaveDir = curHeaveDir;
    }

    public function TriggerRudder() {
        // Light mechanical click for steering
        theGame.VibrateController(0.0, 0.08, 0.04);
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
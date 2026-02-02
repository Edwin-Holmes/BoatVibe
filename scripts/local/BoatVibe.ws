class CBoatVibrationManager extends CObject {
    private var lastTilt, lastPitch, lastHeave : float;
    private var lastTiltDir, lastPitchDir, lastHeaveDir : float;
    private var vibeCooldown : float;

    public function ProcessBuoyancy(dt : float, lV : Vector, rV : Vector, fV : Vector, bV : Vector) {
        var curTilt, curPitch, curHeave : float;
        var dirTilt, dirPitch, dirHeave : float;
        var sTilt, sPitch, sHeave : float;

        // 1. Countdown Logic (The "Gap" controller)
        if (vibeCooldown > 0) {
            vibeCooldown -= dt;
            UpdateState(lV, rV, fV, bV);
            return; 
        }

        // 2. Get current values
        curTilt  = lV.Z - rV.Z;
        curPitch = fV.Z - bV.Z;
        curHeave = (lV.Z + rV.Z + fV.Z + bV.Z) / 4.0;

        // 3. Check for direction flips
        dirTilt  = GetSign(curTilt - lastTilt);
        dirPitch = GetSign(curPitch - lastPitch);
        dirHeave = GetSign(curHeave - lastHeave);

        // 4. Calculate Strength (Lowered thresholds significantly)
        // If direction flipped, we record the strength of the movement
        sTilt  = (dirTilt != lastTiltDir)  ? AbsF(curTilt)  : 0;
        sPitch = (dirPitch != lastPitchDir) ? AbsF(curPitch) : 0;
        sHeave = (dirHeave != lastHeaveDir) ? AbsF(curHeave - lastHeave) * 100.0 : 0; 

        // 5. Trigger Winner (Boosted intensities to 0.2 - 0.4 range)
        if (sHeave > 0.02) {
            theGame.VibrateController(0.4, 0.0, 0.08); // Heavy Drop
            vibeCooldown = 0.6; 
        } 
        else if (sPitch > 0.05) {
            theGame.VibrateController(0.25, 0.0, 0.06); // Nose Pitch
            vibeCooldown = 0.5;
        } 
        else if (sTilt > 0.05) {
            theGame.VibrateController(0.0, 0.2, 0.06); // Side Roll
            vibeCooldown = 0.4;
        }

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

/* @wrapMethod(CBoatComponent) function SetRudderDir( rider : CActor, value : float ) {
    // Check for change
    if (steerSound && boatVibeManager) {
        boatVibeManager.TriggerRudder();
    }
    wrappedMethod(rider, value);
} */
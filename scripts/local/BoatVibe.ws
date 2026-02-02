class CBoatVibrationManager extends CObject {
    private var lastTilt, lastPitch, lastHeave : float;
    private var lastTiltDir, lastPitchDir, lastHeaveDir : float;
    private var vibeCooldown : float;

    public function ProcessBuoyancy(dt : float, lV : Vector, rV : Vector, fV : Vector, bV : Vector) {
        var curTilt, curPitch, curHeave : float;
        var diffTilt, diffPitch, diffHeave : float;
        var dirTilt, dirPitch, dirHeave : float;
        
        // Strength variables
        var sTilt, sPitch, sHeave : float;

        if (vibeCooldown > 0) {
            vibeCooldown -= dt;
            // We still update 'last' values so the math stays current when we wake up
            UpdateState(lV, rV, fV, bV);
            return; 
        }

        // 1. Get current values
        curTilt  = lV.Z - rV.Z;
        curPitch = fV.Z - bV.Z;
        curHeave = (lV.Z + rV.Z + fV.Z + bV.Z) / 4.0;

        // 2. Calculate the "Magnitude" of the direction shift
        // We only care if the direction flipped AND how far we've moved
        dirTilt  = GetSign(curTilt - lastTilt);
        dirPitch = GetSign(curPitch - lastPitch);
        dirHeave = GetSign(curHeave - lastHeave);

        sTilt  = (dirTilt != lastTiltDir)  ? AbsF(curTilt)  : 0;
        sPitch = (dirPitch != lastPitchDir) ? AbsF(curPitch) : 0;
        sHeave = (dirHeave != lastHeaveDir) ? AbsF(curHeave - lastHeave) * 50.0 : 0; // Heave needs a boost to compete

        // 3. Find the Winner (The Dominant Vector)
        if (sHeave > sPitch && sHeave > sTilt && sHeave > 0.05) {
            // HEAVE WIN: A heavy vertical thump
            theGame.VibrateController(0.18, 0.0, 0.06);
            vibeCooldown = 0.5; // Big gap
        } 
        else if (sPitch > sTilt && sPitch > 0.18) {
            // PITCH WIN: The nose dipping/rising
            theGame.VibrateController(0.12, 0.0, 0.05);
            vibeCooldown = 0.45;
        } 
        else if (sTilt > 0.15) {
            // TILT WIN: The side-to-side roll
            theGame.VibrateController(0.0, 0.1, 0.05);
            vibeCooldown = 0.4;
        }

        // 4. Update state
        UpdateState(lV, rV, fV, bV);
    }

    private function UpdateState(lV : Vector, rV : Vector, fV : Vector, bV : Vector) {
        var curTilt, curPitch, curHeave : float;
        curTilt  = lV.Z - rV.Z;
        curPitch = fV.Z - bV.Z;
        curHeave = (lV.Z + rV.Z + fV.Z + bV.Z) / 4.0;

        if (AbsF(curTilt - lastTilt) > 0.001) lastTiltDir = GetSign(curTilt - lastTilt);
        if (AbsF(curPitch - lastPitch) > 0.001) lastPitchDir = GetSign(curPitch - lastPitch);
        if (AbsF(curHeave - lastHeave) > 0.001) lastHeaveDir = GetSign(curHeave - lastHeave);

        lastTilt  = curTilt;
        lastPitch = curPitch;
        lastHeave = curHeave;
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
class CBoatVibrationManager extends CObject {
    private var lastTilt : float;
    private var lastPitch : float;
    private var lastHeave : float;

    public function ProcessBuoyancy(dt : float, lV : Vector, rV : Vector, fV : Vector, bV : Vector) {
        var currentTilt, currentPitch, currentHeave : float;
        var deltaTilt, deltaPitch, deltaHeave : float;
        var rumbleL, rumbleH : float;
        
        // Multipliers to tune the "feel"
        var sensitivity : float = 0.15; 

        // 1. Extract World Z from the Vectors
        currentTilt = lV.Z - rV.Z;
        currentPitch = fV.Z - bV.Z;
        currentHeave = (lV.Z + rV.Z + fV.Z + bV.Z) / 4.0;

        // 2. Calculate Rate of Change (Velocity of the rocking)
        deltaTilt  = AbsF(currentTilt - lastTilt) / dt;
        deltaPitch = AbsF(currentPitch - lastPitch) / dt;
        deltaHeave = AbsF(currentHeave - lastHeave) / dt;

        // 3. Map to Motors
        // LFM = Vertical 'Weight' changes (Heave/Pitch)
        // HFM = Angular 'Tension' changes (Tilt/Roll)
        rumbleL = (deltaHeave * sensitivity) + (deltaPitch * (sensitivity * 0.5));
        rumbleH = (deltaTilt * sensitivity);

        // 4. Smooth out the noise
        if (rumbleL < 0.005) rumbleL = 0;
        if (rumbleH < 0.005) rumbleH = 0;

        // Cap to avoid vibrating the controller off the table
        rumbleL = MinF(rumbleL, 0.3);
        rumbleH = MinF(rumbleH, 0.15);

        if (rumbleL > 0 || rumbleH > 0) {
            theGame.VibrateController(rumbleL, rumbleH, 0.1);
        }

        lastTilt = currentTilt;
        lastPitch = currentPitch;
        lastHeave = currentHeave;
    }

    public function TriggerRudder() {
        theGame.VibrateController(0.0, 0.06, 0.04);
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
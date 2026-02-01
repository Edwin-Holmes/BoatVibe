class CBoatVibrationManager extends CObject {
    private var boatTimer    : float;
    private var waveSeqTimer : float;
    private var waveStep     : int;
    private var isWaving     : bool;

    public function Update(dt: float, currentSpeed : float, rudderMoving : bool) {
        // 1. Wave Sequence (Thump-ripple-ripple)
        if (isWaving) {
            waveSeqTimer -= dt;
            if (waveSeqTimer <= 0) {
                ProcessWaveSequence();
            }
        }

        // 2. Constant Hull Thrum
        // Plays when moving, but not during a wave hit
        if (!isWaving && currentSpeed > 0.1) {
            boatTimer -= dt;
            if (boatTimer <= 0) {
                // Subtle engine/water vibration
                theGame.VibrateController(0.1, 0.1, 0.05); 
                // Speed-based frequency: faster speed = faster pulses
                boatTimer = 0.9 - (MinF(currentSpeed, 1.0) * 0.4); 
            }
        }

        // 3. Rudder Feedback
        // Only vibrates when the rudder is actually being rotated
        if (rudderMoving) {
            theGame.VibrateController(0.15, 0.05, 0.05);
        }
    }

    public function TriggerWaveImpact() {
        if (isWaving) return;
        isWaving = true;
        waveStep = 0;
        ProcessWaveSequence();
    }

    private function ProcessWaveSequence() {
        switch(waveStep) {
            case 0: // The Initial Slam (Heavy)
                theGame.VibrateController(0.8, 0.4, 0.1);
                waveStep = 1;
                waveSeqTimer = 0.25; // Silent gap
                break;
            case 1: // First Resonance (Medium)
                theGame.VibrateController(0.4, 0.1, 0.1);
                waveStep = 2;
                waveSeqTimer = 0.25; // Silent gap
                break;
            case 2: // Final Ripple (Light)
                theGame.VibrateController(0.15, 0.0, 0.1);
                waveStep = 0;
                isWaving = false; 
                break;
        }
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

@addField(CBoatComponent) 
public var isRudderMovingThisTick : bool;

@wrapMethod(CBoatComponent) function SetRudderDir( rider : CActor, value : float ) {
    // Check change before the vanilla code updates rudderDir
    this.isRudderMovingThisTick = (AbsF(this.rudderDir - value) > 0.001);
    wrappedMethod(rider, value);
}

@wrapMethod(CBoatComponent) function OnTick(dt : float) {
    var speedRatio : float;
    var currentVelZ : float;
    var fDiff : float;

    wrappedMethod(dt);

    if (boatVibeManager) {
        // Calculate speedRatio exactly like vanilla does
        speedRatio = GetLinearVelocityXY() / GetMaxSpeed();
        
        // Pass the movement data to manager
        boatVibeManager.Update(dt, speedRatio, isRudderMovingThisTick);

        // WAVE DETECTION
        // We use the same variables the vanilla code just updated in the class
        fDiff = fr.Z - fr.W;
        currentVelZ = (frontSlotTransform.W).Z - prevFrontPosZ;

        if ( IsDiving( currentVelZ, prevFrontWaterPosZ, fDiff ) ) {
            boatVibeManager.TriggerWaveImpact();
        }

        // Reset the rudder flag for the next frame
        isRudderMovingThisTick = false;
    }
}
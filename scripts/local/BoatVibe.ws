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

// Add a flag to the component to track rudder movement
@addField(CBoatComponent) 
public var isRudderMovingThisTick : bool;

// Hook into SetRudderDir to see if the player is actually turning
@wrapMethod(CBoatComponent) function SetRudderDir( rider : CActor, value : float ) {
    var change : float;
    change = AbsF(this.rudderDir - value);
    
    // If there is any change, flag it for the manager
    this.isRudderMovingThisTick = (change > 0.001);
    
    return wrappedMethod(rider, value);
}

// Hook into OnTick to run the manager
@wrapMethod(CBoatComponent) function OnTick(dt : float) {
    // 1. Run vanilla code first to calculate currentSpeed, fDiff, etc.
    wrappedMethod(dt);

    if (boatVibeManager) {
        // 2. Run the update using the local variables calculated by vanilla OnTick
        // Note: we access currentSpeed and the diving logic here
        boatVibeManager.Update(dt, currentSpeed, isRudderMovingThisTick);

        // 3. Wave Detection (Matches the vanilla SoundEvent logic)
        if ( IsDiving( currentFrontVelZ, prevFrontWaterPosZ, (fr.Z - fr.W) ) ) {
            boatVibeManager.TriggerWaveImpact();
        }

        // Reset rudder flag for next tick
        isRudderMovingThisTick = false;
    }
}
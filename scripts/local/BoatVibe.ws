class CBoatVibrationManager extends CObject {
    private var waveSeqTimer : float;
    private var waveStep     : int;
    private var isWaving     : bool;
    private var globalVibeCooldown : float; // Prevents the "boom boom boom" stacking

    public function Update(dt: float) {
        if (globalVibeCooldown > 0) globalVibeCooldown -= dt;

        if (isWaving) {
            waveSeqTimer -= dt;
            if (waveSeqTimer <= 0) {
                ProcessWaveSequence();
            }
        }
    }

    // Triggered by Physics (Moving) OR a Random Timer (Idle)
    public function TriggerWaveImpact(isMoving : bool) {
        if (isWaving || globalVibeCooldown > 0) return;

        isWaving = true;
        waveStep = 0;
        
        // If moving, we use your harder sequence. If idle, a gentle one.
        if (isMoving) {
            ProcessWaveSequence(); 
        } else {
            ProcessIdleSequence();
        }
    }

    private function ProcessWaveSequence() {
        globalVibeCooldown = 0.05; // Short safety gap
        switch(waveStep) {
            case 0: theGame.VibrateController(0.4, 0.2, 0.08); waveSeqTimer = 0.3; waveStep = 1; break; // Slam
            case 1: theGame.VibrateController(0.2, 0.1, 0.08); waveSeqTimer = 0.3; waveStep = 2; break; // Ripple 1
            case 2: theGame.VibrateController(0.1, 0.0, 0.08); isWaving = false; break;                // Ripple 2
        }
    }

    private function ProcessIdleSequence() {
        globalVibeCooldown = 0.05;
        switch(waveStep) {
            case 0: theGame.VibrateController(0.15, 0.0, 0.08); waveSeqTimer = 0.4; waveStep = 1; break; // Gentle nudge
            case 1: theGame.VibrateController(0.05, 0.0, 0.08); waveSeqTimer = 0.4; waveStep = 2; break; // Fading
            case 2: theGame.VibrateController(0.02, 0.0, 0.08); isWaving = false; break;                // Still
        }
    }

    public function TriggerRudder() {
        // Rudder is now much lighter (0.05) and has a cooldown to stop "building up"
        if (globalVibeCooldown <= 0) {
            theGame.VibrateController(0.05, 0.05, 0.04);
            globalVibeCooldown = 0.1; 
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

@addField(CBoatComponent) private var idleWaveTimer : float;

@wrapMethod(CBoatComponent) function SetRudderDir( rider : CActor, value : float ) {
    // Check for change
    if (AbsF(this.rudderDir - value) > 0.005 && boatVibeManager) {
        boatVibeManager.TriggerRudder();
    }
    wrappedMethod(rider, value);
}

@wrapMethod(CBoatComponent) function OnTick(dt : float) {
    var isMoving : bool;
    var currentVelZ : float;
    
    wrappedMethod(dt);

    if (boatVibeManager) {
        boatVibeManager.Update(dt);
        
        // Use the class variable IDLE_SPEED_THRESHOLD
        isMoving = ( GetLinearVelocityXY() > IDLE_SPEED_THRESHOLD );

        if (isMoving) {
            // MOVING: Use physics detection
            currentVelZ = (frontSlotTransform.W).Z - prevFrontPosZ;
            if ( IsDiving( currentVelZ, prevFrontWaterPosZ, (fr.Z - fr.W) ) ) {
                boatVibeManager.TriggerWaveImpact(true);
            }
        } else {
            // IDLE: Use a random timer to simulate gentle lapping water
            idleWaveTimer -= dt;
            if (idleWaveTimer <= 0) {
                boatVibeManager.TriggerWaveImpact(false);
                idleWaveTimer = RandRangeF(4.0, 7.0); // New idle wave every 4-7 seconds
            }
        }
    }
}
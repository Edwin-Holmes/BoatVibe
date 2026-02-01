class CBoatVibrationManager extends CObject {
    private var waveSeqTimer : float;
    private var waveStep     : int;
    private var isWaving     : bool;
    private var globalVibeCooldown : float;

    public function Update(dt: float) {
        if (globalVibeCooldown > 0) globalVibeCooldown -= dt;

        if (isWaving) {
            waveSeqTimer -= dt;
            if (waveSeqTimer <= 0) {
                ProcessWaveSequence();
            }
        }
    }

    public function TriggerWaveImpact() {
        if (isWaving || globalVibeCooldown > 0) return;
        isWaving = true;
        waveStep = 0;
        ProcessWaveSequence();
    }

    private function ProcessWaveSequence() {
        // We use longer durations (0.2s+) to make it feel fluid/heavy
        switch(waveStep) {
            case 0: 
                // 1. Big & Short
                theGame.VibrateController(0.4, 0.2, 0.15); 
                waveSeqTimer = 0.5; // Long gap for fluidity
                waveStep = 1; 
                break;
            case 1: 
                // 2. Longer & Weaker
                theGame.VibrateController(0.15, 0.1, 0.3); 
                waveSeqTimer = 0.6; // Even longer gap
                waveStep = 2; 
                break;
            case 2: 
                // 3. Longest & Weakest (fading out)
                theGame.VibrateController(0.05, 0.0, 0.5); 
                isWaving = false; 
                globalVibeCooldown = 0.4; // Prevents immediate re-trigger
                break;
        }
    }

    public function TriggerRudder() {
        if (globalVibeCooldown <= 0) {
            // Extremelly soft tick
            theGame.VibrateController(0.02, 0.02, 0.04);
            globalVibeCooldown = 0.2; 
        }
    }
    
    public function TriggerIdleNudge() {
        if (isWaving || globalVibeCooldown > 0) return;
        // Just a single very soft "sway" feeling for idle
        theGame.VibrateController(0.05, 0.0, 0.4);
        globalVibeCooldown = 1.0;
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
        
        isMoving = ( GetLinearVelocityXY() > IDLE_SPEED_THRESHOLD );

        if (isMoving) {
            // Re-calculating currentVelZ for the diving check
            currentVelZ = (frontSlotTransform.W).Z - prevFrontPosZ;
            
            if ( IsDiving( currentVelZ, prevFrontWaterPosZ, (fr.Z - fr.W) ) ) {
                boatVibeManager.TriggerWaveImpact();
            }
        } else {
            // IDLE: Random gentle nudge
            idleWaveTimer -= dt;
            if (idleWaveTimer <= 0) {
                boatVibeManager.TriggerIdleNudge();
                idleWaveTimer = RandRangeF(5.0, 8.0); 
            }
        }
    }
}
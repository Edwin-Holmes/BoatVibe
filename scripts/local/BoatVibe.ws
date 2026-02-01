class CBoatVibrationManager extends CObject {
    private var waveSeqTimer : float;
    private var waveStep     : int;
    private var isWaving     : bool;
    private var globalVibeCooldown : float;

    public function Update(dt: float) {
        if (globalVibeCooldown > 0) globalVibeCooldown -= dt;
        if (isWaving) {
            waveSeqTimer -= dt;
            if (waveSeqTimer <= 0) ProcessWaveSequence();
        }
    }

    public function TriggerWaveImpact() {
        if (isWaving || globalVibeCooldown > 0) return;
        isWaving = true;
        waveStep = 0;
        ProcessWaveSequence();
    }

    private function ProcessWaveSequence() {
        switch(waveStep) {
            // Pair 1: The Initial Push
            case 0: 
                theGame.VibrateController(0.12, 0.0, 0.15); // Short "thump"
                waveSeqTimer = 0.15; waveStep = 1; break;
            case 1: 
                theGame.VibrateController(0.05, 0.0, 0.8);  // Long "glide"
                waveSeqTimer = 1.0; waveStep = 2; break;

            // Pair 2: The Secondary Roll (slighly different intensity)
            case 2: 
                theGame.VibrateController(0.08, 0.0, 0.15); 
                waveSeqTimer = 0.15; waveStep = 3; break;
            case 3: 
                theGame.VibrateController(0.03, 0.0, 1.2); 
                waveSeqTimer = 1.3; waveStep = 4; break;

            // Pair 3: The Deep Wash
            case 4: 
                theGame.VibrateController(0.10, 0.0, 0.2); 
                waveSeqTimer = 0.2; waveStep = 5; break;
            case 5: 
                theGame.VibrateController(0.04, 0.0, 1.5); // Very long fade
                isWaving = false; 
                globalVibeCooldown = 0.2; break; 
        }
    }

    public function TriggerIdleNudge() {
        if (isWaving || globalVibeCooldown > 0) return;
        // Idle is now a single very soft but long (0.8s) pulse to prevent "shortness"
        theGame.VibrateController(0.02, 0.0, 0.8); 
        globalVibeCooldown = 1.5;
    }

    public function TriggerRudder() {
        if (globalVibeCooldown <= 0) {
            theGame.VibrateController(0.03, 0.0, 0.05);
            globalVibeCooldown = 0.15; 
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
@addField(CBoatComponent) private var moveWaveTimer : float;

@wrapMethod(CBoatComponent) function OnTick(dt : float) {
    var isMoving : bool;
    wrappedMethod(dt);

    if (boatVibeManager) {
        boatVibeManager.Update(dt);
        isMoving = ( GetLinearVelocityXY() > IDLE_SPEED_THRESHOLD );

        if (isMoving) {
            moveWaveTimer -= dt;
            if (moveWaveTimer <= 0) {
                boatVibeManager.TriggerWaveImpact();
                // Sequence is ~3s long, so 3.2s means a 0.2s gap
                moveWaveTimer = 3.2; 
            }
        } else {
            idleWaveTimer -= dt;
            if (idleWaveTimer <= 0) {
                boatVibeManager.TriggerIdleNudge();
                idleWaveTimer = RandRangeF(4.0, 8.0); 
            }
            moveWaveTimer = 0.2; 
        }
    }
}

@wrapMethod(CBoatComponent) function SetRudderDir( rider : CActor, value : float ) {
    // Check for change
    if (AbsF(this.rudderDir - value) > 0.005 && boatVibeManager) {
        boatVibeManager.TriggerRudder();
    }
    wrappedMethod(rider, value);
}
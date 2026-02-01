class CBoatVibrationManager extends CObject {
    private var waveSeqTimer : float;
    private var waveStep     : int;
    private var isWaving     : bool;

    public function Update(dt: float) {
        if (isWaving) {
            waveSeqTimer -= dt;
            if (waveSeqTimer <= 0) ProcessWaveSequence();
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
            // Pair 1: Moderate Hit -> Longest Glide
            case 0: theGame.VibrateController(0.05, 0.0, 0.12); 
                    waveSeqTimer = 0.12; 
                    waveStep = 1; 
                    break;
            case 1: theGame.VibrateController(0.0, 0.01, 1.0); 
                    waveSeqTimer = 1.65; 
                    waveStep = 2; 
                    break; // Long glide + 0.6s silence

            // Pair 2: Light Hit -> Medium Glide
            case 2: theGame.VibrateController(0.06, 0.0, 0.10); 
                    waveSeqTimer = 0.10; 
                    waveStep = 3; 
                    break;
            case 3: theGame.VibrateController(0.0, 0.01, 0.80); 
                    waveSeqTimer = 1.35; 
                    waveStep = 4; 
                    break; // Med glide + 0.6s silence

            // Pair 3: Softest Hit -> Short Glide
            case 4: theGame.VibrateController(0.04, 0.0, 0.08); 
                    waveSeqTimer = 0.08; 
                    waveStep = 5; 
                    break;
            case 5: theGame.VibrateController(0.0, 0.01, 0.50); 
                    isWaving = false; 
                    break;
        }
    }

    public function Clear() {
        isWaving = false;
        waveStep = 0;
        waveSeqTimer = 0;
        theGame.VibrateController(0.0, 0.0, 0.0); 
    }

    public function TriggerIdleNudge() {
        if (isWaving) return;
        // Just the "Glide" portion for idle, very soft and long
        theGame.VibrateController(0.0, 0.01, 0.05); 
    }

    public function TriggerRudder() {
        // A very brief, crisp mechanical tick
        theGame.VibrateController(0.0, 0.1, 0.001);
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
        isMoving = ( GetLinearVelocityXY() > IDLE_SPEED_THRESHOLD );

        if (isMoving) {
            boatVibeManager.Update(dt);
            moveWaveTimer -= dt;
            
            if (moveWaveTimer <= 0) {
                boatVibeManager.TriggerWaveImpact();
                // Sequence takes ~4s to play including silences.
                // 5.0s ensures a full second of calm before the cycle repeats.
                moveWaveTimer = 4.5; 
            }
        } else {
            // Kill vibrations immediately when button released
            if (moveWaveTimer > 0) {
                boatVibeManager.Clear();
                moveWaveTimer = 0;
            }

            idleWaveTimer -= dt;
            if (idleWaveTimer <= 0) {
                boatVibeManager.TriggerIdleNudge();
                idleWaveTimer = RandRangeF(3.5, 6.0); 
            }
        }
    }
}

@wrapMethod(CBoatComponent) function SetRudderDir( rider : CActor, value : float ) {
    // Check for change
    if (AbsF(this.rudderDir - value) > 0.005 && AbsF(this.rudderDir - value) < 0.5 && boatVibeManager) {
        boatVibeManager.TriggerRudder();
    }
    wrappedMethod(rider, value);
}
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
            case 0: 
                // 1. Big & Short
                theGame.VibrateController(0.25, 0.08, 0.12); 
                waveSeqTimer = 0.5; waveStep = 1; break; 
            case 1: 
                // 2. Longer & Weaker
                theGame.VibrateController(0.1, 0.04, 0.3); 
                waveSeqTimer = 0.6; waveStep = 2; break; 
            case 2: 
                // 3. Longest & Weakest
                theGame.VibrateController(0.03, 0.0, 0.5); 
                isWaving = false; 
                globalVibeCooldown = 0.3; break;
        }
    }

    public function TriggerIdleNudge() {
        if (isWaving || globalVibeCooldown > 0) return;
        // Tiny nudge for idle
        theGame.VibrateController(0.03, 0.0, 0.2); 
        globalVibeCooldown = 0.5;
    }

    public function TriggerRudder() {
        if (globalVibeCooldown <= 0) {
            // Barely-there rudder tick
            theGame.VibrateController(0.01, 0.0, 0.04);
            globalVibeCooldown = 0.2; 
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
            
            // REGULAR RHYTHM: No more randomness, just steady sailing beats
            if (moveWaveTimer <= 0) {
                boatVibeManager.TriggerWaveImpact();
                moveWaveTimer = 3.0; // The "Sailing Rhythm" interval
            }
        } else {
            // RANDOM IDLE: Keeps the boat feeling "parked" in live water
            idleWaveTimer -= dt;
            if (idleWaveTimer <= 0) {
                boatVibeManager.TriggerIdleNudge();
                idleWaveTimer = RandRangeF(5.0, 10.0); 
            }
            // Reset move timer so sailing always starts with a beat immediately
            moveWaveTimer = 0.5; 
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
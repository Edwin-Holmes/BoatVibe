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
                // 1. Big & Short (Initial crest)
                theGame.VibrateController(0.18, 0.0, 0.2); 
                waveSeqTimer = 0.7; waveStep = 1; break; 
            case 1: 
                // 2. Longer & Weaker (The roll)
                theGame.VibrateController(0.08, 0.0, 0.6); 
                waveSeqTimer = 0.9; waveStep = 2; break; 
            case 2: 
                // 3. Longest & Weakest (The fade)
                theGame.VibrateController(0.03, 0.0, 1.0); 
                isWaving = false; 
                globalVibeCooldown = 0.5; break;
        }
    }

    public function TriggerIdleNudge() {
        if (isWaving || globalVibeCooldown > 0) return;
        // Reduced to the absolute floor of perception
        theGame.VibrateController(0.02, 0.0, 0.3); 
        globalVibeCooldown = 1.0;
    }

    public function TriggerRudder() {
        if (globalVibeCooldown <= 0) {
            // Slightly boosted from 0.01 to 0.03
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
                // 4 seconds provides a slow, majestic rhythm
                moveWaveTimer = 4.0; 
            }
        } else {
            idleWaveTimer -= dt;
            if (idleWaveTimer <= 0) {
                boatVibeManager.TriggerIdleNudge();
                idleWaveTimer = RandRangeF(6.0, 12.0); 
            }
            // Start moving wave almost immediately upon acceleration
            moveWaveTimer = 0.4; 
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
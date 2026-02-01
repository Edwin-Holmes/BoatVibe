class CBoatVibrationManager extends CObject {
    private var boatTimer    : float;
    private var waveSeqTimer : float;
    private var waveStep     : int;
    private var isWaving     : bool;

    public function Update(dt: float, boat : CBoatComponent) {
        var currentSpeed     : float;
        var sailingMaxSpeed  : float;

        // 1. Calculate Speed Ratio
        sailingMaxSpeed = boat.GetMaxSpeed();
        if (sailingMaxSpeed > 0) {
            currentSpeed = boat.GetLinearVelocityXY() / sailingMaxSpeed;
        }

        // 2. Wave Sequence Logic (The "Thump-ripple-ripple")
        if (isWaving) {
            waveSeqTimer -= dt;
            if (waveSeqTimer <= 0) {
                ProcessWaveSequence();
            }
        }

        // 3. Constant Hull Thrum (Only play if not currently doing a wave hit)
        if (!isWaving && currentSpeed > 0.1) {
            boatTimer -= dt;
            if (boatTimer <= 0) {
                cvsVibrate(0, 0.01); 
                boatTimer = 0.9 - (currentSpeed * 0.3); 
            }
        }

        // 4. Rudder Tension
        if (boat.GetIsChangingSteer()) {
            cvsVibrate(1, 0.1);
        }
    }

    public function TriggerWaveImpact(isHeavy : bool) {
        // Don't restart if we are already in the middle of a wave thump
        if (isWaving) return;

        isWaving = true;
        waveStep = 0;
        
        // Start immediately
        ProcessWaveSequence();
    }

    private function ProcessWaveSequence() {
        switch(waveStep) {
            case 0: // The Initial Hit
                cvsVibrate(2, 0.15);
                waveStep = 1;
                waveSeqTimer = 0.15; // Gap to next ripple
                break;
            case 1: // First Resonance
                cvsVibrate(1, 0.2);
                waveStep = 2;
                waveSeqTimer = 0.2;
                break;
            case 2: // Final Ripple
                cvsVibrate(1, 0.1);
                waveStep = 0;
                isWaving = false; // Sequence finished
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

// Inject logic into the main Tick
@wrapMethod(CBoatComponent) function OnTick(dt : float) {
    var currentFrontPosZ : float;
    var currentFrontVelZ : float;
    var fDiff : float;

    // Run original code first to populate the physics variables
    wrappedMethod(dt);

    if (boatVibeManager) {
        // Run constant speed/rudder logic
        boatVibeManager.Update(dt, this);

        // Catch the Wave Slap!
        // We use the same 'IsDiving' check CDPR uses for sound/effects
        fDiff = fr.Z - fr.W;
        currentFrontPosZ = (frontSlotTransform.W).Z;
        currentFrontVelZ = currentFrontPosZ - prevFrontPosZ;

        if ( IsDiving( currentFrontVelZ, prevFrontWaterPosZ, fDiff ) ) {
            // If the front splash effect is currently active, it's a hard impact
            boatVibeManager.TriggerWaveImpact(boatEntity.IsEffectActive('front_splash'));
        }
    }
}

@addMethod(CBoatComponent)
public function GetIsChangingSteer() : bool 
{
    // Inside this added method, you have full access to private variables
    return this.isChangingSteer;
}
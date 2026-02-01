class CBoatVibrationManager extends CObject {
    private var boatTimer    : float;
    private var waveSeqTimer : float;
    private var waveStep     : int;
    private var isWaving     : bool;

    public function Update(dt: float, boat : CBoatComponent) {
        var currentSpeed     : float;
        var sailingMaxSpeed  : float;

        sailingMaxSpeed = boat.GetMaxSpeed();
        if (sailingMaxSpeed > 0) {
            currentSpeed = boat.GetLinearVelocityXY() / sailingMaxSpeed;
        }

        // 1. Wave Sequence Logic (Thump -> gap -> ripple -> gap -> ripple)
        if (isWaving) {
            waveSeqTimer -= dt;
            if (waveSeqTimer <= 0) {
                ProcessWaveSequence();
            }
        }

        // 2. Constant Hull Thrum (The "Engine/Water" hum)
        // Only plays if not currently hitting a wave
        if (!isWaving && currentSpeed > 0.1) {
            boatTimer -= dt;
            if (boatTimer <= 0) {
                // Low intensity buzz to feel the speed
                theGame.VibrateController(0.1, 0.1, 0.05); 
                boatTimer = 0.8 - (currentSpeed * 0.3); 
            }
        }

        // 3. Rudder Tension (Feel the wood creaking during turns)
        if (boat.GetIsChangingSteer()) {
            theGame.VibrateController(0.2, 0.0, 0.1);
        }
    }

    public function TriggerWaveImpact(isHeavy : bool) {
        if (isWaving) return;

        isWaving = true;
        waveStep = 0;
        ProcessWaveSequence();
    }

    private function ProcessWaveSequence() {
        switch(waveStep) {
            case 0: // The Big Initial Slam
                // Heavy on the low freq, sharp on the high
                theGame.VibrateController(0.8, 0.6, 0.1);
                waveStep = 1;
                waveSeqTimer = 0.25; // Silent gap for the motor to stop
                break;
            case 1: // The First Ripple
                theGame.VibrateController(0.4, 0.2, 0.12);
                waveStep = 2;
                waveSeqTimer = 0.25; // Another silent gap
                break;
            case 2: // The Final Faint Ripple
                theGame.VibrateController(0.2, 0.0, 0.1);
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

@addMethod(CBoatComponent)
public function GetIsChangingSteer() : bool 
{
    // AbsF check on steerTarget covers holding the turn AND active movement
    return AbsF(this.steerTarget) > 0.1;
}

@wrapMethod(CBoatComponent) function OnTick(dt : float) {
    var currentFrontPosZ, currentFrontVelZ, fDiff : float;

    wrappedMethod(dt);

    if (boatVibeManager) {
        boatVibeManager.Update(dt, this);

        // WAVE DETECTION
        // Prioritize the visual splash effect as the 'Heavy' trigger
        if ( boatEntity.IsEffectActive('front_splash') ) {
            boatVibeManager.TriggerWaveImpact(true);
        } 
        else {
            fDiff = fr.Z - fr.W;
            currentFrontPosZ = (frontSlotTransform.W).Z;
            currentFrontVelZ = currentFrontPosZ - prevFrontPosZ;

            // Physics fallback for smaller waves
            if ( IsDiving( currentFrontVelZ, prevFrontWaterPosZ, fDiff ) ) {
                boatVibeManager.TriggerWaveImpact(false);
            }
        }
    }
}
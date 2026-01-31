class CBoatVibrationManager extends CObject {
    private var boatTimer : float;

    public function Update(dt: float, boat : CBoatComponent) {
        var currentSpeed : float;
        var sailingMaxSpeed : float;

        // 1. Calculate Speed Ratio
        sailingMaxSpeed = boat.GetMaxSpeed();
        if (sailingMaxSpeed > 0) {
            currentSpeed = boat.GetLinearVelocityXY() / sailingMaxSpeed;
        }

        // 2. Constant Hull Thrum (The vibration of the water)
        if (currentSpeed > 0.1) {
            boatTimer -= dt;
            if (boatTimer <= 0) {
                // VeryLight (0) for the water texture
                CSU_HapticVibe(0, 0.1); 
                
                // Interval scales: faster speed = faster heartbeat
                boatTimer = 0.9 - (currentSpeed * 0.6); 
            }
        }

        // 3. Rudder Tension (Feel the wood creak while turning)
        // isChangingSteer is the internal flag for moving the rudder
        if (boat.isChangingSteer) {
            CSU_HapticVibe(0, 0.05);
        }
    }

    public function TriggerWaveImpact(isHeavy : bool) {
        if (isHeavy) {
            CSU_HapticVibe(2, 0.25); // Hard thud for cresting waves
        } else {
            CSU_HapticVibe(1, 0.1);  // Light slap for small chop
        }
    }
}

@addField(CBoatComponent) 
public var boatVibeManager : CBoatVibrationManager;

// Create manager when player takes the helm
@wrapMethod(CBoatComponent) function MountStarted() {
    if (!boatVibeManager) {
        boatVibeManager = new CBoatVibrationManager in this;
    }
    return wrappedMethod();
}

// Destroy manager when player lets go of the helm
@wrapMethod(CBoatComponent) function DismountFinished() {
    if (boatVibeManager) {
        delete boatVibeManager;
        boatVibeManager = NULL;
    }
    return wrappedMethod();
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
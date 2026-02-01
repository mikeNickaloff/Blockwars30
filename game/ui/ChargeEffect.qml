import QtQuick 2.4
import QtQuick.Particles 2.0

Item {
    objectName: "Particle scene"
    width: 100
    height: 100
    id: chargeRoot
    property bool activated: false

    function burst() {
     chargeEmitter.burst(25)
    }

    ParticleSystem {
        id: particleSystem
    }

    ImageParticle {
        objectName: "charging"
        groups: ["charging"]
        source: "file:///home/mike/build/Blockwars30/images/particles/particleA.png"
        color: "#aaffff"
        colorVariation: 0
        alpha: 1
        alphaVariation: 0
        redVariation: 0
        greenVariation: 0
        blueVariation: 0
        rotation: 0
        rotationVariation: 105
        autoRotation: false
        rotationVelocity: 0
        rotationVelocityVariation: 0
        entryEffect: ImageParticle.Fade
        system: particleSystem
    }

    Emitter {
            id: chargeEmitter
        objectName: "chargingemitter"
        x: 0
        y: 44.53125
        width: 99
        height: 26
        enabled: chargeRoot.activated
        group: "charging"
        emitRate: 13
        maximumEmitted: 7
        startTime: 0
        lifeSpan: 1300
        lifeSpanVariation: 1000
        size: 2
        sizeVariation: 0
        endSize: 17
        velocityFromMovement: 0
        system: particleSystem
        velocity:
            AngleDirection {
                angle: 0
                angleVariation: -5
                magnitude: 0
                magnitudeVariation: 0
            }
        acceleration:
            AngleDirection {
                angle: 0
                angleVariation: 16
                magnitude: 0
                magnitudeVariation: 0
            }
        shape:
            RectangleShape {}
    }

    Attractor {
        objectName: "attractor"
        x: 37.1171875
        y: 51.43359375
        width: 26
        height: 17
        enabled: chargeRoot.activated
        groups: ["charging"]
        whenCollidingWith: ["charging"]
        once: false
        affectedParameter: Attractor.Position
        proportionalToDistance: Attractor.Quadratic
        system: particleSystem
        shape:
            EllipseShape {
                fill: false
            }
    }

    Gravity {
        objectName: ""
        x: 0
        y: 39.0859375
        width: 34
        height: 38
        enabled: chargeRoot.activated
        groups: ["charging"]
        whenCollidingWith: []
        once: false
        angle: 179
        magnitude: -46
        system: particleSystem
        shape:
            RectangleShape {}
    }

    Gravity {
        objectName: ""
        x: 68
        y: 39.92578125
        width: 32
        height: 41
        enabled: chargeRoot.activated
        groups: []
        whenCollidingWith: []
        once: false
        angle: -3
        magnitude: -58
        system: particleSystem
        shape:
            RectangleShape {}
    }
}

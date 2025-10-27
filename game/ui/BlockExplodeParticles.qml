import QtQuick 2.4
import QtQuick.Particles 2.0

Item {
    objectName: "Particle scene"
    width: parent.width
    height: parent.height
    property var system
    function burstAt(xpos, ypos) {
        boomEmitter1.burst(1, xpos, ypos)
        smokeEmitter1.burst(10, xpos, ypos)
        boomEmitter2.burst(1, xpos, ypos)
        emberEmitter1.burst(15, xpos, ypos)
    }
    ParticleSystem {
        id: particleSystem
    }

    ImageParticle {
        objectName: "ember1"
        groups: ["ember1"]
        source: "qrc:///images/particles/ember_mid.png"
        color: "white"
        colorVariation: 0
        alpha: 1
        alphaVariation: 0
        redVariation: 0
        greenVariation: 0
        blueVariation: 0
        rotation: 0
        rotationVariation: 47
        autoRotation: false
        rotationVelocity: 0
        rotationVelocityVariation: 0
        entryEffect: ImageParticle.Fade
        system: particleSystem
    }

    ImageParticle {
        objectName: "boom1"
        groups: ["boom1"]
        source: "qrc:///images/particles/boomboom.png"
        color: "#ffc4a3"
        colorVariation: 0
        alpha: 0.9
        alphaVariation: 0
        redVariation: 0
        greenVariation: 0
        blueVariation: 0
        rotation: 0
        rotationVariation: 0
        autoRotation: false
        rotationVelocity: 0
        rotationVelocityVariation: 0
        entryEffect: ImageParticle.None
        system: particleSystem
    }

    ImageParticle {
        objectName: "smoke1"
        groups: ["smoke1"]
        source: "qrc:///images/particles/barrelpoof.png"
        color: "#262821"
        colorVariation: 0
        alpha: 1
        alphaVariation: 0
        redVariation: 0
        greenVariation: 0
        blueVariation: 0
        rotation: 21
        rotationVariation: 20
        autoRotation: false
        rotationVelocity: 0
        rotationVelocityVariation: 0
        entryEffect: ImageParticle.Fade
        system: particleSystem
    }

    ImageParticle {
        objectName: "boom2"
        groups: ["boom2"]
        source: "qrc:///images/particles/boomboom2.png"
        color: "#ffc496"
        colorVariation: 0
        alpha: 0.5
        alphaVariation: 0
        redVariation: 0
        greenVariation: 0
        blueVariation: 0
        rotation: 0
        rotationVariation: 0
        autoRotation: false
        rotationVelocity: 0
        rotationVelocityVariation: 0
        entryEffect: ImageParticle.None
        system: particleSystem
    }

    Emitter {
        objectName: "boomEmitter1"
        id: boomEmitter1
        x: 0
        y: 30
        width: 24
        height: 24
        enabled: false
        group: "boom1"
        emitRate: 1
        maximumEmitted: 20
        startTime: 0
        lifeSpan: 150
        lifeSpanVariation: 0
        size: 72
        sizeVariation: 0
        endSize: 160
        velocityFromMovement: 0
        system: particleSystem
        velocity: CumulativeDirection {}
        acceleration: PointDirection {
            x: 0
            xVariation: 50
            y: 0
            yVariation: 49
        }
        shape: RectangleShape {}
    }
    Emitter {
        id: emberEmitter1
        x: 0
        y: 0
        width: 20
        height: 20
        enabled: false
        group: "ember1"
        emitRate: 15
        maximumEmitted: 150
        startTime: 50
        lifeSpan: 900
        lifeSpanVariation: 200
        size: 8
        sizeVariation: 2
        endSize: 0
        velocityFromMovement: 0
        system: particleSystem
        velocity: PointDirection {
            x: 0
            xVariation: 145
            y: -43
            yVariation: 148
        }
        acceleration: PointDirection {
            x: 0
            xVariation: -25
            y: 0
            yVariation: -225
        }
        shape: RectangleShape {}
    }
    Emitter {
        objectName: "smokeEmitter1"
        id: smokeEmitter1
        x: 0
        y: 0
        width: 30
        height: 30
        enabled: false
        group: "smoke1"
        emitRate: 17
        maximumEmitted: 100
        startTime: 75
        lifeSpan: 2800
        lifeSpanVariation: 0
        size: 55
        sizeVariation: 0
        endSize: 5
        velocityFromMovement: 20
        system: particleSystem
        velocity: PointDirection {
            x: 0
            xVariation: 0
            y: -75
            yVariation: 0
        }
        acceleration: PointDirection {
            x: 0
            xVariation: -5
            y: 0
            yVariation: -25
        }
        shape: RectangleShape {}
    }

    Emitter {
        objectName: "boomEmitter2"
        id: boomEmitter2
        x: 0
        y: 70
        width: 25
        height: 25
        enabled: false
        group: "boom2"
        emitRate: 1
        maximumEmitted: 1
        startTime: 50
        lifeSpan: 150
        lifeSpanVariation: 0
        size: 0
        sizeVariation: 0
        endSize: 200
        velocityFromMovement: 0
        system: particleSystem
        velocity: PointDirection {
            x: 0
            xVariation: 0
            y: 0
            yVariation: 0
        }
        acceleration: PointDirection {
            x: 0
            xVariation: 0
            y: 0
            yVariation: 0
        }
        shape: RectangleShape {}
    }
}

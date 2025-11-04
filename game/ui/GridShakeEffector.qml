import QtQuick 2.15

Item {
    id: root

    // Current translation offsets applied to the target grid.
    property real offsetX: 0
    property real offsetY: 0

    // Impact (block destroyed) tuning.
    property real impactAmplitude: 6
    property int impactDuration: 120

    // Breach (column cleared) tuning.
    property real breachAmplitude: 12
    property int breachDuration: 180

    readonly property bool isAnimating: settleAnimation.running

    function triggerImpact() {
        pulse(impactAmplitude, impactDuration);
    }

    function triggerBreach() {
        pulse(breachAmplitude, breachDuration);
    }

    function pulse(amplitude, duration) {
        if (amplitude <= 0 || duration <= 0)
            return;

        if (settleAnimation.running)
            settleAnimation.stop();

        const angle = Math.random() * Math.PI * 2;
        offsetX = Math.cos(angle) * amplitude;
        offsetY = Math.sin(angle) * amplitude;

        offsetXAnim.duration = duration;
        offsetYAnim.duration = duration;
        settleAnimation.start();
    }

    ParallelAnimation {
        id: settleAnimation
        running: false

        NumberAnimation {
            id: offsetXAnim
            target: root
            property: "offsetX"
            to: 0
            duration: root.impactDuration
            easing.type: Easing.OutQuad
        }

        NumberAnimation {
            id: offsetYAnim
            target: root
            property: "offsetY"
            to: 0
            duration: root.impactDuration
            easing.type: Easing.OutQuad
        }
    }
}

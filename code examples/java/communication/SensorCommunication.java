package com.earlysense.homedevice.sensor.impl.communication;

import com.earlysense.homedevice.sensor.impl.signalprocessor.SensorSignalProcessor;

public interface SensorCommunication {
    void startSensorCommunication();
    void stopSensorCommunication();
    void provideSensorSignalProcessor(final SensorSignalProcessor sensorSignalProcessor);
}

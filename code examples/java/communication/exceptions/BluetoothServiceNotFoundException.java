package com.earlysense.homedevice.sensor.impl.communication.exceptions;

public class BluetoothServiceNotFoundException extends Exception {
    public BluetoothServiceNotFoundException(String errorMessage) {
        super(errorMessage);
    }
}

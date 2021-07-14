package com.earlysense.homedevice.sensor.impl.communication.exceptions;

public class BluetoothCharacteristicNotFoundException extends Exception{
    public BluetoothCharacteristicNotFoundException(String errorMessage) {
        super(errorMessage);
    }
}

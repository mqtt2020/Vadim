package com.earlysense.homedevice.sensor.impl.communication;


//import org.apache.logging.log4j.LogManager;
//import org.apache.logging.log4j.Logger;
import com.earlysense.homedevice.sensor.impl.communication.exceptions.*;
import com.earlysense.homedevice.sensor.impl.signalprocessor.SensorSignalProcessor;
import tinyb.*;

import java.time.Duration;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;

import static com.earlysense.homedevice.sensor.impl.communication.BleSensorAttributes.*;


public class SensorCommunicationImpl implements SensorCommunication {

    //private static final Logger logger = LogManager.getLogger(SensorCommunicationImpl.class);

    private final BluetoothManager bleManager;
    private BluetoothGattService bleDataService;
    private BluetoothGattCharacteristic bleDataCharacteristic;
    private BluetoothDevice bleSensor;

    private final ExecutorService sensorCommunicationMonitor = Executors.newSingleThreadExecutor();
    private Future<?> sensorCommunicationMonitorStatus;

    private SensorSignalProcessor sensorSignalProcessor;

    private volatile boolean isAlive = true;

    public SensorCommunicationImpl() {
        bleManager = BluetoothManager.getBluetoothManager();
    }

    // Inject signal processor
    public void provideSensorSignalProcessor(final SensorSignalProcessor sensorSignalProcessor) {
        this.sensorSignalProcessor = sensorSignalProcessor;
    }

    public void startSensorCommunication() {
        if (sensorSignalProcessor == null) {
            System.out.println("Sensor communication is not initialized with signal processor");
            return;
        }

        System.out.println("Start sensor communication (BLE)");
        sensorCommunicationMonitorStatus = sensorCommunicationMonitor.submit(this::communicationMonitorTask);
    }

    public void stopSensorCommunication() {
        System.out.println("Stop sensor communication (BLE)");
        if (!isAlive)
            return;

        try {
            isAlive = false;
            sensorCommunicationMonitorStatus.get(); // wait for connection monitor to stop
            reset();
        } catch (InterruptedException | ExecutionException e) {
            System.out.println("Failed to stop sensor communication (BLE): " + e);
        }
    }

    private void communicationMonitorTask() {
        Thread.currentThread().setName("com-monitor");
        System.out.println("Start communication monitor task");
        final var DELAY_BETWEEN_ITERATION_SEC = 5;
        while (isAlive) {
            if (!isSensorConnected()) {
                reset();
                connect();
            } else {
                waitSeconds(DELAY_BETWEEN_ITERATION_SEC);
            }
        }
    }

    private boolean isSensorConnected() {
        return bleSensor != null && bleSensor.getConnected();
    }

    private synchronized void reset() {
        if (bleDataService != null)
            bleDataService = null;

        if (bleDataCharacteristic != null) {
            bleDataCharacteristic.disableValueNotifications();
            bleDataCharacteristic = null;
        }

        if (bleSensor != null) {
            bleSensor.disableServicesResolvedNotifications();
            bleSensor.disableConnectedNotifications();
            bleSensor.disconnect();
            bleSensor = null;
        }

        if (bleManager.getAdapters().get(0).getDevices().size() > 0)
            bleManager.getAdapters().get(0).removeDevices();

    }

    private void connect() {
        try {
            startBleDiscovery();
            findSensorByMacAddressWithTimeout();
            bleSensor.enableConnectedNotifications(connectedNotificationsCallback);
            bleSensor.enableServicesResolvedNotifications(servicesResolvedNotificationsCallback);
            if (!bleSensor.connect())
                System.out.println("Cannot connect to sensor (BLE)");

        } catch (BluetoothException e) {
            System.out.println(e);
        } catch (BluetoothSensorNotFoundException e) {
            System.out.println("Sensor (BLE) not found around after timeout");
        } finally {
            stopBleDiscovery();
        }
    }

    // Start BLE discovery if not already running
    private void startBleDiscovery() throws BluetoothException {
        if (!(bleManager.getAdapters().get(0).getDiscovering() || bleManager.getAdapters().get(0).startDiscovery()))
            System.out.println("Cannot start BLE discovery");

    }

    private void stopBleDiscovery() throws BluetoothException {
        bleManager.getAdapters().get(0).stopDiscovery();
    }

    // Stop looping BLE devices when sensor found or after MAX_ATTEMPTS
    private void findSensorByMacAddressWithTimeout() throws BluetoothSensorNotFoundException {
        final var MAX_ATTEMPTS = 15;
        final var DELAY_BETWEEN_ATTEMPTS_SEC = 1;
        for (var attempt = 0; bleSensor == null && attempt < MAX_ATTEMPTS && isAlive; attempt++, waitSeconds(DELAY_BETWEEN_ATTEMPTS_SEC))
            for (var bleDevice : bleManager.getDevices()) {
                if (bleDevice.getAddress().equalsIgnoreCase(MAC_ADDRESS)) {
                    bleSensor = bleDevice;
                    return;
                }
            }

        throw new BluetoothSensorNotFoundException();
    }

    // TinyB Callback: once all services resolved find BLE sensor GATT attributes
    // Use TinyB thread for sensor signal processing as it opens new thread for this callback
    BluetoothNotification<Boolean> servicesResolvedNotificationsCallback = isServicesResolved -> {
        if (isServicesResolved) {
            try {
                System.out.println("Sensor (BLE) services resolved");
                getBleSensorGattAttributes();
                bleDataCharacteristic.enableValueNotifications(sensorSignal -> sensorSignalProcessor.processSignal(sensorSignal));
            } catch (BluetoothServiceNotFoundException | BluetoothCharacteristicNotFoundException e) {
                System.out.println(e);
            }
        }
    };

    private void getBleSensorGattAttributes() throws BluetoothServiceNotFoundException, BluetoothCharacteristicNotFoundException {
        if ((bleDataService = bleSensor.find(DATA_SERVICE_UUID, Duration.ofMillis(2000))) == null)
            throw new BluetoothServiceNotFoundException("Cannot find data service UUID=[" + DATA_SERVICE_UUID + "]");

        if ((bleDataCharacteristic = bleDataService.find(DATA_CHARACTERISTIC_UUID, Duration.ofMillis(2000))) == null)
            throw new BluetoothCharacteristicNotFoundException("Cannot find data characteristic UUID=[" + DATA_CHARACTERISTIC_UUID + "]");

    }

    // TinyB Callback: Print connection status only
    BluetoothNotification<Boolean> connectedNotificationsCallback = isConnected -> System.out.println("Sensor (BLE) is " + (isConnected ? "connected" : "disconnected"));

    // Consider moving to utils
    private void waitSeconds(final long delaySec) {
        try {
            Thread.sleep(delaySec * 1000);
        } catch (InterruptedException e) {
            // do nothing
        }
    }
}

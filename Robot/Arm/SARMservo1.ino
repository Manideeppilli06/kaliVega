#include <ESP32Servo.h>
#include "BluetoothSerial.h"

BluetoothSerial SerialBT;

Servo servo1;
Servo servo2;

void setup() {
  Serial.begin(115200);
  SerialBT.begin("ROBO_ARM");

  servo1.attach(13);  // Servo 1 pin
  servo2.attach(12);  // Servo 2 pin

  servo1.write(70);
  servo2.write(45);

  Serial.println("Bluetooth ready!");
  Serial.println("Use commands like: S1 120, S2 45");
}

void loop() { 
  if (SerialBT.available()) {
    String cmd = SerialBT.readStringUntil('\n');
    cmd.trim();

    // ======== SERVO 1 ========
    if (cmd.startsWith("S1")) {
      int angle = cmd.substring(2).toInt();
      angle = constrain(angle, 0, 180);
      servo1.write(angle);
      SerialBT.printf("Servo1 -> %d°\n", angle);
    }

    // ======== SERVO 2 ========
    else if (cmd.startsWith("S2")) {
      int angle = cmd.substring(2).toInt();
      angle = constrain(angle, 0, 180);
      servo2.write(angle);
      SerialBT.printf("Servo2 -> %d°\n", angle);
    }
  }
}
